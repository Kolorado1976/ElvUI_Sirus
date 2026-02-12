local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local select = select
local unpack = unpack
--WoW API / Variables
local GetCurrencyListInfo = GetCurrencyListInfo
local GetInventoryItemQuality = GetInventoryItemQuality
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetNumFactions = GetNumFactions
local GetPetHappiness = GetPetHappiness
local HasPetUI = HasPetUI
local UnitFactionGroup = UnitFactionGroup
local hooksecurefunc = hooksecurefunc
local GetInventoryItemID = GetInventoryItemID
local GetInventorySlotInfo = GetInventorySlotInfo
local GetItemGem = GetItemGem
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local HybridScrollFrame_GetOffset = HybridScrollFrame_GetOffset

local NUM_FACTIONS_DISPLAYED = NUM_FACTIONS_DISPLAYED
local CHARACTERFRAME_SUBFRAMES = CHARACTERFRAME_SUBFRAMES
local NUM_GEARSET_ICONS_SHOWN = NUM_GEARSET_ICONS_SHOWN
local SKILLS_TO_DISPLAY = SKILLS_TO_DISPLAY
local find = string.find

local Slots = {
	"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", 
	"ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot", 
	"LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", 
	"Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", 
	"RangedSlot", "AmmoSlot"
}

function S:ColorItemCharacterBorder()
	for _,slot in pairs(Slots)do
		local clink = GetInventoryItemLink("player", GetInventorySlotInfo(slot))
		slot = _G["Character"..slot]
		if not slot.textureSoc then
			slot.textureSoc = slot:CreateTexture("nil", "TOOLTIP")
			slot.textureSoc:SetInside()
			slot.textureSoc:SetTexture([[Interface\AddOns\ElvUI\Media\Textures\BagNewItemGlow]])
			slot.textureSoc:SetVertexColor(GetItemQualityColor(5))
			slot.textureSoc:Hide()
		end
		local found
		if clink then
			for i = 1, 3 do
				local _, glink = GetItemGem(clink, i)
				if glink then
					local _, _, itemRarity = GetItemInfo(glink)
					if itemRarity == 5 then
						slot.textureSoc:Show()
						found = true
						break
					end
				end
			end
		end
		if not found and slot.textureSoc then
			slot.textureSoc:Hide()
		end
	end
end

function S:ColorItemInspectBorder()
	for _,slot in pairs(Slots)do
		local clink = GetInventoryItemLink("target", GetInventorySlotInfo(slot))
		slot = _G["Inspect"..slot]
		if slot then
			if not slot.textureSoc then
				slot.textureSoc = slot:CreateTexture("nil", "TOOLTIP")
				slot.textureSoc:SetInside()
				slot.textureSoc:SetTexture([[Interface\AddOns\ElvUI\Media\Textures\BagNewItemGlow]])
				slot.textureSoc:SetVertexColor(GetItemQualityColor(5))
				slot.textureSoc:Hide()
			end
			local found
			if clink then
				for i = 1, 3 do
					local _, glink = GetItemGem(clink, i)
					if glink then
						local _, _, itemRarity = GetItemInfo(glink)
						if itemRarity == 5 then
							slot.textureSoc:Show()
							found = true
							break
						end
					end
				end
			end
			if not found and slot.textureSoc then
				slot.textureSoc:Hide()
			end
		end
	end
end

local function ColorizeStatPane(frame)
	if frame.leftGrad then return end

	local r, g, b = 0.8, 0.8, 0.8
	frame.leftGrad = frame:CreateTexture(nil, "BORDER")
	frame.leftGrad:Width(frame:GetWidth() * .5)
	frame.leftGrad:Height(frame:GetHeight())
	frame.leftGrad:Point("LEFT", frame, "CENTER")
	frame.leftGrad:SetTexture(E.media.blankTex)
	frame.leftGrad:SetGradientAlpha("Horizontal", r, g, b, 0.35, r, g, b, 0)

	frame.rightGrad = frame:CreateTexture(nil, "BORDER")
	frame.rightGrad:Width(frame:GetWidth() * .5)
	frame.rightGrad:Height(frame:GetHeight())
	frame.rightGrad:Point("RIGHT", frame, "CENTER")
	frame.rightGrad:SetTexture(E.Media.Textures.White8x8)
	frame.rightGrad:SetGradientAlpha("Horizontal", r, g, b, 0, r, g, b, 0.35)
end

local function HandleResistanceFrame(frameName)
	for i = 1, 5 do
		local frame = _G[frameName..i]
		if frame then
			frame:Size(24)
			frame:SetTemplate("Default")

			if i ~= 1 then
				frame:ClearAllPoints()
				frame:Point("TOP", _G[frameName..i-1], "BOTTOM", 0, -(E.Border + E.Spacing))
			end

			local icon = select(1, frame:GetRegions())
			local text = select(2, frame:GetRegions())
			
			if icon then
				icon:SetInside()
				icon:SetDrawLayer("ARTWORK")
			end
			
			if text then
				text:SetDrawLayer("OVERLAY")
			end
		end
	end
end

local function UpdateFaction()
	if not ReputationFrame or not ReputationFrame:IsVisible() then return end
	
	local factionOffset = FauxScrollFrame_GetOffset(ReputationListScrollFrame)
	local factionIndex, factionRow, factionButton
	local numFactions = GetNumFactions()
	for i = 1, NUM_FACTIONS_DISPLAYED, 1 do
		factionRow = _G["ReputationBar"..i]
		factionButton = _G["ReputationBar"..i.."ExpandOrCollapseButton"]
		factionIndex = factionOffset + i
		if factionIndex <= numFactions then
			if factionRow.isCollapsed then
				factionButton:GetNormalTexture():SetTexture(E.Media.Textures.Plus)
			else
				factionButton:GetNormalTexture():SetTexture(E.Media.Textures.Minus)
			end
		end
	end
end

local function UpdateHappiness(self)
	local happiness = GetPetHappiness()
	local _, isHunterPet = HasPetUI()
	if not happiness or not isHunterPet then return end

	local texture = self:GetRegions()
	if texture then
		if happiness == 1 then
			texture:SetTexCoord(0.41, 0.53, 0.06, 0.30)
		elseif happiness == 2 then
			texture:SetTexCoord(0.22, 0.345, 0.06, 0.30)
		elseif happiness == 3 then
			texture:SetTexCoord(0.04, 0.15, 0.06, 0.30)
		end
	end
end

local function ColorItemBorder()
	for _, slot in pairs(Slots) do
		local target = _G["Character"..slot]
		if target then
			local slotId = GetInventorySlotInfo(slot)
			local itemId = GetInventoryItemID("player", slotId)

			if itemId then
				local rarity = GetInventoryItemQuality("player", slotId)
				if rarity and rarity > 1 then
					local r, g, b = GetItemQualityColor(rarity)
					target:SetBackdropBorderColor(r, g, b)
				else
					target:SetBackdropBorderColor(unpack(E.media.bordercolor))
				end
			else
				target:SetBackdropBorderColor(unpack(E.media.bordercolor))
			end
		end
	end
	S:ColorItemCharacterBorder()
end

local function LoadSkin()
	if E.private.skins.blizzard.enable ~= true or E.private.skins.blizzard.character ~= true then return; end

	-- Character Frame
	S:HandlePortraitFrame(CharacterFrame)

	-- Tabs
	for i = 1, #CHARACTERFRAME_SUBFRAMES do
		local tab = _G["CharacterFrameTab" .. i]
		if tab then
			tab.HighlightLeft:StripTextures()
			tab.HighlightMiddle:StripTextures()
			tab.HighlightRight:StripTextures()
			S:HandleTab(tab)
		end
	end

	-- Gear Manager Dialog
	GearManagerDialog:StripTextures()
	GearManagerDialog:CreateBackdrop("Transparent")
	GearManagerDialog.backdrop:Point("TOPLEFT", 5, -2)
	GearManagerDialog.backdrop:Point("BOTTOMRIGHT", -1, 4)

	S:HandleCloseButton(GearManagerDialogClose)

	for i = 1, 10 do
		local button = _G["GearSetButton"..i]
		local icon = _G["GearSetButton"..i.."Icon"]
		if button then
			button:StripTextures()
			button:StyleButton()
			button:CreateBackdrop("Default")
			button.backdrop:SetAllPoints()
			
			if icon then
				icon:SetTexCoord(unpack(E.TexCoords))
				icon:SetInside()
			end
		end
	end

	S:HandleButton(GearManagerDialogDeleteSet)
	S:HandleButton(GearManagerDialogEquipSet)
	S:HandleButton(GearManagerDialogSaveSet)

	-- Gear Manager Dialog Popup
	GearManagerDialogPopup:StripTextures()
	GearManagerDialogPopup:CreateBackdrop("Transparent")
	GearManagerDialogPopup.backdrop:Point("TOPLEFT", 5, -2)
	GearManagerDialogPopup.backdrop:Point("BOTTOMRIGHT", -4, 8)

	GearManagerDialogPopup:Height(287 + 15)
	GearManagerDialogPopupScrollFrame:Height(184 + 15)
	GearManagerDialogPopup.BorderBox:StripTextures()
	S:HandleEditBox(GearManagerDialogPopupSearchBox)
	S:HandleEditBox(GearManagerDialogPopupEditBox)

	GearManagerDialogPopupScrollFrame:StripTextures()
	S:HandleScrollBar(GearManagerDialogPopupScrollFrameScrollBar)

	for i = 1, NUM_GEARSET_ICONS_SHOWN do
		local button = _G["GearManagerDialogPopupButton"..i]
		local icon = button.icon

		if button then
			button:StripTextures()
			button:StyleButton(true)

			icon:SetTexCoord(unpack(E.TexCoords))
			_G["GearManagerDialogPopupButton"..i.."Icon"]:SetTexture(nil)

			icon:SetInside()
			button:SetFrameLevel(button:GetFrameLevel() + 2)
			if not button.backdrop then
				button:CreateBackdrop("Default")
				button.backdrop:SetAllPoints()
			end
		end
	end

	S:HandleButton(GearManagerDialogPopupOkay)
	S:HandleButton(GearManagerDialogPopupCancel)

	-- PaperDoll Frame
	PaperDollFrame:StripTextures(true)

	PaperDollFrame.NewPanel:StripTextures()
	ColorizeStatPane(PaperDollFrameStrengthenFrame.Title)
	PaperDollFrameStrengthenFrame.Title.Background:SetAlpha(0)

	S:HandleButton(PaperDollFrameStrengthenFrame.ResetButton)

	for i = 1, C_PlayerInfo.GetNumBonusStats() do
		local statPlus = _G["PaperDollFrameStrengthenFrameStat"..i.."Plus"]
		if statPlus then
			statPlus:StripTextures()
			S:HandleButton(statPlus)
			statPlus:SetNormalTexture(E.Media.Textures.Plus)
			statPlus:GetNormalTexture():SetInside()
			statPlus:SetPushedTexture(E.Media.Textures.Plus)
			statPlus:GetPushedTexture():SetInside()
			statPlus:SetDisabledTexture(E.Media.Textures.Plus)
			statPlus:GetDisabledTexture():SetInside()
			statPlus:GetDisabledTexture():SetDesaturated(true)
		end
	end

	PaperDollSidebarTabs:StripTextures()

	C_Timer:After(0,function()
		if PaperDollFrameItemSetSwapButton then
			PaperDollFrameItemSetSwapButton:StripTextures()
			S:HandleButton(PaperDollFrameItemSetSwapButton)
			PaperDollFrameItemSetSwapButton.Icon:SetTexCoord(unpack(E.TexCoords))
			PaperDollFrameItemSetSwapButton:ClearAllPoints()
			PaperDollFrameItemSetSwapButton:SetParent(ElvUI_PaperDollSidebarTabs and ElvUI_PaperDollSidebarTabs or PaperDollSidebarTabs)
			PaperDollFrameItemSetSwapButton:Size(32)
			local level = ElvUI_PaperDollSidebarTab1 and ElvUI_PaperDollSidebarTab1:GetFrameLevel() or PaperDollSidebarTab1:GetFrameLevel()
			local point = ElvUI_PaperDollSidebarTab1 and ElvUI_PaperDollSidebarTab1 or PaperDollSidebarTab1
			PaperDollFrameItemSetSwapButton:SetFrameLevel(level+1)
			PaperDollFrameItemSetSwapButton:SetPoint("RIGHT",point,"LEFT",-4,0)
		end
	end)
	
	PaperDollFrame.StatsInset:StripTextures()
	PaperDollFrame.EquipInset:StripTextures()
	
	CharacterModelFrame:CreateBackdrop()
	CharacterModelFrame.backdrop:SetOutside(CharacterModelFrameBackgroundOverlay)
	CharacterModelFrame:DisableDrawLayer("OVERLAY")

	S:HandleControlFrame(CharacterModelFrame.controlFrame)

	ColorizeStatPane(CharacterItemLevelFrame)
	CharacterItemLevelFrame.ilvlbackground:SetAlpha(0)

	-- Title Frame
	PlayerTitleFrame:StripTextures()
	PlayerTitleFrame:CreateBackdrop("Default")
	PlayerTitleFrame.backdrop:Point("TOPLEFT", 20, 3)
	PlayerTitleFrame.backdrop:Point("BOTTOMRIGHT", -16, 14)
	PlayerTitleFrame.backdrop:SetFrameLevel(PlayerTitleFrame:GetFrameLevel())
	
	S:HandleNextPrevButton(PlayerTitleFrameButton)
	PlayerTitleFrameButton:ClearAllPoints()
	PlayerTitleFrameButton:Point("RIGHT", PlayerTitleFrame.backdrop, "RIGHT", -2, 0)

	-- Title Picker
	PlayerTitlePickerScrollFrame:StripTextures()
	PlayerTitlePickerScrollFrame:CreateBackdrop("Transparent")

	for i = 1, #PlayerTitlePickerScrollFrame.buttons do
		PlayerTitlePickerScrollFrame.buttons[i].text:FontTemplate()
	end

	S:HandleScrollBar(PlayerTitlePickerScrollFrameScrollBar)

	-- Sidebar Tabs
	for i = 1, #PAPERDOLL_SIDEBARS do
		local tab = _G["PaperDollSidebarTab"..i]
		if tab then
			tab:CreateBackdrop()
			tab.Icon:SetAllPoints()
			tab.Highlights:SetTexture(1, 1, 1, .3)
			tab.Highlights:SetAllPoints()
			tab.TabBg:Kill()
		end
	end

	-- Customization Button
	if CharacterCustomizationButton then
		CharacterCustomizationButton:ClearAllPoints()
		CharacterCustomizationButton:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 18, -18)
		CharacterCustomizationButton:Size(28, 28)
		CharacterCustomizationButton:CreateBackdrop()

		if CharacterCustomizationButton.NormalTexture then
			CharacterCustomizationButton.NormalTexture:SetInside()
			CharacterCustomizationButton.NormalTexture:SetTexCoord(unpack(E.TexCoords))
		end

		if CharacterCustomizationButton.HighlightTexture then
			CharacterCustomizationButton.HighlightTexture:SetTexture(1, 1, 1, 0.3)
			CharacterCustomizationButton.HighlightTexture:SetInside()
		end

		if CharacterCustomizationButton.DisabledTexture then
			CharacterCustomizationButton.DisabledTexture:SetInside()
			CharacterCustomizationButton.DisabledTexture:SetTexCoord(unpack(E.TexCoords))
		end
	end

	-- Gear Manager Toggle
	_G["GearManagerToggleButton"]:Size(26, 32)
	_G["GearManagerToggleButton"]:CreateBackdrop("Default")

	GearManagerToggleButton:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.125, 0.90625)
	GearManagerToggleButton:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.125, 0.90625)
	GearManagerToggleButton:GetHighlightTexture():SetTexture(1, 1, 1, 0.3)
	GearManagerToggleButton:GetHighlightTexture():SetAllPoints()

	-- Equipment Slots
	local popoutButtonOnEnter = function(btn) 
		if btn.icon then
			btn.icon:SetVertexColor(unpack(E.media.rgbvaluecolor)) 
		end
	end
	
	local popoutButtonOnLeave = function(btn) 
		if btn.icon then
			btn.icon:SetVertexColor(1, 1, 1) 
		end
	end

	for _, slot in pairs(Slots) do
		local icon = _G["Character"..slot.."IconTexture"]
		local cooldown = _G["Character"..slot.."Cooldown"]
		local popout = _G["Character"..slot.."PopoutButton"]

		slot = _G["Character"..slot]
		if slot then
			slot:StripTextures()
			slot:StyleButton(false)
			slot:SetTemplate("Default", true, true)

			if icon then
				icon:SetTexCoord(unpack(E.TexCoords))
				icon:SetInside()
			end

			slot:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 2)

			if cooldown then
				E:RegisterCooldown(cooldown)
			end

			if popout then
				popout:StripTextures()
				popout:HookScript("OnEnter", popoutButtonOnEnter)
				popout:HookScript("OnLeave", popoutButtonOnLeave)

				popout.icon = popout:CreateTexture(nil, "ARTWORK")
				popout.icon:Size(24)
				popout.icon:Point("CENTER")
				popout.icon:SetTexture(E.Media.Textures.ArrowUp)

				if slot.verticalFlyout then
					popout.icon:SetRotation(S.ArrowRotation.down)
				else
					popout.icon:SetRotation(S.ArrowRotation.right)
				end
			end
		end
	end

	-- Item Border Colors
	local CheckItemBorderColor = CreateFrame("Frame")
	CheckItemBorderColor:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	CheckItemBorderColor:SetScript("OnEvent", ColorItemBorder)
	CharacterFrame:HookScript("OnShow", ColorItemBorder)
	ColorItemBorder()

	-- Resistance Frames
	HandleResistanceFrame("MagicResFrame")

	select(1, MagicResFrame1:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.25, 0.32421875) --Arcane
	select(1, MagicResFrame2:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.0234375, 0.09765625) --Fire
	select(1, MagicResFrame3:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.13671875, 0.2109375) --Nature
	select(1, MagicResFrame4:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.36328125, 0.4375) --Frost
	select(1, MagicResFrame5:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.4765625, 0.55078125) --Shadow

	-- Dropdowns
	S:HandleDropDownBox(PlayerStatFrameLeftDropDown, 140, "down")
	S:HandleDropDownBox(PlayerStatFrameRightDropDown, 140, "down")
	CharacterAttributesFrame:StripTextures()

	-- Pet Frame
	if PetPaperDollFrame then
		PetPaperDollFrame:StripTextures(true)

		S:HandleRotateButton(PetModelFrameRotateLeftButton)
		S:HandleRotateButton(PetModelFrameRotateRightButton)
		PetModelFrameRotateRightButton:SetPoint("TOPLEFT", PetModelFrameRotateLeftButton, "TOPRIGHT", 3, 0)

		HandleResistanceFrame("PetMagicResFrame")

		select(1, PetMagicResFrame1:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.25, 0.32421875) --Arcane
		select(1, PetMagicResFrame2:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.0234375, 0.09765625) --Fire
		select(1, PetMagicResFrame3:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.13671875, 0.2109375) --Nature
		select(1, PetMagicResFrame4:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.36328125, 0.4375) --Frost
		select(1, PetMagicResFrame5:GetRegions()):SetTexCoord(0.21875, 0.8125, 0.4765625, 0.55078125) --Shadow

		PetAttributesFrame:StripTextures()

		PetPaperDollFrameExpBar:StripTextures()
		PetPaperDollFrameExpBar:SetStatusBarTexture(E.media.normTex)
		E:RegisterStatusBar(PetPaperDollFrameExpBar)
		PetPaperDollFrameExpBar:CreateBackdrop("Default")

		if PetPaperDollPetInfo then
			PetPaperDollPetInfo:SetPoint("TOPLEFT", PetModelFrameRotateLeftButton, "BOTTOMLEFT", 9, -3)
			PetPaperDollPetInfo:GetRegions():SetTexCoord(0.04, 0.15, 0.06, 0.30)
			PetPaperDollPetInfo:SetFrameLevel(PetModelFrame:GetFrameLevel() + 2)
			PetPaperDollPetInfo:CreateBackdrop("Default")
			PetPaperDollPetInfo:Size(24, 24)
			UpdateHappiness(PetPaperDollPetInfo)

			PetPaperDollPetInfo:RegisterEvent("UNIT_HAPPINESS")
			PetPaperDollPetInfo:SetScript("OnEvent", UpdateHappiness)
			PetPaperDollPetInfo:SetScript("OnShow", UpdateHappiness)
		end
	end

	-- Companion Frame
	if PetPaperDollFrameCompanionFrame then
		PetPaperDollFrameCompanionFrame:StripTextures()

		S:HandleRotateButton(CompanionModelFrameRotateLeftButton)
		S:HandleRotateButton(CompanionModelFrameRotateRightButton)
		CompanionModelFrameRotateRightButton:SetPoint("TOPLEFT", CompanionModelFrameRotateLeftButton, "TOPRIGHT", 3, 0)

		S:HandleButton(CompanionSummonButton)
		S:HandleNextPrevButton(CompanionPrevPageButton)
		S:HandleNextPrevButton(CompanionNextPageButton)
	end

	-- Reputation Frame - ТОЛЬКО СТИЛИЗАЦИЯ, БЕЗ ИЗМЕНЕНИЯ ПОЗИЦИЙ
	if ReputationFrame then
		ReputationFrame:StripTextures(true)

		for i = 1, NUM_FACTIONS_DISPLAYED do
			local factionRow = _G["ReputationBar"..i]
			local factionBar = _G["ReputationBar"..i.."ReputationBar"]
			local factionButton = _G["ReputationBar"..i.."ExpandOrCollapseButton"]

			if factionRow then
				factionRow:StripTextures(true)
			end

			if factionBar then
				factionBar:StripTextures()
				factionBar:SetStatusBarTexture(E.media.normTex)
				E:RegisterStatusBar(factionBar)
				factionBar:CreateBackdrop("Default")
			end

			if factionButton then
				factionButton:SetNormalTexture(E.Media.Textures.Minus)
				factionButton.SetNormalTexture = E.noop
				factionButton:GetNormalTexture():Size(15)
				factionButton:SetHighlightTexture(nil)
			end
		end

		hooksecurefunc("ReputationFrame_Update", UpdateFaction)

		if ReputationListScrollFrame then
			ReputationListScrollFrame:StripTextures()
			S:HandleScrollBar(ReputationListScrollFrameScrollBar)
		end

		if ReputationDetailFrame then
			ReputationDetailFrame:StripTextures()
			ReputationDetailFrame:SetTemplate("Transparent")
			ReputationDetailFrame.TextContainer:StripTextures()
			ReputationDetailFrame.TextContainer.ShadowOverlay:StripTextures()

			S:HandleCloseButton(ReputationDetailCloseButton)
			ReputationDetailCloseButton:Point("TOPRIGHT", 3, 4)

			S:HandleCheckBox(ReputationDetailAtWarCheckBox)
			ReputationDetailAtWarCheckBox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-SwordCheck")
			S:HandleCheckBox(ReputationDetailInactiveCheckBox)
			S:HandleCheckBox(ReputationDetailMainScreenCheckBox)
		end
	end

	-- Skill Frame
	if SkillFrame then
		SkillFrame:StripTextures(true)

		S:HandleNextPrevButton(SkillDetailStatusBarUnlearnButton)
		SkillDetailStatusBarUnlearnButton:Size(24)
		SkillDetailStatusBarUnlearnButton:Point("LEFT", SkillDetailStatusBarBorder, "RIGHT", 5, 0)
		SkillDetailStatusBarUnlearnButton:SetHitRectInsets(0, 0, 0, 0)

		SkillFrameExpandButtonFrame:StripTextures()

		SkillFrameCollapseAllButton:SetNormalTexture(E.Media.Textures.Plus)
		SkillFrameCollapseAllButton.SetNormalTexture = E.noop
		SkillFrameCollapseAllButton:GetNormalTexture():Size(16)
		SkillFrameCollapseAllButton:Point("LEFT", SkillFrameExpandTabLeft, "RIGHT", -40, -3)
		SkillFrameCollapseAllButton:SetHighlightTexture(nil)

		hooksecurefunc(SkillFrameCollapseAllButton, "SetNormalTexture", function(_, texture)
			if find(texture, "MinusButton") then
				SkillFrameCollapseAllButton:GetNormalTexture():SetTexture(E.Media.Textures.Minus)
			else
				SkillFrameCollapseAllButton:GetNormalTexture():SetTexture(E.Media.Textures.Plus)
			end
		end)

		for i = 1, SKILLS_TO_DISPLAY do
			local statusBar = _G["SkillRankFrame"..i]
			local statusBarBorder = _G["SkillRankFrame"..i.."Border"]
			local statusBarBackground = _G["SkillRankFrame"..i.."Background"]

			if statusBar then
				statusBar:SetStatusBarTexture(E.media.normTex)
				E:RegisterStatusBar(statusBar)
				statusBar:CreateBackdrop("Default")
			end

			if statusBarBorder then
				statusBarBorder:StripTextures()
			end
			
			if statusBarBackground then
				statusBarBackground:SetTexture(nil)
			end

			local skillTypeLabelText = _G["SkillTypeLabel"..i]
			if skillTypeLabelText then
				skillTypeLabelText:SetNormalTexture(E.Media.Textures.Plus)
				skillTypeLabelText.SetNormalTexture = E.noop
				skillTypeLabelText:GetNormalTexture():Size(16)
				skillTypeLabelText:SetHighlightTexture(nil)

				hooksecurefunc(skillTypeLabelText, "SetNormalTexture", function(self, texture)
					if find(texture, "MinusButton") then
						self:GetNormalTexture():SetTexture(E.Media.Textures.Minus)
					else
						self:GetNormalTexture():SetTexture(E.Media.Textures.Plus)
					end
				end)
			end
		end

		if SkillDetailStatusBar then
			SkillDetailStatusBar:StripTextures()
			SkillDetailStatusBar:SetParent(SkillDetailScrollFrame)
			SkillDetailStatusBar:CreateBackdrop("Default")
			SkillDetailStatusBar:SetStatusBarTexture(E.media.normTex)
			SkillDetailStatusBar:SetParent(SkillDetailScrollFrame)
			E:RegisterStatusBar(SkillDetailStatusBar)
		end

		if SkillListScrollFrame then
			SkillListScrollFrame:StripTextures()
			S:HandleScrollBar(SkillListScrollFrameScrollBar)
		end

		if SkillDetailScrollFrame then
			SkillDetailScrollFrame:StripTextures()
			S:HandleScrollBar(SkillDetailScrollFrameScrollBar)
		end
	end

	-- Token Frame - ТОЛЬКО СТИЛИЗАЦИЯ, БЕЗ ИЗМЕНЕНИЯ ПОЗИЦИЙ
	if TokenFrame then
		TokenFrame:StripTextures(true)

		hooksecurefunc("TokenFrame_Update", function()
			if not TokenFrame:IsVisible() then return end
			
			local scrollFrame = TokenFrameContainer
			if not scrollFrame then return end
			
			local offset = HybridScrollFrame_GetOffset(scrollFrame)
			local buttons = scrollFrame.buttons
			if not buttons then return end
			
			local numButtons = #buttons
			local _, name, isHeader, isExpanded, extraCurrencyType, icon
			local button, index

			for i = 1, numButtons do
				index = offset + i
				name, isHeader, isExpanded, _, _, _, extraCurrencyType, icon = GetCurrencyListInfo(index)
				button = buttons[i]

				if button and name then
					if not button.isSkinned then
						if button.categoryLeft then button.categoryLeft:Kill() end
						if button.categoryRight then button.categoryRight:Kill() end
						if button.highlight then button.highlight:Kill() end

						if button.expandIcon then
							button.expandIcon:SetTexture(E.Media.Textures.Plus)
							button.expandIcon:SetTexCoord(0, 1, 0, 1)
							button.expandIcon:Size(16)
						end

						button.isSkinned = true
					end

					if isHeader then
						if button.expandIcon then
							if isExpanded then
								button.expandIcon:SetTexture(E.Media.Textures.Minus)
							else
								button.expandIcon:SetTexture(E.Media.Textures.Plus)
							end
							button.expandIcon:SetTexCoord(0, 1, 0, 1)
						end
					else
						if button.icon then
							if extraCurrencyType == 1 then
								button.icon:SetTexCoord(unpack(E.TexCoords))
							elseif extraCurrencyType == 2 then
								local factionGroup = UnitFactionGroup("player")
								if factionGroup then
									button.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup)
									button.icon:SetTexCoord(0.03125, 0.59375, 0.03125, 0.59375)
								else
									button.icon:SetTexCoord(unpack(E.TexCoords))
								end
							else
								if icon then
									button.icon:SetTexture(icon)
								end
								button.icon:SetTexCoord(unpack(E.TexCoords))
							end
						end
					end
				end
			end
		end)

		if TokenFrameContainerScrollBar then
			S:HandleScrollBar(TokenFrameContainerScrollBar)
		end

		if TokenFramePopup then
			TokenFramePopup:StripTextures()
			TokenFramePopup:SetTemplate("Transparent")
			S:HandleCloseButton(TokenFramePopupCloseButton)
			S:HandleCheckBox(TokenFramePopupInactiveCheckBox)
			S:HandleCheckBox(TokenFramePopupBackpackCheckBox)
		end
	end
end

S:AddCallback("Skin_Character", LoadSkin)