if GetLocale() ~= "ruRU" then
	return
end

local L = Flightsim.L

-- Russian (Русский)
-- Translated from enUS baseline

L["NOT_INITIALIZED_YET"] = "Flightsim: ещё не инициализирован."
L["LOCKED"] = "Flightsim: заблокирован"
L["UNLOCKED"] = "Flightsim: разблокирован (перетащите рамку для перемещения)"
L["USAGE_SCALE"] = "Flightsim: использование: /flightsim scale 1.0"
L["SCALE_SET"] = "Flightsim: масштаб установлен"
L["USAGE_WIDTH"] = "Flightsim: использование: /flightsim width 320"
L["WIDTH_SET"] = "Flightsim: ширина установлена"
L["USAGE_BARMAX"] = "Flightsim: использование: /flightsim barmax 930"
L["BARMAX_SET"] = "Flightsim: максимум полосы скорости установлен"
L["USAGE_SUSTAINABLE"] =
	"Flightsim: использование: /flightsim sustainable 0   (0 скрывает маркер)"
L["SUSTAINABLE_SET"] = "Flightsim: маркер устойчивой скорости установлен"
L["HIDE_NOT_SKYRIDING"] = "Flightsim: будет скрыт, когда НЕ в полёте по небу"
L["HIDE_WHILE_SKYRIDING"] = "Flightsim: будет скрыт во время полёта по небу"
L["SHOW_ALWAYS"] = "Flightsim: будет всегда отображаться"
L["ABILITY_TOGGLED"] = "Flightsim: %s %s"
L["ABILITY_NOT_FOUND"] = "Flightsim: способность не найдена. Попробуйте /flightsim list"
L["ABILITIES_LIST"] = "Способности Flightsim:"
L["USAGE_MOVE"] = "Flightsim: использование: /flightsim move <способность> <индекс>"
L["ORDER_UPDATED"] = "Flightsim: порядок способностей обновлён"
L["DEBUG_NOT_AVAILABLE"] =
	"Flightsim: отладка недоступна (UI ещё не инициализирован)"
L["STATUS_NOT_AVAILABLE"] =
	"Flightsim: статус недоступен (UI ещё не инициализирован)"
L["RESET_DONE"] = "Flightsim: позиция/масштаб сброшены"
L["COMMANDS_HELP"] = "Команды Flightsim:"

-- Settings
L["LOCK_FRAME"] = "Заблокировать рамку"
L["LOCK_FRAME_DESC"] = "Запрещает перетаскивание рамки Flightsim."
L["ONLY_SKYRIDING"] = "Показывать только при полёте по небу"
L["ONLY_SKYRIDING_DESC"] =
	"Скрывает рамку, когда не на средстве передвижения для полёта по небу."
L["SCALE"] = "Масштаб"
L["SCALE_DESC"] = "Общий масштаб рамки Flightsim."
L["BAR_WIDTH"] = "Ширина полосы"
L["BAR_WIDTH_DESC"] = "Ширина всех полос."
L["FONT_SIZE"] = "Размер шрифта"
L["FONT_SIZE_DESC"] = "Размер шрифта для текста скорости."
L["SHOW_PERCENT"] = "Показывать скорость в процентах"
L["SHOW_PERCENT_DESC"] =
	"Показывает скорость в процентах (напр. 78%) вместо исходного значения."
L["HEIGHT"] = "Высота"
L["SPEED_BAR_HEIGHT_DESC"] = "Высота полосы скорости."
L["SUSTAIN_MARKER_WIDTH"] = "Ширина маркера устойчивости"
L["SUSTAIN_MARKER_WIDTH_DESC"] = "Ширина линии маркера устойчивой скорости."
L["SUSTAIN_MARKER_ALPHA"] = "Непрозрачность маркера устойчивости"
L["SUSTAIN_MARKER_ALPHA_DESC"] =
	"Непрозрачность маркера устойчивой скорости (0.1-1.0)."
L["ACCEL_BAR_HEIGHT_DESC"] = "Высота полосы индикатора ускорения."
L["ABILITY_BAR_HEIGHT_DESC"] = "Высота полос перезарядки способностей."
L["BAR_GAP"] = "Расстояние между секциями"
L["BAR_GAP_DESC"] =
	"Расстояние между секциями зарядов полос способностей."
L["SHOW_SURGE_FORWARD"] = "Показать Рывок вперёд"
L["SHOW_SURGE_FORWARD_DESC"] =
	"Показывает полосу зарядов Рывка вперёд (6 зарядов)."
L["SHOW_SECOND_WIND"] = "Показать Второе дыхание"
L["SHOW_SECOND_WIND_DESC"] =
	"Показывает полосу зарядов Второго дыхания (3 заряда)."
L["SHOW_WHIRLING_SURGE"] = "Показать Вихревой рывок"
L["SHOW_WHIRLING_SURGE_DESC"] =
	"Показывает полосу перезарядки Вихревого рывка (30с)."

-- UI / Debug
L["VISIBILITY_ERROR"] = "Flightsim: ошибка видимости при переходе: "
L["UPDATE_LOOP_ERROR"] = "Flightsim: ошибка цикла обновления: "
L["DEBUG_KV"] = "Flightsim отладка: %s = %s"
L["DEBUG_HEADER"] = "Flightsim отладка: ----"
L["DEBUG_DB_NOT_INIT"] = "Flightsim отладка: БД не инициализирована"
L["DEBUG_ABILITIES_HEADER"] = "Flightsim отладка: способности ----"
L["DEBUG_ABILITY_FORMAT"] =
	"Flightsim отладка: %d) %s включено=%s spellID=%s иконка=%s заряды=%s/%s"
L["DEBUG_FOOTER"] = "Flightsim отладка: ---- конец"
L["STATUS_NOT_INIT"] = "Flightsim: не инициализирован"
L["SHOWN"] = "показан"
L["HIDDEN"] = "скрыт"
L["SKYRIDING"] = "полёт по небу"
L["NOT_SKYRIDING"] = "не полёт по небу"
L["CHARGES_DISABLED"] = "UI зарядов отключён"
L["OPTIMAL_FORMAT"] = "оптимально %.1f"
L["OPTIMAL_OFF"] = "оптимально выкл"
L["STATUS_FORMAT"] = "Flightsim: %s, рамка %s, скорость %.1f (макс %.1f, %s), %s"

L["SHOW_GROUND_MOUNTED"] = "Показывать на земле"
L["SHOW_GROUND_MOUNTED_DESC"] =
	"Также показывает интерфейс, если вы на средстве передвижения для полёта по небу, но ещё находитесь на земле."
L["SHOW_THRILL_OF_THE_SKIES"] = "Восторг небес"
L["SHOW_THRILL_OF_THE_SKIES_DESC"] =
	"Показывает круглый индикатор, когда действует «Восторг небес» (быстрое пикирование ускоряет восстановление зарядов)."
L["SHOW_GROUND_SKIMMING"] = "Полёт у земли"
L["SHOW_GROUND_SKIMMING_DESC"] =
	"Показывает круглый индикатор, когда действует «Полёт у земли» (полёт близко к земле ускоряет восстановление зарядов)."

-- Полоса наклона
L["PITCH_BAR"] = "Полоса наклона"
L["PITCH_BAR_ENABLED"] = "Включить полосу наклона"
L["PITCH_BAR_ENABLED_DESC"] =
	"Показывает полосу направления наклона под полосой ускорения."
L["PITCH_BAR_HEIGHT"] = "Высота полосы"
L["PITCH_DYNAMIC_COLOR"] = "Динамический цвет"
L["PITCH_COLOR_DIVING"] = "Пикирование"
L["PITCH_COLOR_CLIMBING"] = "Набор высоты"

-- Названия и описания настроек
L["SETTINGS_GENERAL"] = "Общие"
L["SETTINGS_APPEARANCE"] = "Внешний вид"
L["SETTINGS_BACKGROUND"] = "Фон"
L["SETTINGS_BACKGROUND_DESC"] = "Цвет фона за полосами способностей."
L["SETTINGS_VISIBILITY"] = "Видимость"
L["SETTINGS_BORDER"] = "Рамка"
L["SETTINGS_BORDER_COLOR"] = "Цвет рамки"
L["SETTINGS_BORDER_COLOR_DESC"] = "Цвет рамки вокруг интерфейса."
L["SETTINGS_BORDER_WIDTH"] = "Ширина рамки"
L["SETTINGS_BORDER_WIDTH_DESC"] = "Ширина рамки вокруг интерфейса (0 = без рамки)."
L["SETTINGS_SPEED_BAR"] = "Полоса скорости"
L["SETTINGS_TEXT_DISPLAY"] = "Отображение текста"
L["SETTINGS_FONT"] = "Шрифт"
L["SETTINGS_FONT_DESC"] = "Шрифт текста скорости."
L["SETTINGS_OUTLINE"] = "Контур"
L["SETTINGS_OUTLINE_DESC"] = "Стиль контура текста."
L["SETTINGS_SUSTAIN_MARKER"] = "Маркер устойчивой скорости"
L["SETTINGS_SHOW_SUSTAIN_MARKER"] = "Показывать маркер устойчивой скорости"
L["SETTINGS_SUSTAIN_MARKER_DESC"] =
	"Показывает вертикальную линию на уровне устойчивой скорости полёта."
L["SETTINGS_COLORS"] = "Цвета"
L["SETTINGS_USE_CUSTOM_COLORS"] = "Использовать свои цвета"
L["SETTINGS_CUSTOM_COLORS_DESC"] =
	"Использует собственные цвета полосы скорости вместо стандартного градиента."
L["SETTINGS_LOW_SPEED_COLOR"] = "Низкая скорость (0%)"
L["SETTINGS_LOW_SPEED_COLOR_DESC"] = "Цвет при минимальной скорости."
L["SETTINGS_MID_SPEED_COLOR"] = "Средняя скорость (50%)"
L["SETTINGS_MID_SPEED_COLOR_DESC"] = "Цвет при половинной скорости."
L["SETTINGS_HIGH_SPEED_COLOR"] = "Высокая скорость (100%)"
L["SETTINGS_HIGH_SPEED_COLOR_DESC"] = "Цвет при максимальной скорости."
L["SETTINGS_SOLID_COLOR_TIP"] =
	"|cff888888Совет: задайте один цвет для всех трёх уровней, чтобы полоса была одноцветной.|r"
L["SETTINGS_ACCELERATION_BAR"] = "Полоса ускорения"
L["SETTINGS_ACCELERATION_DESCRIPTION"] =
	"Полоса ускорения показывает, набираете вы скорость или замедляетесь. При разгоне полоса заполняется вправо, при замедлении — влево.\n\nОна не показывает наклон, высоту или направление — только скорость изменения движения."
L["SETTINGS_DYNAMIC_COLORS"] = "Динамические цвета"
L["SETTINGS_DYNAMIC_COLORS_DESC"] =
	"Меняет цвет в зависимости от направления изменения скорости."
L["SETTINGS_DECELERATION"] = "Замедление"
L["SETTINGS_DECELERATION_COLOR_DESC"] = "Цвет при потере скорости."
L["SETTINGS_ACCELERATION"] = "Ускорение"
L["SETTINGS_ACCELERATION_COLOR_DESC"] = "Цвет при наборе скорости."
L["SETTINGS_ABILITY_BARS"] = "Полосы способностей"
L["SETTINGS_SURGE_FORWARD"] = "Рывок вперёд"
L["SETTINGS_SURGE_COLOR_DESC"] = "Цвет полосы зарядов «Рывка вперёд»."
L["SETTINGS_SECOND_WIND"] = "Второе дыхание"
L["SETTINGS_WIND_COLOR_DESC"] = "Цвет полосы зарядов «Второго дыхания»."
L["SETTINGS_WHIRLING_SURGE"] = "Вихревой рывок"
L["SETTINGS_WHIRL_COLOR_DESC"] = "Цвет полосы перезарядки «Вихревого рывка»."
L["SETTINGS_BACKGROUND_COLORS"] = "Цвета фона"
L["SETTINGS_SURGE_ROW_BG"] = "Фон ряда «Рывка вперёд»"
L["SETTINGS_SURGE_ROW_BG_DESC"] =
	"Цвет фона всего ряда «Рывка вперёд» за всеми зарядами. Альфа 0 делает фон прозрачным."
L["SETTINGS_SURGE_BAR_BG"] = "Фон полосы «Рывка вперёд»"
L["SETTINGS_SURGE_BAR_BG_DESC"] =
	"Цвет фона отдельных полос зарядов «Рывка вперёд», видимый при восстановлении."
L["SETTINGS_WIND_ROW_BG"] = "Фон ряда «Второго дыхания»"
L["SETTINGS_WIND_ROW_BG_DESC"] =
	"Цвет фона всего ряда «Второго дыхания» за всеми зарядами. Альфа 0 делает фон прозрачным."
L["SETTINGS_WIND_BAR_BG"] = "Фон полосы «Второго дыхания»"
L["SETTINGS_WIND_BAR_BG_DESC"] =
	"Цвет фона отдельных полос зарядов «Второго дыхания», видимый при восстановлении."
L["SETTINGS_WHIRL_BAR_BG"] = "Фон полосы «Вихревого рывка»"
L["SETTINGS_WHIRL_BAR_BG_DESC"] =
	"Цвет фона полосы «Вихревого рывка», видимый во время перезарядки."
L["SETTINGS_BUFF_INDICATORS"] = "Индикаторы усилений"
L["SETTINGS_BUFF_DESCRIPTION"] =
	"Небольшие круглые индикаторы появляются по сторонам полосы скорости, когда действуют усиления восстановления зарядов.\n\n|cffffd100Восторг небес|r — срабатывает при быстром пикировании\n|cff4de64dПолёт у земли|r — срабатывает при полёте близко к земле"
L["SETTINGS_SIZE"] = "Размер"
L["SETTINGS_INDICATOR_SIZE"] = "Размер индикатора"
L["SETTINGS_INDICATOR_SIZE_DESC"] =
	"Диаметр круглых индикаторов усилений в пикселях."
L["SETTINGS_THRILL_COLOR_DESC"] = "Цвет круглого индикатора «Восторга небес»."
L["SETTINGS_SKIM_COLOR_DESC"] = "Цвет круглого индикатора «Полёта у земли»."
L["SETTINGS_PITCH_DESCRIPTION"] =
	"Показывает под полосой ускорения двунаправленную полосу устойчивого наклона.\n\n|cffffd100Центр|r = горизонтальный полёт\n|cff74afffСправа|r = пикирование\n|cffff8033Слева|r = набор высоты\n\nВ качестве приближённого значения используются сильно сглаженные изменения скорости, поскольку прямого API наклона нет."
L["SETTINGS_PITCH_HEIGHT_DESC"] = "Высота полосы наклона в пикселях."
L["SETTINGS_PITCH_DYNAMIC_DESC"] =
	"Меняет цвет полосы наклона в зависимости от направления (пикирование или набор высоты)."
L["SETTINGS_DIVING_COLOR_DESC"] = "Цвет при пикировании (нос вниз)."
L["SETTINGS_CLIMBING_COLOR_DESC"] = "Цвет при наборе высоты (нос вверх)."
L["SETTINGS_NONE"] = "Нет"
L["SETTINGS_THICK_OUTLINE"] = "Толстый контур"
