-- Catalog.lua
-- Self-describing registry for MCP/agent discovery

local FenCore = _G.FenCore

---@class CatalogEntry
---@field handler function The actual function
---@field description string What this function does
---@field params table[] Parameter definitions
---@field returns table Return type definition
---@field example? string Example usage

local Catalog = {
    _registry = {},  -- { domainName = { funcName = CatalogEntry } }
}

--- Register a domain with its functions.
---@param domainName string Name of the domain (e.g., "Math")
---@param functions table Map of funcName -> CatalogEntry
function Catalog:RegisterDomain(domainName, functions)
    self._registry[domainName] = functions

    -- Also wire up FenCore.DomainName.FuncName shortcuts
    if not FenCore[domainName] then
        FenCore[domainName] = {}
    end

    for funcName, entry in pairs(functions) do
        if entry.handler then
            FenCore[domainName][funcName] = entry.handler
        end
    end

    FenCore:Log("Registered domain: " .. domainName, "[Catalog]")
end

--- Get full catalog of all registered functions.
--- Used by MCP for agent discovery.
---@return table Structured catalog
function Catalog:GetCatalog()
    local catalog = {
        version = FenCore.version,
        domains = {},
    }

    for domainName, functions in pairs(self._registry) do
        catalog.domains[domainName] = {
            functions = {}
        }

        for funcName, entry in pairs(functions) do
            catalog.domains[domainName].functions[funcName] = {
                description = entry.description,
                params = entry.params,
                returns = entry.returns,
                example = entry.example,
            }
        end
    end

    return catalog
end

--- Search functions by name or description.
---@param query string Search query (partial match)
---@return table[] Matching functions
function Catalog:Search(query)
    local results = {}
    local queryLower = query:lower()

    for domainName, functions in pairs(self._registry) do
        for funcName, entry in pairs(functions) do
            local fullName = domainName .. "." .. funcName
            local matchName = fullName:lower():find(queryLower, 1, true)
            local matchDesc = entry.description and entry.description:lower():find(queryLower, 1, true)

            if matchName or matchDesc then
                table.insert(results, {
                    domain = domainName,
                    name = funcName,
                    fullName = fullName,
                    description = entry.description,
                    params = entry.params,
                    returns = entry.returns,
                })
            end
        end
    end

    return results
end

--- Get info about a specific function.
---@param domainName string Domain name
---@param funcName string Function name
---@return CatalogEntry|nil
function Catalog:GetInfo(domainName, funcName)
    local domain = self._registry[domainName]
    if domain then
        return domain[funcName]
    end
    return nil
end

--- Get list of all domain names.
---@return string[]
function Catalog:GetDomains()
    local domains = {}
    for name in pairs(self._registry) do
        table.insert(domains, name)
    end
    table.sort(domains)
    return domains
end

-- Convenience wrapper for FenCore:GetCatalog()
function FenCore:GetCatalog()
    return Catalog:GetCatalog()
end

function FenCore:SearchCatalog(query)
    return Catalog:Search(query)
end

FenCore.Catalog = Catalog
return Catalog
