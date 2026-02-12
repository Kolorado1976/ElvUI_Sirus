
local E, L, V, P, G = unpack(ElvUI)
local DAN = E:GetModule("DmgAtNameplates")

local animationValues = {
	["verticalUp"] = L["Vertical Up"],
	["verticalDown"] = L["Vertical Down"],
	["fountain"] = L["Fountain"],
	["rainfall"] = L["Rainfall"],
	["disabled"] = L["Disabled"]
}

local function tableForAllEvents(type)
	local table = {
		font = {
			order = 1,
			type = "select",
			name = L["font"],
			dialogControl = "LSM30_Font",
			values = AceGUIWidgetLSMlists.font,
		},
		fontSize = {
			order = 2,
			type = "range",
			name = L["fontSize"],
			min = 5, max = 72, step = 1,
		},
		fontAlpha = {
			order = 3,
			type = "range",
			name = L["fontAlpha"],
			min = 0.1,
			max = 1,
			step = .01,
		},
		fontOutline = {
			order = 4,
			type = "select",
			name = L["Font Outline"],
			values = {
				["NONE"] = L["NONE"],
				["OUTLINE"] = "OUTLINE",
				["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE",
				["THICKOUTLINE"] = "THICKOUTLINE"
			}
		},
		animation = {
			order = 6,
			type = "select",
			name = L["animation"],
			desc = L["animation"],
			values = animationValues,
		},
	}
	return table
end

function DAN:DmgAtNameplatesOptions()
	-- DAN.db = E.db.DmgAtNameplates or P.DmgAtNameplates
	E.Options.args.DmgAtNameplates = {
		order = 55,
		type = "group",
		childGroups = "tab",
		name = string.format("|cff00FF00%s|r", "Всплывающий урон"),
		args = {
			common = {
				order = 1,
				type = "group",
				name = L["common"],
				get = function(info)  return E.db.DmgAtNameplates[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates[info[#info]] = value
				end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["commondesc"]
					},
					enable = {
						order = 2,
						type = "toggle",
						name = L["onorof"],
						desc = L["onorofdesc"],
						get = function(info) return E.db.DmgAtNameplates.enable end,
						set = function(info, value)
							E.db.DmgAtNameplates.enable = value
							if not E.db.DmgAtNameplates.enable then
								DAN:OnDisable()
							else
								DAN:OnEnable()
							end
						end
					},
					showIcon = {
						order = 3,
						type = "toggle",
						name = L["sicon"],
						desc = L["sicon"],
						get = function(info) return E.db.DmgAtNameplates.showIcon end,
						set = function(info, value)
							E.db.DmgAtNameplates.showIcon = value
						end
					},
					showFromAnotherPlayer = {
						order = 4,
						type = "toggle",
						name = L["showFromAnotherPlayer"],
						desc = L["showFromAnotherPlayer"],
						get = function(info) return E.db.DmgAtNameplates.showFromAnotherPlayer end,
						set = function(info, value)
							E.db.DmgAtNameplates.showFromAnotherPlayer = value
						end
					},
					duration = {
						order = 5,
						type = "range",
						name = L["Duration of all animations"],
						min = 0.1, max = 10, step = 0.1,
					},
					spacer2 = {
						order = 6,
						type = "description",
						name = " "
					},
					font = {
						order = 7,
						type = "select",
						name = L["font"],
						dialogControl = "LSM30_Font",
						values = AceGUIWidgetLSMlists.font,
						get = function()
							return E.db.DmgAtNameplates.font
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.font = newValue
						end
					},
					fontSize = {
						order = 8,
						type = "range",
						name = L["fontSize"],
						min = 5, max = 72, step = 1,
					},
					fontAlpha = {
						order = 9,
						type = "range",
						name = L["fontAlpha"],
						min = 0.1,
						max = 1,
						step = .01,
					},
					fontOutline = {
						order = 10,
						type = "select",
						name = L["Font Outline"],
						values = {
							["NONE"] = L["NONE"],
							["OUTLINE"] = "OUTLINE",
							["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE",
							["THICKOUTLINE"] = "THICKOUTLINE"
						}
					},
					header2 = {
						order = 11,
						type = "header",
						name = L["offtarget"]
					},
					showOffTargetText = {
						order = 12,
						type = "toggle",
						name = L["offtarget"],
						desc = "",
						get = function()
							return E.db.DmgAtNameplates.showOffTargetText
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.showOffTargetText = newValue
						end,
					},
					showOffTargetTextSize = {
						order = 13,
						type = "range",
						name = L["otfSize"],
						desc = "",
						min = 5,
						max = 72,
						step = 1,
						disabled = function()
							return not E.db.DmgAtNameplates.showOffTargetText
						end,
						get = function()
							return E.db.DmgAtNameplates.showOffTargetTextSize
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.showOffTargetTextSize = newValue
						end,
					},
					showOffTargetTextAlpha = {
						order = 14,
						type = "range",
						name = L["fontAlpha"],
						desc = "",
						min = 0.1,
						max = 1,
						step = .01,
						disabled = function()
							return not E.db.DmgAtNameplates.showOffTargetText
						end,
						get = function()
							return E.db.DmgAtNameplates.showOffTargetTextAlpha
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.showOffTargetTextAlpha = newValue
						end,
					},
					header3 = {
						order = 15,
						type = "header",
						name = L["SmallHits"]
					},
					smallHits = {
						type = "toggle",
						order = 16,
						name = L["SmallHits"],
						desc = L["SmallHitsdesc"],
						disabled = function()
							return not E.db.DmgAtNameplates.enable or E.db.DmgAtNameplates.smallHitsHide
						end,
						get = function()
							return E.db.DmgAtNameplates.smallHits
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.smallHits = newValue
						end,
					},
					smallHitsScale = {
						order = 17,
						type = "range",
						name = L["SmallHitsScale"],
						desc = "",
						disabled = function()
							return not E.db.DmgAtNameplates.enable or not E.db.DmgAtNameplates.smallHits or E.db.DmgAtNameplates.smallHitsHide
						end,
						min = 0.33,
						max = 1,
						step = .01,
						get = function()
							return E.db.DmgAtNameplates.smallHitsScale
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.smallHitsScale = newValue
						end,
						width = "double"
					},
					smallHitsHide = {
						order = 18,
						type = "toggle",
						name = L["SmallHitsHide"],
						desc = L["SmallHitsHidedesc"],
						get = function()
							return E.db.DmgAtNameplates.smallHitsHide
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.smallHitsHide = newValue
						end,
					},
					textFormat = {
						order = 19,
						type = "select",
						name = L["textformat"],
						values = {
							["none"] = L["none"],
							["csep"] = L["csep"],
							["kkk"] = L["kkk"],
						},
						get = function()
							return E.db.DmgAtNameplates.textFormat
						end,
						set = function(_, newValue)
							E.db.DmgAtNameplates.textFormat = newValue
						end
					},
				},
			},
            playerToTargetDamageTextTab = {
				order = 2,
				type = "group",
				name = L["damageText"],
				get = function(info)  return E.db.DmgAtNameplates[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates[info[#info]] = value
				end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["playerToTargetDamageText"]
					},
					playerToTargetDamageText = {
						order = 2,
						type = "toggle",
						name = L["playerToTargetDamageText"],
						desc = L["pttdtdesc"],
					},
					petToTargetDamageText = {
						order = 3,
						type = "toggle",
						name = L["petToTargetDamageText"],
						desc = L["petttdtdesc"],
					},
					targetToPlayerDamageText = {
						order = 4,
						type = "toggle",
						name = L["targetToPlayerDamageText"],
						desc = L["ttpdtdesc"],
					},
					showDmgToFriend = {
						order = 5,
						type = "toggle",
						name = L["showDmgToFriend"],
						desc = L["showDmgToFriend"],
					},
					showDmgToEnemy = {
						order = 6,
						type = "toggle",
						name = L["showDmgToEnemy"],
						desc = L["showDmgToEnemy"],
					},
					header2 = {
						order = 7,
						type = "header",
						name = L["AnimationDmg"]
					},
					autoAttackPlusCritAnimation = {
						order = 8,
						type = "select",
						name = L["autoAttackPlusCritAnimation"],
						desc = L["autoAttackPlusCritAnimation"],
						values = animationValues,
					},
					autoAttack = {
						order = 9,
						type = "select",
						name = L["autoAttack"],
						desc = L["autoAttack"],
						values = animationValues,
					},
					critAnimation = {
						order = 10,
						type = "select",
						name = L["crit"],
						desc = L["crit"],
						values = animationValues,
					},
					commonDMGAnimation = {
						order = 11,
						type = "select",
						name = L["commonDMGAnimation"],
						desc = L["commonDMGAnimation"],
						values = animationValues,
					},
				},
			},
            playerToTargetHealTextTab = {
				order = 3,
				type = "group",
				name = L["healText"],
				get = function(info)  return E.db.DmgAtNameplates[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates[info[#info]] = value
				end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["playerToTargetHealText"]
					},
					playerToTargetHealText = {
						order = 2,
						type = "toggle",
						name = L["playerToTargetHealText"],
						desc = L["ptthtdesc"],
						get = function(info) return E.db.DmgAtNameplates.playerToTargetHealText end,
						set = function(info, value)
							E.db.DmgAtNameplates.playerToTargetHealText = value
						end
					},
					targetToPlayerHealText = {
						order = 3,
						type = "toggle",
						name = L["targetToPlayerHealText"],
						desc = L["ttphtdesc"],
						get = function(info) return E.db.DmgAtNameplates.targetToPlayerHealText end,
						set = function(info, value)
							E.db.DmgAtNameplates.targetToPlayerHealText = value
						end
					},
					petToTargetHealText = {
						order = 4,
						type = "toggle",
						name = L["petToTargetHealText"],
						desc = L["pettthtdesc"],
						get = function(info) return E.db.DmgAtNameplates.petToTargetHealText end,
						set = function(info, value)
							E.db.DmgAtNameplates.petToTargetHealText = value
						end
					},
					showOverHeal = {
						order = 5,
						type = "toggle",
						name = L["showOverHeal"],
						desc = L["shwrhlldesc"],
						get = function(info) return E.db.DmgAtNameplates.showOverHeal end,
						set = function(info, value)
							E.db.DmgAtNameplates.showOverHeal = value
						end
					},
					header2 = {
						order = 6,
						type = "header",
						name = L["AnimationHeal"]
					},
					healCrit = {
						order = 7,
						type = "select",
						name = L["crit"],
						desc = L["crit"],
						values = animationValues,
						get = function(info) return E.db.DmgAtNameplates.healCrit end,
						set = function(info, value)
							E.db.DmgAtNameplates.healCrit = value
						end
					},
					noHealCrit = {
						order = 8,
						type = "select",
						name = L["noHealCrit"],
						desc = L["noHealCrit"],
						values = animationValues,
						get = function(info) return E.db.DmgAtNameplates.noHealCrit end,
						set = function(info, value)
							E.db.DmgAtNameplates.noHealCrit = value
						end
					},
					healColor = {
						order = 9,
						type = "color",
						name = L["healColor"],
						desc = "",
						hasAlpha = false,
						set = function(_, r, g, b)
							E.db.DmgAtNameplates.healColor = DAN:rgbToHex(r, g, b)
						end,
						get = function()
							return DAN:hexToRGB(E.db.DmgAtNameplates.healColor)
						end,
					},
				},
			},
			DispelTab = {
				order = 4,
				type = "group",
				name = L["DispelTab"],
				get = function(info)  return E.db.DmgAtNameplates.dispel[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates.dispel[info[#info]] = value
				end,
				args = tableForAllEvents("dispel");
			},
			MissTab = {
				order = 5,
				type = "group",
				name = L["MissTab"],
				get = function(info)  return E.db.DmgAtNameplates.miss[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates.miss[info[#info]] = value
				end,
				args = tableForAllEvents("miss");
			},
			InterruptTab = {
				order = 6,
				type = "group",
				name = L["InterruptTab"],
				get = function(info)  return E.db.DmgAtNameplates.interrupt[info[#info]] end,
				set = function(info, value)
					E.db.DmgAtNameplates.interrupt[info[#info]] = value
				end,
				args = tableForAllEvents("interrupt");
			},
		}
	}
end
