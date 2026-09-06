#!/usr/bin/env python3
"""Validate the files that make up the Flightsim addon package.

This intentionally uses only the Python standard library so it can run in a
fresh checkout on CI and on a developer machine.  In particular, pathlib's
``exists`` is not enough for this job on Windows: Windows file lookup is
case-insensitive while WoW's manifest paths are case-sensitive in release
packaging.  ``resolve_exact`` therefore walks each directory entry and checks
the spelling of every path component.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath


TOC_PATH = "flightsim.toc"
LOCALE_DIR = "Locales"
FIRST_PARTY_EXCLUDES = {"Libs", "Tests"}
LOCALE_KEY_RE = re.compile(r"\bL\s*\[\s*([\"'])([^\"']+)\1\s*\]\s*=")
L_USAGE_RE = re.compile(r"(?:\bL|\bFlightsim\.L)\s*\[\s*([\"'])([^\"']+)\1\s*\]")
LOCALE_GUARD_RE = re.compile(
    r'^\s*if\s+GetLocale\s*\(\s*\)\s*~=\s*([\"\'])([^\"\']+)\1\s+then\s*$'
)


class ValidationError(Exception):
    """A user-facing repository validation failure."""


def display(path: Path, root: Path) -> str:
    """Return a stable repository-relative path for diagnostics."""

    return path.relative_to(root).as_posix()


def exact_child(directory: Path, name: str) -> Path | None:
    """Find ``name`` in ``directory`` with exact spelling, if present."""

    try:
        with os.scandir(directory) as entries:
            for entry in entries:
                if entry.name == name:
                    return directory / entry.name
    except OSError:
        return None
    return None


def resolve_exact(base: Path, reference: str, boundary: Path | None = None) -> Path:
    """Resolve a WoW slash or backslash path without case folding.

    ``reference`` may contain ``..`` for an XML file including a sibling
    directory, but it must remain inside the repository root.  Absolute paths,
    empty references, and directory targets are rejected by callers when
    appropriate.
    """

    normalized = reference.strip().replace("\\", "/")
    if not normalized or normalized.startswith("/"):
        raise ValidationError(f"invalid absolute or empty path: {reference!r}")

    parts = PurePosixPath(normalized).parts
    boundary = boundary or base
    current = base
    for part in parts:
        if part in ("", "."):
            continue
        if part == "..":
            if current == boundary:
                raise ValidationError(f"path escapes repository root: {reference!r}")
            current = current.parent
            continue
        child = exact_child(current, part)
        if child is None:
            raise ValidationError(f"missing or incorrectly cased path: {reference!r}")
        current = child

    if current == base:
        raise ValidationError(f"path resolves to repository root: {reference!r}")
    return current


def parse_toc(root: Path) -> list[tuple[str, Path]]:
    """Parse and resolve all non-comment entries in the addon TOC."""

    try:
        toc = resolve_exact(root, TOC_PATH)
    except ValidationError as error:
        raise ValidationError(f"missing or incorrectly cased {TOC_PATH}: {error}") from error
    if not toc.is_file():
        raise ValidationError(f"{TOC_PATH} is not a file")

    entries: list[tuple[str, Path]] = []
    seen: set[str] = set()
    for line_number, raw_line in enumerate(toc.read_text(encoding="utf-8-sig").splitlines(), 1):
        entry = raw_line.strip()
        if not entry or entry.startswith("#"):
            continue
        try:
            resolved = resolve_exact(root, entry)
        except ValidationError as error:
            raise ValidationError(f"{TOC_PATH}:{line_number}: {error}") from error
        if not resolved.is_file():
            raise ValidationError(f"{TOC_PATH}:{line_number}: path is not a file: {entry!r}")
        normalized = PurePosixPath(entry.replace("\\", "/")).as_posix()
        if normalized in seen:
            raise ValidationError(f"{TOC_PATH}:{line_number}: duplicate entry: {entry!r}")
        seen.add(normalized)
        entries.append((entry, resolved))
    return entries


def xml_local_name(tag: str) -> str:
    """Get an XML tag's local name, ignoring an optional namespace."""

    return tag.rsplit("}", 1)[-1].lower()


def validate_xml(root: Path, xml_path: Path, visited: set[Path]) -> int:
    """Validate XML file references recursively and return reference count."""

    xml_path = xml_path.resolve()
    if xml_path in visited:
        return 0
    visited.add(xml_path)
    try:
        document = ET.parse(xml_path)
    except ET.ParseError as error:
        raise ValidationError(f"{display(xml_path, root)}: invalid XML: {error}") from error

    reference_count = 0
    for element in document.getroot().iter():
        reference = element.attrib.get("file")
        if reference is None:
            continue
        reference_count += 1
        try:
            target = resolve_exact(xml_path.parent, reference, root)
        except ValidationError as error:
            raise ValidationError(
                f"{display(xml_path, root)} <{xml_local_name(element.tag)}> file={reference!r}: {error}"
            ) from error
        if not target.is_file():
            raise ValidationError(
                f"{display(xml_path, root)} <{xml_local_name(element.tag)}> file is not a file: {reference!r}"
            )
        if target.suffix.lower() == ".xml":
            reference_count += validate_xml(root, target, visited)
    return reference_count


def source_files(root: Path) -> list[Path]:
    """Return tracked-style first-party Lua paths, excluding tests and libs."""

    files: list[Path] = []
    for path in root.rglob("*.lua"):
        relative = path.relative_to(root)
        if any(part in FIRST_PARTY_EXCLUDES for part in relative.parts):
            continue
        if ".git" in relative.parts:
            continue
        files.append(path)
    return sorted(files)


def locale_keys(path: Path) -> tuple[list[str], set[str], list[str]]:
    """Extract locale assignments, preserving duplicates for diagnostics."""

    text = path.read_text(encoding="utf-8")
    keys = [match.group(2) for match in LOCALE_KEY_RE.finditer(text)]
    duplicates = sorted({key for key in keys if keys.count(key) > 1})
    return keys, set(keys), duplicates


def validate_locales(root: Path) -> tuple[int, int]:
    """Check locale guards, duplicate keys, parity, and runtime key usage."""

    try:
        locale_dir = resolve_exact(root, LOCALE_DIR)
    except ValidationError as error:
        raise ValidationError(f"missing or incorrectly cased {LOCALE_DIR}/ directory: {error}") from error
    if not locale_dir.is_dir():
        raise ValidationError(f"missing {LOCALE_DIR}/ directory")
    files = sorted(locale_dir.glob("*.lua"))
    if not files:
        raise ValidationError(f"no locale files found in {LOCALE_DIR}/")

    by_locale: dict[str, tuple[Path, set[str]]] = {}
    for path in files:
        locale = path.stem
        keys, key_set, duplicates = locale_keys(path)
        if duplicates:
            raise ValidationError(f"{display(path, root)}: duplicate keys: {', '.join(duplicates)}")
        if locale != "enUS":
            lines = path.read_text(encoding="utf-8").splitlines()
            guard_index = None
            for index, line in enumerate(lines[:12]):
                match = LOCALE_GUARD_RE.match(line)
                if match and match.group(2) == locale:
                    guard_index = index
                    break
            if guard_index is None:
                raise ValidationError(
                    f"{display(path, root)}: expected GetLocale() guard for {locale!r} near file start"
                )
            guarded_lines = lines[guard_index + 1 : guard_index + 5]
            if not any(line.strip() == "return" for line in guarded_lines):
                raise ValidationError(
                    f"{display(path, root)}: locale guard for {locale!r} must return before translations"
                )
        by_locale[locale] = (path, key_set)

    if "enUS" not in by_locale:
        raise ValidationError(f"{LOCALE_DIR}/enUS.lua is required as the baseline locale")
    baseline = by_locale["enUS"][1]
    parity_errors: list[str] = []
    for locale, (path, keys) in sorted(by_locale.items()):
        missing = sorted(baseline - keys)
        extra = sorted(keys - baseline)
        if missing or extra:
            details = []
            if missing:
                details.append(f"missing: {', '.join(missing)}")
            if extra:
                details.append(f"extra: {', '.join(extra)}")
            parity_errors.append(f"{display(path, root)} ({'; '.join(details)})")
    if parity_errors:
        raise ValidationError("locale key parity failed: " + " | ".join(parity_errors))

    usages: dict[str, list[str]] = {}
    for path in source_files(root):
        text = path.read_text(encoding="utf-8")
        for match in L_USAGE_RE.finditer(text):
            usages.setdefault(match.group(2), []).append(display(path, root))
    missing_usage = sorted(set(usages) - baseline)
    if missing_usage:
        locations = ", ".join(f"{key} ({', '.join(sorted(set(usages[key])))})" for key in missing_usage)
        raise ValidationError(f"L usages missing from {LOCALE_DIR}/enUS.lua: {locations}")
    return len(files), len(usages)


def validate_repository(root: Path) -> tuple[int, int, int, int]:
    """Run all checks and return TOC/XML/locale/usage counts."""

    toc_entries = parse_toc(root)
    toc_paths = {path.resolve() for _, path in toc_entries}
    locale_dir = resolve_exact(root, LOCALE_DIR)
    for locale_path in sorted(locale_dir.glob("*.lua")):
        if locale_path.resolve() not in toc_paths:
            raise ValidationError(f"locale is not listed in {TOC_PATH}: {display(locale_path, root)}")
    visited_xml: set[Path] = set()
    xml_references = 0
    for _, path in toc_entries:
        if path.suffix.lower() == ".xml":
            xml_references += validate_xml(root, path, visited_xml)
    locale_count, usage_count = validate_locales(root)
    return len(toc_entries), xml_references, locale_count, usage_count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the parent of Tests/)",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        toc_count, xml_count, locale_count, usage_count = validate_repository(root)
    except (OSError, UnicodeError, ValidationError) as error:
        print(f"REPO_VALIDATION_FAILED: {error}", file=sys.stderr)
        return 1
    print(
        "REPO_VALIDATION_OK: "
        f"{toc_count} TOC files, {xml_count} XML references, "
        f"{locale_count} locales, {usage_count} extracted locale keys"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
