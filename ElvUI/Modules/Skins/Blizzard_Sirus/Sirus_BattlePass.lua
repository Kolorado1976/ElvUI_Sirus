-- Проверяем существование ElvUI
if not ElvUI then return end

local E, L, V, P, G = unpack(ElvUI)

-- Проверяем, существует ли модуль Skins и включены ли скины
if not E:GetModule('Skins', true) then return end

local S = E:GetModule('Skins')

-- Проверяем, включены ли скины BattlePass
local function ShouldStyleBattlePass()
    -- В версии 3.3.5 может быть другая структура настроек
    if E.private and E.private.skins and E.private.skins.blizzard then
        return E.private.skins.blizzard.enable and (E.private.skins.blizzard.battlePass ~= false)
    end
    
    -- Если структура отличается, пытаемся получить настройки иначе
    if E.db and E.db.general then
        -- Проверяем включены ли скины вообще
        return true -- Временно возвращаем true, чтобы протестировать
    end
    
    return false
end

-- Если скины не включены, выходим
if not ShouldStyleBattlePass() then return end

local function CreateBeautifulButton(button)
    if not button then return end
    
    -- Проверяем, не стилизовали ли уже эту кнопку
    if button._ElvStyled then return end
    
    -- Создаем красивый фон
    if not button.backdrop then
        button.backdrop = CreateFrame("Frame", nil, button)
        button.backdrop:SetAllPoints()
        button.backdrop:SetFrameLevel(button:GetFrameLevel() - 1)
        button.backdrop:SetBackdrop({
            bgFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
            edgeFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = E.mult * 2,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        button.backdrop:SetBackdropColor(0, 0, 0, 0)
        button.backdrop:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        
        -- Градиент для фона
        if button.backdrop.CreateTexture then
            button.backdrop.gradient = button.backdrop:CreateTexture(nil, "BACKGROUND")
            button.backdrop.gradient:SetAllPoints()
            button.backdrop.gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                0.2, 0.2, 0.2, 0.8,
                0.4, 0.4, 0.4, 0.9
            )
        end
        
        -- Светящаяся граница
        if button.backdrop.CreateTexture then
            button.backdrop.overlay = button.backdrop:CreateTexture(nil, "OVERLAY")
            button.backdrop.overlay:SetAllPoints()
            button.backdrop.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
            button.backdrop.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
            button.backdrop.overlay:SetVertexColor(0.8, 0.8, 0, 0.4)
            button.backdrop.overlay:Hide()
        end
    end
    
    -- Эффект при наведении
    local oldOnEnter = button:GetScript("OnEnter")
    button:SetScript("OnEnter", function(self)
        if oldOnEnter then oldOnEnter(self) end
        if self.backdrop and self.backdrop.overlay then
            self.backdrop.overlay:Show()
            if self.backdrop.gradient then
                self.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                    0.3, 0.3, 0.3, 0.9,
                    0.5, 0.5, 0.5, 1
                )
            end
            self.backdrop:SetBackdropBorderColor(0.9, 0.9, 0, 1)
        end
    end)
    
    local oldOnLeave = button:GetScript("OnLeave")
    button:SetScript("OnLeave", function(self)
        if oldOnLeave then oldOnLeave(self) end
        if self.backdrop and self.backdrop.overlay then
            self.backdrop.overlay:Hide()
            if self.backdrop.gradient then
                self.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                    0.2, 0.2, 0.2, 0.8,
                    0.4, 0.4, 0.4, 0.9
                )
            end
            self.backdrop:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        end
    end)
    
    -- Стилизация текста
    if button.GetFontString then
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetFont(E.media.normFont, 12)
            fontString:SetShadowColor(0, 0, 0, 1)
            fontString:SetShadowOffset(1, -1)
        end
    end
    
    -- Очистка стандартных текстур
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    
    -- Убираем стандартные границы
    for i = 1, (button:GetNumRegions() or 0) do
        local region = select(i, button:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetTexture("")
            region:SetAlpha(0)
        end
    end
    
    button._ElvStyled = true
end

-- Улучшенная полоска прогресса
local function CreateBeautifulStatusBar(statusBar)
    if not statusBar then return end
    
    -- Проверяем, не стилизовали ли уже эту полоску
    if statusBar._ElvStyled then return end
    
    -- Основная текстура прогресса
    if statusBar.CreateTexture then
        statusBar.progressTexture = statusBar:CreateTexture(nil, "ARTWORK")
        statusBar.progressTexture:SetAllPoints()
        statusBar.progressTexture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusBar.progressTexture:SetGradientAlpha("HORIZONTAL", 
            0, 0.5, 1, 0.8,  -- Синий
            0, 0.8, 1, 1     -- Голубой
        )
    end
    
    -- Фон
    if statusBar.CreateTexture then
        statusBar.background = statusBar:CreateTexture(nil, "BACKGROUND")
        statusBar.background:SetAllPoints()
        statusBar.background:SetTexture(E.media.blankTex or "Interface\\Buttons\\WHITE8X8")
        statusBar.background:SetVertexColor(0.1, 0.1, 0.1, 0.6)
    end
    
    -- Блестящая анимация
    if statusBar.CreateTexture then
        statusBar.spark = statusBar:CreateTexture(nil, "OVERLAY")
        statusBar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        statusBar.spark:SetBlendMode("ADD")
        statusBar.spark:SetAlpha(0.8)
        statusBar.spark:SetSize(20, (statusBar:GetHeight() or 20) * 2)
        statusBar.spark:SetPoint("CENTER", statusBar.progressTexture, "RIGHT", 0, 0)
    end
    
    -- Обновление позиции блеска
    local oldSetValue = statusBar.SetValue
    if oldSetValue then
        statusBar.SetValue = function(self, value, ...)
            oldSetValue(self, value, ...)
            
            if self.spark and self.progressTexture then
                local min, max = self:GetMinMaxValues()
                local width = self:GetWidth() or 100
                local progress = max > min and ((value - min) / (max - min)) or 0
                
                self.spark:SetPoint("CENTER", self.progressTexture, "RIGHT", -width * (1 - progress), 0)
            end
        end
    end
    
    statusBar._ElvStyled = true
end

-- Красивые карточки уровней
local function StyleLevelCard(card)
    if not card then return end
    
    -- Проверяем, не стилизовали ли уже эту карточку
    if card._ElvStyled then return end
    
    -- Градиентный фон для карточки
    if not card.backdrop then
        card.backdrop = CreateFrame("Frame", nil, card)
        card.backdrop:SetAllPoints()
        card.backdrop:SetFrameLevel(card:GetFrameLevel() - 1)
        card.backdrop:SetBackdrop({
            bgFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
            edgeFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = E.mult * 2,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        card.backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
        
        -- Главный градиент
        if card.backdrop.CreateTexture then
            card.backdrop.gradient = card.backdrop:CreateTexture(nil, "BACKGROUND")
            card.backdrop.gradient:SetAllPoints()
            card.backdrop.gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
            card.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                0.15, 0.15, 0.2, 0.8,
                0.25, 0.25, 0.3, 0.9
            )
        end
    end
    
    -- Стилизация текста на карточке
    local function ApplyFontToFrame(frame)
        if not frame then return end
        
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child and child.IsObjectType then
                if child:IsObjectType("FontString") then
                    child:SetFont(E.media.normFont, 11)
                    child:SetShadowColor(0, 0, 0, 1)
                    child:SetShadowOffset(1, -1)
                else
                    ApplyFontToFrame(child)
                end
            end
        end
    end
    
    ApplyFontToFrame(card)
    
    -- Стилизация кнопок на карточке
    if card.FreeFrame and card.FreeFrame.ActionButton then
        CreateBeautifulButton(card.FreeFrame.ActionButton)
    end
    
    if card.PremiumFrame and card.PremiumFrame.ActionButton then
        CreateBeautifulButton(card.PremiumFrame.ActionButton)
        -- Особый стиль для премиум кнопки
        if card.PremiumFrame.ActionButton.backdrop then
            if card.PremiumFrame.ActionButton.backdrop.gradient then
                card.PremiumFrame.ActionButton.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                    0.8, 0.6, 0, 0.8,  -- Золотистый
                    1, 0.8, 0, 0.9     -- Яркий золотой
                )
            end
            card.PremiumFrame.ActionButton.backdrop:SetBackdropBorderColor(1, 0.8, 0, 1)
        end
    end
    
    card._ElvStyled = true
end

-- Простая функция для удаления текстур
local function StripTextures(frame, kill)
    if not frame then return end
    
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:IsObjectType("Texture") then
            if kill then
                region:SetTexture(nil)
                region:SetAlpha(0)
            else
                region:Hide()
            end
        end
    end
end

-- Главная функция стилизации BattlePass
local function StyleBattlePassFrame()
    if not _G.BattlePassFrame then return end
    
    local f = _G.BattlePassFrame
    
    -- Проверяем, не стилизовали ли уже этот фрейм
    if f._ElvStyled then return end
    
    -- ============================================
    -- КОНТРОЛЬ РАЗМЕРОВ - ЭТО РЕШИТ ПРОБЛЕМУ!
    -- ============================================
    
    -- Сохраняем оригинальные размеры если они есть
    if f:GetWidth() > 800 or f:GetHeight() > 600 then
        -- Устанавливаем комфортные размеры
        f:SetSize(640, 480)
    end
    
    -- Центрируем окно
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    -- Если окно не было изменено ранее, устанавливаем базовые размеры
    if f:GetWidth() < 100 or f:GetHeight() < 100 then
        f:SetSize(720, 520)
    end
    
    -- Запрещаем изменение размеров пользователем (опционально)
    f:SetResizable(false)
    f:SetMovable(true)
    
    -- ============================================
    
    -- Полная переработка фона
    StripTextures(f, true)
    
    -- Красивый основной фон
    if f.CreateTexture then
        f.background = f:CreateTexture(nil, "BACKGROUND")
        f.background:SetAllPoints()
        f.background:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.background:SetVertexColor(0.1, 0.1, 0.2, 0.9)
    end
    
    -- Декоративная рамка
    f.borderFrame = CreateFrame("Frame", nil, f)
    f.borderFrame:SetPoint("TOPLEFT", -3, 3)
    f.borderFrame:SetPoint("BOTTOMRIGHT", 3, -3)
    f.borderFrame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = {left = 5, right = 5, top = 5, bottom = 5}
    })
    f.borderFrame:SetBackdropColor(0, 0, 0, 0)
    f.borderFrame:SetBackdropBorderColor(0.8, 0.6, 0, 0.8)
    
    -- Стилизация верхней панели
    if f.TopPanel then
        -- Панель опыта
        if f.TopPanel.ExperiencePanel then
            local ep = f.TopPanel.ExperiencePanel
            
            -- Полоска опыта
            if ep.StatusBar then
                CreateBeautifulStatusBar(ep.StatusBar)
            end
            
            -- Кнопка покупки
            if ep.PurchaseButton then
                CreateBeautifulButton(ep.PurchaseButton)
            end
            
            -- Текст на панели опыта
            for i = 1, ep:GetNumRegions() do
                local region = select(i, ep:GetRegions())
                if region and region:IsObjectType("FontString") then
                    region:SetFont(E.media.normFont, 12)
                    region:SetShadowColor(0, 0, 0, 1)
                    region:SetShadowOffset(1, -1)
                end
            end
        end
        
        -- Кнопки навигации
        local navButtons = {
            f.TopPanel.RewardPageButton,
            f.TopPanel.QuestPageButton
        }
        
        for _, btn in pairs(navButtons) do
            if btn then
                CreateBeautifulButton(btn)
            end
        end
    end
    
    -- Стилизация главной страницы с уровнями
    if f.Content and f.Content.MainPage then
        local main = f.Content.MainPage
        
        -- Скроллбар (упрощенная версия)
        if main.ScrollFrame and main.ScrollFrame.ScrollBar then
            local sb = main.ScrollFrame.ScrollBar
            StripTextures(sb, true)
            
            local thumb = sb:GetThumbTexture()
            if thumb then
                thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
                thumb:SetVertexColor(0.8, 0.6, 0, 0.8)
            end
            
            -- Стилизация кнопок скроллбара
            local upButton = sb:GetChildren()
            if upButton then
                CreateBeautifulButton(upButton)
                local downButton = upButton:GetSibling()
                if downButton then
                    CreateBeautifulButton(downButton)
                end
            end
        end
        
        -- Карточки уровней
        if main.ScrollFrame and main.ScrollFrame.buttons then
            for _, card in ipairs(main.ScrollFrame.buttons) do
                StyleLevelCard(card)
            end
        end
        
        -- Кнопка покупки премиума
        if main.PurchasePremiumButton then
            CreateBeautifulButton(main.PurchasePremiumButton)
            if main.PurchasePremiumButton.backdrop then
                if main.PurchasePremiumButton.backdrop.gradient then
                    main.PurchasePremiumButton.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                        0.8, 0.6, 0, 0.9,
                        1, 0.8, 0, 1
                    )
                end
                main.PurchasePremiumButton.backdrop:SetBackdropBorderColor(1, 0.8, 0, 1)
            end
        end
    end
    
    -- Стилизация страницы квестов
    if f.Content and f.Content.QuestPage then
        local questPage = f.Content.QuestPage
        
        -- Скроллбар (упрощенная версия)
        if questPage.ScrollFrame and questPage.ScrollFrame.ScrollBar then
            local sb = questPage.ScrollFrame.ScrollBar
            StripTextures(sb, true)
            
            local thumb = sb:GetThumbTexture()
            if thumb then
                thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
                thumb:SetVertexColor(0.8, 0.6, 0, 0.8)
            end
            
            -- Стилизация кнопок скроллбара
            local upButton = sb:GetChildren()
            if upButton then
                CreateBeautifulButton(upButton)
                local downButton = upButton:GetSibling()
                if downButton then
                    CreateBeautifulButton(downButton)
                end
            end
        end
        
        -- Стилизация всех квестов
        if questPage.UpdateQuestHolders then
            local oldUpdate = questPage.UpdateQuestHolders
            questPage.UpdateQuestHolders = function(self, ...)
                oldUpdate(self, ...)
                
                local holder = self.ScrollFrame and self.ScrollFrame.ScrollChild
                if holder then
                    for i = 1, holder:GetNumChildren() do
                        local child = select(i, holder:GetChildren())
                        if child and child.IsObjectType and child:IsObjectType("Frame") then
                            -- Фон для квеста
                            if not child.backdrop then
                                child.backdrop = CreateFrame("Frame", nil, child)
                                child.backdrop:SetAllPoints()
                                child.backdrop:SetFrameLevel(child:GetFrameLevel() - 1)
                                child.backdrop:SetBackdrop({
                                    bgFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
                                    edgeFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
                                    tile = false,
                                    tileSize = 0,
                                    edgeSize = E.mult,
                                    insets = {left = 0, right = 0, top = 0, bottom = 0}
                                })
                                child.backdrop:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
                                
                                if child.backdrop.CreateTexture then
                                    child.backdrop.gradient = child.backdrop:CreateTexture(nil, "BACKGROUND")
                                    child.backdrop.gradient:SetAllPoints()
                                    child.backdrop.gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
                                    child.backdrop.gradient:SetGradientAlpha("VERTICAL", 
                                        0.15, 0.15, 0.2, 0.6,
                                        0.25, 0.25, 0.3, 0.7
                                    )
                                end
                            end
                            
                            -- Полоска прогресса квеста
                            if child.Progress and child.Progress.StatusBar then
                                CreateBeautifulStatusBar(child.Progress.StatusBar)
                            end
                            
                            -- Кнопка действия
                            if child.ActionButton then
                                CreateBeautifulButton(child.ActionButton)
                            end
                            
                            -- Стилизация текста квеста
                            for j = 1, child:GetNumRegions() do
                                local region = select(j, child:GetRegions())
                                if region and region:IsObjectType("FontString") then
                                    region:SetFont(E.media.normFont, 11)
                                    region:SetShadowColor(0, 0, 0, 1)
                                    region:SetShadowOffset(1, -1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Стилизация диалоговых окон
    local styleDialogs = {
        "PurchasePremiumDialog",
        "PurchaseExperienceDialog", 
        "PurchaseLevelExperienceDialog",
        "QuestActionDialog",
        "ItemRewardFrame",
        "AlertFrame"
    }
    
    for _, dialogName in pairs(styleDialogs) do
        local dialog = f[dialogName]
        if dialog then
            StripTextures(dialog, true)
            
            -- Красивый фон
            local bgFrame = CreateFrame("Frame", nil, dialog)
            bgFrame:SetAllPoints()
            bgFrame:SetBackdrop({
                bgFile = E.media.blankTex or "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 16,
                insets = {left = 5, right = 5, top = 5, bottom = 5}
            })
            bgFrame:SetBackdropColor(0.1, 0.1, 0.2, 0.95)
            bgFrame:SetBackdropBorderColor(0.8, 0.6, 0, 0.8)
            
            -- Стилизация кнопок в диалогах
            for i = 1, dialog:GetNumChildren() do
                local child = select(i, dialog:GetChildren())
                if child and child:IsObjectType("Button") then
                    CreateBeautifulButton(child)
                end
            end
            
            -- Стилизация текста в диалогах
            for i = 1, dialog:GetNumRegions() do
                local region = select(i, dialog:GetRegions())
                if region and region:IsObjectType("FontString") then
                    region:SetFont(E.media.normFont, 14)
                    region:SetShadowColor(0, 0, 0, 1)
                    region:SetShadowOffset(1, -1)
                end
            end
        end
    end
    
    -- Кнопка закрытия (упрощенная версия)
    if f.CloseButton then
        StripTextures(f.CloseButton, true)
        CreateBeautifulButton(f.CloseButton)
        
        -- Добавляем крестик
        local closeText = f.CloseButton:CreateFontString(nil, "OVERLAY")
        closeText:SetFont(E.media.normFont, 14)
        closeText:SetText("X")
        closeText:SetTextColor(1, 0.2, 0.2)
        closeText:SetPoint("CENTER")
        
        local oldCloseEnter = f.CloseButton:GetScript("OnEnter")
        f.CloseButton:SetScript("OnEnter", function(self)
            if oldCloseEnter then oldCloseEnter(self) end
            if closeText then
                closeText:SetTextColor(1, 0.3, 0.3, 1)
            end
        end)
        
        local oldCloseLeave = f.CloseButton:GetScript("OnLeave")
        f.CloseButton:SetScript("OnLeave", function(self)
            if oldCloseLeave then oldCloseLeave(self) end
            if closeText then
                closeText:SetTextColor(1, 0.2, 0.2, 1)
            end
        end)
    end
    
    -- Применение шрифтов ко всему фрейму
    local function ApplyFontsToFrame(frame, size)
        if not frame then return end
        
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region:IsObjectType("FontString") then
                region:SetFont(E.media.normFont, size or 12)
                region:SetShadowColor(0, 0, 0, 1)
                region:SetShadowOffset(1, -1)
            end
        end
        
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child then
                if child:IsObjectType("Button") then
                    local text = child:GetFontString()
                    if text then
                        text:SetFont(E.media.normFont, size or 12)
                        text:SetShadowColor(0, 0, 0, 1)
                        text:SetShadowOffset(1, -1)
                    end
                end
                -- Рекурсивно для детей
                ApplyFontsToFrame(child, size)
            end
        end
    end
    
    ApplyFontsToFrame(f, 12)
    
    -- Отмечаем фрейм как стилизованный
    f._ElvStyled = true
    
    -- Обновление после стилизации
    if f.UpdateDisplay then
        f:UpdateDisplay()
    end
end

-- Загрузка скина
local function LoadEnhancedSkin()
    if _G.BattlePassFrame then
        StyleBattlePassFrame()
    else
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_LOGIN")
        waitFrame:SetScript("OnEvent", function(self)
            if _G.BattlePassFrame then
                StyleBattlePassFrame()
                self:UnregisterAllEvents()
            end
        end)
        
        -- Также проверяем при открытии фрейма
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(self, event, addon)
            if event == "ADDON_LOADED" and addon == "Blizzard_BattlePassUI" then
                if _G.BattlePassFrame then
                    StyleBattlePassFrame()
                    self:UnregisterAllEvents()
                end
            end
        end)
    end
end

-- Регистрируем скин через ElvUI
local function Initialize()
    -- Создаем задержку для загрузки BattlePass
    local f = CreateFrame("Frame")
    
    local function CheckAndStyle()
        if _G.BattlePassFrame then
            LoadEnhancedSkin()
            return true
        end
        return false
    end
    
    -- Проверяем сразу
    if not CheckAndStyle() then
        -- Если еще не загружено, ждем события
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("ADDON_LOADED")
        
        f:SetScript("OnEvent", function(self, event, addon)
            if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == "Blizzard_BattlePassUI") then
                if CheckAndStyle() then
                    self:UnregisterAllEvents()
                end
            end
        end)
        
        -- Также проверяем через таймер на случай, если событие пропущено
        f.timer = f:CreateAnimationGroup()
        f.timer.anim = f.timer:CreateAnimation()
        f.timer.anim:SetDuration(1)
        f.timer:SetScript("OnFinished", function()
            if CheckAndStyle() then
                f:UnregisterAllEvents()
                f.timer:Stop()
            end
        end)
        f.timer:Play()
    end
end

-- Запускаем инициализацию после загрузки ElvUI
if E and E.RegisterModule then
    E:RegisterModule('Sirus_BattlePass_Skin', Initialize)
else
    -- Альтернативный способ инициализации
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        Initialize()
        initFrame:UnregisterAllEvents()
    end)
end