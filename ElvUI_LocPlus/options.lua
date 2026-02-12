local E, ElvUI_L, V, P, G = unpack(ElvUI)
local LPB = E:GetModule("LocationPlus")
local LSM = E.Libs and E.Libs.LSM

-- Загружаем локаль плагина
local L = LibStub("AceLocale-3.0"):GetLocale("ElvUI_LocPlus", true) or {}

-- Создаем метатаблицу для автоматического возврата ключа, если перевод не найден
setmetatable(L, {
    __index = function(t, k)
        -- Возвращаем сам ключ как строку, если перевод не найден
        return k
    end
})

local format = string.format
local OTHER, LEVEL_RANGE, EMBLEM_SYMBOL, TRADE_SKILLS, FILTERS = OTHER, LEVEL_RANGE, EMBLEM_SYMBOL, TRADE_SKILLS, FILTERS
local COLOR, CLASS_COLORS, CUSTOM, COLOR_PICKER = COLOR, CLASS_COLORS, CUSTOM, COLOR_PICKER

-- GLOBALS: AceGUIWidgetLSMlists

-- Получаем список шрифтов
local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists or {}
if LSM then
    AceGUIWidgetLSMlists.font = AceGUIWidgetLSMlists.font or LSM:HashTable("font")
end

-- Устанавливаем значения по умолчанию в глобальную таблицу P
if P and not P.locplus then
    P.locplus = {
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

local newsign = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:14:14|t"

local LEVEL_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\levelup.tga:22:22|t"

function LPB:AddOptions()
    if not E.Options then E.Options = { args = {} } end
    if not E.Options.args then E.Options.args = {} end
    
    E.Options.args.locplus = {
        order = 9000,
        type = "group",
        name = L and L["Location Plus"] or "Location Plus",
        args = {
            name = {
                order = 1,
                type = "header",
                name = (L and L["Location Plus "] or "Location Plus ") .. format("v|cff33ffff%s|r", LPB.version) .. 
                       (L and L[" by Benik (EU-Emerald Dream)"] or " by Benik (EU-Emerald Dream)"),
            },
            desc = {
                order = 2,
                type = "description",
                name = L and L["LocationPlus adds a movable player location panel, 2 datatext panels and more"] 
                      or "LocationPlus adds a movable player location panel, 2 datatext panels and more",
            },
            spacer1 = {
                order = 3,
                type = "description",
                name = "",
            },
            toptop = {
                order = 4,
                type = "group",
                name = L and L["General"] or "General",
                guiInline = true,
                args = {
                    LoginMsg = {
                        order = 1,
                        name = L and L["Login Message"] or "Login Message",
                        desc = L and L["Enable/Disable the Login Message"] or "Enable/Disable the Login Message",
                        type = "toggle",
                        width = "full",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                    },
                    combat = {
                        order = 2,
                        name = L and L["Combat Hide"] or "Combat Hide",
                        desc = L and L["Show/Hide all panels when in combat"] or "Show/Hide all panels when in combat",
                        type = "toggle",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                    },
                    timer = {
                        order = 3,
                        name = L and L["Update Timer"] or "Update Timer",
                        desc = L and L["Adjust coords updates (in seconds) to avoid cpu load. Bigger number = less cpu load. Requires reloadUI."] 
                              or "Adjust coords updates (in seconds) to avoid cpu load. Bigger number = less cpu load. Requires reloadUI.",
                        type = "range",
                        min = 0.05, max = 1, step = 0.05,
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            E:StaticPopup_Show("PRIVATE_RL")
                        end,
                    },
                    zonetext = {
                        order = 4,
                        name = L and L["Hide Blizzard Zone Text"] or "Hide Blizzard Zone Text",
                        type = "toggle",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:ToggleBlizZoneText() 
                        end,
                    },
                },
            },
            general = {
                order = 5,
                type = "group",
                name = L and L["Show"] or "Show",
                guiInline = true,
                args = {
                    both = {
                        order = 1,
                        name = L and L["Zone and Subzone"] or "Zone and Subzone",
                        desc = L and L["Displays the main zone and the subzone in the location panel"] 
                              or "Displays the main zone and the subzone in the location panel",
                        type = "toggle",
                        width = "full",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                    },
                    hidecoords = {
                        order = 2,
                        name = (L and L["Hide Coords"] or "Hide Coords") .. newsign,
                        desc = L and L["Show/Hide the coord frames"] or "Show/Hide the coord frames",
                        type = "toggle",
                        width = "full",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:HideCoords() 
                        end,
                    },
                    dig = {
                        order = 3,
                        name = L and L["Detailed Coords"] or "Detailed Coords",
                        desc = L and L["Adds 2 digits in the coords"] or "Adds 2 digits in the coords",
                        type = "toggle",
                        width = "full",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:CoordsDigit() 
                        end,
                    },
                    displayOther = {
                        order = 4,
                        name = OTHER or "Other",
                        type = "select",
                        desc = L and L["Show additional info in the Location Panel."] or "Show additional info in the Location Panel.",
                        values = {
                            ["NONE"] = NONE or "None",
                            ["RLEVEL"] = LEVEL_ICON .. " " .. (LEVEL_RANGE or "Level Range"),
                        },
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                    },
                    showicon = {
                        order = 5,
                        name = EMBLEM_SYMBOL or "Symbol",
                        type = "toggle",
                        disabled = function() return E.db.locplus.displayOther == "NONE" end,
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                    },
                    mouseover = {
                        order = 6,
                        name = L and L["Mouse Over"] or "Mouse Over",
                        desc = L and L["The frame is not shown unless you mouse over the frame."] 
                              or "The frame is not shown unless you mouse over the frame.",
                        type = "toggle",
                        width = "full",
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:MouseOver() 
                        end,
                    },
                    malpha = {
                        order = 7,
                        type = "range",
                        name = L and L["Alpha"] or "Alpha",
                        desc = L and L["Change the alpha level of the frame."] or "Change the alpha level of the frame.",
                        min = 0, max = 1, step = 0.1,
                        disabled = function() return not E.db.locplus.mouseover end,
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:MouseOver() 
                        end,
                    },
                },
            },
            gen_tt = {
                order = 6,
                type = "group",
                name = L and L["Tooltip"] or "Tooltip",
                get = function(info) return E.db.locplus[ info[#info] ] end,
                set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                args = {
                    tt_grp = {
                        order = 1,
                        type = "group",
                        name = L and L["Tooltip"] or "Tooltip",
                        guiInline = true,
                        args = {
                            tt = {
                                order = 1,
                                name = L and L["Show/Hide tooltip"] or "Show/Hide tooltip",
                                type = "toggle",
                            },
                            ttcombathide = {
                                order = 2,
                                name = L and L["Combat Hide"] or "Combat Hide",
                                desc = L and L["Hide tooltip while in combat."] or "Hide tooltip while in combat.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            tthint = {
                                order = 3,
                                name = L and L["Show Hints"] or "Show Hints",
                                desc = L and L["Enable/Disable hints on Tooltip."] or "Enable/Disable hints on Tooltip.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                        },
                    },
                    tt_options = {
                        order = 2,
                        type = "group",
                        name = L and L["Show"] or "Show",
                        guiInline = true,
                        args = {
                            ttst = {
                                order = 1,
                                name = L and L["Status"] or "Status",
                                desc = L and L["Enable/Disable status on Tooltip."] or "Enable/Disable status on Tooltip.",
                                type = "toggle",
                                width = "full",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            ttlvl = {
                                order = 2,
                                name = LEVEL_RANGE or "Level Range",
                                desc = L and L["Enable/Disable level range on Tooltip."] or "Enable/Disable level range on Tooltip.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            spacer2 = {
                                order = 3,
                                type = "description",
                                width = "full",
                                name = "",
                            },
                            ttreczones = {
                                order = 4,
                                name = L and L["Recommended Zones"] or "Recommended Zones",
                                desc = L and L["Enable/Disable recommended zones on Tooltip."] or "Enable/Disable recommended zones on Tooltip.",
                                type = "toggle",
                                width = "full",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            ttinst = {
                                order = 5,
                                name = L and L["Zone Dungeons"] or "Zone Dungeons",
                                desc = L and L["Enable/Disable dungeons in the zone, on Tooltip."] or "Enable/Disable dungeons in the zone, on Tooltip.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            ttrecinst = {
                                order = 6,
                                name = L and L["Recommended Dungeons"] or "Recommended Dungeons",
                                desc = L and L["Enable/Disable recommended dungeons on Tooltip."] or "Enable/Disable recommended dungeons on Tooltip.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            ttcoords = {
                                order = 7,
                                name = L and L["with Entrance Coords"] or "with Entrance Coords",
                                desc = L and L["Enable/Disable the coords for area dungeons and recommended dungeon entrances, on Tooltip."] 
                                      or "Enable/Disable the coords for area dungeons and recommended dungeon entrances, on Tooltip.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt or not E.db.locplus.ttrecinst end,
                            },
                        },
                    },
                    tt_filters = {
                        order = 3,
                        type = "group",
                        name = FILTERS or "Filters",
                        guiInline = true,
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                        args = {
                            tthideraid = {
                                order = 1,
                                name = L and L["Hide Raid"] or "Hide Raid",
                                desc = L and L["Show/Hide raids on recommended dungeons."] or "Show/Hide raids on recommended dungeons.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                            tthidepvp = {
                                order = 2,
                                name = L and L["Hide PvP"] or "Hide PvP",
                                desc = L and L["Show/Hide PvP zones, Arenas and BGs on recommended dungeons and zones."] 
                                      or "Show/Hide PvP zones, Arenas and BGs on recommended dungeons and zones.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.tt end,
                            },
                        },
                    },
                },
            },
            layout = {
                order = 7,
                type = "group",
                name = L and L["Layout"] or "Layout",
                args = {
                    lp_lo = {
                        order = 1,
                        type = "group",
                        name = L and L["Layout"] or "Layout",
                        guiInline = true,
                        args = {
                            shadow = {
                                order = 1,
                                name = L and L["Shadows"] or "Shadows",
                                desc = L and L["Enable/Disable layout with shadows."] or "Enable/Disable layout with shadows.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.noback end,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:ShadowPanels() 
                                end,
                            },
                            trans = {
                                order = 2,
                                name = L and L["Transparent"] or "Transparent",
                                desc = L and L["Enable/Disable transparent layout."] or "Enable/Disable transparent layout.",
                                type = "toggle",
                                disabled = function() return not E.db.locplus.noback end,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:TransparentPanels() 
                                end,
                            },
                            noback = {
                                order = 3,
                                name = L and L["Backdrop"] or "Backdrop",
                                desc = L and L["Hides all panels background so you can place them on ElvUI's top or bottom panel."] 
                                      or "Hides all panels background so you can place them on ElvUI's top or bottom panel.",
                                type = "toggle",
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:TransparentPanels() 
                                    LPB:ShadowPanels() 
                                end,
                            },
                        },
                    },
                    locpanel = {
                        order = 2,
                        type = "group",
                        name = L and L["Location Panel"] or "Location Panel",
                        guiInline = true,
                        args = {
                            ht = {
                                order = 1,
                                name = L and L["Larger Location Panel"] or "Larger Location Panel",
                                desc = L and L["Adds 6 pixels at the Main Location Panel height."] or "Adds 6 pixels at the Main Location Panel height.",
                                type = "toggle",
                                width = "full",
                                disabled = function() return not E.db.locplus.noback end,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:DTHeight() 
                                end,
                            },
                            lpauto = {
                                order = 2,
                                type = "toggle",
                                name = L and L["Auto width"] or "Auto width",
                                desc = L and L["Auto resized Location Panel."] or "Auto resized Location Panel.",
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    if value then
                                        E.db.locplus.trunc = false 
                                    end
                                end,
                            },
                            lpwidth = {
                                order = 3,
                                type = "range",
                                name = L and L["Width"] or "Width",
                                desc = L and L["Adjust the Location Panel Width."] or "Adjust the Location Panel Width.",
                                min = 100, max = 300, step = 1,
                                disabled = function() return E.db.locplus.lpauto end,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                            },
                            trunc = {
                                order = 4,
                                type = "toggle",
                                name = L and L["Truncate text"] or "Truncate text",
                                desc = L and L["Truncates the text rather than auto enlarge the location panel when the text is bigger than the panel."] 
                                      or "Truncates the text rather than auto enlarge the location panel when the text is bigger than the panel.",
                                disabled = function() return E.db.locplus.lpauto end,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                            },
                            customColor = {
                                order = 5,
                                type = "select",
                                name = COLOR or "Color",
                                values = {
                                    [1] = L and L["Auto Colorize"] or "Auto Colorize",
                                    [2] = CLASS_COLORS or "Class Colors",
                                    [3] = CUSTOM or "Custom",
                                },
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) E.db.locplus[ info[#info] ] = value end,
                            },
                            userColor = {
                                order = 6,
                                type = "color",
                                name = COLOR_PICKER or "Color Picker",
                                disabled = function() return E.db.locplus.customColor == 1 or E.db.locplus.customColor == 2 end,
                                get = function(info)
                                    local t = E.db.locplus[ info[#info] ] or { r = 1, g = 1, b = 1 }
                                    return t.r, t.g, t.b
                                end,
                                set = function(info, r, g, b)
                                    local t = E.db.locplus[ info[#info] ] or { r = 1, g = 1, b = 1 }
                                    t.r, t.g, t.b = r, g, b
                                    LPB:CoordsColor()
                                end,
                            },
                        },
                    },
                    coords = {
                        order = 3,
                        type = "group",
                        name = L and L["Coordinates"] or "Coordinates",
                        guiInline = true,
                        args = {
                            customCoordsColor = {
                                order = 1,
                                type = "select",
                                name = COLOR or "Color",
                                values = {
                                    [1] = L and L["Use Custom Location Color"] or "Use Custom Location Color",
                                    [2] = CLASS_COLORS or "Class Colors",
                                    [3] = CUSTOM or "Custom",
                                },
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:CoordsColor() 
                                end,
                            },
                            userCoordsColor = {
                                order = 2,
                                type = "color",
                                name = COLOR_PICKER or "Color Picker",
                                disabled = function() return E.db.locplus.customCoordsColor == 1 or E.db.locplus.customCoordsColor == 2 end,
                                get = function(info)
                                    local t = E.db.locplus[ info[#info] ] or { r = 1, g = 1, b = 1 }
                                    return t.r, t.g, t.b
                                end,
                                set = function(info, r, g, b)
                                    local t = E.db.locplus[ info[#info] ] or { r = 1, g = 1, b = 1 }
                                    t.r, t.g, t.b = r, g, b
                                    LPB:CoordsColor()
                                end,
                            },
                            dig = {
                                order = 3,
                                name = L and L["Detailed Coords"] or "Detailed Coords",
                                desc = L and L["Adds 2 digits in the coords"] or "Adds 2 digits in the coords",
                                type = "toggle",
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:CoordsDigit() 
                                end,
                            },
                        },
                    },
                    panels = {
                        order = 4,
                        type = "group",
                        name = L and L["Size"] or "Size",
                        guiInline = true,
                        args = {
                            dtwidth = {
                                order = 1,
                                type = "range",
                                name = L and L["DataTexts Width"] or "DataTexts Width",
                                desc = L and L["Adjust the DataTexts Width."] or "Adjust the DataTexts Width.",
                                min = 70, max = 200, step = 1,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:DTWidth() 
                                end,
                            },
                            dtheight = {
                                order = 2,
                                type = "range",
                                name = L and L["All Panels Height"] or "All Panels Height",
                                desc = L and L["Adjust All Panels Height."] or "Adjust All Panels Height.",
                                min = 10, max = 32, step = 1,
                                get = function(info) return E.db.locplus[ info[#info] ] end,
                                set = function(info, value) 
                                    E.db.locplus[ info[#info] ] = value 
                                    LPB:DTHeight() 
                                end,
                            },
                        },
                    },
                    font = {
                        order = 5,
                        type = "group",
                        name = L and L["Fonts"] or "Fonts",
                        guiInline = true,
                        get = function(info) return E.db.locplus[ info[#info] ] end,
                        set = function(info, value) 
                            E.db.locplus[ info[#info] ] = value 
                            LPB:ChangeFont() 
                        end,
                        args = {
                            lpfont = {
                                type = "select", 
                                dialogControl = "LSM30_Font",
                                order = 1,
                                name = L and L["Font"] or "Font",
                                desc = L and L["Choose font for the Location and Coords panels."] or "Choose font for the Location and Coords panels.",
                                values = AceGUIWidgetLSMlists.font or {},
                            },
                            lpfontsize = {
                                order = 2,
                                name = L and L["Font Size"] or "Font Size",
                                desc = L and L["Set the font size."] or "Set the font size.",
                                type = "range",
                                min = 6, max = 22, step = 1,
                            },
                            lpfontflags = {
                                order = 3,
                                name = L and L["Font Outline"] or "Font Outline",
                                type = "select",
                                values = {
                                    ["NONE"] = NONE or "None",
                                    ["OUTLINE"] = "OUTLINE",
                                    ["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE",
                                    ["THICKOUTLINE"] = "THICKOUTLINE",
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

-- Регистрация через правильный EP
local function RegisterOptions()
    local EP = E.Libs and E.Libs.EP
    if EP and not LPB._registered then
        LPB._registered = true
        EP:RegisterPlugin("ElvUI_LocPlus", function()
            if LPB.AddOptions then
                LPB:AddOptions()
            end
        end)
    end
end

-- Регистрируем опции при загрузке модуля
RegisterOptions()