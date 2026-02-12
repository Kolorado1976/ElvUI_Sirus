local L = OVERACHIEVER_STRINGS
local OVERACHIEVER_ACHID = OVERACHIEVER_ACHID

local QuestAchievementDB = {}
local QuestLogTooltip = CreateFrame("GameTooltip", "Overachiever_QuestTooltip", UIParent, "GameTooltipTemplate")

-- Добавьте эти переменные здесь:
local lastCheckTime = 0
local CHECK_DELAY = 2 -- Задержка между проверками в секундах
local lastQuestAcceptedName = nil
local lastMessageTime = {}

local lastCheckedQuest = {}
local lastCheckTimeByName = 0
local CHECK_DELAY_BY_NAME = 5 -- Задержка 5 секунд между повторными проверками одного квеста

local function chatprint(msg, premsg)
    if Overachiever and Overachiever.chatprint then
        Overachiever.chatprint(msg, premsg)
    else
        premsg = premsg or "[Overachiever]"
        DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00"..premsg.."|r "..msg, 0.741, 1, 0.467)
    end
end

-- Простой таймер для WoW 3.3.5
local function SimpleTimer(delay, callback)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            frame:SetScript("OnUpdate", nil)
            if callback then
                callback()
            end
        end
    end)
    return frame
end

-- Функция для очистки названия квеста
local function CleanQuestName(questName)
    if not questName or type(questName) ~= "string" then
        return ""
    end
    
    -- Убираем префиксы
    questName = questName:gsub("^Получено задание: ", "")
    questName = questName:gsub("^Получено: ", "")
    questName = questName:gsub("^Задание: ", "")
    questName = questName:gsub("^Квест: ", "")
    questName = questName:gsub("^Quest: ", "")
    questName = questName:gsub("^Accepted: ", "")
    
    -- Убираем лишние пробелы
    questName = questName:gsub("^%s+", ""):gsub("%s+$", ""):trim()
    
    return questName
end

-- Добавляем функцию trim если ее нет
if not string.trim then
    string.trim = function(self)
        return self:gsub("^%s+", ""):gsub("%s+$", "")
    end
end

-- Проверяем, существует ли достижение (исправленная версия для WoW 3.3.5)
local function AchievementExists(achievementID)
    local id, name, points, completed, month, day, year, description, flags, icon = GetAchievementInfo(achievementID)
    return id and id ~= 0 and name and name ~= ""
end

-- Получаем название достижения (исправленная версия для WoW 3.3.5)
local function GetAchievementName(achievementID)
    local id, name, points, completed, month, day, year, description, flags, icon = GetAchievementInfo(achievementID)
    
    if not id or id == 0 then
        return "Достижение #" .. achievementID .. " (не существует)"
    end
    
    if name and name ~= "" and name ~= "0" then
        return name
    end
    
    return "Достижение #" .. achievementID
end

-- Получаем информацию о завершении достижения
local function GetAchievementCompletion(achievementID)
    local id, name, points, completed, month, day, year, description, flags, icon = GetAchievementInfo(achievementID)
    
    if not id or id == 0 then
        return false
    end
    
    return completed or false
end

-- Функция для проверки, является ли строка валидным названием квеста
local function IsValidQuestName(str)
    if not str or type(str) ~= "string" then
        return false
    end
    
    local s = str:trim()
    
    if #s < 3 then
        return false
    end
    
    if #s > 100 then
        return false
    end
    
    if s:match("^[%.,!%?:;%s]+$") then
        return false
    end
    
    local hasLetters = false
    for char in s:gmatch("[%aА-Яа-я]") do
        hasLetters = true
        break
    end
    
    if not hasLetters then
        return false
    end
    
    return true, s
end

-- УЛУЧШЕННАЯ функция для точной проверки по названию квеста
local function QuickCheckByQuestName(questName)
    if not QuestAchievementDB then return false end
    
    local cleanName = CleanQuestName(questName)
    
    -- Сначала ищем ТОЧНОЕ совпадение
    local achievements = QuestAchievementDB[cleanName]
    
    if achievements and #achievements > 0 then
        return true, achievements
    end
    
    -- Если точное совпадение не найдено, ищем частичные совпадения
    -- но только если название квеста достаточно длинное для надежного поиска
    if #cleanName < 10 then
        -- Для коротких названий не ищем частичные совпадения, чтобы избежать ложных срабатываний
        return false, nil
    end
    
    local lowerName = cleanName:lower()
    
    -- Список для найденных достижений
    local foundAchievements = {}
    local foundAchievementIDs = {}
    
    for key, achievements in pairs(QuestAchievementDB) do
        if type(key) == "string" then
            local lowerKey = key:lower()
            
            -- Проверяем частичные совпадения ТОЛЬКО для длинных названий
            if #key >= 8 and #cleanName >= 8 then
                -- Проверяем, начинается ли название квеста с ключа или наоборот
                local questStartsWithKey = lowerName:sub(1, #lowerKey) == lowerKey
                local keyStartsWithQuest = lowerKey:sub(1, #lowerName) == lowerName
                
                -- Проверяем наличие ключевых слов внутри
                local containsKey = lowerName:find(lowerKey, 1, true)
                local keyContainsQuest = lowerKey:find(lowerName, 1, true)
                
                -- Используем комбинацию условий для более точного поиска
                if (questStartsWithKey or keyStartsWithQuest) and 
                   (containsKey or keyContainsQuest) then
                    
                    -- Дополнительная проверка: должны совпадать хотя бы 60% символов
                    local matchScore = 0
                    for i = 1, math.min(#lowerName, #lowerKey) do
                        if lowerName:sub(i, i) == lowerKey:sub(i, i) then
                            matchScore = matchScore + 1
                        end
                    end
                    
                    local minLength = math.min(#lowerName, #lowerKey)
                    local matchPercentage = matchScore / minLength
                    
                    if matchPercentage >= 0.6 then -- 60% совпадение
                        for _, ach in ipairs(achievements) do
                            if not foundAchievementIDs[ach.id] then
                                foundAchievementIDs[ach.id] = true
                                table.insert(foundAchievements, ach)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Сортируем результаты по релевантности
    if #foundAchievements > 0 then
        -- Сортируем по длине названия (более короткие обычно точнее)
        table.sort(foundAchievements, function(a, b)
            local aLen = #a.questName or 0
            local bLen = #b.questName or 0
            return aLen < bLen
        end)
        
        -- Ограничиваем количество результатов
        if #foundAchievements > 5 then
            local limited = {}
            for i = 1, 5 do
                table.insert(limited, foundAchievements[i])
            end
            return true, limited
        end
        
        return true, foundAchievements
    end
    
    return false, nil
end

local function ExtractQuestsFromAchievement(achievementID)
    local quests = {}
    
    if not AchievementExists(achievementID) then
        return quests
    end
    
    local achievementName = GetAchievementName(achievementID)
    local numCriteria = GetAchievementNumCriteria(achievementID)
    
    -- Обычные критерии
    for i = 1, numCriteria do
        local criteriaString, criteriaType, completed, quantity, reqQuantity, flags, assetID, quantityString, criteriaID = GetAchievementCriteriaInfo(achievementID, i)
        
        if criteriaString and criteriaString ~= "" then
            -- Очищаем строку от цветовых кодов и других символов
            local cleanString = criteriaString:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "):gsub("|T.-|t", ""):trim()
            
            -- Убираем цифры в начале/конце (например, "1. Название квеста" или "Название квеста (1/10)")
            cleanString = cleanString:gsub("^%d+%.%s*", ""):gsub("^%d+%s*", ""):gsub("%s*%(%d+/%d+%)%s*$", "")
            
            -- СТРОГАЯ ПРОВЕРКА: название должно быть достаточно длинным и содержать буквы
            if cleanString and #cleanString >= 5 then
                -- Проверяем, похоже ли это на название квеста
                local hasLetters = cleanString:match("[%aА-Яа-я]")
                local hasQuestKeywords = cleanString:lower():match("квест") or cleanString:lower():match("задание") or 
                                        cleanString:lower():match("quest") or cleanString:lower():match("mission")
                
                if hasLetters and (hasQuestKeywords or #cleanString >= 8) then
                    -- Исключаем очевидно неподходящие строки
                    local isInvalid = cleanString:match("^%d+$") or -- Только цифры
                                    cleanString:match("^x%d+$") or -- x123
                                    cleanString:match("^[%.,!%?:;]+$") or -- Только пунктуация
                                    #cleanString > 100 -- Слишком длинное
                    
                    if not isInvalid then
                        local questEntry = {
                            name = cleanString,
                            nameLower = cleanString:lower(),
                            achievementName = achievementName,
                            criteriaIndex = i,
                            criteriaString = criteriaString,
                            assetID = assetID,
                            criteriaID = criteriaID,
                            criteriaType = criteriaType
                        }
                        
                        table.insert(quests, questEntry)
                    end
                end
            end
        end
    end
    
    -- ОТКЛЮЧАЕМ проверку названия достижения как квеста - это вызывает много ложных срабатываний
    -- Вместо этого добавляем только если в названии есть явные указания на квест
    
    local cleanAchievementName = achievementName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):trim()
    
    -- Только если название содержит явные слова "квест" или "задание"
    if cleanAchievementName:lower():match("квест") or cleanAchievementName:lower():match("задание") or 
       cleanAchievementName:lower():match("quest:") or cleanAchievementName:lower():match("^quest ") then
        
        local questEntry = {
            name = cleanAchievementName,
            nameLower = cleanAchievementName:lower(),
            achievementName = achievementName,
            criteriaIndex = 0,
            criteriaString = cleanAchievementName,
            criteriaType = -1,
            isAchievementName = true
        }
        
        table.insert(quests, questEntry)
    end
    
    return quests
end

-- Создаем фрейм для всплывающих уведомлений
local AlertFrame = CreateFrame("Frame", "Overachiever_AlertFrame", UIParent)
AlertFrame:SetSize(400, 160)
AlertFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
AlertFrame:SetBackdropColor(0,0,0,0.9)
AlertFrame:SetFrameStrata("TOOLTIP")
AlertFrame:Hide()

AlertFrame.Icon = AlertFrame:CreateTexture(nil, "OVERLAY")
AlertFrame.Icon:SetSize(40, 40)
AlertFrame.Icon:SetPoint("TOPLEFT", 15, -15)
AlertFrame.Icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")

AlertFrame.Title = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
AlertFrame.Title:SetPoint("TOP", 0, -15)
AlertFrame.Title:SetText("|cffffcc00Связанное достижение|r")

-- Увеличиваем доступное пространство для текста квеста
AlertFrame.QuestText = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
AlertFrame.QuestText:SetPoint("TOPLEFT", 65, -40)
AlertFrame.QuestText:SetPoint("RIGHT", -15, 0)  -- Привязываем к правому краю
AlertFrame.QuestText:SetJustifyH("LEFT")
AlertFrame.QuestText:SetText("")

-- Настройка для названия достижения
AlertFrame.AchievementText = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
AlertFrame.AchievementText:SetPoint("TOPLEFT", 65, -70)  -- Больше отступ от текста квеста
AlertFrame.AchievementText:SetPoint("RIGHT", -15, 0)     -- Привязываем к правому краю
AlertFrame.AchievementText:SetJustifyH("LEFT")
AlertFrame.AchievementText:SetText("")

AlertFrame.InfoText = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
AlertFrame.InfoText:SetPoint("TOPLEFT", 15, -110)
AlertFrame.InfoText:SetPoint("RIGHT", -15, 0)
AlertFrame.InfoText:SetJustifyH("CENTER")
AlertFrame.InfoText:SetText("Этот квест связан с достижением")

-- Функция для переноса длинных текстов (исправленная версия)
local function UpdateAlertTexts(questName, achievements)
    if not achievements or #achievements == 0 then
        return
    end
    
    local ach = achievements[1]  -- Берем первое достижение
    local completed = GetAchievementCompletion(ach.id)
    local maxWidth = 300  -- Максимальная ширина текста в пикселях
    
    -- Обработка названия квеста
    local questText = "Квест: |cffffcc00" .. questName .. "|r"
    
    -- Если текст слишком длинный, разбиваем на несколько строк
    if string.len(questName) > 40 then
        local wrappedQuest = ""
        local line = ""
        local words = {}
        
        -- Разбиваем на слова
        for word in questName:gmatch("%S+") do
            table.insert(words, word)
        end
        
        -- Собираем строки
        for i, word in ipairs(words) do
            if string.len(line .. " " .. word) < 40 then
                if line == "" then
                    line = word
                else
                    line = line .. " " .. word
                end
            else
                wrappedQuest = wrappedQuest .. (wrappedQuest == "" and "" or "|n") .. line
                line = word
            end
        end
        
        if line ~= "" then
            wrappedQuest = wrappedQuest .. (wrappedQuest == "" and "" or "|n") .. line
        end
        
        questText = "Квест: |cffffcc00" .. wrappedQuest .. "|r"
    end
    
    AlertFrame.QuestText:SetText(questText)
    
    -- Обработка названия достижения
    local status = completed and "|cff00ff00[Завершено]|r" or "|cffff0000[Не завершено]|r"
    local achievementText = "Достижение: " .. status .. " |cffffff00" .. ach.name .. "|r"
    
    -- Если название достижения слишком длинное
    if string.len(ach.name) > 35 then
        local wrappedAchievement = ""
        local line = ""
        local words = {}
        
        for word in ach.name:gmatch("%S+") do
            table.insert(words, word)
        end
        
        for i, word in ipairs(words) do
            if string.len(line .. " " .. word) < 35 then
                if line == "" then
                    line = word
                else
                    line = line .. " " .. word
                end
            else
                wrappedAchievement = wrappedAchievement .. (wrappedAchievement == "" and "" or "|n") .. line
                line = word
            end
        end
        
        if line ~= "" then
            wrappedAchievement = wrappedAchievement .. (wrappedAchievement == "" and "" or "|n") .. line
        end
        
        achievementText = "Достижение: " .. status .. " |cffffff00" .. wrappedAchievement .. "|r"
    end
    
    AlertFrame.AchievementText:SetText(achievementText)
    
    -- Автоматически подстраиваем высоту фрейма
    local questHeight = AlertFrame.QuestText:GetStringHeight()
    local achievementHeight = AlertFrame.AchievementText:GetStringHeight()
    local totalHeight = 140 + questHeight + achievementHeight  -- Базовая высота + текст
    
    AlertFrame:SetHeight(math.max(160, totalHeight))  -- Минимум 160 пикселей
    
    -- Возвращаем достижение для использования в других местах
    return ach
end

local function ShowAlertPopup(questName, achievements)
    if not Overachiever_Settings or Overachiever_Settings.ShowPopupAlerts == false then
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Всплывающие окна отключены в настройках")
        end
        return
    end
    
    if not achievements or #achievements == 0 then
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Нет достижений для показа")
        end
        return
    end
    
    local ach = achievements[1]
    
    if Overachiever_Settings and Overachiever_Settings.DebugMode then
        chatprint("Показываю всплывающее окно для: " .. questName)
        chatprint("Достижение: " .. ach.name .. " (ID: " .. ach.id .. ")")
    end
    
    local _, _, _, _, _, _, _, _, _, icon = GetAchievementInfo(ach.id)
    if icon then
        AlertFrame.Icon:SetTexture(icon)
    else
        AlertFrame.Icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    end
    
    -- Используем новую функцию для установки текста
    UpdateAlertTexts(questName, achievements)
    
    -- Устанавливаем текст в InfoText
    if #achievements > 1 then
        AlertFrame.InfoText:SetText("Этот квест связан с " .. #achievements .. " достижениями")
    else
        AlertFrame.InfoText:SetText("Этот квест связан с достижением")
    end
    
    -- Перепозиционируем InfoText
    AlertFrame.InfoText:ClearAllPoints()
    AlertFrame.InfoText:SetPoint("TOP", AlertFrame.AchievementText, "BOTTOM", 0, -15)
    AlertFrame.InfoText:SetPoint("LEFT", 15, 0)
    AlertFrame.InfoText:SetPoint("RIGHT", -15, 0)
    
    AlertFrame:SetAlpha(0)
    AlertFrame:Show()
    
    -- Позиционируем фрейм
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    
    -- Анимация появления и скрытия
    local alpha = 0
    local fadeInFrame = CreateFrame("Frame")
    fadeInFrame:SetScript("OnUpdate", function(self, elapsed)
        alpha = alpha + elapsed * 2
        if alpha >= 1 then
            alpha = 1
            self:SetScript("OnUpdate", nil)
        end
        AlertFrame:SetAlpha(alpha)
    end)
    
    SimpleTimer(10, function()  -- Увеличили время показа до 10 секунд
        if AlertFrame:IsShown() then
            alpha = 1
            local fadeOutFrame = CreateFrame("Frame")
            fadeOutFrame:SetScript("OnUpdate", function(self, elapsed)
                alpha = alpha - elapsed * 2
                if alpha <= 0 then
                    alpha = 0
                    self:SetScript("OnUpdate", nil)
                    AlertFrame:Hide()
                end
                AlertFrame:SetAlpha(alpha)
            end)
        end
    end)
end

local function CheckQuestByName(questName, forceShow, silentMode)
    if not QuestAchievementDB or not Overachiever_Settings then
        return false
    end
    
    -- Если модуль отключен в настройках и не форсирован показ
    if not forceShow and (not Overachiever_Settings.QuestAchievementTips or Overachiever_Settings.QuestAchievementTips == false) then
        return false
    end
    
    if not questName or questName == "" then
        return false
    end
    
    local cleanName = CleanQuestName(questName)
    
    -- Отфильтровываем короткие и невалидные названия
    if #cleanName < 5 or not IsValidQuestName(cleanName) then
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Пропускаем короткое/невалидное название квеста: " .. cleanName)
        end
        return false
    end
    
    -- Защита от повторной проверки одного и того же квеста в короткий промежуток времени
    local currentTime = GetTime()
    local lastCheck = lastCheckedQuest[cleanName] or 0
    
    -- Если проверяли этот квест менее 5 секунд назад - пропускаем
    if currentTime - lastCheck < CHECK_DELAY_BY_NAME and not forceShow then
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Пропускаем квест (недавно проверялся): " .. cleanName)
        end
        return false
    end
    
    -- Обновляем время последней проверки
    lastCheckedQuest[cleanName] = currentTime
    
    -- Ищем в базе данных с УЖЕСТОЧЕННЫМ поиском
    local found, achievements = QuickCheckByQuestName(cleanName)
    
    if found and achievements and #achievements > 0 then
        -- ФИЛЬТРУЕМ РЕЗУЛЬТАТЫ: оставляем только те, где совпадение достаточно точное
        local filteredAchievements = {}
        
        for _, ach in ipairs(achievements) do
            local achQuestName = ach.questName or ""
            
            -- Проверяем качество совпадения
            if achQuestName:lower() == cleanName:lower() then
                -- Точное совпадение - всегда включаем
                table.insert(filteredAchievements, ach)
            elseif #cleanName >= 10 and #achQuestName >= 10 then
                -- Для длинных названий проверяем частичное совпадение
                local cleanLower = cleanName:lower()
                local achLower = achQuestName:lower()
                
                -- Проверяем, содержится ли одно в другом
                if cleanLower:find(achLower, 1, true) or achLower:find(cleanLower, 1, true) then
                    -- Дополнительная проверка на общие слова
                    local commonWords = 0
                    for word in cleanLower:gmatch("%w+") do
                        if achLower:find(word, 1, true) then
                            commonWords = commonWords + 1
                        end
                    end
                    
                    if commonWords >= 2 then -- Хотя бы 2 общих слова
                        table.insert(filteredAchievements, ach)
                    end
                end
            end
        end
        
        -- Если после фильтрации ничего не осталось, возвращаем false
        if #filteredAchievements == 0 then
            if Overachiever_Settings and Overachiever_Settings.DebugMode then
                chatprint("После фильтрации достижений не осталось для: " .. cleanName)
            end
            return false
        end
        
        achievements = filteredAchievements
        
        -- Сортируем достижения: сначала точные совпадения, затем по ID
        table.sort(achievements, function(a, b)
            local aExact = (a.questName or ""):lower() == cleanName:lower()
            local bExact = (b.questName or ""):lower() == cleanName:lower()
            
            if aExact and not bExact then return true end
            if bExact and not aExact then return false end
            return a.id < b.id
        end)
        
        -- Ограничиваем количество отображаемых достижений (максимум 3)
        if #achievements > 3 then
            local limited = {}
            for i = 1, 3 do
                table.insert(limited, achievements[i])
            end
            achievements = limited
        end
        
        -- Показываем всплывающее окно (если включено)
        if Overachiever_Settings and Overachiever_Settings.ShowPopupAlerts ~= false and not silentMode then
            ShowAlertPopup(cleanName, achievements)
        end
        
        -- Показываем в чате (если не silentMode и включены сообщения в чате)
        if not silentMode and (Overachiever_Settings.ChatMessages == nil or Overachiever_Settings.ChatMessages == true) then
            -- Проверяем, не показывали ли мы это сообщение недавно
            local lastTimeForQuest = lastMessageTime[cleanName] or 0
            
            if currentTime - lastTimeForQuest > 30 then -- Задержка 30 секунд между одинаковыми сообщениями
                lastMessageTime[cleanName] = currentTime
                
                DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r ====================================", 0.741, 1, 0.467)
                DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r Квест: " .. cleanName, 0.741, 1, 0.467)
                DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r Найдено достижений: " .. #achievements, 0.741, 1, 0.467)
                
                for i, ach in ipairs(achievements) do
                    local completed = GetAchievementCompletion(ach.id)
                    local status = completed and "|cff00ff00[Завершено]|r" or "|cffff0000[Не завершено]|r"
                    local matchType = (ach.questName or ""):lower() == cleanName:lower() and "(точное)" or "(частичное)"
                    
                    DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r " .. ach.name .. " " .. status .. " " .. matchType, 0.741, 1, 0.467)
                end
                
                DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r ====================================", 0.741, 1, 0.467)
            end
        end
        
        return true
    else
        -- Только в режиме отладки показываем, что достижений не найдено
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Достижений не найдено для квеста: " .. cleanName)
        end
        return false
    end
end

-- Функция проверки всех активных квестов по названию (ТОЛЬКО ПОКАЗЫВАЕТ ТЕ, У КОТОРЫХ ЕСТЬ ДОСТИЖЕНИЯ)
local function CheckAllActiveQuestsByName()
    local currentTime = GetTime()
    if currentTime - lastCheckTime < CHECK_DELAY then
        return
    end
    lastCheckTime = currentTime
    
    if not QuestAchievementDB or not Overachiever_Settings or not Overachiever_Settings.QuestAchievementTips then
        return
    end
    
    local foundAny = false
    
    if Overachiever_Settings and Overachiever_Settings.DebugMode then
        chatprint("=== ПРОВЕРКА ВСЕХ АКТИВНЫХ КВЕСТОВ ===")
    end
    
    -- Используем таблицу для отслеживания уже проверенных квестов в этой сессии
    local checkedInThisSession = {}
    
    -- Проверяем все квесты в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, _, isHeader = GetQuestLogTitle(i)
        
        -- Пропускаем заголовки
        if not isHeader and title and title ~= "" then
            local cleanName = CleanQuestName(title)
            
            -- Проверяем, не проверяли ли мы этот квест в этой сессии
            if not checkedInThisSession[cleanName] then
                checkedInThisSession[cleanName] = true
                
                -- В режиме отладки показываем все квесты
                if Overachiever_Settings and Overachiever_Settings.DebugMode then
                    chatprint("Проверяю квест: " .. cleanName)
                end
                
                -- Проверяем достижения для этого квеста в ТИХОМ режиме (не показываем в чате)
                local found = CheckQuestByName(cleanName, false, true) -- true = silentMode
                
                -- Если нашли достижения, показываем ТОЛЬКО ЭТОТ квест
                if found then
                    foundAny = true
                    -- Теперь показываем этот квест в нормальном режиме, НО проверяем задержку
                    local lastCheck = lastCheckedQuest[cleanName] or 0
                    if currentTime - lastCheck >= CHECK_DELAY_BY_NAME then
                        CheckQuestByName(cleanName, true, false) -- false = не silentMode
                    else
                        if Overachiever_Settings and Overachiever_Settings.DebugMode then
                            chatprint("Пропускаем повторную проверку квеста (задержка): " .. cleanName)
                        end
                    end
                end
            else
                if Overachiever_Settings and Overachiever_Settings.DebugMode then
                    chatprint("Пропускаем уже проверенный квест в этой сессии: " .. cleanName)
                end
            end
        end
    end
    
    if Overachiever_Settings and Overachiever_Settings.DebugMode then
        if foundAny then
            chatprint("Найдены достижения.")
        else
            chatprint("Достижений не найдено.")
        end
    end
end

local lastCheckTime = 0
local CHECK_DELAY = 2 -- Задержка между проверками в секундах

-- Упрощенный обработчик событий
local questEventFrame = CreateFrame("Frame")
questEventFrame:RegisterEvent("QUEST_LOG_UPDATE")
questEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
questEventFrame:RegisterEvent("QUEST_ACCEPTED")

local lastQuestAcceptedName = nil
local lastQuestAcceptedTime = 0
local CHECK_DELAY_ACCEPTED = 5 -- Задержка 5 секунд между проверками принятого квеста

questEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_ACCEPTED" then
        -- В WoW 3.3.5 QUEST_ACCEPTED передает индекс в журнале
        local questIndex = ...
        
        if questIndex then
            -- Получаем название квеста
            local title, _, _, _, isHeader = GetQuestLogTitle(questIndex)
            
            if not isHeader and title then
                lastQuestAcceptedName = title
                lastQuestAcceptedTime = GetTime()
                
                if Overachiever_Settings and Overachiever_Settings.DebugMode then
                    chatprint("Принят квест: " .. title)
                end
                
                -- Немедленно проверяем по названию (не в тихом режиме)
                SimpleTimer(1.0, function()
                    CheckQuestByName(title, true, false) -- false = не silentMode
                end)
            end
        end
        
    elseif event == "QUEST_LOG_UPDATE" then
        if Overachiever_Settings and Overachiever_Settings.DebugMode then
            chatprint("Событие QUEST_LOG_UPDATE получено")
        end
        
        -- Проверяем, не был ли только что принят квест
        local currentTime = GetTime()
        if currentTime - lastQuestAcceptedTime < CHECK_DELAY_ACCEPTED then
            if Overachiever_Settings and Overachiever_Settings.DebugMode then
                chatprint("Пропускаем QUEST_LOG_UPDATE - недавно приняли квест")
            end
            return
        end
        
        -- Проверяем все квесты по названиям (будут показаны только те, у которых есть достижения)
        SimpleTimer(1.5, CheckAllActiveQuestsByName)
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Проверяем квесты при входе в мир (будут показаны только те, у которых есть достижения)
        SimpleTimer(3.0, CheckAllActiveQuestsByName)
    end
end)

-- УЛУЧШЕННАЯ функция для построения базы данных
function Overachiever.BuildQuestToAchievementDB()
    QuestAchievementDB = {}
    
    chatprint("=== ПОСТРОЕНИЕ БАЗЫ ДАННЫХ ===")
    chatprint("Строю полную базу данных связей квестов и достижений...")
    
    -- Используем расширенный диапазон ID достижений
    local achievementIDs = {}
    for i = 1, 5000 do -- Увеличили до 5000
        table.insert(achievementIDs, i)
    end
    
    local totalLinks = 0
    local achievementsProcessed = 0
    local achievementsWithQuests = 0
    local totalQuestsFound = 0
    
    -- Проходим по всем достижениям
    for _, achievementID in ipairs(achievementIDs) do
        if AchievementExists(achievementID) then
            achievementsProcessed = achievementsProcessed + 1
            
            -- Извлекаем все возможные квесты из этого достижения
            local quests = ExtractQuestsFromAchievement(achievementID)
            
            if #quests > 0 then
                achievementsWithQuests = achievementsWithQuests + 1
                totalQuestsFound = totalQuestsFound + #quests
                
                local achievementName = GetAchievementName(achievementID)
                local completed = GetAchievementCompletion(achievementID)
                
                -- Обрабатываем каждый найденный квест
                for _, quest in ipairs(quests) do
                    local questName = quest.name
                    
                    if questName and questName ~= "" then
                        local isValid, cleanedName = IsValidQuestName(questName)
                        
                        if isValid then
                            cleanedName = CleanQuestName(cleanedName)
                            
                            if not QuestAchievementDB[cleanedName] then
                                QuestAchievementDB[cleanedName] = {}
                            end
                            
                            -- Проверяем, нет ли уже этого достижения для этого квеста
                            local exists = false
                            for _, existing in ipairs(QuestAchievementDB[cleanedName]) do
                                if existing.id == achievementID then
                                    exists = true
                                    break
                                end
                            end
                            
                            if not exists then
                                local achievementData = {
                                    id = achievementID,
                                    name = achievementName,
                                    completed = completed or false,
                                    questName = cleanedName,
                                    criteriaString = quest.criteriaString or achievementName,
                                    criteriaType = quest.criteriaType or 0,
                                    isMetaAchievement = (quest.criteriaType == 8) -- Критерий типа 8 = мета-достижение
                                }
                                
                                table.insert(QuestAchievementDB[cleanedName], achievementData)
                                totalLinks = totalLinks + 1
                            end
                        end
                    end
                end
            end
            
            -- Показываем прогресс
            if achievementsProcessed % 500 == 0 then
                chatprint(string.format("Обработано: %d достижений | С квестами: %d | Связей: %d", 
                    achievementsProcessed, achievementsWithQuests, totalLinks))
            end
        end
    end
    
    -- ДОПОЛНИТЕЛЬНО: проверяем все мета-достижения (достижения, состоящие из других достижений)
    chatprint("=== ПРОВЕРКА МЕТА-ДОСТИЖЕНИЙ ===")
    local metaAchievementsFound = 0
    
    for _, achievementID in ipairs(achievementIDs) do
        if AchievementExists(achievementID) then
            local achievementName = GetAchievementName(achievementID)
            local numCriteria = GetAchievementNumCriteria(achievementID)
            
            -- Ищем мета-достижения (те, у которых есть критерии типа "достижение")
            for i = 1, numCriteria do
                local criteriaString, criteriaType = GetAchievementCriteriaInfo(achievementID, i)
                
                -- Тип 8 = мета-критерий (другое достижение)
                if criteriaType == 8 then
                    -- Пытаемся найти связанные квесты через мета-достижение
                    -- Извлекаем название критерия
                    local cleanCriteria = criteriaString:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "):trim()
                    
                    if cleanCriteria and cleanCriteria ~= "" then
                        -- Ищем это название в нашей базе данных как квест
                        for questName, achievements in pairs(QuestAchievementDB) do
                            if type(questName) == "string" then
                                -- Проверяем, содержит ли название квеста строку критерия
                                local lowerQuestName = questName:lower()
                                local lowerCriteria = cleanCriteria:lower()
                                
                                if lowerQuestName == lowerCriteria or 
                                   lowerQuestName:find(lowerCriteria, 1, true) or
                                   lowerCriteria:find(lowerQuestName, 1, true) then
                                   
                                    -- Добавляем мета-достижение для этого квеста
                                    local exists = false
                                    for _, existing in ipairs(QuestAchievementDB[questName]) do
                                        if existing.id == achievementID then
                                            exists = true
                                            break
                                        end
                                    end
                                    
                                    if not exists then
                                        local completed = GetAchievementCompletion(achievementID)
                                        local achievementData = {
                                            id = achievementID,
                                            name = achievementName,
                                            completed = completed or false,
                                            questName = questName,
                                            criteriaString = cleanCriteria,
                                            criteriaType = 8,
                                            isMetaAchievement = true
                                        }
                                        
                                        table.insert(QuestAchievementDB[questName], achievementData)
                                        totalLinks = totalLinks + 1
                                        metaAchievementsFound = metaAchievementsFound + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    chatprint(string.format("Найдено мета-достижений: %d", metaAchievementsFound))
    
    -- Сохраняем в переменные персонажа
    if not Overachiever_CharVars then
        Overachiever_CharVars = {}
    end
    Overachiever_CharVars.QuestAchievementDB = QuestAchievementDB
    Overachiever_CharVars.QuestAchievementDBVersion = 3.0 -- Обновили версию
    Overachiever_CharVars.QuestAchievementDBTime = time()
    
    -- Статистика
    local uniqueQuests = 0
    for _ in pairs(QuestAchievementDB) do
        uniqueQuests = uniqueQuests + 1
    end
    
    chatprint("========================================")
    chatprint("БАЗА ДАННЫХ ПОЛНОСТЬЮ ПОСТРОЕНА!")
    chatprint(string.format("Обработано достижений: %d", achievementsProcessed))
    chatprint(string.format("Достижений с квестами: %d", achievementsWithQuests))
    chatprint(string.format("Всего связей квест-достижение: %d", totalLinks))
    chatprint(string.format("Уникальных квестов в БД: %d", uniqueQuests))
    chatprint(string.format("Мета-достижений добавлено: %d", metaAchievementsFound))
    chatprint("========================================")
end

-- УЛУЧШЕННАЯ функция для быстрой проверки по названию квеста
local function QuickCheckByQuestName(questName)
    if not QuestAchievementDB then return false end
    
    local cleanName = CleanQuestName(questName)
    
    -- Сначала ищем точное совпадение
    local achievements = QuestAchievementDB[cleanName]
    
    if achievements and #achievements > 0 then
        return true, achievements
    end
    
    -- Ищем по частичному совпадению (более тщательный поиск)
    local lowerName = cleanName:lower()
    
    -- Список для найденных достижений
    local foundAchievements = {}
    local foundAchievementIDs = {}
    
    for key, achievements in pairs(QuestAchievementDB) do
        if type(key) == "string" then
            local lowerKey = key:lower()
            
            -- Проверяем разные варианты совпадений
            if lowerName == lowerKey then
                -- Точное совпадение
                for _, ach in ipairs(achievements) do
                    if not foundAchievementIDs[ach.id] then
                        foundAchievementIDs[ach.id] = true
                        table.insert(foundAchievements, ach)
                    end
                end
            elseif lowerName:find(lowerKey, 1, true) then
                -- Название квеста содержит ключ из базы
                for _, ach in ipairs(achievements) do
                    if not foundAchievementIDs[ach.id] then
                        foundAchievementIDs[ach.id] = true
                        table.insert(foundAchievements, ach)
                    end
                end
            elseif lowerKey:find(lowerName, 1, true) then
                -- Ключ из базы содержит название квеста
                for _, ach in ipairs(achievements) do
                    if not foundAchievementIDs[ach.id] then
                        foundAchievementIDs[ach.id] = true
                        table.insert(foundAchievements, ach)
                    end
                end
            end
        end
    end
    
    if #foundAchievements > 0 then
        return true, foundAchievements
    end
    
    return false, nil
end

function Overachiever.CountQuestAchievementLinks()
    local count = 0
    if not QuestAchievementDB then return 0 end
    for key, achievements in pairs(QuestAchievementDB) do
        count = count + #achievements
    end
    return count
end

-- Команды для управления

SLASH_OVERACHIEVER_REBUILDDB1 = "/oarebuild"
SlashCmdList["OVERACHIEVER_REBUILDDB"] = function()
    chatprint("Перестраиваю базу данных связей квестов и достижений...")
    Overachiever.BuildQuestToAchievementDB()
end

SLASH_OVERACHIEVER_STATS1 = "/oastats"
SlashCmdList["OVERACHIEVER_STATS"] = function()
    chatprint("=== СТАТИСТИКА БАЗЫ ДАННЫХ ===")
    
    if not QuestAchievementDB then
        chatprint("База данных не загружена.")
        return
    end
    
    local totalQuests = 0
    local totalAchievements = 0
    local uniqueAchievements = {}
    
    for key, achievements in pairs(QuestAchievementDB) do
        if #achievements > 0 then
            totalQuests = totalQuests + 1
            totalAchievements = totalAchievements + #achievements
            
            for _, ach in ipairs(achievements) do
                uniqueAchievements[ach.id] = true
            end
        end
    end
    
    chatprint(string.format("Всего квестов в БД: %d", totalQuests))
    chatprint(string.format("Всего связей: %d", totalAchievements))
    
    local uniqueCount = 0
    for _ in pairs(uniqueAchievements) do
        uniqueCount = uniqueCount + 1
    end
    chatprint(string.format("Уникальных достижений: %d", uniqueCount))
end

-- Команда для проверки квеста по названию
SLASH_OVERACHIEVER_CHECKQUEST1 = "/oacheckquest"
SlashCmdList["OVERACHIEVER_CHECKQUEST"] = function(msg)
    if not msg or msg == "" then
        -- Если не указано название, проверяем все активные квесты (ТОЛЬКО ТЕ, У КОТОРЫХ ЕСТЬ ДОСТИЖЕНИЯ)
        -- Убираем сообщение о начале проверки
        CheckAllActiveQuestsByName()
        return
    end
    
    -- Только в режиме отладки показываем заголовок
    if Overachiever_Settings and Overachiever_Settings.DebugMode then
        chatprint("=== ПРОВЕРКА КВЕСТА ===")
        chatprint("Название: " .. msg)
    end
    
    CheckQuestByName(msg, true, false) -- false = не silentMode
end

-- Команда для включения/выключения сообщений в чате
SLASH_OVERACHIEVER_CHATMESSAGES1 = "/oachat"
SlashCmdList["OVERACHIEVER_CHATMESSAGES"] = function()
    if not Overachiever_Settings then
        Overachiever_Settings = {}
    end
    
    Overachiever_Settings.ChatMessages = not (Overachiever_Settings.ChatMessages == false)
    chatprint("Сообщения в чате: " .. (Overachiever_Settings.ChatMessages and "|cff00ff00ВКЛЮЧЕНЫ|r" or "|cffff0000ВЫКЛЮЧЕНЫ|r"))
end

-- Команда для проверки ВСЕХ активных квестов (включая те, у которых нет достижений - только для отладки)
SLASH_OVERACHIEVER_CHECKALL1 = "/oacheckall"
SlashCmdList["OVERACHIEVER_CHECKALL"] = function()
    chatprint("=== ПОЛНАЯ ПРОВЕРКА ВСЕХ АКТИВНЫХ КВЕСТОВ ===")
    
    local foundAny = false
    
    -- Проверяем все квесты в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, _, isHeader = GetQuestLogTitle(i)
        
        -- Пропускаем заголовки
        if not isHeader and title and title ~= "" then
            local cleanName = CleanQuestName(title)
            
            chatprint("Квест: " .. cleanName)
            
            -- Проверяем в НЕ тихом режиме
            local found = CheckQuestByName(cleanName, true, false) -- false = не silentMode
            
            if found then
                foundAny = true
            else
                chatprint("  Достижений не найдено")
            end
        end
    end
    
    if not foundAny then
        chatprint("Среди всех активных квестов достижений не найдено")
    end
end

-- Команда для включения/выключения тихого режима (только квесты с достижениями)
SLASH_OVERACHIEVER_QUIET1 = "/oaquiet"
SlashCmdList["OVERACHIEVER_QUIET"] = function()
    if not Overachiever_Settings then
        Overachiever_Settings = {}
    end
    
    Overachiever_Settings.QuietMode = not Overachiever_Settings.QuietMode
    chatprint("Тихий режим: " .. (Overachiever_Settings.QuietMode and "|cff00ff00ВКЛЮЧЕН|r" or "|cffff0000ВЫКЛЮЧЕН|r"))
    chatprint("Теперь будут показываться только квесты, у которых есть связанные достижения.")
end

-- Команда для проверки последнего принятого квеста
SLASH_OVERACHIEVER_CHECKLAST1 = "/oachecklast"
SlashCmdList["OVERACHIEVER_CHECKLAST"] = function()
    chatprint("=== ПРОВЕРКА ПОСЛЕДНЕГО ПРИНЯТОГО КВЕСТА ===")
    
    if lastQuestAcceptedName then
        chatprint("Последний квест: " .. lastQuestAcceptedName)
        CheckQuestByName(lastQuestAcceptedName, true)
    else
        chatprint("Нет информации о последнем принятом квесте")
    end
end

-- Команда для поиска квеста по части названия
SLASH_OVERACHIEVER_FINDQUEST1 = "/oafindquest"
SlashCmdList["OVERACHIEVER_FINDQUEST"] = function(msg)
    if not msg or msg == "" then
        chatprint("Использование: /oafindquest <часть названия>")
        return
    end
    
    chatprint("=== ПОИСК КВЕСТОВ ===")
    chatprint("Ищем: " .. msg)
    
    local searchLower = msg:lower()
    local foundCount = 0
    
    for key, achievements in pairs(QuestAchievementDB) do
        if type(key) == "string" and key:lower():find(searchLower, 1, true) then
            foundCount = foundCount + 1
            chatprint(string.format("%d. %s (%d достижений)", foundCount, key, #achievements))
            
            -- Если нашли точное совпадение, показываем достижения
            if key:lower() == searchLower then
                chatprint("ТОЧНОЕ СОВПАДЕНИЕ! Показываю достижения:")
                for i, ach in ipairs(achievements) do
                    local completed = GetAchievementCompletion(ach.id)
                    local status = completed and "|cff00ff00✓|r" or "|cffff0000✗|r"
                    chatprint(string.format("  %s %s (ID: %d)", status, ach.name, ach.id))
                end
            end
        end
    end
    
    if foundCount == 0 then
        chatprint("Квестов не найдено")
    else
        chatprint(string.format("Найдено квестов: %d", foundCount))
    end
end

SLASH_OVERACHIEVER_DEBUG1 = "/oadebug"
SlashCmdList["OVERACHIEVER_DEBUG"] = function()
    if not Overachiever_Settings then
        Overachiever_Settings = {}
    end
    
    Overachiever_Settings.DebugMode = not Overachiever_Settings.DebugMode
    DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r Режим отладки: " .. 
        (Overachiever_Settings.DebugMode and "|cff00ff00ВКЛЮЧЕН|r" or "|cffff0000ВЫКЛЮЧЕН|r"), 0.741, 1, 0.467)
end

SLASH_OVERACHIEVER_TOGGLEPOPUP1 = "/oatogglepopup"
SlashCmdList["OVERACHIEVER_TOGGLEPOPUP"] = function()
    if not Overachiever_Settings then
        Overachiever_Settings = {}
    end
    
    Overachiever_Settings.ShowPopupAlerts = not Overachiever_Settings.ShowPopupAlerts
    chatprint("Всплывающие уведомления: " .. (Overachiever_Settings.ShowPopupAlerts and "|cff00ff00Включены|r" or "|cffff0000Выключены|r"))
end

SLASH_OVERACHIEVER_REBUILDSTRICT1 = "/oarebuildstrict"
SlashCmdList["OVERACHIEVER_REBUILDSTRICT"] = function()
    chatprint("Перестраиваю базу данных с более строгими критериями...")
    chatprint("Это может занять несколько минут.")
    
    -- Очищаем старую базу
    if Overachiever_CharVars then
        Overachiever_CharVars.QuestAchievementDB = nil
        Overachiever_CharVars.QuestAchievementDBVersion = nil
    end
    QuestAchievementDB = {}
    
    -- Запускаем перестройку
    SimpleTimer(2, function()
        Overachiever.BuildQuestToAchievementDB()
    end)
end

local function InitializeQuestAchievementModule()
    if not Overachiever_Settings then
        Overachiever_Settings = {}
    end
    
    -- Настройки по умолчанию
    if Overachiever_Settings.QuestAchievementTips == nil then
        Overachiever_Settings.QuestAchievementTips = true
    end
    if Overachiever_Settings.ShowPopupAlerts == nil then
        Overachiever_Settings.ShowPopupAlerts = true
    end
    if Overachiever_Settings.DebugMode == nil then
        Overachiever_Settings.DebugMode = false
    end
    
    if Overachiever_Settings.DebugMode then
        chatprint("Настройки всплывающих окон: " .. (Overachiever_Settings.ShowPopupAlerts and "ВКЛ" or "ВЫКЛ"))
    end
    
    if Overachiever_Settings.QuestAchievementTips == false then
        chatprint("Модуль связи квестов и достижений отключен в настройках.")
        return
    end
    
    -- Загружаем или создаем базу данных
    if Overachiever_CharVars and Overachiever_CharVars.QuestAchievementDB then
        QuestAchievementDB = Overachiever_CharVars.QuestAchievementDB
        local linkCount = Overachiever.CountQuestAchievementLinks()
        chatprint("База данных связей загружена. " .. (linkCount or 0) .. " связей квест-достижение.")
    else
        chatprint("Первая загрузка. Строю базу данных связей...")
        SimpleTimer(3, function()
            Overachiever.BuildQuestToAchievementDB()
        end)
    end
    
    chatprint("Модуль связи квестов и достижений готов.")
    chatprint("Команды:")
    chatprint("  /oarebuild - перестроить базу данных")
    chatprint("  /oastats - статистика базы данных")
    chatprint("  /oacheckquest <название> - проверить квест")
    chatprint("  /oachecklast - проверить последний принятый квест")
    chatprint("  /oafindquest <часть названия> - найти квесты в БД")
    chatprint("  /oadebug - включить/выключить отладку")
    chatprint("  /oatogglepopup - включить/выключить всплывающие окна")
end

-- Автоматическая инициализация
local isInitialized = false

local function DelayedInit()
    if not isInitialized then
        isInitialized = true
        SimpleTimer(5, function()
            InitializeQuestAchievementModule()
        end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        DelayedInit()
    elseif event == "ADDON_LOADED" and arg1 == "Overachiever" then
        self:UnregisterEvent("ADDON_LOADED")
        DelayedInit()
    end
end)

-- Экспортируем функции
Overachiever.InitializeQuestAchievementModule = InitializeQuestAchievementModule
Overachiever.BuildQuestToAchievementDB = Overachiever.BuildQuestToAchievementDB
Overachiever.CheckQuestByName = CheckQuestByName
Overachiever.CountQuestAchievementLinks = Overachiever.CountQuestAchievementLinks
Overachiever.ExtractQuestsFromAchievement = ExtractQuestsFromAchievement
Overachiever.GetAllAchievements = function()
    local achievements = {}
    for i = 1, 3000 do
        table.insert(achievements, i)
    end
    return achievements
end

-- Сообщение о загрузке
DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r Модуль связи квестов и достижений загружен!", 0.741, 1, 0.467)
DEFAULT_CHAT_FRAME:AddMessage("|cff7eff00[Overachiever]|r Принимайте квесты для автоматической проверки связей", 0.741, 1, 0.467)