local E, ElvUI_L, V, P, G = unpack(ElvUI) -- E = AddOn (движок ElvUI)
local LPB = E:NewModule("LocationPlus", "AceTimer-3.0")
local DT = E:GetModule("DataTexts")
local LSM = E.Libs.LSM

-- ЗАГРУЖАЕМ ЛОКАЛЬ ПЛАГИНА - СРАЗУ ПОСЛЕ ОБЪЯВЛЕНИЯ МОДУЛЯ
local L = LibStub("AceLocale-3.0"):GetLocale("ElvUI_LocPlus", true)
if not L then 
    L = {} -- создаем пустую таблицу, если локаль не загрузилась
end

local tourist = LibStub and LibStub("LibTourist-3.0", true)

local format, tonumber, pairs, print, tostring = string.format, tonumber, pairs, print, tostring
local CreateFrame = CreateFrame
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local GetBindLocation = GetBindLocation
local GetCurrentMapAreaID = GetCurrentMapAreaID
local GetMinimapZoneText = GetMinimapZoneText
local GetPlayerMapPosition = GetPlayerMapPosition
local GetRealZoneText = GetRealZoneText
local GetSubZoneText = GetSubZoneText
local GetZonePVPInfo = GetZonePVPInfo
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local UnitLevel = UnitLevel
local UIFrameFadeIn, UIFrameFadeOut, ToggleFrame = UIFrameFadeIn, UIFrameFadeOut, ToggleFrame
local IsControlKeyDown, IsShiftKeyDown = IsControlKeyDown, IsShiftKeyDown
local GameTooltip, WorldMapFrame = _G["GameTooltip"], _G["WorldMapFrame"]

local PLAYER, UNKNOWN, TRADE_SKILLS, LEVEL_RANGE, STATUS, HOME, CONTINENT = PLAYER, UNKNOWN, TRADE_SKILLS, LEVEL_RANGE, STATUS, HOME, CONTINENT
local SANCTUARY_TERRITORY, ARENA, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE, PVP, RAID = SANCTUARY_TERRITORY, ARENA, HOSTILE, CONTESTED_TERRITORY, COMBAT, AGGRO_WARNING_IN_INSTANCE, PVP, RAID

-- GLOBALS: LocationPlusPanel, LeftCoordDtPanel, RightCoordDtPanel, XCoordsPanel, YCoordsPanel, selectioncolor, continent, continentID

local left_dtp = CreateFrame("Frame", "LeftCoordDtPanel", E.UIParent)
local right_dtp = CreateFrame("Frame", "RightCoordDtPanel", E.UIParent)

local COORDS_WIDTH = 30 -- Coord panels width
local classColor = RAID_CLASS_COLORS[E.myclass] -- for text coloring

LPB.version = GetAddOnMetadata("ElvUI_LocPlus", "Version") or "2.25"

-- Инициализация таблиц настроек
if not E.db.locplus then 
    E.db.locplus = {
        -- Options
        both = true,
        combat = false,
        timer = 0.5,
        dig = true,
        displayOther = "RLEVEL",
        showicon = true,
        hidecoords = false,
        zonetext = true,
        -- Tooltip
        tt = true,
        ttcombathide = true,
        tthint = true,
        ttst = true,
        ttlvl = true,
        ttinst = true,
        ttreczones = true,
        ttrecinst = true,
        ttcoords = true,
        -- Filters
        tthideraid = false,
        tthidepvp = false,
        -- Layout
        dtshow = true,
        shadow = false,
        trans = true,
        noback = true,
        ht = false,
        lpwidth = 200,
        dtwidth = 100,
        dtheight = 21,
        lpauto = true,
        userColor = { r = 1, g = 1, b = 1 },
        customColor = 1,
        userCoordsColor = { r = 1, g = 1, b = 1 },
        customCoordsColor = 3,
        trunc = false,
        mouseover = false,
        malpha = 1,
        -- Fonts
        lpfont = E.db.general and E.db.general.font or "Friz Quadrata TT",
        lpfontsize = 12,
        lpfontflags = "NONE",
        -- Init
        LoginMsg = true,
    } 
end

do
    -- Регистрируем дататекстовые панели
    DT:RegisterPanel(LeftCoordDtPanel, 1, "ANCHOR_BOTTOM", 0, -4)
    DT:RegisterPanel(RightCoordDtPanel, 1, "ANCHOR_BOTTOM", 0, -4)

    -- Настройка дататекстов по умолчанию для ElvUI
    if P and P.datatexts and P.datatexts.panels then
        P.datatexts.panels.RightCoordDtPanel = "Time"
        P.datatexts.panels.LeftCoordDtPanel = "Durability"
    end
end

local SPACING = 1

-- Status
local function GetStatus(color)
    local status = ""
    local statusText
    local r, g, b = 1, 1, 0
    local pvpType = GetZonePVPInfo()
    local inInstance, _ = IsInInstance()
    if(pvpType == "sanctuary") then
        status = SANCTUARY_TERRITORY
        r, g, b = 0.41, 0.8, 0.94
    elseif(pvpType == "arena") then
        status = ARENA
        r, g, b = 1, 0.1, 0.1
    elseif(pvpType == "friendly") then
        status = L and L["Friendly"] or "Friendly"
        r, g, b = 0.1, 1, 0.1
    elseif(pvpType == "hostile") then
        status = HOSTILE
        r, g, b = 1, 0.1, 0.1
    elseif(pvpType == "contested") then
        status = CONTESTED_TERRITORY
        r, g, b = 1, 0.7, 0.10
    elseif(pvpType == "combat" ) then
        status = COMBAT
        r, g, b = 1, 0.1, 0.1
    elseif(inInstance) then
        status = L and L["In Instance"] or "In Instance"
        r, g, b = 1, 0.1, 0.1
    else
        status = CONTESTED_TERRITORY
    end

    statusText = format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, status)
    if color then
        return r, g, b
    else
        return statusText
    end
end

-- Dungeon coords
local function GetDungeonCoords(zone, withBrackets)
    local z, x, y = "", 0, 0
    local dcoords

    if tourist and tourist.IsInstance and tourist:IsInstance(zone) then
        z, x, y = tourist:GetEntrancePortalLocation(zone)
    end

    if z == nil or not E.db.locplus.ttcoords then
        return ""
    end
    
    x = tonumber(E:Round(x, 0))
    y = tonumber(E:Round(y, 0))
    
    -- Разные форматы в зависимости от контекста
    if withBrackets == false then
        dcoords = format(" %d,%d", x, y)
    else
        dcoords = format(" (%d, %d)", x, y)
    end

    return dcoords
end

-- PvP/Raid filter
local function PvPorRaidFilter(zone)
    local isPvP, isRaid
    isPvP = nil
    isRaid = nil

    if not tourist then return "" end

    if(tourist.IsArena and tourist:IsArena(zone) or tourist.IsBattleground and tourist:IsBattleground(zone)) then
        if E.db.locplus.tthidepvp then
            return
        end
        isPvP = true
    end

    if(not isPvP and tourist.GetInstanceGroupSize and tourist:GetInstanceGroupSize(zone) >= 10) then
        if E.db.locplus.tthideraid then
            return
        end
        isRaid = true
    end

    return (isPvP and "|cffff0000 "..PVP.."|r" or "")..(isRaid and "|cffff4400 "..RAID.."|r" or "")
end

-- Recommended zones (безопасная версия)
local function GetRecomZones(zone)
    if not tourist then return end
    
    local low, high = tourist:GetLevel(zone)
    local r, g, b = tourist:GetLevelColor(zone)
    local zContinent = tourist:GetContinent(zone)
    local continent = zContinent

    if PvPorRaidFilter(zone) == nil then return end

    GameTooltip:AddDoubleLine(
    "|cffffffff"..tostring(zone)
    ..(PvPorRaidFilter(zone) or ""),
    format("|cff%02xff00%s|r", continent == zContinent and 0 or 255, zContinent or "")
    ..(" |cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and tostring(low) or ("%d-%d"):format(low or 0, high or 0))))
end

-- Dungeons in the zone
local function GetZoneDungeons(dungeon)
    if not tourist then return end
    
    local low, high = tourist:GetLevel(dungeon)
    local r, g, b = tourist:GetLevelColor(dungeon)
    local groupSize = tourist:GetInstanceGroupSize(dungeon)
    -- ИСПРАВЛЕНО: форматирование размера группы
    local groupSizeStyle = (groupSize and groupSize > 0 and format("|cFFFFFF00 (%d)|r", groupSize)) or ""
    local name = dungeon

    if PvPorRaidFilter(dungeon) == nil then return end

    GameTooltip:AddDoubleLine(
        "|cffffffff"..tostring(name)
        ..groupSizeStyle
        ..GetDungeonCoords(dungeon)  -- Теперь вернёт " (41, 56)"
        ..(PvPorRaidFilter(dungeon) or ""),
        ("|cff%02x%02x%02x%s|r"):format(
            r * 255, g * 255, b * 255,
            (low == high and tostring(low) or ("%d-%d"):format(low or 0, high or 0))
        )
    )
end

-- Recommended Dungeons
local function GetRecomDungeons(dungeon)
    if not tourist then return end
    
    local low, high = tourist:GetLevel(dungeon)
    local r, g, b = tourist:GetLevelColor(dungeon)
    local instZone = tourist:GetInstanceZone(dungeon)
    local name = dungeon

    if PvPorRaidFilter(dungeon) == nil then return end

    if instZone == nil then
        instZone = ""
    else
        -- ИСПРАВЛЕНО: убираем лишнюю скобку
        instZone = "|cFFFFA500 ("..tostring(instZone)..")"
    end

    GameTooltip:AddDoubleLine(
        "|cffffffff"..tostring(name)
        ..instZone
        ..GetDungeonCoords(dungeon)  -- Теперь вернёт " (41, 56)"
        ..(PvPorRaidFilter(dungeon) or ""),
        ("|cff%02x%02x%02x%s|r"):format(
            r * 255, g * 255, b * 255,
            (low == high and tostring(low) or ("%d-%d"):format(low or 0, high or 0))
        )
    )
end

-- Icons on Location Panel
local LEVEL_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\levelup.tga:22:22|t"

-- Zone level range
local function GetLevelRange(zoneText, ontt)
    local zoneText = GetRealZoneText() or UNKNOWN
    local low, high = 0, 0
    local dlevel
    
    if tourist and tourist.GetLevel then
        low, high = tourist:GetLevel(zoneText)
    end
    
    if low and high and low > 0 and high > 0 then
        local r, g, b = tourist:GetLevelColor(zoneText)
        if low ~= high then
            dlevel = format("|cff%02x%02x%02x%d-%d|r", r*255, g*255, b*255, low, high) or ""
        else
            dlevel = format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, high) or ""
        end

        if ontt then
            return dlevel
        else
            if E.db.locplus.showicon then
                dlevel = format(" (%s) ", dlevel)..LEVEL_ICON
            else
                dlevel = format(" (%s) ", dlevel)
            end
        end
    end

    return dlevel or ""
end

local capRank = 800
local selectioncolor = 0.8, 0.7, 0.3

local function UpdateTooltip()
    local zoneText = GetRealZoneText() or UNKNOWN
    local curPos = (zoneText.." ") or ""

    GameTooltip:ClearLines()

    -- Zone
    -- Zone
	GameTooltip:AddDoubleLine(
		(L["Zone : "] or "Zone : "),  -- Используем L или английский по умолчанию
		zoneText, 
		1, 1, 1, 
		0.8, 0.7, 0.3
	)

    -- Continent
    local continentName = UNKNOWN
    if tourist and tourist.GetContinent then
        continentName = tourist:GetContinent(zoneText) or UNKNOWN
    end
    GameTooltip:AddDoubleLine(CONTINENT.." : ", tostring(continentName), 1, 1, 1, 0.8, 0.7, 0.3)

    -- Home
    GameTooltip:AddDoubleLine(HOME.." :", GetBindLocation(), 1, 1, 1, 0.41, 0.8, 0.94)

    -- Status
    if E.db.locplus.ttst then
        GameTooltip:AddDoubleLine((L and L["Status"] or "Status").." :", GetStatus(false), 1, 1, 1)
    end

    -- Zone level range
    if E.db.locplus.ttlvl and tourist then
        local checklvl = GetLevelRange(zoneText, true)
        if checklvl ~= "" then
            GameTooltip:AddDoubleLine(LEVEL_RANGE.." : ", checklvl, 1, 1, 1, 1, 1, 1)
        end
    end

    -- Recommended zones
    if E.db.locplus.ttreczones and tourist and tourist.IterateRecommendedZones then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L and L["Recommended Zones :"] or "Recommended Zones :"), 0.8, 0.7, 0.3)

        for zone in tourist:IterateRecommendedZones() do
            GetRecomZones(zone)
        end
    end

    -- Instances in the zone
    if E.db.locplus.ttinst and tourist and tourist.DoesZoneHaveInstances and tourist:DoesZoneHaveInstances(zoneText) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(curPos..(L and L["Dungeons :"] or "Dungeons :"), 0.8, 0.7, 0.3)

        for dungeon in tourist:IterateZoneInstances(zoneText) do
            GetZoneDungeons(dungeon)
        end
    end

    -- Recommended Instances
    local level = UnitLevel("player")
    if E.db.locplus.ttrecinst and tourist and tourist.HasRecommendedInstances and tourist:HasRecommendedInstances() and level >= 15 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L and L["Recommended Dungeons :"] or "Recommended Dungeons :"), 0.8, 0.7, 0.3)

        for dungeon in tourist:IterateRecommendedInstances() do
            GetRecomDungeons(dungeon)
        end
    end

    -- Hints
    if E.db.locplus.tt then
        if E.db.locplus.tthint then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine((L and L["Left Click : "] or "Left Click : "), (L and L["Toggle WorldMap"] or "Toggle WorldMap"), 0.7, 0.7, 1, 0.7, 0.7, 1)
            GameTooltip:AddDoubleLine((L and L["Right Click : "] or "Right Click : "), (L and L["Toggle Configuration"] or "Toggle Configuration"),0.7, 0.7, 1, 0.7, 0.7, 1)
            GameTooltip:AddDoubleLine((L and L["Shift Click : "] or "Shift Click : "), (L and L["Send position to chat"] or "Send position to chat"),0.7, 0.7, 1, 0.7, 0.7, 1)
            GameTooltip:AddDoubleLine((L and L["Ctrl Click : "] or "Ctrl Click : "), (L and L["Toggle Datatexts"] or "Toggle Datatexts"),0.7, 0.7, 1, 0.7, 0.7, 1)
        end
        GameTooltip:Show()
    else
        GameTooltip:Hide()
    end
end

-- mouse over the location panel
local function LocPanel_OnEnter(self,...)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)

    if InCombatLockdown() and E.db.locplus.ttcombathide then
        GameTooltip:Hide()
    else
        UpdateTooltip()
    end

    if E.db.locplus.mouseover then
        UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
    end
end

-- mouse leaving the location panel
local function LocPanel_OnLeave(self,...)
    GameTooltip:Hide()
    if E.db.locplus.mouseover then
        UIFrameFadeOut(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
    end
end

-- Hide in combat, after fade function ends
local function LocPanelOnFade()
    if LocationPlusPanel then
        LocationPlusPanel:Hide()
    end
end

-- Coords Creation
local function CreateCoords()
    local x, y = GetPlayerMapPosition("player")
    local dig

    if E.db.locplus.dig then
        dig = 2
    else
        dig = 0
    end

    if x and x > 0 then
        x = tonumber(E:Round(100 * x, dig))
    end
    if y and y > 0 then
        y = tonumber(E:Round(100 * y, dig))
    end

    return x, y
end

-- clicking the location panel
local function LocPanel_OnClick(self, btn)
    local zoneText = GetRealZoneText() or UNKNOWN
    if btn == "LeftButton" then
        if IsShiftKeyDown() then
            local edit_box = ChatEdit_ChooseBoxForSend()
            local x, y = CreateCoords()
            local message
            local coords = tostring(x)..", "..tostring(y)
                if zoneText ~= GetSubZoneText() then
                    message = format("%s: %s (%s)", zoneText, GetSubZoneText(), coords)
                else
                    message = format("%s (%s)", zoneText, coords)
                end
                if edit_box then
                    ChatEdit_ActivateChat(edit_box)
                    edit_box:Insert(message)
                end
        else
            if IsControlKeyDown() then
                LeftCoordDtPanel:SetScript("OnShow", function(self) E.db.locplus.dtshow = true end)
                LeftCoordDtPanel:SetScript("OnHide", function(self) E.db.locplus.dtshow = false end)
                ToggleFrame(LeftCoordDtPanel)
                ToggleFrame(RightCoordDtPanel)
            else
                ToggleFrame(WorldMapFrame)
            end
        end
    end
    if btn == "RightButton" then
        -- ИСПРАВЛЕНО для ElvUI WotLK версии
        if E and E.ToggleOptionsUI then
            E:ToggleOptionsUI()
        elseif E and E.ToggleConfig then
            E:ToggleConfig()
        else
            E:ToggleOptionsUI("")
        end
    end
end

-- Custom text color. Credits: Edoc
local color = { r = 1, g = 1, b = 1 }
local function unpackColor(color)
    return color.r, color.g, color.b
end

-- Location panel
local function CreateLocPanel()
    local loc_panel = CreateFrame("Frame", "LocationPlusPanel", E.UIParent)
    loc_panel:Width(E.db.locplus.lpwidth or 200)
    loc_panel:Height(E.db.locplus.dtheight or 21)
    loc_panel:Point("TOP", E.UIParent, "TOP", 0, -E.mult -22)
    loc_panel:SetFrameStrata("LOW")
    loc_panel:SetFrameLevel(2)
    loc_panel:EnableMouse(true)
    loc_panel:SetScript("OnEnter", LocPanel_OnEnter)
    loc_panel:SetScript("OnLeave", LocPanel_OnLeave)
    loc_panel:SetScript("OnMouseUp", LocPanel_OnClick)

    -- Location Text
    loc_panel.Text = loc_panel:CreateFontString(nil, "LOW")
    loc_panel.Text:Point("CENTER", 0, 0)
    loc_panel.Text:SetAllPoints()
    loc_panel.Text:SetJustifyH("CENTER")
    loc_panel.Text:SetJustifyV("MIDDLE")

    -- Hide in combat
    loc_panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    loc_panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    loc_panel:SetScript("OnEvent",function(self, event)
        if E.db.locplus.combat then
            if event == "PLAYER_REGEN_DISABLED" then
                UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
                self.fadeInfo.finishedFunc = LocPanelOnFade
            elseif event == "PLAYER_REGEN_ENABLED" then
                if E.db.locplus.mouseover then
                    UIFrameFadeIn(self, 0.2, self:GetAlpha(), E.db.locplus.malpha)
                else
                    UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
                end
                self:Show()
            end
        end
    end)

    -- Mover for ElvUI
    E:CreateMover(loc_panel, "LocationMover", L and L["LocationPlus "] or "LocationPlus ")
end

local function HideDT()
    if E.db.locplus.dtshow then
        RightCoordDtPanel:Show()
        LeftCoordDtPanel:Show()
    else
        RightCoordDtPanel:Hide()
        LeftCoordDtPanel:Hide()
    end
end

-- Coord panels
local function CreateCoordPanels()
    -- X Coord panel
    local coordsX = CreateFrame("Frame", "XCoordsPanel", LocationPlusPanel)
    coordsX:Width(COORDS_WIDTH)
    coordsX:Height(E.db.locplus.dtheight or 21)
    coordsX:SetFrameStrata("LOW")
    coordsX.Text = coordsX:CreateFontString(nil, "LOW")
    coordsX.Text:SetAllPoints()
    coordsX.Text:SetJustifyH("CENTER")
    coordsX.Text:SetJustifyV("MIDDLE")

    -- Y Coord panel
    local coordsY = CreateFrame("Frame", "YCoordsPanel", LocationPlusPanel)
    coordsY:Width(COORDS_WIDTH)
    coordsY:Height(E.db.locplus.dtheight or 21)
    coordsY:SetFrameStrata("LOW")
    coordsY.Text = coordsY:CreateFontString(nil, "LOW")
    coordsY.Text:SetAllPoints()
    coordsY.Text:SetJustifyH("CENTER")
    coordsY.Text:SetJustifyV("MIDDLE")

    LPB:CoordsColor()
end

-- mouse over option
function LPB:MouseOver()
    if not LocationPlusPanel then return end
    
    if E.db.locplus.mouseover then
        LocationPlusPanel:SetAlpha(E.db.locplus.malpha or 1)
    else
        LocationPlusPanel:SetAlpha(1)
    end
end

-- datatext panels width
function LPB:DTWidth()
    LeftCoordDtPanel:Width(E.db.locplus.dtwidth or 100)
    RightCoordDtPanel:Width(E.db.locplus.dtwidth or 100)
end

-- all panels height
function LPB:DTHeight()
    if not LocationPlusPanel then return end
    
    if E.db.locplus.ht then
        LocationPlusPanel:Height((E.db.locplus.dtheight or 21)+6)
    else
        LocationPlusPanel:Height(E.db.locplus.dtheight or 21)
    end

    LeftCoordDtPanel:Height(E.db.locplus.dtheight or 21)
    RightCoordDtPanel:Height(E.db.locplus.dtheight or 21)

    if XCoordsPanel and YCoordsPanel then
        XCoordsPanel:Height(E.db.locplus.dtheight or 21)
        YCoordsPanel:Height(E.db.locplus.dtheight or 21)
    end
end

-- Fonts
function LPB:ChangeFont()
    if not LocationPlusPanel or not E.media then 
        E.media = E.media or {}
        return 
    end
    
    E.media.lpFont = LSM:Fetch("font", E.db.locplus.lpfont or E.db.general.font or "Friz Quadrata TT")

    local panelsToFont = {LocationPlusPanel, XCoordsPanel, YCoordsPanel}
    for _, frame in pairs(panelsToFont) do
        if frame and frame.Text then
            frame.Text:FontTemplate(E.media.lpFont, E.db.locplus.lpfontsize or 12, E.db.locplus.lpfontflags or "NONE")
        end
    end

    local dtToFont = {RightCoordDtPanel, LeftCoordDtPanel}
    for _, panel in pairs(dtToFont) do
        if panel and panel.numPoints then
            for i=1, panel.numPoints do
                local pointIndex = DT.PointLocation and DT.PointLocation[i]
                if panel.dataPanels and pointIndex and panel.dataPanels[pointIndex] and panel.dataPanels[pointIndex].text then
                    panel.dataPanels[pointIndex].text:FontTemplate(E.media.lpFont, E.db.locplus.lpfontsize or 12, E.db.locplus.lpfontflags or "NONE")
                    panel.dataPanels[pointIndex].text:SetPoint("CENTER", 0, 1)
                end
            end
        end
    end
end

function LPB:ShadowPanels()
    local panelsToAddShadow = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LeftCoordDtPanel, RightCoordDtPanel}

    for _, frame in pairs(panelsToAddShadow) do
        if frame then
            if not frame.shadow then
                -- Передаём число, а не строку
                frame:CreateShadow(3)  -- или любое другое число
            end
            if E.db.locplus.shadow and frame.shadow then
                frame.shadow:Show()
            elseif frame.shadow then
                frame.shadow:Hide()
            end
        end
    end

    if E.db.locplus.shadow then
        SPACING = 2
    else
        SPACING = 1
    end

    self:HideCoords()
end

-- Show/Hide coord frames
function LPB:HideCoords()
    if not XCoordsPanel or not YCoordsPanel or not LocationPlusPanel then return end
    
    XCoordsPanel:ClearAllPoints()
    YCoordsPanel:ClearAllPoints()
    XCoordsPanel:Point("RIGHT", LocationPlusPanel, "LEFT", -SPACING, 0)
    YCoordsPanel:Point("LEFT", LocationPlusPanel, "RIGHT", SPACING, 0)

    LeftCoordDtPanel:ClearAllPoints()
    RightCoordDtPanel:ClearAllPoints()

    if E.db.locplus.hidecoords then
        XCoordsPanel:Hide()
        YCoordsPanel:Hide()
        LeftCoordDtPanel:Point("RIGHT", LocationPlusPanel, "LEFT", -SPACING, 0)
        RightCoordDtPanel:Point("LEFT", LocationPlusPanel, "RIGHT", SPACING, 0)
    else
        XCoordsPanel:Show()
        YCoordsPanel:Show()
        LeftCoordDtPanel:Point("RIGHT", XCoordsPanel, "LEFT", -SPACING, 0)
        RightCoordDtPanel:Point("LEFT", YCoordsPanel, "RIGHT", SPACING, 0)
    end
end

-- Toggle transparency
function LPB:TransparentPanels()
    local panelsToAddTrans = {LocationPlusPanel, XCoordsPanel, YCoordsPanel, LeftCoordDtPanel, RightCoordDtPanel}

    for _, frame in pairs(panelsToAddTrans) do
        if frame then
            if not E.db.locplus.noback then
                E.db.locplus.shadow = false
                frame:SetTemplate("Default", true)
            elseif E.db.locplus.trans then
                frame:SetTemplate("Transparent")
            else
                frame:SetTemplate("Default", true)
            end
        end
    end
end

function LPB:UpdateLocation()
    if not LocationPlusPanel or not LocationPlusPanel.Text then return end
    
    local subZoneText = GetMinimapZoneText() or ""
    local zoneText = GetRealZoneText() or UNKNOWN
    local displayLine

    -- zone and subzone
    if E.db.locplus.both then
        if (subZoneText ~= "") and (subZoneText ~= zoneText) then
            displayLine = zoneText .. ": " .. subZoneText
        else
            displayLine = subZoneText
        end
    else
        displayLine = subZoneText
    end

    -- Show Other (Level)
    if E.db.locplus.displayOther == "RLEVEL" then
        local displaylvl = GetLevelRange(zoneText) or ""
        if displaylvl ~= "" then
            displayLine = displayLine..displaylvl
        end
    else
        displayLine = displayLine
    end

    if displayLine == "" then
        displayLine = UNKNOWN
    end

    LocationPlusPanel.Text:SetText(displayLine)

    -- Coloring
    if displayLine ~= "" then
        if E.db.locplus.customColor == 1 then
            LocationPlusPanel.Text:SetTextColor(GetStatus(true))
        elseif E.db.locplus.customColor == 2 then
            LocationPlusPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            LocationPlusPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor or {r=1,g=1,b=1}))
        end
    end

    -- Sizing
    local fixedwidth = (E.db.locplus.lpwidth or 200) + 18
    local autowidth = (LocationPlusPanel.Text:GetStringWidth() or 100) + 18

    if E.db.locplus.lpauto then
        LocationPlusPanel:Width(autowidth)
        LocationPlusPanel.Text:Width(autowidth)
    else
        LocationPlusPanel:Width(fixedwidth)
        if E.db.locplus.trunc then
            LocationPlusPanel.Text:Width(fixedwidth - 18)
            LocationPlusPanel.Text:SetWordWrap(false)
        elseif autowidth > fixedwidth then
            LocationPlusPanel:Width(autowidth)
            LocationPlusPanel.Text:Width(autowidth)
        end
    end
end

function LPB:UpdateCoords()
    if not XCoordsPanel or not XCoordsPanel.Text or not YCoordsPanel or not YCoordsPanel.Text then return end
    
    local x, y = CreateCoords()
    local xt, yt

    if (x == 0 or x == nil) and (y == 0 or y == nil) then
        XCoordsPanel.Text:SetText("-")
        YCoordsPanel.Text:SetText("-")
    else
        if x < 10 then
            xt = "0"..tostring(x)
        else
            xt = tostring(x)
        end

        if y < 10 then
            yt = "0"..tostring(y)
        else
            yt = tostring(y)
        end
        XCoordsPanel.Text:SetText(xt)
        YCoordsPanel.Text:SetText(yt)
    end
end

-- Coord panels width
function LPB:CoordsDigit()
    if not XCoordsPanel or not YCoordsPanel then return end
    
    if E.db.locplus.dig then
        XCoordsPanel:Width(COORDS_WIDTH*1.5)
        YCoordsPanel:Width(COORDS_WIDTH*1.5)
    else
        XCoordsPanel:Width(COORDS_WIDTH)
        YCoordsPanel:Width(COORDS_WIDTH)
    end
end

function LPB:CoordsColor()
    if not XCoordsPanel or not XCoordsPanel.Text or not YCoordsPanel or not YCoordsPanel.Text then return end
    
    if E.db.locplus.customCoordsColor == 1 then
        XCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor or {r=1,g=1,b=1}))
        YCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userColor or {r=1,g=1,b=1}))
    elseif E.db.locplus.customCoordsColor == 2 then
        XCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
        YCoordsPanel.Text:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        XCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userCoordsColor or {r=1,g=1,b=1}))
        YCoordsPanel.Text:SetTextColor(unpackColor(E.db.locplus.userCoordsColor or {r=1,g=1,b=1}))
    end
end

-- Datatext panels
local function CreateDTPanels()
    -- Left coords Datatext panel
    left_dtp:Width(E.db.locplus.dtwidth or 100)
    left_dtp:Height(E.db.locplus.dtheight or 21)
    left_dtp:SetFrameStrata("LOW")
    left_dtp:SetParent(LocationPlusPanel)

    -- Right coords Datatext panel
    right_dtp:Width(E.db.locplus.dtwidth or 100)
    right_dtp:Height(E.db.locplus.dtheight or 21)
    right_dtp:SetFrameStrata("LOW")
    right_dtp:SetParent(LocationPlusPanel)
end

-- Update changes
function LPB:LocPlusUpdate()
    self:TransparentPanels()
    self:ShadowPanels()
    self:DTHeight()
    HideDT()
    self:CoordsDigit()
    self:MouseOver()
    self:HideCoords()
end

-- Defaults in case something is wrong on first load
function LPB:LocPlusDefaults()
    if E.db.locplus.lpwidth == nil then
        E.db.locplus.lpwidth = 200
    end

    if E.db.locplus.dtwidth == nil then
        E.db.locplus.dtwidth = 100
    end

    if E.db.locplus.dtheight == nil then
        E.db.locplus.dtheight = 21
    end
    
    if E.db.locplus.timer == nil then
        E.db.locplus.timer = 0.5
    end
    
    if E.db.locplus.lpfont == nil then
        E.db.locplus.lpfont = E.db.general and E.db.general.font or "Friz Quadrata TT"
    end
    
    if E.db.locplus.lpfontsize == nil then
        E.db.locplus.lpfontsize = 12
    end
    
    if E.db.locplus.lpfontflags == nil then
        E.db.locplus.lpfontflags = "NONE"
    end
    
    if E.db.locplus.customColor == nil then
        E.db.locplus.customColor = 1
    end
    
    if E.db.locplus.customCoordsColor == nil then
        E.db.locplus.customCoordsColor = 3
    end
    
    if E.db.locplus.userColor == nil then
        E.db.locplus.userColor = { r = 1, g = 1, b = 1 }
    end
    
    if E.db.locplus.userCoordsColor == nil then
        E.db.locplus.userCoordsColor = { r = 1, g = 1, b = 1 }
    end
end

function LPB:ToggleBlizZoneText()
    if not ZoneTextFrame then return end
    
    if E.db.locplus.zonetext then
        ZoneTextFrame:UnregisterAllEvents()
    else
        ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        ZoneTextFrame:RegisterEvent("ZONE_CHANGED")
    end
end

function LPB:TimerUpdate()
    self:CancelAllTimers()
    self:ScheduleRepeatingTimer("UpdateCoords", E.db.locplus.timer or 0.5)
end

-- needed to fix LocPlus datatext font
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent",function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        LPB:ChangeFont()
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

function LPB:Initialize()
    self:LocPlusDefaults()
    CreateLocPanel()
    CreateDTPanels()
    CreateCoordPanels()
    self:LocPlusUpdate()
    self:TimerUpdate()
    self:ToggleBlizZoneText()
    self:ScheduleRepeatingTimer("UpdateLocation", 0.5)
    
    -- ПРАВИЛЬНАЯ регистрация плагина для этой версии ElvUI
    local EP = E.Libs and E.Libs.EP
    if EP then
        EP:RegisterPlugin("ElvUI_LocPlus", function()
            if self.AddOptions then
                self:AddOptions()
            end
        end)
    end
    
    if LocationPlusPanel then
        LocationPlusPanel:RegisterEvent("PLAYER_REGEN_DISABLED")
        LocationPlusPanel:RegisterEvent("PLAYER_REGEN_ENABLED")
    end

    if E.db.locplus.LoginMsg then
        print(L and L["Location Plus "] or "Location Plus ", format("v|cff33ffff%s|r", self.version), 
              L and L[" is loaded. Thank you for using it."] or " is loaded. Thank you for using it.")
    end
end

E:RegisterModule(LPB:GetName())