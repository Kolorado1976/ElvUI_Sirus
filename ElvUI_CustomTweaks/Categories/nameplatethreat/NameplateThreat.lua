local E, L, V, P, G = unpack(ElvUI)
local NP = E:GetModule("NamePlates")
local CT = E:GetModule("CustomTweaks")
local isEnabled = E.private["CustomTweaks"] and E.private["CustomTweaks"]["NameplateThreat"] and true or false

-- Настройки по умолчанию
P["CustomTweaks"]["NameplateThreat"] = {
    enabled = false,
    useColor = true,
    useText = false,
    textSize = 10,
    useClassColor = false,
    textColor = {r = 1, g = 1, b = 1},
    threatColor = {
        [1] = {r = 0.47, g = 0.6, b = 0.15},   -- Низкая угроза
        [2] = {r = 1, g = 0.6, b = 0},         -- Средняя угроза
        [3] = {r = 1, g = 0, b = 0},           -- Высокая угроза (танк)
    }
}

-- Кэшируем функции
local UnitExists, UnitIsUnit, UnitThreatSituation, UnitClass = 
      UnitExists, UnitIsUnit, UnitThreatSituation, UnitClass
local unpack, pairs = unpack, pairs

local UPDATE_THROTTLE = 0.1
local lastUpdate = 0

-- Локальные функции
local function UpdateThreat(frame)
    if not E.db.CustomTweaks.NameplateThreat.enabled then return end
    
    local now = GetTime()
    if now - lastUpdate < UPDATE_THROTTLE then return end
    lastUpdate = now
    
    local unit = frame.unit
    if not unit or not UnitExists(unit) or UnitIsUnit(unit, "player") then
        ClearThreat(frame)
        return
    end

    local status = UnitThreatSituation("player", unit)
    local settings = E.db.CustomTweaks.NameplateThreat
    
    if status and status > 0 then
        ApplyThreat(frame, status, settings)
    else
        ClearThreat(frame)
    end
end

local function ApplyThreat(frame, status, settings)
    local r, g, b
    
    if settings.useClassColor then
        local _, class = UnitClass(frame.unit)
        if class then
            local color = E:ClassColor(class)
            if color then
                r, g, b = color.r, color.g, color.b
            else
                -- Используем стандартные цвета угрозы
                if status == 1 then
                    r, g, b = 0.47, 0.6, 0.15
                elseif status == 2 then
                    r, g, b = 1, 0.6, 0
                else -- status == 3
                    r, g, b = 1, 0, 0
                end
            end
        else
            -- Используем стандартные цвета угрозы
            if status == 1 then
                r, g, b = 0.47, 0.6, 0.15
            elseif status == 2 then
                r, g, b = 1, 0.6, 0
            else -- status == 3
                r, g, b = 1, 0, 0
            end
        end
    else
        local color = settings.threatColor[status] or settings.threatColor[3]
        r, g, b = color.r, color.g, color.b
    end
    
    if settings.useColor then
        frame.Health:SetStatusBarColor(r, g, b)
        if frame.Health.backdrop then
            frame.Health.backdrop:SetBackdropBorderColor(r, g, b)
        end
    end
    
    if settings.useText then
        if not frame.CustomTweaksThreatText then
            frame.CustomTweaksThreatText = frame.Health:CreateFontString(nil, "OVERLAY")
            frame.CustomTweaksThreatText:SetPoint("CENTER", frame.Health, "CENTER", 0, 0)
            frame.CustomTweaksThreatText:FontTemplate()
        end
        
        frame.CustomTweaksThreatText:SetText(status == 3 and "TANK" or "THREAT")
        local textColor = settings.textColor
        frame.CustomTweaksThreatText:SetTextColor(textColor.r, textColor.g, textColor.b)
        frame.CustomTweaksThreatText:SetFont(nil, settings.textSize, "OUTLINE")
        frame.CustomTweaksThreatText:Show()
    end
    
    if not frame.ThreatIndicator then
        frame.ThreatIndicator = frame.Health:CreateTexture(nil, "OVERLAY")
        frame.ThreatIndicator:SetTexture(E.Media.Textures.White8x8)
        frame.ThreatIndicator:SetSize(6, 6)
        frame.ThreatIndicator:SetPoint("TOP", frame.Health, "TOP", 0, 1)
    end
    frame.ThreatIndicator:SetVertexColor(r, g, b)
    frame.ThreatIndicator:Show()
end

local function ClearThreat(frame)
    if frame.CustomTweaksThreatText then
        frame.CustomTweaksThreatText:Hide()
    end
    
    if frame.ThreatIndicator then
        frame.ThreatIndicator:Hide()
    end
    
    if E.db.CustomTweaks.NameplateThreat.useColor then
        -- Возвращаем оригинальный цвет здоровья
        local color = NP.db.colors.healthColor or {r = 0.2, g = 0.2, b = 0.2}
        frame.Health:SetStatusBarColor(color.r, color.g, color.b)
        
        if frame.Health.backdrop then
            frame.Health.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
        end
    end
end

-- Основная функция для обновления всех видимых неймплейтов
local function UpdateAllVisibleNameplates()
    if not E.db.CustomTweaks.NameplateThreat.enabled then return end
    
    for frame in pairs(NP.VisiblePlates) do
        if frame and frame.unit then
            UpdateThreat(frame)
        end
    end
end

-- Функция для хуков
local function HookNameplates()
    -- Хук на функцию обновления всех элементов неймплейта
    hooksecurefunc(NP, "UpdateElement_All", function(_, frame)
        UpdateThreat(frame)
    end)
    
    -- Хук на функцию обновления здоровья
    hooksecurefunc(NP, "Update_HealthColor", function(_, frame)
        UpdateThreat(frame)
    end)
    
    -- Обновляем все уже видимые неймплейты
    UpdateAllVisibleNameplates()
end

local function UpdateSettings()
    E.private.CustomTweaks.NameplateThreat = E.private.CustomTweaks.NameplateThreat or false
    E.db.CustomTweaks.NameplateThreat = E.db.CustomTweaks.NameplateThreat or P["CustomTweaks"]["NameplateThreat"]
    
    if E.db.CustomTweaks.NameplateThreat.enabled then
        HookNameplates()
    else
        -- Если твик выключен, очищаем все индикаторы
        for frame in pairs(NP.VisiblePlates) do
            ClearThreat(frame)
        end
    end
    
    -- Обновляем все неймплейты
    UpdateAllVisibleNameplates()
end

-- Функция конфигурации
local function ConfigTable()
    -- Добавляем настройки в уже существующую категорию Nameplate
    E.Options.args.CustomTweaks.args.Nameplate.args.options.args.NameplateThreat = {
        type = "group",
        name = "Nameplate Threat",
        order = 1,
        get = function(info) 
            return E.db.CustomTweaks.NameplateThreat[info[#info]] 
        end,
        set = function(info, value) 
            E.db.CustomTweaks.NameplateThreat[info[#info]] = value
            UpdateSettings()
        end,
        args = {
            header = {
                type = "header",
                order = 1,
                name = "Nameplate Threat Settings",
            },
            enabled = {
                type = 'toggle',
                order = 2,
                name = "Enable Threat Indicator",
                desc = "Отображает индикатор уровня угрозы на неймлейтах.",
                disabled = function() return not isEnabled end,
            },
            useColor = {
                type = 'toggle',
                order = 3,
                name = "Color Nameplate",
                desc = "Окрашивать неймлейт в цвет угрозы",
                disabled = function() return not isEnabled end,
            },
            useText = {
                type = 'toggle',
                order = 4,
                name = "Show Text",
                desc = "Показывать текст угрозы",
                disabled = function() return not isEnabled end,
            },
            useClassColor = {
                type = 'toggle',
                order = 5,
                name = "Use Class Color",
                desc = "Использовать цвет класса вместо стандартных цветов угрозы",
                disabled = function() return not isEnabled end,
            },
            textSize = {
                type = 'range',
                order = 6,
                name = "Text Size",
                desc = "Размер текста угрозы",
                min = 8, max = 24, step = 1,
                disabled = function() 
                    return not isEnabled or not E.db.CustomTweaks.NameplateThreat.useText 
                end,
            },
            threatColor1 = {
                type = "color",
                order = 10,
                name = "Low Threat",
                desc = "Цвет для низкого уровня угрозы",
                hasAlpha = false,
                disabled = function() 
                    return not isEnabled or E.db.CustomTweaks.NameplateThreat.useClassColor 
                end,
                get = function(info)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[1]
                    return c.r, c.g, c.b
                end,
                set = function(info, r, g, b)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[1]
                    c.r, c.g, c.b = r, g, b
                    UpdateSettings()
                end
            },
            threatColor2 = {
                type = "color",
                order = 11,
                name = "Medium Threat",
                desc = "Цвет для среднего уровня угрозы",
                hasAlpha = false,
                disabled = function() 
                    return not isEnabled or E.db.CustomTweaks.NameplateThreat.useClassColor 
                end,
                get = function(info)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[2]
                    return c.r, c.g, c.b
                end,
                set = function(info, r, g, b)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[2]
                    c.r, c.g, c.b = r, g, b
                    UpdateSettings()
                end
            },
            threatColor3 = {
                type = "color",
                order = 12,
                name = "High Threat (Tank)",
                desc = "Цвет для высокого уровня угрозы",
                hasAlpha = false,
                disabled = function() 
                    return not isEnabled or E.db.CustomTweaks.NameplateThreat.useClassColor 
                end,
                get = function(info)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[3]
                    return c.r, c.g, c.b
                end,
                set = function(info, r, g, b)
                    local c = E.db.CustomTweaks.NameplateThreat.threatColor[3]
                    c.r, c.g, c.b = r, g, b
                    UpdateSettings()
                end
            },
            textColor = {
                type = "color",
                order = 13,
                name = "Text Color",
                desc = "Цвет текста угрозы",
                hasAlpha = false,
                disabled = function() 
                    return not isEnabled or not E.db.CustomTweaks.NameplateThreat.useText 
                end,
                get = function(info)
                    local c = E.db.CustomTweaks.NameplateThreat.textColor
                    return c.r, c.g, c.b
                end,
                set = function(info, r, g, b)
                    local c = E.db.CustomTweaks.NameplateThreat.textColor
                    c.r, c.g, c.b = r, g, b
                    UpdateSettings()
                end
            },
        },
    }
end

-- Регистрируем конфигурацию
CT.Configs["NameplateThreat"] = ConfigTable

-- Если твик не включен, выходим
if not isEnabled then return end

-- Инициализация
local function InitializeThreat()
    -- Даем время ElvUI инициализировать NamePlates модуль
    E:Delay(2, function()
        UpdateSettings()
        
        -- Регистрируем обработчики изменений настроек
        E.RegisterCallback(CT, "ElvUI_PrivateSettingChanged", function(_, setting)
            if setting == "CustomTweaks" then
                UpdateSettings()
            end
        end)
        
        E.RegisterCallback(CT, "ElvUI_PublicSettingChanged", function(_, setting)
            if setting == "CustomTweaks" then
                UpdateSettings()
            end
        end)
        
        print("|cff4beb2cCustomTweaks|r: Nameplate Threat initialized")
    end)
end

-- Запускаем инициализацию после загрузки ElvUI
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    InitializeThreat()
end)

-- Обработчик событий для неймплейтов
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if not E.db.CustomTweaks.NameplateThreat.enabled then return end
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Ждем немного, чтобы ElvUI успел обновить неймплейт
        E:Delay(0.1, function()
            if NP.VisiblePlates then
                -- Ищем фрейм для этого юнита
                for frame in pairs(NP.VisiblePlates) do
                    if frame and frame.unit == unit then
                        UpdateThreat(frame)
                        break
                    end
                end
            end
        end)
        
    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        -- При изменении угрозы обновляем все видимые неймплейты
        E:Delay(0.05, function()
            UpdateAllVisibleNameplates()
        end)
    end
end)

-- Также обновляем неймплейты при изменении цели
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function()
    if E.db.CustomTweaks.NameplateThreat.enabled then
        E:Delay(0.05, UpdateAllVisibleNameplates)
    end
end)