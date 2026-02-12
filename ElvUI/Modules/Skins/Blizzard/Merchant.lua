local E, L, V, P, G = unpack(select(2, ...)) -- Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

-- Lua functions
local _G = _G
local unpack = unpack
-- WoW API / Variables
local GetBuybackItemInfo = GetBuybackItemInfo
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetMerchantNumItems = GetMerchantNumItems

local function LoadSkin()
	if E.private.skins.blizzard.enable ~= true or E.private.skins.blizzard.merchant ~= true then
		return
	end

	local MerchantFrame = _G.MerchantFrame
	S:HandlePortraitFrame(MerchantFrame)
	
	-- Удаляем устаревшие элементы
	MerchantFrameInset:StripTextures()
	-- MerchantArtFrame удален - убираем эту строку
	MerchantMoneyBg:StripTextures()
	MerchantMoneyInset:StripTextures()

	if _G.MerchantFrameSearchEditBox then
		S:HandleEditBox(_G.MerchantFrameSearchEditBox)
	end

	if _G.MerchantFrameLootFilter then
		S:HandleDropDownBox(_G.MerchantFrameLootFilter)
	end

	MerchantFrame:EnableMouseWheel(true)
	MerchantFrame:SetScript("OnMouseWheel", function(_, value)
		if value > 0 then
			if MerchantPrevPageButton:IsShown() and MerchantPrevPageButton:IsEnabled() == 1 then
				MerchantPrevPageButton_OnClick()
			end
		else
			if MerchantNextPageButton:IsShown() and MerchantNextPageButton:IsEnabled() == 1 then
				MerchantNextPageButton_OnClick()
			end
		end
	end)

	for i = 1, 12 do
		local item = _G["MerchantItem" .. i]
		local button = _G["MerchantItem" .. i .. "ItemButton"]
		local icon = _G["MerchantItem" .. i .. "ItemButtonIconTexture"]
		local money = _G["MerchantItem" .. i .. "MoneyFrame"]
		local nameFrame = _G["MerchantItem" .. i .. "NameFrame"]
		local name = _G["MerchantItem" .. i .. "Name"]
		local slot = _G["MerchantItem" .. i .. "SlotTexture"]

		-- Проверяем существование элемента перед обработкой
		if item then
			item:StripTextures(true)
			item:CreateBackdrop("Default")
			item.backdrop:Point("BOTTOMRIGHT", 0, -4)
		end

		if button then
			button:StripTextures()
			button:StyleButton()
			button:SetTemplate("Default", true)
			button:Size(40)
			if item then
				button:Point("TOPLEFT", item, "TOPLEFT", 4, -4)
			end
		end

		if icon then
			icon:SetTexCoord(unpack(E.TexCoords))
			icon:SetInside()
		end

		if nameFrame and slot then
			nameFrame:Point("LEFT", slot, "RIGHT", -6, -17)
		end

		if name and slot then
			name:Point("LEFT", slot, "RIGHT", -4, 5)
		end

		if money and button then
			money:ClearAllPoints()
			money:Point("BOTTOMLEFT", button, "BOTTOMRIGHT", 3, 0)
		end

		for j = 1, 2 do
			local currencyItem = _G["MerchantItem" .. i .. "AltCurrencyFrameItem" .. j]
			local currencyIcon = _G["MerchantItem" .. i .. "AltCurrencyFrameItem" .. j .. "Texture"]
			
			if currencyIcon and not currencyIcon.backdrop then
				currencyIcon.backdrop = CreateFrame("Frame", nil, currencyItem)
				currencyIcon.backdrop:SetTemplate("Default")
				currencyIcon.backdrop:SetFrameLevel(currencyItem and currencyItem:GetFrameLevel() or 0)
				currencyIcon.backdrop:SetOutside(currencyIcon)
				
				currencyIcon:SetTexCoord(unpack(E.TexCoords))
				currencyIcon:SetParent(currencyIcon.backdrop)
			end
		end
	end

	S:HandleNextPrevButton(MerchantNextPageButton, nil, nil, true)
	S:HandleNextPrevButton(MerchantPrevPageButton, nil, nil, true)

	if MerchantRepairItemButton then
		MerchantRepairItemButton:StyleButton()
		MerchantRepairItemButton:SetTemplate()
		
		for i = 1, MerchantRepairItemButton:GetNumRegions() do
			local region = select(i, MerchantRepairItemButton:GetRegions())
			if region and region:GetObjectType() == "Texture" and region:GetTexture() == "Interface\\MerchantFrame\\UI-Merchant-RepairIcons" then
				region:SetTexCoord(0.04, 0.24, 0.07, 0.5)
				region:SetInside()
			end
		end
	end

	if MerchantRepairAllButton then
		MerchantRepairAllButton:StyleButton()
		MerchantRepairAllButton:SetTemplate()
	end

	if MerchantRepairAllIcon then
		MerchantRepairAllIcon:SetTexCoord(0.34, 0.1, 0.34, 0.535, 0.535, 0.1, 0.535, 0.535)
		MerchantRepairAllIcon:SetInside()
	end

	if MerchantGuildBankRepairButton then
		MerchantGuildBankRepairButton:StyleButton()
		MerchantGuildBankRepairButton:SetTemplate()
	end

	if MerchantGuildBankRepairButtonIcon then
		MerchantGuildBankRepairButtonIcon:SetTexCoord(0.61, 0.82, 0.1, 0.52)
		MerchantGuildBankRepairButtonIcon:SetInside()
	end

	if MerchantBuyBackItem then
		MerchantBuyBackItem:StripTextures(true)
		MerchantBuyBackItem:CreateBackdrop("Transparent")
		MerchantBuyBackItem.backdrop:Point("TOPLEFT", -6, 6)
		MerchantBuyBackItem.backdrop:Point("BOTTOMRIGHT", 6, -6)
		if MerchantItem10 then
			MerchantBuyBackItem:Point("TOPLEFT", MerchantItem10, "BOTTOMLEFT", 0, -48)
		end
	end

	if MerchantBuyBackItemItemButton then
		MerchantBuyBackItemItemButton:StripTextures()
		MerchantBuyBackItemItemButton:SetTemplate("Default", true)
		MerchantBuyBackItemItemButton:StyleButton()
	end

	if MerchantBuyBackItemItemButtonIconTexture then
		MerchantBuyBackItemItemButtonIconTexture:SetTexCoord(unpack(E.TexCoords))
		MerchantBuyBackItemItemButtonIconTexture:SetInside()
	end

	for i = 1, 2 do
		local tab = _G["MerchantFrameTab" .. i]
		if tab then
			S:HandleTab(tab)
		end
	end

	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		local numMerchantItems = GetMerchantNumItems()
		local index
		local itemButton, itemName
		for i = 1, MERCHANT_ITEMS_PER_PAGE do
			index = (((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i)
			itemButton = _G["MerchantItem" .. i .. "ItemButton"]
			itemName = _G["MerchantItem" .. i .. "Name"]

			if index <= numMerchantItems and itemButton and itemButton.link then
				local _, _, quality = GetItemInfo(itemButton.link)
				if quality then
					local r, g, b = GetItemQualityColor(quality)
					if itemName then
						itemName:SetTextColor(r, g, b)
					end
					itemButton:SetBackdropBorderColor(r, g, b)
				elseif itemButton then
					itemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
				end
			elseif itemButton then
				itemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
			end
		end

		local buybackName = GetBuybackItemInfo(GetNumBuybackItems())
		if buybackName then
			local _, _, quality = GetItemInfo(buybackName)
			if quality then
				local r, g, b = GetItemQualityColor(quality)
				if MerchantBuyBackItemName then
					MerchantBuyBackItemName:SetTextColor(r, g, b)
				end
				if MerchantBuyBackItemItemButton then
					MerchantBuyBackItemItemButton:SetBackdropBorderColor(r, g, b)
				end
			elseif MerchantBuyBackItemItemButton then
				MerchantBuyBackItemItemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
			end
		elseif MerchantBuyBackItemItemButton then
			MerchantBuyBackItemItemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end)

	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
		local numBuybackItems = GetNumBuybackItems()
		local itemButton, itemName
		for i = 1, BUYBACK_ITEMS_PER_PAGE do
			itemButton = _G["MerchantItem" .. i .. "ItemButton"]
			itemName = _G["MerchantItem" .. i .. "Name"]

			if i <= numBuybackItems and itemButton then
				local buybackName = GetBuybackItemInfo(i)
				if buybackName then
					local _, _, quality = GetItemInfo(buybackName)
					if quality then
						local r, g, b = GetItemQualityColor(quality)
						if itemName then
							itemName:SetTextColor(r, g, b)
						end
						itemButton:SetBackdropBorderColor(r, g, b)
					else
						itemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
					end
				end
			elseif itemButton then
				itemButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
			end
		end
	end)
end

S:AddCallback("Skin_Merchant", LoadSkin)