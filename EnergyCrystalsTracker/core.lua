local addonName, ECT = ...
string.trim = string.trim or function(self)
    return self:match("^%s*(.-)%s*$")
end
function ECT.TrimString(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$") or str
end

local lastAutoAdvanceStage = nil
local lastAutoAdvanceCrystals = 0

-- Локальные ссылки на string функции для безопасности
local strmatch = string.match
local strtrim = string.trim or function(s) 
    if type(s) == "string" then
        return s:match("^%s*(.-)%s*$") 
    end
    return s or ""
end
local strlower = string.lower
local strupper = string.upper
local strfind = string.find
local strsub = string.sub
local strformat = string.format
local strsplit = string.split or function(delimiter, text)
    local result = {}
    for match in (text..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return unpack(result)
end

-- И обновите cleanName функцию:
local function cleanName(name)
    if not name then return "" end
    local cleaned = string.lower(name)
    cleaned = cleaned:gsub("%s+", " ")
    cleaned = ECT.TrimString(cleaned)
    return cleaned
end

local SHOW_RESET_TIMER_ALWAYS = true -- Флаг для постоянного показа таймера

-- Глобальная переменная для сохранения
ECT_SavedVars = ECT_SavedVars or {}

-- Убедимся, что все поля существуют
ECT_SavedVars.currentStage = ECT_SavedVars.currentStage or 1
ECT_SavedVars.crystalsSpent = ECT_SavedVars.crystalsSpent or 0
ECT_SavedVars.totalCrystalsEver = ECT_SavedVars.totalCrystalsEver or 0
ECT_SavedVars.crystalsCollected = ECT_SavedVars.crystalsCollected or 0

-- ИЗМЕНЕНО: Теперь отслеживаем статус выполнения задания
ECT_SavedVars.essenceQuestCompleted = ECT_SavedVars.essenceQuestCompleted or false
ECT_SavedVars.essenceQuestReadyNotified = ECT_SavedVars.essenceQuestReadyNotified or nil
ECT_SavedVars.essenceCurrent = ECT_SavedVars.essenceCurrent or 0
ECT_SavedVars.essenceRequired = ECT_SavedVars.essenceRequired or 3

-- ДОБАВЛЕНО: Для отслеживания времени сброса ежедневных заданий
ECT_SavedVars.questResetTime = ECT_SavedVars.questResetTime or nil
ECT_SavedVars.nextResetCheckTime = ECT_SavedVars.nextResetCheckTime or nil

-- ДОБАВЛЕНО: Для задания "Испытание Честью"
ECT_SavedVars.honorQuestCompleted = ECT_SavedVars.honorQuestCompleted or false
ECT_SavedVars.honorQuestReadyNotified = ECT_SavedVars.honorQuestReadyNotified or nil
ECT_SavedVars.honorCurrent = ECT_SavedVars.honorCurrent or 0
ECT_SavedVars.honorRequired = ECT_SavedVars.honorRequired or 500

ECT_SavedVars.minimapPos = ECT_SavedVars.minimapPos or {}
ECT_SavedVars.minimapPos.angle = ECT_SavedVars.minimapPos.angle or 0
ECT_SavedVars.minimapPos.radius = ECT_SavedVars.minimapPos.radius or 80

-- МИГРАЦИЯ СТАРЫХ ДАННЫХ (из версии с currentCategory)
if ECT_SavedVars.currentCategory and not ECT_SavedVars.currentStage then
    local categoryToStage = {
        [7] = 1,  -- 7+ Категория
        [6] = 2,  -- 6 Категория
        [5] = 5,  -- 5 Категория (после 6, 6+, 6++)
        [4] = 9,  -- 4 Категория
        [3] = 14, -- 3 Категория
        [2] = 20, -- 2 Категория
        [1] = 27, -- 1 Категория
    }
    local stage = categoryToStage[ECT_SavedVars.currentCategory] or 1
    ECT_SavedVars.currentStage = stage
    local spent = 0
    for i = 1, stage do
        spent = spent + (ECT.Config.STAGES[i].cost or 0)
    end
    ECT_SavedVars.crystalsSpent = spent
    print("|cFFFFD100[ECT] Миграция данных: категория " .. ECT_SavedVars.currentCategory .. " → этап " .. stage .. "|r")
end

-- Ссылка на глобальную таблицу (для удобства)
ECT.SavedVars = ECT_SavedVars

-- Функция для синхронизации локальной ссылки с глобальной таблицей
function ECT.SyncSavedVars()
    ECT.SavedVars = ECT_SavedVars
end

-- Переменные для задержки проверки заданий
local lastQuestCheckTime = 0
local QUEST_CHECK_DELAY = 1.0  -- 1 секунда задержки

-- Настройки этапов (43 этапа)
ECT.Config = {
    ITEM_ID = 280513,  -- Кристаллы Энергии
    ESSENCE_QUEST_ID = 39501,  -- ID задания "Испытание Отвагой"
    HONOR_QUEST_ID = 39500,    -- ID задания "Испытание Честью"
    HONOR_POINTS_REQUIRED = 500,  -- Необходимо 500 очков сражения
    WIN_POINTS = 200,  -- Очки за победу в PvP
    TOTAL_CRYSTALS_NEEDED = 30720,
    STAGES = { 
        { name = "7 Категория", cost = 16, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_7.blp" },
        { name = "7+ Категория", cost = 16, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_7.blp" },
        { name = "6 Категория", cost = 32, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_6.blp" },
        { name = "6+ Категория", cost = 32, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_6.blp" },
        { name = "6++ Категория", cost = 32, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_6.blp" },
        { name = "5 Категория", cost = 64, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_5.blp" },
        { name = "5+ Категория", cost = 64, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_5.blp" },
        { name = "5++ Категория", cost = 64, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_5.blp" },
        { name = "5+++ Категория", cost = 64, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_5.blp" },
        { name = "4 Категория", cost = 128, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_4.blp" },
        { name = "4+ Категория", cost = 128, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_4.blp" },
        { name = "4++ Категория", cost = 128, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_4.blp" },
        { name = "4+++ Категория", cost = 128, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_4.blp" },
        { name = "4++++ Категория", cost = 128, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_4.blp" },
        { name = "3 Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "3+ Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "3++ Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "3+++ Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "3++++ Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "3+++++ Категория", cost = 256, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_3.blp" },
        { name = "2 Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2+ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2++ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2+++ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2++++ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2+++++ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "2++++++ Категория", cost = 512, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_2.blp" },
        { name = "1 Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1+ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1+++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1++++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1+++++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1++++++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "1+++++++ Категория", cost = 1024, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ+", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ+++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ++++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ+++++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ++++++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
        { name = "ВНЕ КАТЕГОРИЙ+++++++", cost = 2048, icon = "Interface\\AddOns\\EnergyCrystalsTracker\\Icons\\custom_category_ooc_1.blp" },
    }
}

-- Определение этапов с боссами (вынесено в отдельную переменную для повторного использования)
ECT.BOSS_STAGES = {
    ["7+ Категория"] = true,      -- Босс для получения 6 категории
    ["6++ Категория"] = true,     -- Босс для получения 5 категории  
    ["5+++ Категория"] = true,    -- Босс для получения 4 категории
    ["4++++ Категория"] = true,   -- Босс для получения 3 категории
    ["3+++++ Категория"] = true,  -- Босс для получения 2 категории
    ["2++++++ Категория"] = true, -- Босс для получения 1 категории
    ["1+++++++ Категория"] = true, -- Босс для получения "ВНЕ КАТЕГОРИЙ"
}

-- Вспомогательная функция для проверки, является ли этап этапом с боссом
function ECT.IsBossStage(stageName)
    return ECT.BOSS_STAGES[stageName] or false
end

-- Функция для повторяющихся строк
function ECT.StringRep(char, count)
    local result = ""
    for i = 1, count do
        result = result .. char
    end
    return result
end

-- Функция для получения количества предметов в сумках
function ECT.GetItemCount(itemID)
    local total = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local id = GetContainerItemID(bag, slot)
            if id == itemID then
                local _, stackCount = GetContainerItemInfo(bag, slot)
                total = total + (stackCount or 1)
            end
        end
    end
    return total
end

function ECT.GetCrystalsCount()
    return ECT.GetItemCount(ECT.Config.ITEM_ID)
end

-- Исправленная функция для проверки активной ауры категории (по названию)
function ECT.CheckCurrentAura()
    -- Создаем улучшенную таблицу для поиска по названию
    local nameToStage = {
        -- 7 категории
        ["7 категория"] = 1,
        ["7-я категория"] = 1,
        ["7-я (+) категория"] = 2, -- 7+ Категория
        ["7+ категория"] = 2,
        
        -- 6 категории  
        ["6 категория"] = 3,      -- "6 Категория" (этап 3 в STAGES)
        ["6-я категория"] = 3,
        ["6-я (+) категория"] = 4, -- "6+ Категория" (этап 4)
        ["6+ категория"] = 4,
        ["6-я (++) категория"] = 5, -- "6++ Категория" (этап 5)
        ["6++ категория"] = 5,
        
        -- 5 категории
        ["5 категория"] = 6,      -- "5 Категория"
        ["5-я категория"] = 6,
        ["5-я (+) категория"] = 7, -- "5+ Категория"
        ["5+ категория"] = 7,
        ["5-я (++) категория"] = 8, -- "5++ Категория"
        ["5++ категория"] = 8,
        ["5-я (+++) категория"] = 9, -- "5+++ Категория"
        ["5+++ категория"] = 9,
        
        -- 4 категории
        ["4 категория"] = 10,     -- "4 Категория"
        ["4-я категория"] = 10,
        ["4-я (+) категория"] = 11, -- "4+ Категория"
        ["4+ категория"] = 11,
        ["4-я (++) категория"] = 12, -- "4++ Категория"
        ["4++ категория"] = 12,
        ["4-я (+++) категория"] = 13, -- "4+++ Категория"
        ["4+++ категория"] = 13,
        ["4-я (++++) категория"] = 14, -- "4++++ Категория"
        ["4++++ категория"] = 14,
        
        -- 3 категории
        ["3 категория"] = 15,     -- "3 Категория"
        ["3-я категория"] = 15,
        ["3-я (+) категория"] = 16, -- "3+ Категория"
        ["3+ категория"] = 16,
        ["3-я (++) категория"] = 17, -- "3++ Категория"
        ["3++ категория"] = 17,
        ["3-я (+++) категория"] = 18, -- "3+++ Категория"
        ["3+++ категория"] = 18,
        ["3-я (++++) категория"] = 19, -- "3++++ Категория"
        ["3++++ категория"] = 19,
        ["3-я (+++++) категория"] = 20, -- "3+++++ Категория"
        ["3+++++ категория"] = 20,
        
        -- 2 категории
        ["2 категория"] = 21,     -- "2 Категория"
        ["2-я категория"] = 21,
        ["2-я (+) категория"] = 22, -- "2+ Категория"
        ["2+ категория"] = 22,
        ["2-я (++) категория"] = 23, -- "2++ Категория"
        ["2++ категория"] = 23,
        ["2-я (+++) категория"] = 24, -- "2+++ Категория"
        ["2+++ категория"] = 24,
        ["2-я (++++) категория"] = 25, -- "2++++ Категория"
        ["2++++ категория"] = 25,
        ["2-я (+++++) категория"] = 26, -- "2+++++ Категория"
        ["2+++++ категория"] = 26,
        ["2-я (++++++) категория"] = 27, -- "2++++++ Категория"
        ["2++++++ категория"] = 27,
        
        -- 1 категории
        ["1 категория"] = 28,     -- "1 Категория"
        ["1-я категория"] = 28,
        ["1-я (+) категория"] = 29, -- "1+ Категория"
        ["1+ категория"] = 29,
        ["1-я (++) категория"] = 30, -- "1++ Категория"
        ["1++ категория"] = 30,
        ["1-я (+++) категория"] = 31, -- "1+++ Категория"
        ["1+++ категория"] = 31,
        ["1-я (++++) категория"] = 32, -- "1++++ Категория"
        ["1++++ категория"] = 32,
        ["1-я (+++++) категория"] = 33, -- "1+++++ Категория"
        ["1+++++ категория"] = 33,
        ["1-я (++++++) категория"] = 34, -- "1++++++ Категория"
        ["1++++++ категория"] = 34,
        ["1-я (+++++++) категория"] = 35, -- "1+++++++ Категория"
        ["1+++++++ категория"] = 35,
        
        -- ВНЕ КАТЕГОРИЙ
        ["вне категорий"] = 36,    -- "ВНЕ КАТЕГОРИЙ"
        ["вне категорий+"] = 37,   -- "ВНЕ КАТЕГОРИЙ+"
        ["вне категорий++"] = 38,  -- "ВНЕ КАТЕГОРИЙ++"
        ["вне категорий+++"] = 39, -- "ВНЕ КАТЕГОРИЙ+++"
        ["вне категорий++++"] = 40, -- "ВНЕ КАТЕГОРИЙ++++"
        ["вне категорий+++++"] = 41, -- "ВНЕ КАТЕГОРИЙ+++++"
        ["вне категорий++++++"] = 42, -- "ВНЕ КАТЕГОРИЙ++++++"
        ["вне категорий+++++++"] = 43, -- "ВНЕ КАТЕГОРИЙ+++++++"
    }

    -- Вспомогательная функция для очистки названия
    local function cleanName(name)
        if not name then return "" end
        local cleaned = string.lower(name)
        cleaned = cleaned:gsub("%s+", " ")
        cleaned = cleaned:trim()
        return cleaned
    end
    
    -- Вспомогательная функция для подсчета плюсов
    local function countPluses(str)
        if not str then return 0 end
        local onlyPluses = str:gsub("[^%+]", "")
        return #onlyPluses
    end
    
    -- Вспомогательная функция для извлечения номера категории
    local function extractCategoryNumber(str)
        if not str then return nil end
        local numbers = {}
        for num in str:gmatch("%d+") do
            table.insert(numbers, tonumber(num))
        end
        return numbers[1]
    end
    
    -- Сначала проверяем дебаффы (категории обычно здесь)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", i)
        if name then
            local cleanedName = cleanName(name)
            
            -- Проверяем, содержит ли название "категория"
            if string.find(cleanedName, "категория") then
                local categoryNum = extractCategoryNumber(cleanedName)
                if categoryNum then
                    local plusCount = countPluses(cleanedName)
                    
                    -- Ищем соответствующий этап в STAGES
                    for stageIdx, stage in ipairs(ECT.Config.STAGES) do
                        local stageNameLower = cleanName(stage.name)
                        local stageCategoryNum = extractCategoryNumber(stageNameLower)
                        
                        if stageCategoryNum and stageCategoryNum == categoryNum then
                            local stagePlusCount = countPluses(stageNameLower)
                            
                            if stagePlusCount == plusCount then
                                return stageIdx, 0, name
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Затем проверяем баффы
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name then
            local cleanedName = cleanName(name)
            
            if string.find(cleanedName, "категория") then
                local categoryNum = extractCategoryNumber(cleanedName)
                if categoryNum then
                    local plusCount = countPluses(cleanedName)
                    
                    for stageIdx, stage in ipairs(ECT.Config.STAGES) do
                        local stageNameLower = cleanName(stage.name)
                        local stageCategoryNum = extractCategoryNumber(stageNameLower)
                        
                        if stageCategoryNum and stageCategoryNum == categoryNum then
                            local stagePlusCount = countPluses(stageNameLower)
                            
                            if stagePlusCount == plusCount then
                                return stageIdx, 0, name
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Сообщение об ошибке выводим только при первой проверке или через большие интервалы
    return nil, nil, nil
end

function ECT.DebugAuras()
    print("|cFFFF0000=== ОТЛАДКА ВСЕХ АУР НА ИГРОКЕ ===|r")
    
    -- Проверяем все баффы с категориями
    print("|cFF00FF00БАФФЫ с 'категория':|r")
    local buffCount = 0
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name and string.find(string.lower(name), "категория") then
            buffCount = buffCount + 1
            print(string.format("  Слот %d: %s (ID: %d)", i, name, spellId or 0))
        end
    end
    if buffCount == 0 then
        print("  Не найдено")
    end
    
    -- Проверяем все дебаффы с категориями
    print("|cFF00FF00ДЕБАФФЫ с 'категория':|r")
    local debuffCount = 0
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", i)
        if name and string.find(string.lower(name), "категория") then
            debuffCount = debuffCount + 1
            print(string.format("  Слот %d: %s (ID: %d)", i, name, spellId or 0))
        end
    end
    if debuffCount == 0 then
        print("  Не найдено")
    end
    
    -- Тестируем нашу функцию проверки
    print("|cFFFF0000=== РЕЗУЛЬТАТ CheckCurrentAura ===|r")
    local stageIndex, auraId, auraName = ECT.CheckCurrentAura()
    if stageIndex then
        local stageName = ECT.Config.STAGES[stageIndex].name
        print(string.format("|cFF00FF00Найдена категория: %s|r", stageName))
        print(string.format("|cFFFFD100Название ауры: %s|r", auraName))
    else
        print("|cFFFF0000Функция не нашла ауру категории|r")
    end
end

-- Упрощенная функция для поиска категории по названию
function ECT.FindCategoryByName()
    -- Сначала проверяем дебаффы (в вашем случае категория была в дебаффах)
    for i = 1, 40 do
        local name = UnitDebuff("player", i)
        if name then
            local nameLower = string.lower(name)
            if string.find(nameLower, "категория") then
                print(string.format("|cFF00FF00[ECT] Найдена аура категории в дебаффах: %s|r", name))
                
                -- Пробуем определить этап
                for stageIdx, stage in ipairs(ECT.Config.STAGES) do
                    local stageNameLower = string.lower(stage.name)
                    -- Упрощенное сравнение
                    if string.find(nameLower, "6") and string.find(nameLower, "%+") then
                        -- Это может быть 6+ категория
                        if stage.name == "6+ Категория" then
                            return stageIdx, 0, name
                        end
                    end
                end
            end
        end
    end
    
    -- Затем проверяем баффы
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name then
            local nameLower = string.lower(name)
            if string.find(nameLower, "категория") then
                print(string.format("|cFF00FF00[ECT] Найдена аура категории в баффах: %s|r", name))
                -- Аналогичная логика обработки...
            end
        end
    end
    
    return nil, nil, nil
end

function ECT.UpdateStageFromAura()
    local stageIndex, auraId, auraName = ECT.CheckCurrentAura()
    
    if stageIndex then
        -- Проверяем, изменилась ли категория
        local oldStageIndex = ECT_SavedVars.currentStage or 1
        local oldStageName = ECT.Config.STAGES[oldStageIndex] and ECT.Config.STAGES[oldStageIndex].name or "Неизвестно"
        
        if stageIndex ~= oldStageIndex then
            -- Категория изменилась
            ECT_SavedVars.currentStage = stageIndex
            
            -- Пересчитываем потраченные кристаллы
            local spent = 0
            for i = 1, stageIndex do
                spent = spent + (ECT.Config.STAGES[i].cost or 0)
            end
            ECT_SavedVars.crystalsSpent = spent
            
            -- Обновляем максимальное количество кристаллов
            local currentCrystals = ECT.GetCrystalsCount()
            local totalNow = spent + currentCrystals
            if (ECT_SavedVars.totalCrystalsEver or 0) < totalNow then
                ECT_SavedVars.totalCrystalsEver = totalNow
            end
            
            -- Синхронизируем
            ECT.SyncSavedVars()
            
            -- Показываем сообщение только если действительно изменилась категория
            local newStageName = ECT.Config.STAGES[stageIndex].name
            print(string.format("|cFF00FF00[ECT] Категория обновлена: %s -> %s|r", oldStageName, newStageName))
            
            -- Если окно открыто, обновляем отображение
            if ECT.MainFrame and ECT.MainFrame:IsVisible() then
                ECT.UpdateDisplay()
            end
            
            return true
        end
        -- Если категория не изменилась, не выводим сообщение
        return false
    else
        -- Не найдена аура категории, выводим сообщение только изредка
        local currentTime = GetTime()
        if not ECT_SavedVars.lastAuraCheckMessage or 
           (currentTime - ECT_SavedVars.lastAuraCheckMessage) > 300 then -- Раз в 5 минут
            
            local currentStage = ECT_SavedVars.currentStage or 1
            local stageName = ECT.Config.STAGES[currentStage].name
            
            print("|cFFFF0000[ECT] Не найдена аура категории на игроке|r")
            print(string.format("|cFFFFD100[ECT] Текущая категория: %s|r", stageName))
            
            ECT_SavedVars.lastAuraCheckMessage = currentTime
        end
    end
    
    return false
end

-- Функция для периодической проверки ауры
local lastAuraCheckTime = 0
local AURA_CHECK_INTERVAL = 300.0 -- Проверяем каждые 10 секунд

function ECT.CheckAuraPeriodically()
    local currentTime = GetTime()
    if currentTime - lastAuraCheckTime > AURA_CHECK_INTERVAL then
        lastAuraCheckTime = currentTime
        ECT.UpdateStageFromAura()
    end
end

-- УНИВЕРСАЛЬНАЯ функция для проверки прогресса любого задания по его ID
function ECT.CheckQuestProgress(questID, defaultRequired)
    if not questID then
        return false, "no_quest_id", 0, defaultRequired or 0
    end
    
    -- Проверяем, есть ли задание в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and questId and questId == questID then
            local currentCount, requiredCount = 0, defaultRequired or 0
            
            -- Получаем информацию о прогрессе задания
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, type, finished = GetQuestLogLeaderBoard(j, i)
                if text then
                    -- ФОРМАТ SIRUS.SU: текст вида "Получить эссенции отваги (1/3)"
                    -- Ищем любой текст с числами в формате (число/число)
                    local current, required = strmatch(text, "%((%d+)/(%d+)%)")
                    if current and required then
                        currentCount = tonumber(current)
                        requiredCount = tonumber(required)
                        break
                    end
                    
                    -- Формат 1: "0/3"
                    current, required = strmatch(text, "(%d+)/(%d+)")
                    if current and required then
                        currentCount = tonumber(current)
                        requiredCount = tonumber(required)
                        break
                    end
                    
                    -- Формат 2: "0 из 3"
                    current, required = strmatch(text, "(%d+) из (%d+)")
                    if current and required then
                        currentCount = tonumber(current)
                        requiredCount = tonumber(required)
                        break
                    end
                    
                    -- Формат 3: любой текст с числами
                    current, required = strmatch(text, "(%d+).-(%d+)")
                    if current and required then
                        currentCount = tonumber(current)
                        requiredCount = tonumber(required)
                        break
                    end
                end
            end
            
            -- Определяем статус задания
            if isComplete == 1 then
                return true, "ready", currentCount, requiredCount
            elseif currentCount >= 0 then
				-- квест ВЗЯТ, даже если 0/3
				return false, "in_progress", currentCount, requiredCount
			end
        end
    end
    
    -- Задание не найдено в журнале
    return false, "not_found", 0, defaultRequired or 0
end

-- Функция для поиска задания по названию в журнале
function ECT.FindQuestByName(questName)
    local questNameLower = string.lower(questName)
    
    print("|cFFFF0000Поиск задания по названию: '" .. questName .. "'|r")
    
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and title and questId then
            local titleLower = string.lower(title)
            if string.find(titleLower, questNameLower) then
                print("Найдено задание: |cFF00FF00" .. title .. "|r (ID: " .. questId .. ")")
                print("Статус: " .. (isComplete == 1 and "|cFF00FF00Готово|r" or "|cFFFF0000В процессе|r"))
                
                -- Покажем прогресс
                local numObjectives = GetNumQuestLeaderBoards(i)
                for j = 1, numObjectives do
                    local text, type, finished = GetQuestLogLeaderBoard(j, i)
                    print("Прогресс: |cFFFFA500" .. (text or "нет") .. "|r")
                end
                
                return questId
            end
        end
    end
    
    print("|cFFFF0000Задание не найдено по названию|r")
    return nil
end

-- Функция для отображения ВСЕХ заданий в журнале
function ECT.ShowAllQuests()
    print("|cFFFF0000=== ВСЕ задания в журнале ===|r")
    
    local totalQuests = GetNumQuestLogEntries()
    print("Всего записей в журнале: " .. totalQuests)
    
    local questCount = 0
    for i = 1, totalQuests do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if isHeader then
            print("|cFF00AAFF[РАЗДЕЛ]: " .. title .. "|r")
        else
            if title and questId then
                questCount = questCount + 1
                local statusText
                if isComplete == 1 then
                    statusText = "|cFF00FF00Готово к сдаче|r"
                elseif isComplete == -1 then
                    statusText = "|cFFFF0000Провалено|r"
                else
                    statusText = "|cFFFFFF00В процессе|r"
                end
                
                print(string.format("  #%d: |cFFFFA500%s|r (ID: %d) - %s", 
                    questCount, title, questId, statusText))
                
                -- Покажем прогресс для активных заданий
                if isComplete == 0 then
                    local numObjectives = GetNumQuestLeaderBoards(i)
                    for j = 1, numObjectives do
                        local text, type, finished = GetQuestLogLeaderBoard(j, i)
                        if text then
                            print("     Прогресс: |cFFAAAAAA" .. text .. "|r")
                        end
                    end
                end
            end
        end
    end
    
    print("|cFF00FF00Всего обычных заданий: " .. questCount .. "|r")
end

-- Универсальная функция для проверки прогресса специального задания
function ECT.CheckSpecialQuestProgress(questSectionName, progressKeywords)
    local currentCount, requiredCount = 0, 3
    local isComplete = 0
    local questIndex = nil
    
    -- Ищем раздел задания
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, complete, _, questId = GetQuestLogTitle(i)
        
        if isHeader and title and string.lower(title):find(string.lower(questSectionName)) then
            questIndex = i
            isComplete = complete or 0
            
            -- Сохраняем ID для будущего использования
            if questId and questId ~= 1 then  -- ID=1 это дефолтный ID для заголовков
                return questId, isComplete, questIndex
            end
            break
        end
    end
    
    if not questIndex then
        -- Раздел не найден
        return nil, 0, nil
    end
    
    return nil, isComplete, questIndex
end

-- Функция для проверки задания "Испытание Отвагой" (специальная для Sirus.su)
function ECT.CheckEssenceQuestProgress()
    local currentCount, requiredCount = 0, 3
    
    local questId, isComplete, questIndex = ECT.CheckSpecialQuestProgress("испытание отвагой", {"героическое", "подземелье"})
    
    if not questIndex then
        -- Раздел не найден
        return false, "not_found", 0, 3
    end
    
    -- Проверяем статус задания через GetQuestLogTitle
    if isComplete == 1 then
        -- Задание готово к сдаче
        return true, "ready", 3, 3
    end
    
    -- Парсим прогресс из целей задания
    local numObjectives = GetNumQuestLeaderBoards(questIndex)
    
    if numObjectives > 0 then
        for j = 1, numObjectives do
            local text, type, finished = GetQuestLogLeaderBoard(j, questIndex)
            if text then
                -- Пробуем разные форматы для парсинга
                local patterns = {
                    "(%d+)/(%d+)",                    -- 1/3
                    "%d+%s*/%s*(%d+)/(%d+)",          -- пройдено: 1/3
                    "героическое.*(%d+).-(%d+)",      -- героическое подземелье пройдено: 1/3
                    "подземелье.*(%d+).-(%d+)",       -- подземелье пройдено: 1/3
                    "пройдено.*(%d+).-(%d+)",         -- пройдено: 1/3
                }
                
                for _, pattern in ipairs(patterns) do
                    local current, required = strmatch(text, pattern)
                    if current and required then
                        currentCount = tonumber(current)
                        requiredCount = tonumber(required)
                        
                        -- Если текст содержит "Героическое подземелье пройдено", это наш прогресс
                        if string.find(string.lower(text), "героическое") or 
                           string.find(string.lower(text), "подземелье") then
                            -- Нашли правильный прогресс
                            local status = (currentCount >= requiredCount) and "ready" or "in_progress"
                            local completed = (currentCount >= requiredCount)
                            
                            -- Обновляем сохраненные переменные
                            ECT_SavedVars.essenceCurrent = currentCount
                            ECT_SavedVars.essenceRequired = requiredCount
                            ECT_SavedVars.essenceQuestCompleted = completed
                            
                            return completed, status, currentCount, requiredCount
                        end
                    end
                end
            end
        end
    end
    
    -- Если не нашли прогресс в целях, возвращаем дефолтные значения
    return false, "in_progress", currentCount, requiredCount
end

-- Функция для проверки задания "Испытание Честью" с новыми критериями
function ECT.CheckHonorQuestProgress()
    local currentPoints, requiredPoints = 0, ECT.Config.HONOR_POINTS_REQUIRED
    
    local questId, isComplete, questIndex = ECT.CheckSpecialQuestProgress("испытание честью", {"очков", "сражения", "честью"})
    
    if not questIndex then
        -- Раздел не найден
        return false, "not_found", 0, requiredPoints
    end
    
    -- Проверяем статус задания через GetQuestLogTitle
    if isComplete == 1 then
        -- Задание готово к сдаче
        ECT_SavedVars.honorCurrent = requiredPoints
        ECT_SavedVars.honorRequired = requiredPoints
        ECT_SavedVars.honorQuestCompleted = true
        return true, "ready", requiredPoints, requiredPoints
    end
    
    -- Парсим прогресс из целей задания
    local numObjectives = GetNumQuestLeaderBoards(questIndex)
    
    if numObjectives > 0 then
        for j = 1, numObjectives do
            local text, type, finished = GetQuestLogLeaderBoard(j, questIndex)
            if text then
                -- print("|cFFFFA500[ECT Debug] Проверяем текст цели: " .. text .. "|r")
                
                -- Пробуем разные форматы для парсинга очков сражения
                local patterns = {
                    "(%d+)/(%d+)%s*очков сражения",  -- 150/500 очков сражения
                    "(%d+).-(%d+)%s*очков сражения", -- 150 из 500 очков сражения
                    "очков.*(%d+).-(%d+)",           -- очков сражения: 150/500
                    "сражения.*(%d+).-(%d+)",        -- сражения: 150/500
                    "честью.*(%d+).-(%d+)",          -- честью: 150/500
                    "pvp.*(%d+).-(%d+)",             -- PvP: 150/500
                    "(%d+).-(%d+)%s*очков",          -- 150/500 очков
                    "(%d+).-(%d+)%s*сражения",       -- 150/500 сражения
                    "(%d+).-(%d+)%s*побед",          -- 1/3 побед (старый формат)
                }
                
                -- Сначала попробуем простой поиск чисел в формате X/Y
                local simpleCurrent, simpleRequired = strmatch(text, "(%d+)/(%d+)")
                if simpleCurrent and simpleRequired then
                    currentPoints = tonumber(simpleCurrent)
                    requiredPoints = tonumber(simpleRequired)
                    
                    -- print(string.format("|cFF00FF00[ECT Debug] Нашли простые числа: %d/%d|r", currentPoints, requiredPoints))
                    
                    -- Если это старый формат с малыми числами (победы)
                    if requiredPoints <= 10 then
                        -- Конвертируем старый формат в новый
                        currentPoints = currentPoints * ECT.Config.WIN_POINTS
                        requiredPoints = ECT.Config.HONOR_POINTS_REQUIRED
                        -- print("|cFFFFA500[ECT Debug] Конвертировано из старого формата|r")
                    end
                    
                    -- Проверяем, содержит ли текст информацию об очках сражения
                    local lowerText = string.lower(text)
                    if string.find(lowerText, "очков") or 
                       string.find(lowerText, "сражения") or
                       string.find(lowerText, "pvp") or
                       string.find(lowerText, "честью") then
                        
                        -- Задание выполнено только когда currentPoints >= requiredPoints
                        local completed = (currentPoints >= requiredPoints)
                        local status = completed and "ready" or "in_progress"
                        
                        -- Обновляем сохраненные переменные
                        ECT_SavedVars.honorCurrent = currentPoints
                        ECT_SavedVars.honorRequired = requiredPoints
                        ECT_SavedVars.honorQuestCompleted = completed
                        
                        -- print(string.format("|cFF00FF00[ECT Debug] Возвращаем: %s, %d/%d|r", 
                        --   status, currentPoints, requiredPoints))
                        
                        return completed, status, currentPoints, requiredPoints
                    end
                end
                
                -- Если простой поиск не сработал, попробуем паттерны
                for _, pattern in ipairs(patterns) do
                    local current, required = strmatch(text, pattern)
                    if current and required then
                        currentPoints = tonumber(current)
                        requiredPoints = tonumber(required)
                        
                        print(string.format("|cFF00FF00[ECT Debug] Нашли по паттерну '%s': %d/%d|r", 
                            pattern, currentPoints, requiredPoints))
                        
                        -- Если это старый формат с малыми числами (победы)
                        if requiredPoints <= 10 then
                            -- Конвертируем старый формат в новый
                            currentPoints = currentPoints * ECT.Config.WIN_POINTS
                            requiredPoints = ECT.Config.HONOR_POINTS_REQUIRED
                            -- print("|cFFFFA500[ECT Debug] Конвертировано из старого формата|r")
                        end
                        
                        -- Проверяем, содержит ли текст информацию об очках сражения
                        local lowerText = string.lower(text)
                        if string.find(lowerText, "очков") or 
                           string.find(lowerText, "сражения") or
                           string.find(lowerText, "pvp") or
                           string.find(lowerText, "честью") then
                            
                            -- Задание выполнено только когда currentPoints >= requiredPoints
                            local completed = (currentPoints >= requiredPoints)
                            local status = completed and "ready" or "in_progress"
                            
                            -- Обновляем сохраненные переменные
                            ECT_SavedVars.honorCurrent = currentPoints
                            ECT_SavedVars.honorRequired = requiredPoints
                            ECT_SavedVars.honorQuestCompleted = completed
                            
                            -- print(string.format("|cFF00FF00[ECT Debug] Возвращаем: %s, %d/%d|r", 
                            --    status, currentPoints, requiredPoints))
                            
                            return completed, status, currentPoints, requiredPoints
                        end
                    end
                end
                
                -- Если ничего не нашли, попробуем найти любые числа в тексте
                local allNumbers = {}
                for number in string.gmatch(text, "%d+") do
                    table.insert(allNumbers, tonumber(number))
                end
                
                if #allNumbers >= 2 then
                    currentPoints = allNumbers[1]
                    requiredPoints = allNumbers[2]
                    
                    -- print(string.format("|cFF00FF00[ECT Debug] Нашли числа в тексте: %d и %d|r", 
                    --   currentPoints, requiredPoints))
                    
                    -- Если это старый формат с малыми числами (победы)
                    if requiredPoints <= 10 then
                        -- Конвертируем старый формат в новый
                        currentPoints = currentPoints * ECT.Config.WIN_POINTS
                        requiredPoints = ECT.Config.HONOR_POINTS_REQUIRED
                        -- print("|cFFFFA500[ECT Debug] Конвертировано из старого формата|r")
                    end
                    
                    -- Задание выполнено только когда currentPoints >= requiredPoints
                    local completed = (currentPoints >= requiredPoints)
                    local status = completed and "ready" or "in_progress"
                    
                    -- Обновляем сохраненные переменные
                    ECT_SavedVars.honorCurrent = currentPoints
                    ECT_SavedVars.honorRequired = requiredPoints
                    ECT_SavedVars.honorQuestCompleted = completed
                    
                    -- print(string.format("|cFF00FF00[ECT Debug] Возвращаем: %s, %d/%d|r", 
                    --   status, currentPoints, requiredPoints))
                    
                    return completed, status, currentPoints, requiredPoints
                end
            end
        end
    end
	
	-- ПРИНУДИТЕЛЬНАЯ МИГРАЦИЯ если требуется
    if requiredPoints <= 10 then
        -- Это старый формат - конвертируем на лету
        currentPoints = currentPoints * ECT.Config.WIN_POINTS
        requiredPoints = 500
        
        -- И сохраняем в настройках
        ECT_SavedVars.honorCurrent = currentPoints
        ECT_SavedVars.honorRequired = requiredPoints
        
        print("|cFFFFFF00[ECT] Автоматическая миграция формата чести|r")
    end
    
    -- Если не нашли прогресс в целях, возвращаем дефолтные значения
    -- НО проверим, не выполнилось ли задание каким-то другим способом
    ---if ECT_SavedVars.honorQuestCompleted then
        -- print("|cFFFFA500[ECT Debug] Использую сохраненные значения|r")
    --    return true, "ready", ECT_SavedVars.honorCurrent or requiredPoints, requiredPoints
    -- end
    
    -- print("|cFFFFA500[ECT Debug] Не нашли прогресс, возвращаем 0/500|r")
    -- return false, "in_progress", currentPoints, requiredPoints
end

-- Функция для принудительной проверки задания "Испытание Честью" из журнала
function ECT.ForceCheckHonorQuest()
    print("|cFFFFD100[ECT] Принудительная проверка задания 'Испытание Честью'...|r")
    
    local currentPoints, requiredPoints = 0, 500
    local completed = false
    local questFound = false
    
    -- Проверяем все задания в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and title then
            local titleLower = string.lower(title)
            
            -- Разные варианты названия задания
            local isHonorQuest = string.find(titleLower, "испытание") and 
                                (string.find(titleLower, "честью") or 
                                 string.find(titleLower, "честь") or
                                 string.find(titleLower, "pvp"))
            
            -- Также проверяем текст цели
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, type, finished = GetQuestLogLeaderBoard(j, i)
                if text then
                    local textLower = string.lower(text)
                    if string.find(textLower, "очков сражения") or 
                       string.find(textLower, "очки сражения") or
                       string.find(textLower, "сражения") or
                       string.find(textLower, "pvp") then
                        isHonorQuest = true
                    end
                end
            end
            
            if isHonorQuest then
                questFound = true
                print(string.format("|cFF00FF00[ECT] Найдено задание: %s (ID: %d)|r", title, questId or 0))
                print(string.format("|cFFFFA500[ECT] Статус в журнале: %s|r", isComplete == 1 and "Готово к сдаче" or "В процессе"))
                
                -- Если задание готово к сдаче
                if isComplete == 1 then
                    print("|cFF00FF00[ECT] Задание готово к сдаче!|r")
                    currentPoints = requiredPoints
                    completed = true
                else
                    -- Парсим прогресс из целей
                    for j = 1, numObjectives do
                        local text, type, finished = GetQuestLogLeaderBoard(j, i)
                        if text then
                            print(string.format("|cFFFFA500[ECT] Текст цели: %s|r", text))
                            
                            -- Простой поиск чисел в формате X/Y
                            local current, required = strmatch(text, "(%d+)/(%d+)")
                            if current and required then
                                currentPoints = tonumber(current)
                                requiredPoints = tonumber(required)
                                
                                print(string.format("|cFF00FF00[ECT] Парсинг: %d/%d|r", currentPoints, requiredPoints))
                                
                                -- Если это старый формат с малыми числами
                                if requiredPoints <= 10 then
                                    currentPoints = currentPoints * ECT.Config.WIN_POINTS
                                    requiredPoints = ECT.Config.HONOR_POINTS_REQUIRED
                                    print(string.format("|cFF00FF00[ECT] Конвертировано в: %d/%d очков сражения|r", 
                                        currentPoints, requiredPoints))
                                end
                                
                                completed = (currentPoints >= requiredPoints)
                                break
                            end
                        end
                    end
                end
                
                -- Обновляем сохраненные данные
                ECT_SavedVars.honorCurrent = currentPoints
                ECT_SavedVars.honorRequired = requiredPoints
                ECT_SavedVars.honorQuestCompleted = completed
                
                -- Синхронизируем
                ECT.SyncSavedVars()
                
                print(string.format("|cFF00FF00[ECT] Статус обновлен: %d/%d (%s)|r", 
                    currentPoints, requiredPoints, completed and "Выполнено" or "В процессе"))
                
                if ECT.MainFrame and ECT.MainFrame:IsVisible() then
                    ECT.UpdateDisplay()
                end
                
                return currentPoints, requiredPoints, completed
            end
        end
    end
    
    if not questFound then
        print("|cFFFF0000[ECT] Задание 'Испытание Честью' не найдено в журнале|r")
        print("|cFFFFA500[ECT] Возможные причины:|r")
        print("|cFFFFA5001. Задание еще не взято|r")
        print("|cFFFFA5002. Задание уже сдано|r")
        print("|cFFFFA5003. Название задания отличается|r")
        
        -- Сбрасываем статус, если задание не найдено
        if ECT_SavedVars.honorQuestCompleted then
            print("|cFFFF0000[ECT] Сбрасываю некорректный статус 'Выполнено'|r")
            ECT_SavedVars.honorQuestCompleted = false
            ECT_SavedVars.honorCurrent = 0
            ECT_SavedVars.honorRequired = 500
            ECT.SyncSavedVars()
        end
    end
    
    return currentPoints, requiredPoints, completed
end

-- Функция для поиска задания "Испытание Честью" в журнале с диагностикой
function ECT.DebugFindHonorQuest()
    print("|cFFFF0000=== Диагностика поиска задания 'Испытание Честью' ===|r")
    
    local foundAny = false
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and title then
            local titleLower = string.lower(title)
            
            -- Проверяем различные варианты названия
            if string.find(titleLower, "честью") or 
               string.find(titleLower, "честь") or
               string.find(titleLower, "pvp") or
               string.find(titleLower, "пвп") or
               string.find(titleLower, "сражен") or
               string.find(titleLower, "битв") then
                
                foundAny = true
                print(string.format("|cFF00FF00[ECT] Возможное задание: %s (ID: %d)|r", title, questId or 0))
                print(string.format("|cFFFFA500[ECT] Статус: %s|r", isComplete == 1 and "Готово к сдаче" or "В процессе"))
                
                -- Показываем прогресс
                local numObjectives = GetNumQuestLeaderBoards(i)
                for j = 1, numObjectives do
                    local text, type, finished = GetQuestLogLeaderBoard(j, i)
                    if text then
                        print(string.format("|cFFFFFF00[ECT] Цель %d: %s|r", j, text))
                    end
                end
            end
        end
    end
    
    if not foundAny then
        print("|cFFFF0000[ECT] Не найдено ни одного задания с тематикой чести/PvP|r")
        print("|cFFFFA500[ECT] Показываю ВСЕ задания в журнале:|r")
        
        for i = 1, GetNumQuestLogEntries() do
            local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
            
            if not isHeader and title then
                print(string.format("  |cFFFFFF00%d. %s (ID: %d)|r", i, title, questId or 0))
            end
        end
    end
end

-- Функция для поиска задания по содержанию текста целей
function ECT.FindQuestByObjectiveText(textPattern)
    print(string.format("|cFFFFD100[ECT] Поиск задания по тексту цели: '%s'|r", textPattern))
    
    local patternLower = string.lower(textPattern)
    
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and title then
            local numObjectives = GetNumQuestLeaderBoards(i)
            for j = 1, numObjectives do
                local text, type, finished = GetQuestLogLeaderBoard(j, i)
                if text and string.find(string.lower(text), patternLower) then
                    print(string.format("|cFF00FF00[ECT] Найдено задание: %s (ID: %d)|r", title, questId or 0))
                    print(string.format("|cFFFFA500[ECT] Цель: %s|r", text))
                    return i, questId, title, text
                end
            end
        end
    end
    
    print("|cFFFF0000[ECT] Задание не найдено|r")
    return nil, nil, nil, nil
end

-- Функция для обновления статуса задания при событиях
function ECT.UpdateQuestStatus()
    -- Принудительно сбрасываем статус, если задание не найдено
    local questFound = false
    
    -- Проверяем, есть ли задание в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title = GetQuestLogTitle(i)
        if title and string.find(string.lower(title), "честью") then
            questFound = true
            break
        end
    end
    
    -- Если задание не найдено, но статус "Выполнено" - сбрасываем
    if not questFound and ECT_SavedVars.honorQuestCompleted then
        print("|cFFFF0000[ECT] Внимание: задание 'Испытание Честью' не найдено, но статус 'Выполнено'|r")
        print("|cFFFFA500[ECT] Сбрасываю статус...|r")
        ECT_SavedVars.honorQuestCompleted = false
        ECT_SavedVars.honorQuestReadyNotified = nil
    end
    -- Сначала проверяем, не нужно ли сбросить задания
    ECT.CheckQuestReset()
    
    -- Проверяем текущую ауру
    ECT.UpdateStageFromAura()
    
    -- ДЛЯ SIRUS.SU: Используем специальные функции для проверки
    -- Они ищут задания по названию раздела, а не по ID
    local essenceCompleted, essenceStatus, essenceCurrent, essenceRequired = ECT.CheckEssenceQuestProgress()
    local honorCompleted, honorStatus, honorCurrent, honorRequired = ECT.CheckHonorQuestProgress()
    
    -- Если специальные функции не нашли задание, пробуем по ID (для совместимости)
    if essenceStatus == "not_found" then
        essenceCompleted, essenceStatus, essenceCurrent, essenceRequired = ECT.CheckQuestProgress(ECT.Config.ESSENCE_QUEST_ID, 3)
    end
    
    if honorStatus == "not_found" then
        honorCompleted, honorStatus, honorCurrent, honorRequired = ECT.CheckQuestProgress(ECT.Config.HONOR_QUEST_ID, 3)
    end
    
    -- Сохраняем старые значения для сравнения
    local oldEssenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
    local oldEssenceCurrent = ECT_SavedVars.essenceCurrent or 0
    local oldHonorCompleted = ECT_SavedVars.honorQuestCompleted or false
    local oldHonorCurrent = ECT_SavedVars.honorCurrent or 0
    
    -- Сохраняем новые значения
    ECT_SavedVars.essenceQuestCompleted = essenceCompleted
    ECT_SavedVars.essenceCurrent = essenceCurrent or 0
    ECT_SavedVars.essenceRequired = essenceRequired or 3
    ECT_SavedVars.honorQuestCompleted = honorCompleted
    ECT_SavedVars.honorCurrent = honorCurrent or 0
    ECT_SavedVars.honorRequired = honorRequired or 3
    
    -- Проверяем изменение статуса
    local essenceChanged = (oldEssenceCompleted ~= essenceCompleted) or (oldEssenceCurrent ~= essenceCurrent)
    local honorChanged = (oldHonorCompleted ~= honorCompleted) or (oldHonorCurrent ~= honorCurrent)
    
    -- Уведомления при изменении статуса
	if honorChanged then
		if honorCompleted then
			if not ECT_SavedVars.honorQuestReadyNotified then
				-- Воспроизведение звука для "Испытание Честью"
				local current = honorCurrent or 0
				local required = honorRequired or 500
				
				-- Определяем, старый или новый формат задания
				local effectiveRequired = (required <= 10) and required or 500
				local effectiveCurrent
				if required <= 10 then
					effectiveCurrent = current * 200
				else
					effectiveCurrent = current
				end
				
				PlayQuestSound("honor.mp3", "Испытание честью", effectiveCurrent, effectiveRequired)
				
				-- Дополнительное информативное сообщение для нового формата
				if required > 10 then
					print("|cFFFFA500[ECT] Критерии: Победа = +200 очков, Проигрыш = половина эффективности|r")
				end
				
				ECT_SavedVars.honorQuestReadyNotified = true
			end
		else
			-- Показываем прогресс при изменении
			if honorStatus == "in_progress" then
				if honorRequired <= 10 then
					-- Старый формат: победы
					print(string.format("|cFFFFA500[Испытание Честью] Прогресс: %d/%d побед на поле боя или в потасовке|r", 
						honorCurrent, honorRequired))
				else
					-- Новый формат: очки сражения
					print(string.format("|cFFFFA500[Испытание Честью] Прогресс: %d/%d очков сражения|r", 
						honorCurrent, honorRequired))
					print("|cFFFFA500[Испытание Честью] Победа: +200 очков, проигрыш: половина эффективности|r")
				end
			elseif honorStatus == "active" then
				-- Задание взято, но прогресс еще 0
				if honorRequired <= 10 then
					print("|cFFFFA500[Испытание Честью] Задание взято: 0/3 побед на поле боя или в потасовке|r")
				else
					print("|cFFFFA500[Испытание Честью] Задание взято: 0/500 очков сражения|r")
					print("|cFFFFA500[Испытание Честью] Критерии: победа = +200 очков, проигрыш = половина эффективности|r")
				end
			end
			ECT_SavedVars.honorQuestReadyNotified = nil
		end
	end

if essenceChanged then
    if essenceCompleted then
        if not ECT_SavedVars.essenceQuestReadyNotified then
            -- Воспроизведение звука для "Испытание Отвагой"
            PlayQuestSound("essence.mp3", "Испытание отвагой", essenceCurrent, essenceRequired)
            ECT_SavedVars.essenceQuestReadyNotified = true
        end
    else
        -- Показываем прогресс при изменении
        if essenceStatus == "in_progress" then
            print(string.format("|cFFFFA500[Испытание Отвагой] Прогресс: %d/%d подземелий пройдено|r", 
                essenceCurrent, essenceRequired))
        elseif essenceStatus == "active" then
            -- Задание взято, но прогресс еще 0
            print("|cFFFFA500[Испытание Отвагой] Задание взято: 0/3 подземелий пройдено|r")
        end
        ECT_SavedVars.essenceQuestReadyNotified = nil
    end
end
	
	-- После проверки заданий сохраняем информацию о взятых
    local today = date("%Y-%m-%d")
    if not ECT_SavedVars.takenQuests then
        ECT_SavedVars.takenQuests = {}
    end
    if not ECT_SavedVars.takenQuests[today] then
        ECT_SavedVars.takenQuests[today] = {}
    end
    
    -- Сохраняем информацию о взятых заданиях
    if essenceCurrent > 0 then
        ECT_SavedVars.takenQuests[today][ECT.Config.ESSENCE_QUEST_ID] = true
    end
    if honorCurrent > 0 then
        ECT_SavedVars.takenQuests[today][ECT.Config.HONOR_QUEST_ID] = true
    end
    
    -- Обновляем отображение если окно открыто
    if ECT.MainFrame and ECT.MainFrame:IsVisible() then
        ECT.UpdateDisplay()
    end
    
    return essenceCompleted, honorCompleted, essenceCurrent, honorCurrent, essenceRequired, honorRequired
end

-- Исправленная функция проверки звуковых файлов
function ECT.CheckSoundFiles()
    print("|cFFFFD100=== Проверка звуковых файлов ===|r")
    
    -- Список звуковых файлов для проверки
    local soundFiles = {
        {name = "essence.mp3", desc = "Испытание Отвагой"},
        {name = "honor.mp3", desc = "Испытание Честью"},
    }
    
    -- Используем простой таймер на основе OnUpdate
    local checkIndex = 1
    local checkDelay = 0
    local checkFrame = CreateFrame("Frame")
    
    checkFrame:SetScript("OnUpdate", function(self, elapsed)
        checkDelay = checkDelay + elapsed
        if checkDelay >= 2 then -- 2 секунды задержки между звуками
            checkDelay = 0
            
            if checkIndex > #soundFiles then
                self:SetScript("OnUpdate", nil)
                print("|cFF00FF00=== Проверка завершена ===|r")
                return
            end
            
            local file = soundFiles[checkIndex]
            local soundPath = "Interface\\AddOns\\EnergyCrystalsTracker\\Sounds\\" .. file.name
            
            print("|cFFFFFF00" .. file.desc .. " (" .. file.name .. ")|r")
            
            -- Пробуем воспроизвести звук
            local success, errorMsg = pcall(function()
                PlaySoundFile(soundPath, "Master")
            end)
            
            if success then
                print("|cFF00FF00✓ Звук воспроизводится|r")
            else
                print("|cFFFF0000✗ Ошибка: " .. (errorMsg or "неизвестная ошибка") .. "|r")
                print("|cFFFFA500Проверьте наличие файла: " .. soundPath .. "|r")
            end
            
            checkIndex = checkIndex + 1
        end
    end)
end

-- Простая функция тестирования звуков
function ECT.TestSound(soundType)
    if soundType == "essence" or soundType == "отвага" then
        local soundPath = "Interface\\AddOns\\EnergyCrystalsTracker\\Sounds\\essence.mp3"
        print("|cFFFFFF00Тестирование звука для Испытания Отвагой|r")
        
        local success, errorMsg = pcall(function()
            PlaySoundFile(soundPath, "Master")
        end)
        
        if success then
            print("|cFF00FF00✓ Звук essence.mp3 воспроизведен|r")
        else
            print("|cFFFF0000✗ Ошибка: " .. (errorMsg or "неизвестная ошибка") .. "|r")
            -- Пробуем стандартный звук
            PlaySound(619, "Master")
            print("|cFFFFA500Воспроизведен стандартный звук задания|r")
        end
        
    elseif soundType == "honor" or soundType == "честь" then
        local soundPath = "Interface\\AddOns\\EnergyCrystalsTracker\\Sounds\\honor.mp3"
        print("|cFFFFFF00Тестирование звука для Испытания Честью|r")
        
        local success, errorMsg = pcall(function()
            PlaySoundFile(soundPath, "Master")
        end)
        
        if success then
            print("|cFF00FF00✓ Звук honor.mp3 воспроизведен|r")
        else
            print("|cFFFF0000✗ Ошибка: " .. (errorMsg or "неизвестная ошибка") .. "|r")
            -- Пробуем стандартный звук
            PlaySound(619, "Master")
            print("|cFFFFA500Воспроизведен стандартный звук задания|r")
        end
        
    else
        print("|cFFFFFF00Тестирование стандартного звука задания|r")
        PlaySound(619, "Master")
        print("|cFF00FF00✓ Стандартный звук задания воспроизведен|r")
    end
end

-- Функция для продвижения на следующий этап вручную
function ECT.AdvanceToNextStage()
    local currentStage = ECT_SavedVars.currentStage or 1
    local nextStage = currentStage + 1
    if nextStage <= #ECT.Config.STAGES then
        ECT_SavedVars.currentStage = nextStage
        local spent = 0
        for i = 1, nextStage do
            spent = spent + ECT.Config.STAGES[i].cost
        end
        ECT_SavedVars.crystalsSpent = spent
        local currentCrystals = ECT.GetCrystalsCount()
        local totalNow = spent + currentCrystals
        if (ECT_SavedVars.totalCrystalsEver or 0) < totalNow then
            ECT_SavedVars.totalCrystalsEver = totalNow
        end
        ECT.SyncSavedVars()
        if ECT.MainFrame and ECT.MainFrame:IsVisible() then
            ECT.UpdateDisplay()
        end
        print("|cFF00FF00[ECT] Продвижение на следующий этап:|r " .. ECT.Config.STAGES[nextStage].name)
        print("|cFFFFD100[ECT] Потрачено кристаллов: " .. spent .. "|r")
        return true
    else
        print("|cFFFF0000[ECT] Вы уже на максимальном этапе!|r")
        return false
    end
end

-- Функция для возврата на предыдущий этап
function ECT.ReturnToPreviousStage()
    local currentStage = ECT_SavedVars.currentStage or 1
    local prevStage = currentStage - 1
    if prevStage >= 1 then
        ECT_SavedVars.currentStage = prevStage
        local spent = 0
        for i = 1, prevStage do
            spent = spent + ECT.Config.STAGES[i].cost
        end
        ECT_SavedVars.crystalsSpent = spent
        ECT.SyncSavedVars()
        if ECT.MainFrame and ECT.MainFrame:IsVisible() then
            ECT.UpdateDisplay()
        end
        print("|cFF00FF00[ECT] Возврат на предыдущий этап:|r " .. ECT.Config.STAGES[prevStage].name)
        print("|cFFFFD100[ECT] Потрачено кристаллов: " .. spent .. "|r")
        return true
    else
        print("|cFFFF0000[ECT] Вы уже на первом этапе!|r")
        return false
    end
end

-- Функция для установки конкретного этапа
function ECT.SetSpecificStage(stageName)
    for i, stage in ipairs(ECT.Config.STAGES) do
        if stage.name == stageName then
            ECT_SavedVars.currentStage = i
            local spent = 0
            for j = 1, i do
                spent = spent + ECT.Config.STAGES[j].cost
            end
            ECT_SavedVars.crystalsSpent = spent
            local currentCrystals = ECT.GetCrystalsCount()
            local totalNow = spent + currentCrystals
            if (ECT_SavedVars.totalCrystalsEver or 0) < totalNow then
                ECT_SavedVars.totalCrystalsEver = totalNow
            end
            ECT.SyncSavedVars()
            if ECT.MainFrame and ECT.MainFrame:IsVisible() then
                ECT.UpdateDisplay()
            end
            print("|cFF00FF00[ECT] Установлен этап:|r " .. stage.name)
            print("|cFFFFD100[ECT] Потрачено кристаллов: " .. spent .. "|r")
            return true
        end
    end
    print("|cFFFF0000[ECT] Этап не найден: " .. (stageName or "nil") .. "|r")
    return false
end

-- Функция для скрытия информации о боссе
function ECT.HideBossInfo()
    if ECT.MainFrame.bossInfoFrame and ECT.MainFrame.bossInfoFrame:IsShown() then
        ECT.MainFrame.bossInfoFrame:Hide()
        -- Возвращаем элементы на место
        ECT.MainFrame.spentText:ClearAllPoints()
        ECT.MainFrame.spentText:SetPoint("TOP", ECT.MainFrame.nextText, "BOTTOM", 0, -10)
        ECT.MainFrame.statsText:ClearAllPoints()
        ECT.MainFrame.statsText:SetPoint("TOP", ECT.MainFrame.spentText, "BOTTOM", 0, -5)
        ECT.MainFrame.currentInfo:ClearAllPoints()
        ECT.MainFrame.currentInfo:SetPoint("TOP", ECT.MainFrame.statsText, "BOTTOM", 0, -5)
    end
    if ECT.BossInfoFrame and ECT.BossInfoFrame:IsShown() then
        ECT.BossInfoFrame:Hide()
    end
end

function ECT.CreateMainFrame()
    local frame = CreateFrame("Frame", "ECTMainFrame", UIParent)
    frame:SetSize(450, 750)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Общий обработчик для всего окна с проверкой цели
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- Проверяем, не кликнули ли по кнопке или другому интерактивному элементу
            local mouseFocus = GetMouseFocus()
            local clickedOnInteractive = false
            
            -- Проверяем, является ли элемент под курсором кнопкой или другим интерактивным элементом
            if mouseFocus and mouseFocus:IsObjectType("Button") then
                clickedOnInteractive = true
            end
            
            -- Также проверяем, не кликнули ли по тексту или другому элементу
            if mouseFocus and mouseFocus:GetName() then
                local name = mouseFocus:GetName()
                -- Если это дочерний элемент, который не должен запускать перемещение
                if string.find(name, "UIPanelCloseButton") or 
                   string.find(name, "Button") or
                   mouseFocus == ECT.MainFrame.returnBtn or
                   mouseFocus == ECT.MainFrame.advanceBtn or
                   mouseFocus == ECT.MainFrame.resetBtn then
                    clickedOnInteractive = true
                end
            end
            
            -- Запускаем перемещение только если кликнули на не-интерактивную область
            if not clickedOnInteractive then
                self:StartMoving()
                self.isMoving = true
            end
        end
    end)
    
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
        end
    end)
    
    frame:SetScript("OnHide", function(self)
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
        end
    end)
    
    -- Фон с текстурой Blizzard Parchment (однотонный)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    bg:SetTexCoord(0, 1, 0, 1)
    bg:SetVertexColor(0.8, 0.8, 0.8, 0.9) -- Серый однотонный цвет с прозрачностью
    
    -- Декоративная рамка (упрощенная)
    local border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    border:SetBackdropBorderColor(0.7, 0.5, 1, 0.9)
    
    -- Верхний декоративный элемент (упрощенный)
    local topDecoration = frame:CreateTexture(nil, "ARTWORK")
    topDecoration:SetSize(450, 60)
    topDecoration:SetPoint("TOP", 0, 12)
    topDecoration:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    topDecoration:SetTexCoord(0, 1, 0.1, 0.9)
    topDecoration:SetVertexColor(0.5, 0.3, 0.8, 0.9)

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetFont("Fonts\\FRIZQT__.ttf", 20, "OUTLINE")
    titleText:SetPoint("TOP", 0, -20)
    titleText:SetText("|cFFC0C0FFТрекер Кристаллов Энергии|r")
    titleText:SetShadowOffset(2, -2)
    titleText:SetShadowColor(0, 0, 0, 0.8)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetSize(32, 32)
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    -- Панель текущего этапа
    local stagePanel = CreateFrame("Frame", nil, frame)
    stagePanel:SetSize(410, 80)
    stagePanel:SetPoint("TOP", 0, -60)
    
    local stagePanelBg = stagePanel:CreateTexture(nil, "BACKGROUND")
    stagePanelBg:SetAllPoints()
    stagePanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
	stagePanelBg:SetTexCoord(0, 1, 0, 1)
	stagePanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) 
    
    local icon = stagePanel:CreateTexture(nil, "OVERLAY")
    icon:SetSize(64, 64)
    icon:SetPoint("LEFT", 10, 0)

    local stageText = stagePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stageText:SetFont("Fonts\\FRIZQT__.ttf", 18, "OUTLINE")
    stageText:SetPoint("LEFT", 80, 10)
    stageText:SetJustifyH("LEFT")
    stageText:SetTextColor(1, 1, 0.6)
    stageText:SetShadowOffset(1, -1)
    stageText:SetShadowColor(0, 0, 0, 0.8)

    -- ДОБАВЛЕНО: Подтекст этапа
    local stageSubText = stagePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stageSubText:SetFont("Fonts\\ARIALN.ttf", 12, "OUTLINE")
    stageSubText:SetPoint("LEFT", 80, -15)
    stageSubText:SetJustifyH("LEFT")
    stageSubText:SetTextColor(0.8, 0.8, 0.4)
    stageSubText:SetShadowOffset(1, -1)
    stageSubText:SetShadowColor(0, 0, 0, 0.8)

    -- Разделитель
    local line1 = frame:CreateTexture(nil, "OVERLAY")
    line1:SetSize(410, 2)
    line1:SetPoint("TOP", stagePanel, "BOTTOM", 0, -10)
    line1:SetTexture("Interface\\Buttons\\WHITE8X8")
    line1:SetGradient("HORIZONTAL", CreateColor(0.8, 0.6, 1, 0), CreateColor(0.8, 0.6, 1, 0.8), CreateColor(0.8, 0.6, 1, 0))

    -- 1. Прогресс-бар кристаллов
    local crystalPanel = CreateFrame("Frame", nil, frame)
    crystalPanel:SetSize(410, 60)
    crystalPanel:SetPoint("TOP", line1, "BOTTOM", 0, -20)
    
    local crystalPanelBg = crystalPanel:CreateTexture(nil, "BACKGROUND")
    crystalPanelBg:SetAllPoints()
    crystalPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    crystalPanelBg:SetTexCoord(0, 1, 0, 1)
    crystalPanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) -- Светло-серый однотонный

    local crystalIcon = crystalPanel:CreateTexture(nil, "OVERLAY")
    crystalIcon:SetSize(32, 32)
    crystalIcon:SetTexture("Interface\\Icons\\inv_misc_crystalepic")
    crystalIcon:SetPoint("LEFT", 15, 5)

    local crystalsText = crystalPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    crystalsText:SetFont("Fonts\\FRIZQT__.ttf", 16, "OUTLINE")
    crystalsText:SetPoint("LEFT", crystalIcon, "RIGHT", 10, 5)
    crystalsText:SetTextColor(0.4, 1, 0.6)
    crystalsText:SetShadowOffset(1, -1)
    crystalsText:SetShadowColor(0, 0, 0, 0.8)

    local crystalsBarFrame = CreateFrame("Frame", nil, crystalPanel)
    crystalsBarFrame:SetSize(320, 20)
    crystalsBarFrame:SetPoint("BOTTOM", 10, 8)

    local crystalsBarBg = crystalsBarFrame:CreateTexture(nil, "BACKGROUND")
    crystalsBarBg:SetAllPoints()
    crystalsBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    crystalsBarBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Комментируем или удаляем бордер
	local crystalsBarBorder = crystalsBarFrame:CreateTexture(nil, "BORDER")
	crystalsBarBorder:SetAllPoints()
	crystalsBarBorder:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
	crystalsBarBorder:SetVertexColor(0.4, 0.8, 0.5, 0.3)

    local crystalsBar = crystalsBarFrame:CreateTexture(nil, "OVERLAY")
    crystalsBar:SetSize(0, 20)
    crystalsBar:SetPoint("LEFT")
    crystalsBar:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    crystalsBar:SetGradient("HORIZONTAL", CreateColor(0.2, 0.9, 0.4, 1), CreateColor(0.4, 1, 0.6, 1))

    local crystalsBarText = crystalsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crystalsBarText:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    crystalsBarText:SetPoint("CENTER")
    crystalsBarText:SetTextColor(1, 1, 1)
    crystalsBarText:SetShadowOffset(1, -1)
    crystalsBarText:SetShadowColor(0, 0, 0, 0.8)

    -- 2. Прогресс-бар эссенций отваги
    local essencePanel = CreateFrame("Frame", nil, frame)
    essencePanel:SetSize(410, 60)
    essencePanel:SetPoint("TOP", crystalPanel, "BOTTOM", 0, -15)
    
    local essencePanelBg = essencePanel:CreateTexture(nil, "BACKGROUND")
    essencePanelBg:SetAllPoints()
    essencePanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    essencePanelBg:SetTexCoord(0, 1, 0, 1)
    essencePanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) -- Светло-серый однотонный

    local essenceIcon = essencePanel:CreateTexture(nil, "OVERLAY")
    essenceIcon:SetSize(32, 32)
    essenceIcon:SetTexture("Interface\\Icons\\inv_misc_gem_pearl_04")
    essenceIcon:SetPoint("LEFT", 15, 5)

    local essenceText = essencePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    essenceText:SetFont("Fonts\\FRIZQT__.ttf", 16, "OUTLINE")
    essenceText:SetPoint("LEFT", essenceIcon, "RIGHT", 10, 5)
    essenceText:SetTextColor(1, 0.8, 0.4)
    essenceText:SetShadowOffset(1, -1)
    essenceText:SetShadowColor(0, 0, 0, 0.8)

    local essenceBarFrame = CreateFrame("Frame", nil, essencePanel)
    essenceBarFrame:SetSize(320, 20)
    essenceBarFrame:SetPoint("BOTTOM", 10, 8)

    local essenceBarBg = essenceBarFrame:CreateTexture(nil, "BACKGROUND")
    essenceBarBg:SetAllPoints()
    essenceBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    essenceBarBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local essenceBarBorder = essenceBarFrame:CreateTexture(nil, "BORDER")
    essenceBarBorder:SetAllPoints()
    essenceBarBorder:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    essenceBarBorder:SetVertexColor(1, 0.6, 0.2, 0.3)

    local essenceBar = essenceBarFrame:CreateTexture(nil, "OVERLAY")
    essenceBar:SetSize(320, 20)
    essenceBar:SetPoint("LEFT")
    essenceBar:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")

    local essenceBarText = essenceBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    essenceBarText:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    essenceBarText:SetPoint("CENTER")
    essenceBarText:SetTextColor(1, 1, 1)
    essenceBarText:SetShadowOffset(1, -1)
    essenceBarText:SetShadowColor(0, 0, 0, 0.8)

    local lineEssence = frame:CreateTexture(nil, "OVERLAY")
    lineEssence:SetSize(410, 2)
    lineEssence:SetPoint("TOP", essencePanel, "BOTTOM", 0, -10)
    lineEssence:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineEssence:SetGradient("HORIZONTAL", CreateColor(1, 0.6, 0.2, 0), CreateColor(1, 0.6, 0.2, 0.8), CreateColor(1, 0.6, 0.2, 0))

    -- ДОБАВЛЕНО: 3. Прогресс-бар испытания честью
    local honorPanel = CreateFrame("Frame", nil, frame)
    honorPanel:SetSize(410, 60)
    honorPanel:SetPoint("TOP", lineEssence, "BOTTOM", 0, -15)
    
    local honorPanelBg = honorPanel:CreateTexture(nil, "BACKGROUND")
    honorPanelBg:SetAllPoints()
    honorPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    honorPanelBg:SetTexCoord(0, 1, 0, 1)
    honorPanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) -- Светло-серый однотонный

    local honorIcon = honorPanel:CreateTexture(nil, "OVERLAY")
    honorIcon:SetSize(32, 32)
    honorIcon:SetTexture("Interface\\Icons\\inv_misc_rune_07")
    honorIcon:SetPoint("LEFT", 15, 5)

    local honorText = honorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    honorText:SetFont("Fonts\\FRIZQT__.ttf", 16, "OUTLINE")
    honorText:SetPoint("LEFT", honorIcon, "RIGHT", 10, 5)
    honorText:SetTextColor(0.4, 0.8, 1)
    honorText:SetShadowOffset(1, -1)
    honorText:SetShadowColor(0, 0, 0, 0.8)

    local honorBarFrame = CreateFrame("Frame", nil, honorPanel)
    honorBarFrame:SetSize(320, 20)
    honorBarFrame:SetPoint("BOTTOM", 10, 8)

    local honorBarBg = honorBarFrame:CreateTexture(nil, "BACKGROUND")
    honorBarBg:SetAllPoints()
    honorBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    honorBarBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local honorBarBorder = honorBarFrame:CreateTexture(nil, "BORDER")
    honorBarBorder:SetAllPoints()
    honorBarBorder:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    honorBarBorder:SetVertexColor(0.4, 0.6, 1, 0.3)

    local honorBar = honorBarFrame:CreateTexture(nil, "OVERLAY")
    honorBar:SetSize(320, 20)
    honorBar:SetPoint("LEFT")
    honorBar:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")

    local honorBarText = honorBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    honorBarText:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    honorBarText:SetPoint("CENTER")
    honorBarText:SetTextColor(1, 1, 1)
    honorBarText:SetShadowOffset(1, -1)
    honorBarText:SetShadowColor(0, 0, 0, 0.8)

    local lineHonor = frame:CreateTexture(nil, "OVERLAY")
    lineHonor:SetSize(410, 2)
    lineHonor:SetPoint("TOP", honorPanel, "BOTTOM", 0, -10)
    lineHonor:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineHonor:SetGradient("HORIZONTAL", CreateColor(0.4, 0.6, 1, 0), CreateColor(0.4, 0.6, 1, 0.8), CreateColor(0.4, 0.6, 1, 0))

    -- 4. Блок с информацией о следующем этапе
    local nextPanel = CreateFrame("Frame", nil, frame)
    nextPanel:SetSize(410, 110)
    nextPanel:SetPoint("TOP", lineHonor, "BOTTOM", 0, -20)
    
    -- ИСПРАВЛЕНО: Убрана лишняя строка frame.statsPanel = statsPanel
    
    local nextPanelBg = nextPanel:CreateTexture(nil, "BACKGROUND")
    nextPanelBg:SetAllPoints()
    nextPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    nextPanelBg:SetTexCoord(0, 1, 0, 1)
    nextPanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) -- Светло-серый однотонный

    -- Создаем кликабельный текст для информации о боссе (будет показываться только при необходимости)
    local bossInfoTextBtn = CreateFrame("Button", nil, nextPanel)
    bossInfoTextBtn:SetSize(380, 25)
    bossInfoTextBtn:SetPoint("BOTTOM", 0, 5)
    bossInfoTextBtn:Hide() -- По умолчанию скрыта
    
    -- Текст кнопки
    bossInfoTextBtn.text = bossInfoTextBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossInfoTextBtn.text:SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    bossInfoTextBtn.text:SetAllPoints()
    bossInfoTextBtn.text:SetJustifyH("CENTER")
    bossInfoTextBtn.text:SetTextColor(1, 0.3, 0.3)
    bossInfoTextBtn.text:SetText("|cFFFF0000[Следующий этап требует убийства босса! Нажмите для информации]|r")
    
    -- Подсветка при наведении
    bossInfoTextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    bossInfoTextBtn:GetHighlightTexture():SetVertexColor(1, 0.5, 0.5, 0.3)
    
    -- В функции ECT.CreateMainFrame() найдите обработчик кнопки bossInfoTextBtn:
	bossInfoTextBtn:SetScript("OnClick", function(self)
		local stageIndex = ECT_SavedVars.currentStage or 1
		local stage = ECT.Config.STAGES[stageIndex]
		
		-- Показываем информацию о ТЕКУЩЕМ этапе (который является босс-этапом)
		if ECT.IsBossStage(stage.name) then
			ECT.ShowBossInfo(stage.name)
		end
	end)    
    -- Всплывающая подсказка
    bossInfoTextBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Информация о боссе")
        GameTooltip:AddLine("Нажмите для получения информации о боссе", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    bossInfoTextBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Основной текст информации о следующем этапе (не кликабельный)
    local nextText = nextPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextText:SetFont("Fonts\\ARIALN.ttf", 14, "OUTLINE")
    nextText:SetPoint("TOP", 0, -10)
    nextText:SetSize(380, 60)
    nextText:SetJustifyH("CENTER")
    nextText:SetJustifyV("TOP")
    nextText:SetTextColor(1, 0.9, 0.6)
    nextText:SetShadowOffset(1, -1)
    nextText:SetShadowColor(0, 0, 0, 0.8)

    local bossInfoFrame = CreateFrame("Frame", nil, nextPanel)
    bossInfoFrame:SetSize(380, 180)
    bossInfoFrame:SetPoint("TOP", nextText, "BOTTOM", 0, -10)
    bossInfoFrame:Hide()
    bossInfoFrame:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    bossInfoFrame:SetBackdropColor(0.95, 0.95, 0.95, 0.9) -- Почти белый однотонный
    bossInfoFrame:SetBackdropBorderColor(0.8, 0.3, 0.3, 0.8)

    local bossIcon = bossInfoFrame:CreateTexture(nil, "OVERLAY")
    bossIcon:SetSize(64, 64)
    bossIcon:SetPoint("TOPLEFT", 10, -10)
    bossIcon:SetTexture("Interface\\Icons\\inv_misc_gem_03")

    local bossInfoText = bossInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossInfoText:SetFont("Fonts\\ARIALN.ttf", 12)
    bossInfoText:SetPoint("TOPLEFT", bossIcon, "TOPRIGHT", 10, -5)
    bossInfoText:SetPoint("BOTTOMRIGHT", -10, 35)
    bossInfoText:SetJustifyH("LEFT")
    bossInfoText:SetJustifyV("TOP")
    bossInfoText:SetNonSpaceWrap(false)
    bossInfoText:SetTextColor(1, 1, 0.8)

    local closeBossInfoBtn = CreateFrame("Button", nil, bossInfoFrame, "UIPanelButtonTemplate")
    closeBossInfoBtn:SetSize(100, 22)
    closeBossInfoBtn:SetPoint("BOTTOM", 0, 10)
    closeBossInfoBtn:SetText("Закрыть")
    closeBossInfoBtn:SetScript("OnClick", function()
        ECT.HideBossInfo()
    end)

    local line3 = frame:CreateTexture(nil, "OVERLAY")
    line3:SetSize(410, 2)
    line3:SetPoint("TOP", nextPanel, "BOTTOM", 0, -10)
    line3:SetTexture("Interface\\Buttons\\WHITE8X8")
    line3:SetGradient("HORIZONTAL", CreateColor(0.8, 0.6, 1, 0), CreateColor(0.8, 0.6, 1, 0.8), CreateColor(0.8, 0.6, 1, 0))

    -- 5. Статистика и информация
    local statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetSize(410, 140)
    statsPanel:SetPoint("TOP", line3, "BOTTOM", 0, -10)
    
    local statsPanelBg = statsPanel:CreateTexture(nil, "BACKGROUND")
    statsPanelBg:SetAllPoints()
    statsPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    statsPanelBg:SetTexCoord(0, 1, 0, 1)
    statsPanelBg:SetVertexColor(0.9, 0.9, 0.9, 0.6) -- Светло-серый однотонный

    local spentText = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spentText:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    spentText:SetPoint("TOP", 0, -10)
    spentText:SetTextColor(1, 0.8, 0.3)
    spentText:SetShadowOffset(1, -1)
    spentText:SetShadowColor(0, 0, 0, 0.8)

    local statsText = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetFont("Fonts\\ARIALN.ttf", 14, "OUTLINE")
    statsText:SetPoint("TOP", spentText, "BOTTOM", 0, -8)
    statsText:SetTextColor(0.8, 0.9, 1)

    local currentInfo = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentInfo:SetFont("Fonts\\ARIALN.ttf", 14, "OUTLINE")
    currentInfo:SetPoint("TOP", statsText, "BOTTOM", 0, -8)
    currentInfo:SetTextColor(1, 1, 0.4)

    local essenceStats = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    essenceStats:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    essenceStats:SetPoint("TOP", currentInfo, "BOTTOM", 0, -8)
    essenceStats:SetTextColor(1, 0.8, 0.3)

    -- ДОБАВЛЕНО: Статистика чести
    local honorStats = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    honorStats:SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    honorStats:SetPoint("TOP", essenceStats, "BOTTOM", 0, -8)
    honorStats:SetTextColor(0.4, 0.8, 1)

    -- 6. Кнопки управления
    local buttonsPanel = CreateFrame("Frame", nil, frame)
    buttonsPanel:SetSize(410, 50)
    buttonsPanel:SetPoint("BOTTOM", 0, 20)
    
    local buttonsPanelBg = buttonsPanel:CreateTexture(nil, "BACKGROUND")
    buttonsPanelBg:SetAllPoints()
    buttonsPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    buttonsPanelBg:SetTexCoord(0, 1, 0, 1)
    buttonsPanelBg:SetVertexColor(0.95, 0.95, 0.95, 0.7) -- Почти белый однотонный

    -- КНОПКИ
    local returnBtn = CreateFrame("Button", nil, buttonsPanel, "UIPanelButtonTemplate")
    returnBtn:SetSize(120, 28)
    returnBtn:SetPoint("LEFT", 20, 0)
    returnBtn:SetText("|cFFFFC0C0 Предыдущий|r")
    returnBtn:SetNormalFontObject(GameFontNormal)
    returnBtn:GetFontString():SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    returnBtn:SetScript("OnClick", function()
        ECT.ReturnToPreviousStage()
    end)

    local advanceBtn = CreateFrame("Button", nil, buttonsPanel, "UIPanelButtonTemplate")
    advanceBtn:SetSize(120, 28)
    advanceBtn:SetPoint("CENTER", 0, 0)
    advanceBtn:SetText("|cFFC0FFC0Следующий |r")
    advanceBtn:GetFontString():SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    advanceBtn:SetScript("OnClick", function()
        ECT.AdvanceToNextStage()
    end)

    local resetBtn = CreateFrame("Button", nil, buttonsPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 28)
    resetBtn:SetPoint("RIGHT", -20, 0)
    resetBtn:SetText("|cFFFFC0806+ Категория|r")
    resetBtn:GetFontString():SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    resetBtn:SetScript("OnClick", function()
        ECT.SetSpecificStage("6+ Категория")
    end)

    ECT.MainFrame = frame
    ECT.MainFrame.stagePanel = stagePanel -- Добавлено для доступа к панели этапа
    ECT.MainFrame.icon = icon
    ECT.MainFrame.stageText = stageText
    ECT.MainFrame.stageSubText = stageSubText
    ECT.MainFrame.crystalsText = crystalsText
    ECT.MainFrame.crystalsBarFrame = crystalsBarFrame
    ECT.MainFrame.crystalsBar = crystalsBar
    ECT.MainFrame.crystalsBarText = crystalsBarText
    ECT.MainFrame.essenceText = essenceText
    ECT.MainFrame.essenceBarFrame = essenceBarFrame
    ECT.MainFrame.essenceBar = essenceBar
    ECT.MainFrame.essenceBarText = essenceBarText
    ECT.MainFrame.honorText = honorText -- ДОБАВЛЕНО
    ECT.MainFrame.honorBarFrame = honorBarFrame -- ДОБАВЛЕНО
    ECT.MainFrame.honorBar = honorBar -- ДОБАВЛЕНО
    ECT.MainFrame.honorBarText = honorBarText -- ДОБАВЛЕНО
    ECT.MainFrame.nextPanel = nextPanel
    ECT.MainFrame.nextText = nextText
    ECT.MainFrame.bossInfoTextBtn = bossInfoTextBtn -- Добавлена кнопка информации о боссе
    ECT.MainFrame.bossInfoFrame = bossInfoFrame
    ECT.MainFrame.bossIcon = bossIcon
    ECT.MainFrame.bossInfoText = bossInfoText
    ECT.MainFrame.closeBossInfoBtn = closeBossInfoBtn
    ECT.MainFrame.statsPanel = statsPanel -- Теперь переменная определена
    ECT.MainFrame.spentText = spentText
    ECT.MainFrame.statsText = statsText
    ECT.MainFrame.currentInfo = currentInfo
    ECT.MainFrame.essenceStats = essenceStats
    ECT.MainFrame.honorStats = honorStats -- ДОБАВЛЕНО
    ECT.MainFrame.returnBtn = returnBtn
    ECT.MainFrame.advanceBtn = advanceBtn
    ECT.MainFrame.resetBtn = resetBtn
    ECT.MainFrame.line3 = line3 -- Добавлено для правильного позиционирования
	ECT.UpdateStageInfo()
end

function ECT.UpdateStageInfo()
    local stageIndex = ECT_SavedVars.currentStage or 1
    local currentStage = ECT.Config.STAGES[stageIndex]
    local nextStage = ECT.Config.STAGES[stageIndex + 1]

    if not currentStage then return end

    -- Название этапа
    if ECT.StageTitle then
        ECT.StageTitle:SetText(currentStage.name)
    end

    -- Кликабельный текст про босса
    if ECT.BossRequirementText then
        if ECT.ShouldShowBossRequirementText(nextStage) then
            ECT.BossRequirementText:SetText(
                "|cff00ffffСледующий этап требует убийства босса|r"
            )
            ECT.BossRequirementText:Show()
        else
            ECT.BossRequirementText:Hide()
        end
    end
end


-- Создание отдельного окна для информации о боссе
function ECT.CreateBossInfoFrame()
    local frame = CreateFrame("Frame", "ECTBossInfoFrame", UIParent)
    frame:SetSize(500, 650)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Фон с текстурой Blizzard Parchment (однотонный)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    bg:SetTexCoord(0, 1, 0, 1)
    bg:SetVertexColor(0.9, 0.9, 0.9, 0.95) -- Светло-серый однотонный
    bg:SetHorizTile(false)
    bg:SetVertTile(false)
    
    -- Декоративная рамка (упрощенная)
    local border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", 4, -4)
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    border:SetBackdropBorderColor(1, 0.2, 0.2, 0.9)
    
    -- Верхний декоративный элемент (упрощенный)
    local topDecoration = frame:CreateTexture(nil, "ARTWORK")
    topDecoration:SetSize(500, 70)
    topDecoration:SetPoint("TOP", 0, 15)
    topDecoration:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    topDecoration:SetTexCoord(0, 1, 0, 1)
    topDecoration:SetVertexColor(0.8, 0.1, 0.1, 0.9)

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetFont("Fonts\\FRIZQT__.ttf", 22, "OUTLINE")
    titleText:SetPoint("TOP", 0, -25)
    titleText:SetText("|cFFFF0000 Информация о задании |r")
    titleText:SetShadowOffset(3, -3)
    titleText:SetShadowColor(0, 0, 0, 1)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetSize(32, 32)
    closeButton:SetPoint("TOPRIGHT", -10, -10)
    closeButton:SetScript("OnClick", function() 
        ECT.HideBossInfo() 
    end)

    -- Панель информации о боссе
    local bossPanel = CreateFrame("Frame", nil, frame)
    bossPanel:SetSize(460, 80)
    bossPanel:SetPoint("TOP", 0, -70)
    
    local bossPanelBg = bossPanel:CreateTexture(nil, "BACKGROUND")
    bossPanelBg:SetAllPoints()
    bossPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    bossPanelBg:SetTexCoord(0, 1, 0, 1)
    bossPanelBg:SetVertexColor(0.95, 0.95, 0.95, 0.8) -- Почти белый однотонный

    local bossIcon = bossPanel:CreateTexture(nil, "OVERLAY")
    bossIcon:SetSize(64, 64)
    bossIcon:SetPoint("LEFT", 10, 0)

    local bossNameText = bossPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bossNameText:SetFont("Fonts\\FRIZQT__.ttf", 18, "OUTLINE")
    bossNameText:SetPoint("LEFT", 80, 5)
    bossNameText:SetJustifyH("LEFT")
    bossNameText:SetTextColor(1, 0.6, 0.2)
    bossNameText:SetShadowOffset(2, -2)
    bossNameText:SetShadowColor(0, 0, 0, 0.9)

    -- Установка точки привязки для scrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "ECTBossInfoScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(460, 420)
    scrollFrame:SetPoint("TOP", bossPanel, "BOTTOM", 0, -10)
    
    -- Стилизация полосы прокрутки
    local scrollBar = _G["ECTBossInfoScrollFrameScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(16)
        local thumbTexture = scrollBar:GetThumbTexture()
        if thumbTexture then
            thumbTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
            thumbTexture:SetVertexColor(1, 0.4, 0.4, 0.8)
        end
    end

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(440, 1000)
    scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, 0)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Фон для текста с текстурой Blizzard Parchment
    local textBg = scrollChild:CreateTexture(nil, "BACKGROUND")
    textBg:SetAllPoints()
    textBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    textBg:SetTexCoord(0, 1, 0, 1)
    textBg:SetVertexColor(0.95, 0.95, 0.95, 0.7) -- Почти белый однотонный

    local infoText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetFont("Fonts\\FRIZQT__.ttf", 15, "OUTLINE")
    infoText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -15)
    infoText:SetPoint("RIGHT", scrollChild, "RIGHT", -25, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetNonSpaceWrap(true)
    infoText:SetTextColor(1, 1, 0.8)
    infoText:SetShadowOffset(1, -1)
    infoText:SetShadowColor(0, 0, 0, 0.8)

    -- Нижняя панель с кнопкой
    local bottomPanel = CreateFrame("Frame", nil, frame)
    bottomPanel:SetSize(460, 50)
    bottomPanel:SetPoint("BOTTOM", 0, 15)
    
    local bottomPanelBg = bottomPanel:CreateTexture(nil, "BACKGROUND")
    bottomPanelBg:SetAllPoints()
    bottomPanelBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    bottomPanelBg:SetTexCoord(0, 1, 0, 1)
    bottomPanelBg:SetVertexColor(0.95, 0.95, 0.95, 0.9) -- Почти белый однотонный

    local closeButtonBig = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    closeButtonBig:SetSize(140, 32)
    closeButtonBig:SetPoint("CENTER", 0, 0)
    closeButtonBig:SetText("|cFFFFC0C0Закрыть|r")
    closeButtonBig:GetFontString():SetFont("Fonts\\FRIZQT__.ttf", 14, "OUTLINE")
    closeButtonBig:SetScript("OnClick", function() 
        ECT.HideBossInfo() 
    end)

    ECT.BossInfoFrame = frame
    ECT.BossInfoFrame.bossIcon = bossIcon
    ECT.BossInfoFrame.bossNameText = bossNameText
    ECT.BossInfoFrame.infoText = infoText
    ECT.BossInfoFrame.scrollFrame = scrollFrame
    ECT.BossInfoFrame.scrollChild = scrollChild
end

function ECT.ShowBossInfo(stageName)
    if not ECT.BossInfoFrame then
        ECT.CreateBossInfoFrame()
    end
    
    -- Позиционирование окна
    if ECT.MainFrame and ECT.MainFrame:IsShown() then
        ECT.BossInfoFrame:ClearAllPoints()
        ECT.BossInfoFrame:SetPoint("LEFT", ECT.MainFrame, "RIGHT", 10, 0)
    else
        ECT.BossInfoFrame:ClearAllPoints()
        ECT.BossInfoFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    local bossInfoMap = {
        ["7+ Категория"] = {
            title = "Испытание для получения 6 категории",
            bossName = "F-Reaper 8000 TX",
            bossIcon = "Interface\\Icons\\inv_misc_gem_02", 
            description = "|cFF804000Описание испытания:|r\nДля получения 6-й категории тебе необходимо будет уничтожить прототип боевой машины, скрытый в секретных подземельях.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Сирус телепортирует вас к боссу\n4. Уничтожьте F-Reaper 8000 TX\n5. Вернитесь к Джулии с доказательством победы",
            difficulty = "|cFFFFA500Сложность: СРЕДНЯЯ|r\n• Размер группы: 4 игрока\n• Состав: 1 танк, 1 лекарь, 2+ дамагеров",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_02:20|t |cFFFFA500Вы получите: 6 категорию|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(2 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA500210 золота и 2300 опыта|r",
            },
        },
        ["6++ Категория"] = {
            title = "Испытание для получения 5 категории",
            bossName = "Октарион",
            bossIcon = "Interface\\Icons\\inv_misc_gem_03",
            description = "|cFF804000Описание испытания:|r\nДля получения 5-й категории тебе необходимо будет одолеть Октариона, чародея пламени.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса \n3. Телепортация к боссу\n4. Уничтожьте Октариона\n5. Вернитесь к Джулии с доказательством победа",
            difficulty = "|cFFFF0000Сложность: ВЫСОКАЯ|r\n• Размер группы: 6-10 игроков\n• Состав: 1-2 танка, 2 лекаря, остальные дамагеры",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_03:20|t |cFFFFA500Вы получите: 5 категорию|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(3 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA50050 золота и 2300 ОПЫТА|r",
            },
        },
        ["5+++ Категория"] = {
            title = "Испытание для получения 4 категории",
            bossName = "Малар",
            bossIcon = "Interface\\Icons\\inv_misc_gem_03",
            description = "|cFF804000Описание испытания:|r\nДля получения 4-й категории тебе нужно одолеть великого чародея, Малара.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Телепортация к боссу\n4. Уничтожьте Малара\n5. Вернитесь к Джулии",
            difficulty = "|cFFFF0000Сложность: ОЧЕНЬ ВЫСОКАЯ|r\n• Размер группы: 10-12 игроков\n• Состав: 2 танка, 3 лекаря, 5-7 дамагеров",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_03:20|t |cFFFFA500Вы получите: 4 категорию|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(4 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA5002300 ОПЫТА|r",
            },
        },   
        ["4++++ Категория"] = {
            title = "Испытание для получения 3 категории",
            bossName = "Волтрис",
            bossIcon = "Interface\\Icons\\inv_misc_gem_03",
            description = "|cFF804000Описание испытания:|r\nЕсли ты хочешь получить 3-ю категорию, тебе необходимо будет убить ледяного элементаля Волтриса.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Телепортация к боссу\n4. Уничтожьте Волтриса\n5. Вернитесь к Джулии",
            difficulty = "|cFFFF0000Сложность: ЭПИЧЕСКАЯ|r\n• Размер группы: 20-25 игроков\n• Состав: 3 танка, 5 лекарей, 12-17 дамагеров",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_03:20|t |cFFFFA500Вы получите: 3 категорию|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(5 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA5002300 ОПЫТА|r",
            },   
        },
        ["3+++++ Категория"] = {
            title = "Испытание для получения 2 категории",
            bossName = "Инфернос",
            bossIcon = "Interface\\Icons\\inv_misc_gem_03",
            description = "|cFF804000Описание испытания:|r\nТревожные вести пришли к нам от наших друзей из Запределья! Инфернос угрожает всему Азероту.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Телепортация к боссу\n4. Уничтожьте Инферноса\n5. Вернитесь к Джулии",
            difficulty = "|cFFFF0000Сложность: ЛЕГЕНДАРНАЯ|r\n• Размер группы: 30-35 игроков\n• Состав: 4 танка, 7 лекарей, 19-24 дамагеров",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_03:20|t |cFFFFA500Вы получите: 2 категорию|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(7 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA5002300 ОПЫТА|r",
            },   
        },
        ["2++++++ Категория"] = {
            title = "Испытание для получения 1 категории",
            bossName = "Родамирус",
            bossIcon = "Interface\\Icons\\inv_misc_gem_amethyst_01",
            description = "|cFF804000Описание испытания:|r\nМашина судного дня угрожает Азероту! Родамирус должен быть остановлен.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Телепортация к боссу\n4. Уничтожьте Родамируса\n5. Вернитесь к Джулии",
            difficulty = "|cFFFF0000Сложность: МИФИЧЕСКАЯ|r\n• Размер группы: 40 игроков\n• Состав: 5 танков, 8 лекарей, 27 дамагеров",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_amethyst_01:20|t |cFFFFA5001 категория|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(7 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA5002300 ОПЫТА|r",
            },   
        },
        ["1+++++++ Категория"] = {
            title = "Испытание для получения ранга ВНЕ КАТЕГОРИЙ",
            bossName = "Зорт",
            bossIcon = "Interface\\Icons\\inv_misc_gem_variety_01",
            description = "|cFF804000Описание испытания:|r\nВремя на исходе, ГЕРОЙ. Изумрудный сон содрогается от присутствия Зорта.",
            instructions = "|cFF804000Инструкция:|r\n1. Поговорите с Джулией\n2. Найдите Сируса\n3. Телепортация в Изумрудный Сон\n4. Уничтожьте Зорта\n5. Вернитесь к Джулии",
            difficulty = "|cFFFF0000Сложность: ЛЕГЕНДАРНАЯ|r\n• Размер группы: 25 игроков\n• Требуется высокий уровень предметов",
            rewards = {
                "|cFF804000Награды:|r",
                "|TInterface\\Icons\\inv_misc_gem_variety_01:20|t |cFFFFA500Категория ВНЕ КАТЕГОРИЙ|r",
                "|TInterface\\Icons\\inv_misc_coin_17:20|t |cFFFFA500Монета удачи Джулии|r |cFF00FF00(9 шт.)|r",
                "|TInterface\\Icons\\inv_legendary_breathofblackprince_str:20|t |cFFFFA500Осколок черного бриллианта|r",
                "|TInterface\\Icons\\inv_misc_coin_01:20|t |cFFFFA5002300 ОПЫТА|r",
            },
        }
    }

    local info = bossInfoMap[stageName]
    if not info then
        if string.find(stageName, "ВНЕ КАТЕГОРИЙ") then
            info = bossInfoMap["1+++++++ Категория"]
        end
    end

    if info then
        local textLines = {
            info.title .. "\n",
            info.description,
            "\n",
            info.instructions,
            "\n",
            info.difficulty,
            "\n",
        }
        
        if info.rewards and type(info.rewards) == "table" then
            table.insert(textLines, table.concat(info.rewards, "\n") .. "\n")
        else
            table.insert(textLines, "|cFF00FF00Награды:|r Информация о наградах отсутствует\n")
        end
        
        local text = table.concat(textLines, "")
        
        -- Установка текстуры иконки босса с проверкой
        if info.bossIcon then
            ECT.BossInfoFrame.bossIcon:SetTexture(info.bossIcon)
            if not ECT.BossInfoFrame.bossIcon:GetTexture() then
                local altBossIcons = {
                    "Interface\\Icons\\inv_misc_gem_02",
                    "Interface\\Icons\\inv_misc_gem_03",
                    "Interface\\Icons\\inv_misc_gem_04",
                    "Interface\\Icons\\inv_misc_gem_05",
                }
                
                for _, altIcon in ipairs(altBossIcons) do
                    ECT.BossInfoFrame.bossIcon:SetTexture(altIcon)
                    if ECT.BossInfoFrame.bossIcon:GetTexture() then
                        break
                    end
                end
                
                if not ECT.BossInfoFrame.bossIcon:GetTexture() then
                    ECT.BossInfoFrame.bossIcon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
                end
            end
        else
            ECT.BossInfoFrame.bossIcon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
        end
        
        -- Обновление имени босса
        ECT.BossInfoFrame.bossNameText:SetText(info.bossName)
        
        -- Обновление текста
        ECT.BossInfoFrame.infoText:SetText(text)
        
        -- Простая установка высоты
        ECT.BossInfoFrame.scrollChild:SetHeight(500)
        
        -- Показываем окно
        ECT.BossInfoFrame:Show()
        
        print("|cFFFFD100[ECT] Показана информация для этапа: " .. stageName .. "|r")
        return true
    else
        print("|cFFFF0000[ECT] Информация для этапа '" .. (stageName or "nil") .. "' не найдена|r")
        return false
    end
end

function ECT.UpdateDisplay()
    ECT.HideBossInfo()
    local stageIndex = ECT_SavedVars.currentStage or 1
    local stage = ECT.Config.STAGES[stageIndex]
    local nextStageIndex = stageIndex + 1
    local nextStage = ECT.Config.STAGES[nextStageIndex]
    local crystalsNow = ECT.GetCrystalsCount()
    
    -- Проверяем сохраненный статус заданий
    local essenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
    local essenceCurrent = ECT_SavedVars.essenceCurrent or 0
    local essenceRequired = ECT_SavedVars.essenceRequired or 3
    local honorCompleted = ECT_SavedVars.honorQuestCompleted or false
    local honorCurrent = ECT_SavedVars.honorCurrent or 0
    local honorRequired = ECT_SavedVars.honorRequired or 3
    
    -- Получаем время до сброса
    local resetTimeStr, secondsUntilReset, currentTimeStr, debugInfo = ECT.GetResetTimeFormatted()
    local timeUntilReset = ECT.FormatTime(secondsUntilReset)
    
    -- Определяем цвет таймера
    local timerColor
    if secondsUntilReset > 3600 then -- Более 1 часа
        timerColor = "|cFF00FF00" -- Зеленый
    elseif secondsUntilReset > 600 then -- Более 10 минут
        timerColor = "|cFFFFFF00" -- Желтый
    else -- Менее 10 минут
        timerColor = "|cFFFF0000" -- Красный
    end

    -- Проверяем, есть ли задание в журнале (активно ли оно)
    local essenceQuestActive, essenceStatus = ECT.CheckQuestProgress(ECT.Config.ESSENCE_QUEST_ID, 3)
    local honorQuestActive, honorStatus = ECT.CheckQuestProgress(ECT.Config.HONOR_QUEST_ID, 3)
    
    local totalSpent = ECT_SavedVars.crystalsSpent or 0
    
    -- Проверяем и устанавливаем иконку этапа
    local iconTexture = stage.icon
    ECT.MainFrame.icon:SetTexture(iconTexture)
    
    if not ECT.MainFrame.icon:GetTexture() then
        local alternativeIcons = {
            "Interface\\Icons\\inv_misc_gem_01",
            "Interface\\Icons\\inv_misc_crystalepic",
            "Interface\\Icons\\inv_jewelry_talisman_04",
        }
        
        for _, altIcon in ipairs(alternativeIcons) do
            ECT.MainFrame.icon:SetTexture(altIcon)
            if ECT.MainFrame.icon:GetTexture() then
                break
            end
        end
        
        if not ECT.MainFrame.icon:GetTexture() then
            ECT.MainFrame.icon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
        end
    end
    
    -- Обновляем текст этапа
    ECT.MainFrame.stageText:SetText("Текущий этап:\n|cFFFFD100" .. stage.name .. "|r")
    
    -- Обновляем подтекст этапа (стоимость)
    if ECT.MainFrame.stageSubText then
        ECT.MainFrame.stageSubText:SetText("Требуется: " .. (stage.cost or 0) .. " кристаллов")
    end
    
    ECT.MainFrame.currentInfo:SetText("Для этого этапа нужно: " .. (stage.cost or 0) .. " кристаллов")
    
    -- 1. Обновление прогресса кристаллов для ТЕКУЩЕГО этапа
    ECT.MainFrame.crystalsText:SetText("Кристаллов Энергии: |cFF00FF00" .. crystalsNow .. "|r")
    
    local currentNeeded = stage.cost or 0
    local isCurrentBossStage = ECT.IsBossStage(stage.name)
    local isNextBossStage = nextStage and ECT.IsBossStage(nextStage.name) or false
    
    local width = math.min((crystalsNow / currentNeeded) * 320, 320)
    ECT.MainFrame.crystalsBar:SetSize(width, 20)
    
    -- Сначала скрываем кнопку информации о боссе
    if ECT.MainFrame.bossInfoTextBtn then
        ECT.MainFrame.bossInfoTextBtn:Hide()
    end
    
    if crystalsNow >= currentNeeded then
        -- Текущий этап выполнен
        ECT.MainFrame.crystalsBar:SetVertexColor(0, 1, 0)
        ECT.MainFrame.crystalsBarText:SetText(string.format("Готово! (%d/%d)", crystalsNow, currentNeeded))
        
        if isCurrentBossStage then
            ECT.MainFrame.nextText:SetText(string.format(
                "Текущий этап: %s выполнен!\n|cFFFFD100%d кристаллов собрано|r",
                stage.name, crystalsNow
            ))
            if ECT.MainFrame.bossInfoTextBtn then
                ECT.MainFrame.bossInfoTextBtn:Show()
            end
        else
            if nextStage then
                local nextNeeded = nextStage.cost or 0
                ECT.MainFrame.nextText:SetText(string.format(
                    "Для следующего этапа %s нужно:\n|cFFFFD100%d кристаллов|r",
                    nextStage.name, nextNeeded
                ))
            else
                ECT.MainFrame.nextText:SetText("|cFF00FF00Вы достигли конца цепочки!|r")
            end
        end
    else
        -- Текущий этап еще не выполнен
        ECT.MainFrame.crystalsBar:SetVertexColor(0.2, 0.8, 0.2)
        local remaining = currentNeeded - crystalsNow
        local pct = math.floor((crystalsNow / currentNeeded) * 100)
        ECT.MainFrame.crystalsBarText:SetText(string.format("%d/%d (%d%%) - Осталось: %d", crystalsNow, currentNeeded, pct, remaining))
        
        ECT.MainFrame.nextText:SetText(string.format(
            "Для этапа %s нужно:\n|cFFFFD100%d кристаллов|r (осталось: %d)",
            stage.name, currentNeeded, remaining
        ))
    end
    
    -- Показываем кликабельный текст о боссе
    if ECT.MainFrame.bossInfoTextBtn and isCurrentBossStage and nextStage then
        ECT.MainFrame.bossInfoTextBtn:Show()
    end
    
    -- 2. Обновление статуса задания "Испытание Отвагой"
    ECT.MainFrame.essenceText:SetText("Задание: Испытание Отвагой")

	if essenceCompleted then
		-- Задание выполнено - только таймер сброса
		ECT.MainFrame.essenceBar:SetVertexColor(0, 1, 0)
		ECT.MainFrame.essenceBar:SetSize(320, 20)
		ECT.MainFrame.essenceBarText:SetText(string.format(
			"Выполнено! Сброс через %s%s|r",
			timerColor,
			timeUntilReset
		))
	else
		-- Задание не выполнено
		local essenceWidth = math.min((essenceCurrent / essenceRequired) * 320, 320)
		ECT.MainFrame.essenceBar:SetSize(essenceWidth, 20)
		ECT.MainFrame.essenceBar:SetVertexColor(1, 0.8, 0.2)
		
		-- Определяем текст в зависимости от статуса
		local statusText = ""
		if essenceQuestActive or essenceCurrent > 0 then
			-- Задание активно или есть прогресс
			if essenceCurrent >= essenceRequired then
				statusText = string.format("Готово к сдаче! (%d/%d)", 
					essenceCurrent, essenceRequired)
			else
				statusText = string.format("%d/%d подземелий пройдено", 
					essenceCurrent, essenceRequired)
			end
		else
			-- Задание не взято
			statusText = "Задание не выполняется"
		end
		
		ECT.MainFrame.essenceBarText:SetText(statusText)
	end
    
    -- 3. Обновление статуса задания "Испытание Честью"
    ECT.MainFrame.honorText:SetText("Задание: Испытание Честью")
    
    if honorCompleted then
        -- Задание выполнено - показываем выполнено
        ECT.MainFrame.honorBar:SetVertexColor(0, 1, 0)
        ECT.MainFrame.honorBar:SetSize(320, 20)
        ECT.MainFrame.honorBarText:SetText(string.format(
            "Выполнено! (%d/%d) Сброс через %s%s|r",
            honorCurrent, honorRequired,
            timerColor,
            timeUntilReset
        ))
    else
        -- Задание не выполнено - показываем текущий прогресс
        local honorWidth = math.min((honorCurrent / honorRequired) * 320, 320)
        ECT.MainFrame.honorBar:SetSize(honorWidth, 20)
        ECT.MainFrame.honorBar:SetVertexColor(0.4, 0.6, 1)
        
        -- Определяем текст прогресса
        local progressText = ""
        if honorCurrent > 0 then
            -- Есть прогресс
            progressText = string.format("%d/%d очков сражения (победа: +%d)", 
                honorCurrent, honorRequired, ECT.Config.WIN_POINTS)
        else
            -- Прогресса нет
            progressText = string.format("0/%d очков сражения", honorRequired)
        end
        
        ECT.MainFrame.honorBarText:SetText(progressText)
    end
    
    -- 4. Обновление статистики
    ECT.MainFrame.spentText:SetText("Потрачено кристаллов: |cFFFFA500" .. totalSpent .. "|r")

    -- Рассчитываем реальную сумму всех cost из STAGES
    local realTotalCrystalsNeeded = 0
    for i, stageData in ipairs(ECT.Config.STAGES) do
        realTotalCrystalsNeeded = realTotalCrystalsNeeded + (stageData.cost or 0)
    end

    -- Обновляем конфигурацию, если требуется
    if ECT.Config.TOTAL_CRYSTALS_NEEDED ~= realTotalCrystalsNeeded then
        print("|cFFFFFF00[ECT] Корректировка: общая сумма кристаллов исправлена с " .. 
              ECT.Config.TOTAL_CRYSTALS_NEEDED .. " на " .. realTotalCrystalsNeeded .. "|r")
        ECT.Config.TOTAL_CRYSTALS_NEEDED = realTotalCrystalsNeeded
    end

    -- Рассчитываем прогресс
    local currentProgress = totalSpent + crystalsNow
    local isMaxStage = stageIndex == #ECT.Config.STAGES
    local progressPct = 0

    if isMaxStage then
        currentProgress = totalSpent
        progressPct = 100
    else
        if ECT.Config.TOTAL_CRYSTALS_NEEDED > 0 then
            progressPct = math.floor(currentProgress / ECT.Config.TOTAL_CRYSTALS_NEEDED * 100)
        else
            progressPct = 0
        end
    end

    -- Обновляем информацию о времени сброса
    ECT.MainFrame.statsText:SetText(string.format(
        "Прогресс: %d / %d кристаллов (%d%%)\n" ..
        "Сброс заданий через: %s%s|r\n" ..
        "Местное время: %s → %s (03:00 МСК)",
        currentProgress,
        ECT.Config.TOTAL_CRYSTALS_NEEDED,
        progressPct,
        timerColor,
        timeUntilReset,
        currentTimeStr,
        resetTimeStr
    ))

    ECT.MainFrame.essenceStats:SetText("")
    ECT.MainFrame.honorStats:SetText("")
end

function ECT.TurnInEssences()
    local essenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
    local honorCompleted = ECT_SavedVars.honorQuestCompleted or false
    
    if essenceCompleted then
        print("|cFF00FF00[ECT] Задание 'Испытание Отвагой' выполнено! Иди к Джулии.|r")
    else
        print("|cFFFF0000[ECT] Задание 'Испытание Отвагой' не выполнено!|r")
    end
    
    if honorCompleted then
        print("|cFF00FF00[ECT] Задание 'Испытание Честью' выполнено! Иди к Джулии.|r")
        print("|cFFFFA500[ECT] Прогресс: " .. (ECT_SavedVars.honorCurrent or 0) .. "/" .. (ECT_SavedVars.honorRequired or 500) .. " очков сражения|r")
    else
        print("|cFFFF0000[ECT] Задание 'Испытание Честью' не выполнено!|r")
        print("|cFFFFA500[ECT] Прогресс: " .. (ECT_SavedVars.honorCurrent or 0) .. "/" .. (ECT_SavedVars.honorRequired or 500) .. " очков сражения|r")
    end
    
    return essenceCompleted or honorCompleted
end

function ECT.IsQuestTaken(questID)
    -- Проверяем историю заданий или другие методы
    -- В WoW API нет прямого способа проверить, было ли задание взято и сдано
    
    -- Вместо этого будем использовать флаг в сохраненных данных
    -- Добавим новую переменную для отслеживания взятых заданий
    ECT_SavedVars.takenQuests = ECT_SavedVars.takenQuests or {}
    
    -- Проверяем, было ли задание взято сегодня
    local today = date("%Y-%m-%d")
    if ECT_SavedVars.takenQuests[today] and ECT_SavedVars.takenQuests[today][questID] then
        return true
    end
    
    -- Проверяем активное задание в журнале
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, _, _, qID = GetQuestLogTitle(i)
        if not isHeader and qID and qID == questID then
            -- Задание активно в журнале
            return true
        end
    end
    
    return false
end

-- Функции для сдачи задания
function ECT.TurnInEssences()
    local essenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
    local honorCompleted = ECT_SavedVars.honorQuestCompleted or false -- ДОБАВЛЕНО
    
    if essenceCompleted then
        print("|cFF00FF00[ECT] Задание 'Испытание Отвагой' выполнено! Иди к Джулии.|r")
    else
        print("|cFFFF0000[ECT] Задание 'Испытание Отвагой' не выполнено!|r")
    end
    
    if honorCompleted then -- ДОБАВЛЕНО
        print("|cFF00FF00[ECT] Задание 'Испытание Честью' выполнено! Иди к Джулии.|r")
    else
        print("|cFFFF0000[ECT] Задание 'Испытание Честью' не выполнено!|r")
    end
    
    return essenceCompleted or honorCompleted
end

-- Функции для ручного обновления статуса (для совместимости со старыми командами)
function ECT.IncrementEssenceProgress()
    -- Теперь автоматически проверяем статус задания
    ECT.UpdateQuestStatus()
    print("|cFFFFA500[ECT] Проверка статуса заданий 'Испытание Отвагой' и 'Испытание Честью'|r")
end

-- Функции сброса
function ECT.ResetEssenceProgress()
    ECT_SavedVars.essenceQuestCompleted = false
    ECT_SavedVars.essenceQuestReadyNotified = nil
    ECT_SavedVars.essenceCurrent = 0
    print("|cFF00FF00[ECT] Статус задания 'Испытание Отвагой' сброшен|r")
    if ECT.MainFrame and ECT.MainFrame:IsVisible() then
        ECT.UpdateDisplay()
    end
end

-- ДОБАВЛЕНО: Функция сброса прогресса чести
function ECT.ResetHonorProgress()
    ECT_SavedVars.honorQuestCompleted = false
    ECT_SavedVars.honorQuestReadyNotified = nil
    ECT_SavedVars.honorCurrent = 0
    print("|cFF00FF00[ECT] Статус задания 'Испытание Честью' сброшен|r")
    if ECT.MainFrame and ECT.MainFrame:IsVisible() then
        ECT.UpdateDisplay()
    end
end

-- ДОБАВЛЕНО: Функция сброса всех заданий
function ECT.ResetAllQuests()
    ECT.ResetEssenceProgress()
    ECT.ResetHonorProgress()
    print("|cFF00FF00[ECT] Статус всех заданий сброшен|r")
end

function ECT.CreateMinimapButton()
    if ECTMinimapButton and ECTMinimapButton ~= ECT.MinimapButton then
        ECTMinimapButton:Hide()
        ECTMinimapButton = nil
    end

    local button = CreateFrame("Button", "ECTMinimapButton", Minimap)
    button:SetSize(24, 24)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture("Interface\\Icons\\inv_misc_crystalepic")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local isDragging = false

    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:LockHighlight()
    end)

    button:SetScript("OnDragStop", function(self)
        if not isDragging then return end
        isDragging = false
        self:UnlockHighlight()

        ECT_SavedVars.minimapPos = ECT_SavedVars.minimapPos or {}

        local mx, my = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x = x / scale - mx
        y = y / scale - my

        ECT_SavedVars.minimapPos.angle = math.atan2(y, x)
        ECT_SavedVars.minimapPos.radius = math.min(80, math.sqrt(x * x + y * y))

        ECT.SyncSavedVars()
        ECT.UpdateMinimapPosition()
    end)

    button:SetScript("OnClick", function(self, btn)
        if isDragging then
            isDragging = false
            return
        end

        if btn == "LeftButton" then
            ECT.ToggleMainFrame()
        elseif btn == "RightButton" then
            ECT_SavedVars.minimapPos = { angle = 0, radius = 80 }
            ECT.SyncSavedVars()
            ECT.UpdateMinimapPosition()
            print("|cFF00FF00[ECT] Позиция кнопки сброшена|r")
        end
    end)

    button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:ClearLines()

		GameTooltip:AddLine("Трекер Кристаллов Энергии", 1, 1, 1)
		GameTooltip:AddLine("ЛКМ — открыть окно", 0.9, 0.9, 0.9)
		GameTooltip:AddLine("ЛКМ + перетаскивание — переместить", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("ПКМ — сбросить позицию", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Сброс заданий в 03:00 МСК", 0.8, 1, 0.5)
		GameTooltip:AddLine(" ")

		local stageIndex = ECT_SavedVars.currentStage or 1
		local stage = ECT.Config.STAGES[stageIndex]
		local crystalsNow = ECT.GetCrystalsCount()

		GameTooltip:AddLine("Текущий этап: " .. stage.name, 1, 1, 0.5)
		GameTooltip:AddLine("Кристаллов: " .. crystalsNow, 0.2, 1, 0.2)
		GameTooltip:AddLine(" ")

		-- Добавляем информацию о текущей ауре
		local auraStageIndex, auraId, auraName = ECT.CheckCurrentAura()
		if auraStageIndex then
			local auraStageName = ECT.Config.STAGES[auraStageIndex].name
			GameTooltip:AddLine("Активная категория (аура): " .. auraStageName, 0.2, 1, 0.2)
			if auraStageIndex ~= stageIndex then
				GameTooltip:AddLine("|cFFFF0000Внимание: расхождение с сохраненных данных!|r", 1, 0.3, 0.3)
				GameTooltip:AddLine("Используйте /ect syncaura для синхронизации", 1, 1, 0.5)
			end
		else
			GameTooltip:AddLine("Активная категория: не определена", 1, 0.3, 0.3)
		end
		GameTooltip:AddLine(" ")

		-- ===== Испытание Отвагой =====
		if ECT_SavedVars.essenceQuestCompleted then
			GameTooltip:AddLine("Исп. отвагой — Выполнено", 0, 1, 0)
		elseif ECT_SavedVars.essenceCurrent ~= nil then
			GameTooltip:AddLine(
				string.format(
					"Исп. отвагой — %d/%d",
					ECT_SavedVars.essenceCurrent,
					ECT_SavedVars.essenceRequired or 3
				),
				1, 0.8, 0.4
			)
		else
			GameTooltip:AddLine("Исп. отвагой — не взято", 1, 0.3, 0.3)
		end

		-- ===== Испытание Честью =====
		-- ИСПРАВЛЕНО: Всегда показываем актуальный прогресс
		local honorCurrent = ECT_SavedVars.honorCurrent or 0
		local honorRequired = ECT_SavedVars.honorRequired or 500
		local honorCompleted = ECT_SavedVars.honorQuestCompleted or false
		
		if honorCompleted then
			GameTooltip:AddLine("Исп. честью — Выполнено", 0, 1, 0)
		elseif honorCurrent > 0 then
			GameTooltip:AddLine(
				string.format(
					"Исп. честью — %d/%d очков сражения",
					honorCurrent,
					honorRequired
				),
				0.4, 0.8, 1
			)
		else
			GameTooltip:AddLine(
				string.format(
					"Исп. честью — 0/%d очков сражения",
					honorRequired
				),
				1, 0.3, 0.3
			)
		end

		-- Время
		local resetTimeStr, secondsUntilReset, currentTimeStr = ECT.GetResetTimeFormatted()
		local timeUntilReset = ECT.FormatTime(secondsUntilReset)

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Ваше время: " .. currentTimeStr .. " -> " .. resetTimeStr .. " (03:00 МСК)", 0.8, 0.8, 1)
		GameTooltip:AddLine("Через: " .. timeUntilReset, 0.5, 1, 1)

		GameTooltip:Show()
	end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ECT.MinimapButton = button
    ECT.UpdateMinimapPosition()
end


function ECT.UpdateMinimapPosition()
    if not ECT.MinimapButton then return end
    
    -- Проверяем и инициализируем minimapPos если необходимо
    ECT_SavedVars.minimapPos = ECT_SavedVars.minimapPos or {}
    ECT_SavedVars.minimapPos.angle = ECT_SavedVars.minimapPos.angle or 0
    ECT_SavedVars.minimapPos.radius = ECT_SavedVars.minimapPos.radius or 80
    
    local angle = ECT_SavedVars.minimapPos.angle
    local radius = ECT_SavedVars.minimapPos.radius
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    ECT.MinimapButton:ClearAllPoints()
    ECT.MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ECT.UpdateCrystalsCount()
    local oldCrystals = ECT_SavedVars.crystalsCollected or 0
    
    local currentCrystals = ECT.GetCrystalsCount()

    local totalSoFar = (ECT_SavedVars.crystalsSpent or 0) + currentCrystals
    if (ECT_SavedVars.totalCrystalsEver or 0) < totalSoFar then
        ECT_SavedVars.totalCrystalsEver = totalSoFar
    end

    if currentCrystals > oldCrystals then
        local gained = currentCrystals - oldCrystals
        UIErrorsFrame:AddMessage(
            string.format("|cFF00FF00+%d Кристалл(ов) Энергии|r |cFFFFD100(Всего: %d)|r", gained, currentCrystals),
            1.0, 1.0, 1.0, 1.0, 3.0
        )
        local stageIndex = ECT_SavedVars.currentStage or 1
        local nextStageIndex = stageIndex + 1
        if nextStageIndex <= #ECT.Config.STAGES then
            local nextStage = ECT.Config.STAGES[nextStageIndex]
            local needed = nextStage.cost
            if needed > 0 then
                local remaining = needed - currentCrystals
                if remaining > 0 and remaining <= 10 then
                    print("|cFFFFD100[ECT] Осталось собрать " .. remaining .. " кристаллов для перехода на " .. nextStage.name .. "|r")
                elseif currentCrystals >= needed then
                    print("|cFF00FF00[ECT] Достаточно кристаллов для перехода на " .. nextStage.name .. "! Используйте /ect next после сдачи квестов.|r")
                end
            end
        end
    end

    ECT_SavedVars.crystalsCollected = currentCrystals

    if ECT.MainFrame and ECT.MainFrame:IsVisible() then
        ECT.UpdateDisplay()
    end
end

function ECT.OnInitialize()
    ECT.CreateMainFrame()
    ECT.CreateMinimapButton()
    ECT.CreateBossInfoFrame()
    ECT.UpdateCrystalsCount()
    
    -- Инициализируем время сброса заданий (исправленная версия)
    if not ECT_SavedVars.questResetTime then
        ECT_SavedVars.questResetTime, _ = ECT.GetNextResetTime()
    else
        -- Проверяем, не устарело ли сохраненное время
        local currentTime = time()
        if currentTime >= ECT_SavedVars.questResetTime then
            ECT_SavedVars.questResetTime, _ = ECT.GetNextResetTime()
            ECT.CheckQuestReset() -- Сбрасываем задания если нужно
        end
    end
	
	-- МИГРАЦИЯ ДАННЫХ ЧЕСТИ (для старых персонажей)
    if ECT_SavedVars.honorRequired and ECT_SavedVars.honorRequired <= 10 then
        -- Сохраняем старые значения для сообщения
        local oldCurrent = ECT_SavedVars.honorCurrent or 0
        local oldRequired = ECT_SavedVars.honorRequired
        
        -- Конвертируем победы в очки сражения
        ECT_SavedVars.honorCurrent = oldCurrent * ECT.Config.WIN_POINTS  -- 200 за победу
        ECT_SavedVars.honorRequired = 500  -- принудительно устанавливаем 500
        
        print("|cFFFFD100[ECT] Миграция данных чести:|r")
        print(string.format("|cFFFFA500Старый формат: %d/%d побед|r", oldCurrent, oldRequired))
        print(string.format("|cFF00FF00Новый формат: %d/%d очков сражения|r", 
            ECT_SavedVars.honorCurrent, ECT_SavedVars.honorRequired))
        print("|cFFFFFF00(победа = +200 очков, проигрыш = половина эффективности)|r")
    end
    
    -- Выводим информацию о времени сброса при загрузке
    local resetTimeStr, secondsUntilReset, currentTimeStr = ECT.GetResetTimeFormatted()
    local timeUntilReset = ECT.FormatTime(secondsUntilReset)
    
    print("|cFFFFD100[ECT] Текущее время (ваше): " .. currentTimeStr .. "|r")
    print("|cFFFFD100[ECT] Следующий сброс заданий (03:00 МСК): " .. resetTimeStr .. " (через " .. timeUntilReset .. ")|r")
    
    -- Проверяем текущую ауру при загрузке
    ECT_DelayedCall(2, function()
        ECT.UpdateStageFromAura()
    end)
    
    -- Проверяем статус задания при загрузке
    ECT.UpdateQuestStatus()
    
    local stageIndex = ECT_SavedVars.currentStage or 1
    local crystalsNow = ECT.GetCrystalsCount()
    local essenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
    local essenceCurrent = ECT_SavedVars.essenceCurrent or 0
    local honorCompleted = ECT_SavedVars.honorQuestCompleted or false -- ДОБАВЛЕНО
    local honorCurrent = ECT_SavedVars.honorCurrent or 0 -- ДОБАВЛЕНО
    
    print("|cFFFFD100[Energy Crystals Tracker] загружен|r")
    print("|cFFFFD100Текущий этап: " .. ECT.Config.STAGES[stageIndex].name .. "|r")
    print("|cFF00FF00Кристаллов: " .. crystalsNow .. "|r")
    print(string.format("|cFFFFA500Исп. Отвагой: %s (%d/3)|r", essenceCompleted and "Выполнено" or "Не выполнено", essenceCurrent))
    print(string.format("|cFF0080FFИсп. Честью: %s (%d/3)|r", honorCompleted and "Выполнено" or "Не выполнено", honorCurrent)) -- ДОБАВЛЕНО
    
    print("|cFF00FF00Команды:|r")
    print("  |cFF00FF00/ect|r - открыть окно")
    print("  |cFF00FF00/ect next|r - следующий этап (после сдачи квестов)")
    print("  |cFF00FF00/ect prev|r - предыдущий этап")
    print("  |cFF00FF00/ect stage 6+|r - установить 6+ категорию")
    print("  |cFF00FF00/ect turnin|r - проверить статус заданий (после сдачи квестов)")
    print("  |cFF00FF00/ect checkquests|r - проверить статус заданий")
    print("  |cFF00FF00/ect stats|r - статистика")
    print("  |cFF00FF00/ect boss ВНЕ КАТЕГОРИЙ|r - информация о боссе вне категорий")
    print("  |cFF00FF00/ect reset|r - сбросить прогресс всех заданий")
    print("  |cFF00FF00/ect reset отвага|r - сбросить прогресс 'Испытание Отвагой'")
    print("  |cFF00FF00/ect reset честь|r - сбросить прогресс 'Испытание Честью'")
    print("  |cFF00FF00/ect checkaura|r - проверить текущую ауру категории")
    print("  |cFF00FF00/ect syncaura|r - синхронизировать категорию с аурой")
end

function ECT.ToggleMainFrame()
    if ECT.MainFrame:IsShown() then
        ECT.MainFrame:Hide()
        ECT.HideBossInfo()
    else
        -- Перед показом проверяем текущую ауру
        ECT.UpdateStageFromAura()
        ECT.MainFrame:Show()
        ECT.UpdateDisplay()
    end
end

-- Исправленная функция CheckAutoAdvance
function ECT.CheckAutoAdvance()
    local stageIndex = ECT_SavedVars.currentStage or 1
    local crystalsNow = ECT.GetCrystalsCount()
    local nextStageIndex = stageIndex + 1
    
    if nextStageIndex <= #ECT.Config.STAGES then
        local nextStage = ECT.Config.STAGES[nextStageIndex]
        local needed = nextStage.cost
        
        if needed > 0 and crystalsNow >= needed then
            -- Проверяем, не было ли уже сообщения для этого этапа
            if lastAutoAdvanceStage ~= nextStageIndex or crystalsNow > lastAutoAdvanceCrystals then
                lastAutoAdvanceStage = nextStageIndex
                lastAutoAdvanceCrystals = crystalsNow
                
                print("|cFF00FF00[ECT] Достаточно кристаллов для перехода на " .. nextStage.name .. "!|r")
                print("|cFFFFD100[ECT] Используйте команду: /ect next (после сдачи квестов)|r")
            end
        else
            -- Если кристаллов стало меньше, сбрасываем запомненный этап
            if crystalsNow < lastAutoAdvanceCrystals then
                lastAutoAdvanceStage = nil
                lastAutoAdvanceCrystals = 0
            end
        end
    end
end

-- Создаем фрейм для обработки событий
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA") -- Добавлено для отслеживания изменения аур

-- Создаем отдельный фрейм для отложенных задач
local delayFrame = CreateFrame("Frame")
local delayFunc = nil
local delayTime = 0
local delayElapsed = 0

delayFrame:SetScript("OnUpdate", function(self, elapsed)
    if delayFunc then
        delayElapsed = delayElapsed + elapsed
        if delayElapsed >= delayTime then
            delayFunc()
            delayFunc = nil
            delayTime = 0
            delayElapsed = 0
        end
    end
end)

-- Создаем фрейм для периодической проверки сброса заданий
local resetCheckFrame = CreateFrame("Frame")
resetCheckFrame.lastCheck = 0
resetCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    self.lastCheck = self.lastCheck + elapsed
    if self.lastCheck >= 60 then -- Проверяем каждую минуту
        self.lastCheck = 0
        ECT.CheckQuestReset()
        
        -- Обновляем отображение если окно открыто
        if ECT.MainFrame and ECT.MainFrame:IsVisible() then
            ECT.UpdateDisplay()
        end
    end
end)

-- Создаем фрейм для периодической проверки ауры
local auraCheckFrame = CreateFrame("Frame")
auraCheckFrame.lastCheck = 0
auraCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    self.lastCheck = self.lastCheck + elapsed
    if self.lastCheck >= 1 then -- Проверяем каждую секунду
        self.lastCheck = 0
        ECT.CheckAuraPeriodically()
    end
end)

-- Простая функция задержки
function ECT_DelayedCall(delay, func)
    delayFunc = func
    delayTime = delay
    delayElapsed = 0
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        ECT.OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        -- Проверяем статус задания после полной загрузки персонажа
        ECT_DelayedCall(3, function()
            ECT.UpdateQuestStatus()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Проверяем ауру при входе в мир
        ECT_DelayedCall(2, function()
            ECT.UpdateStageFromAura()
        end)
    elseif event == "BAG_UPDATE" then
        ECT.UpdateCrystalsCount()
        ECT.CheckAutoAdvance()
    -- Добавьте переменную для защиты от частых вызовов
    elseif event == "QUEST_LOG_UPDATE" then
        local currentTime = GetTime()
        if currentTime - lastQuestCheckTime > QUEST_CHECK_DELAY then
            lastQuestCheckTime = currentTime
            ECT.UpdateQuestStatus()
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            -- Проверяем изменение ауры игрока с задержкой
            ECT_DelayedCall(0.5, function()
                ECT.UpdateStageFromAura()
            end)
        end
    end
end)

-- Функция поиска задания по названию
function ECT.FindQuestIdByName(questNamePattern)
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
        if not isHeader and title and questId then
            if string.find(string.lower(title), string.lower(questNamePattern)) then
                return questId
            end
        end
    end
    return nil
end

-- ============================================================================
-- ФУНКЦИИ ДЛЯ ТАЙМЕРА СБРОСА ЕЖЕДНЕВНЫХ ЗАДАНИЙ (ОБЪЕДИНЕННАЯ ВЕРСИЯ)
-- ============================================================================

function ECT.GetNextResetTime()
    -- GetGameTime() возвращает время сервера
    -- На сервере Sirus.su (Москва) это московское время
    
    local serverHour, serverMinute = GetGameTime()
    
    -- Вычисляем текущее время на сервере в секундах от начала суток
    local currentSeconds = serverHour * 3600 + serverMinute * 60
    
    -- Сброс в 03:00 (10800 секунд от начала суток)
    local resetSeconds = 3 * 3600  -- 03:00 = 10800 секунд
    
    local secondsUntilReset
    
    if currentSeconds < resetSeconds then
        -- Если сейчас меньше 03:00, сброс сегодня в 03:00
        secondsUntilReset = resetSeconds - currentSeconds
    else
        -- Если сейчас уже после 03:00, сброс завтра в 03:00
        secondsUntilReset = (24 * 3600 - currentSeconds) + resetSeconds
    end
    
    -- Преобразуем в абсолютное время (секунды с эпохи)
    local currentTime = time()
    local nextResetTime = currentTime + secondsUntilReset
    
    return nextResetTime, secondsUntilReset
end

function ECT.GetResetTimeFormatted()
    local nextResetTime, secondsUntilReset = ECT.GetNextResetTime()
    
    -- Получаем серверное время для отладки
    local serverHour, serverMinute = GetGameTime()
    local serverTimeStr = string.format("%02d:%02d", serverHour, serverMinute)
    
    -- Время сброса в локальном времени игрока
    local resetDate = date("*t", nextResetTime)
    local resetHour = resetDate.hour
    local resetMinute = resetDate.min
    local resetTimeStr = string.format("%02d:%02d", resetHour, resetMinute)
    
    -- Текущее локальное время игрока
    local currentDate = date("*t")
    local currentHour = currentDate.hour
    local currentMinute = currentDate.min
    local currentTimeStr = string.format("%02d:%02d", currentHour, currentMinute)
    
    -- Отладочная информация
    local debugInfo = string.format("Сервер (МСК): %s → %02d:%02d", 
        serverTimeStr, serverHour, serverMinute)
    
    return resetTimeStr, secondsUntilReset, currentTimeStr, debugInfo
end

-- Функция форматирования времени
function ECT.FormatTime(seconds)
    if seconds <= 0 then
        return "00:00:00"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    -- Для большей точности
    if hours > 0 then
        return string.format("%d ч. %02d м.", hours, minutes)
    elseif minutes > 0 then
        return string.format("%d м. %02d с.", minutes, secs)
    else
        return string.format("%d с.", secs)
    end
end

function ECT.ShouldShowBossRequirementText(nextStage)
    if not nextStage then
        return false
    end
    
    -- Проверяем, является ли следующий этап этапом с боссом
    return ECT.IsBossStage(nextStage.name)
end

-- Функция проверки необходимости сброса заданий (упрощенная)
function ECT.CheckQuestReset()
    local serverHour, serverMinute = GetGameTime()
    serverHour = serverHour or 0
    serverMinute = serverMinute or 0
    
    -- Проверяем, не наступило ли время сброса (03:00)
    local shouldReset = false
    
    if serverHour >= 3 then
        -- Если сейчас 3:00 или больше
        if not ECT_SavedVars.lastResetCheck then
            shouldReset = true
        else
            -- Проверяем, был ли уже сброс сегодня
            local lastCheckHour = ECT_SavedVars.lastResetCheck.hour or 0
            if lastCheckHour < 3 and serverHour >= 3 then
                shouldReset = true
            end
        end
    end
    
    if shouldReset then
        -- Сбрасываем прогресс заданий
        ECT_SavedVars.essenceQuestCompleted = false
        ECT_SavedVars.essenceQuestReadyNotified = nil
        ECT_SavedVars.essenceCurrent = 0
        
        ECT_SavedVars.honorQuestCompleted = false
        ECT_SavedVars.honorQuestReadyNotified = nil
        ECT_SavedVars.honorCurrent = 0
        
        -- Сохраняем время проверки
        ECT_SavedVars.lastResetCheck = {
            hour = serverHour,
            minute = serverMinute,
            gameTime = GetTime()
        }
        
        -- Получаем информацию о следующем сбросе
        local resetTimeStr, secondsUntilReset, currentTimeStr, debugInfo = ECT.GetResetTimeFormatted()
        local timeUntilReset = ECT.FormatTime(secondsUntilReset)
        
        print("|cFF00FF00[ECT] Ежедневные задания сброшены! (03:00 МСК)|r")
        print("|cFF00FF00[ECT] Текущее время: " .. currentTimeStr .. "|r")
        print("|cFF00FF00[ECT] Следующий сброс: " .. resetTimeStr .. " (через " .. timeUntilReset .. ")|r")
        
        -- Обновляем отображение
        if ECT.MainFrame and ECT.MainFrame:IsVisible() then
            ECT.UpdateDisplay()
        end
        
        return true
    end
    
    -- Сохраняем время последней проверки
    ECT_SavedVars.lastResetCheck = {
        hour = serverHour,
        minute = serverMinute,
        gameTime = GetTime()
    }
    
    return false
end

-- Объединенные слэш-команды для проверки времени сброса
SLASH_ECTRESETTIME1 = "/ecttime"
SLASH_ECTRESETTIME2 = "/ectresetcheck"
SlashCmdList["ECTRESETTIME"] = function()
    local resetTimeStr, secondsUntilReset, currentTimeStr, debugInfo = ECT.GetResetTimeFormatted()
    local timeUntilReset = ECT.FormatTime(secondsUntilReset)
    
    print("|cFFFFD100=== Время сброса ежедневных заданий (03:00 МСК) ===|r")
    print("|cFF00FF00Ваше время:|r " .. currentTimeStr)
    print("|cFF00FF00Следующий сброс:|r " .. resetTimeStr)
    print("|cFF00FF00Осталось:|r " .. timeUntilReset)
    print("|cFFFFA500" .. debugInfo .. "|r")
    
    -- Проверяем, не пора ли сбросить задания
    local wasReset = ECT.CheckQuestReset()
    if not wasReset then
        print("|cFF00FF00[ECT] Сброс еще не наступил.|r")
    end
end

SLASH_ECT1 = "/ect"
SLASH_ECT2 = "/кристаллы"
SlashCmdList["ECT"] = function(msg)
    local input = strtrim(msg)
    local command, arg = strsplit(" ", input, 2)
    command = strlower(command)
    if command == "" or command == "show" or command == "открыть" then
        ECT.ToggleMainFrame()
    elseif command == "setstage" or command == "stage" then
        local inputStage = strtrim(arg or "")
        if inputStage == "" then
            print("|cFFFF0000Укажите категорию: /ect stage 6, /ect stage 6+, /ect stage ВНЕ КАТЕГОРИЙ и т.д.|r")
            return
        end
        local searchName = inputStage
        if not string.find(inputStage, "ВНЕ КАТЕГОРИЙ") then
            searchName = inputStage .. " Категория"
        end
        local foundStage = nil
        for i, stage in ipairs(ECT.Config.STAGES) do
            if stage.name == searchName then
                foundStage = i
                break
            end
        end
        if foundStage then
            ECT_SavedVars.currentStage = foundStage
            local spent = 0
            for j = 1, foundStage do
                spent = spent + ECT.Config.STAGES[j].cost
            end
            ECT_SavedVars.crystalsSpent = spent
            local currentCrystals = ECT.GetCrystalsCount()
            local totalNow = spent + currentCrystals
            if (ECT_SavedVars.totalCrystalsEver or 0) < totalNow then
                ECT_SavedVars.totalCrystalsEver = totalNow
            end
            ECT.SyncSavedVars()
            if ECT.MainFrame and ECT.MainFrame:IsVisible() then
                ECT.UpdateDisplay()
            end
            print("|cFF00FF00Этап установлен:|r " .. ECT.Config.STAGES[foundStage].name)
            print("|cFFFFD100Потрачено кристаллов: " .. spent .. "|r")
            print("|cFFFFD100Данные сохранены! После перезахода прогресс останется.|r")
        else
            print("|cFFFF0000Категория не найдена. Возможные форматы:|r")
            print("  /ect stage 6     (6 Категория)")
            print("  /ect stage 6+    (6+ Категория)")
            print("  /ect stage 6++   (6++ Категория)")
            print("  /ect stage 5     (5 Категория)")
            print("  /ect stage 1++++ (1++++ Категория)")
            print("  /ect stage ВНЕ КАТЕГОРИЙ")
            print("  /ect stage ВНЕ КАТЕГОРИЙ+")
        end
    elseif command == "next" or command == "следующий" then
        if ECT.AdvanceToNextStage() then
            print("|cFF00FF00[ECT] Используйте эту команду после сдачи квестов Джулии|r")
        end
    elseif command == "prev" or command == "предыдущий" or command == "назад" then
        if ECT.ReturnToPreviousStage() then
            print("|cFF00FF00[ECT] Возврат на предыдущий этап выполнен|r")
        end
    elseif command == "testsound" or command == "тестзвука" then
        local soundType = strtrim(arg or "quest")
        soundType = strlower(soundType)
        
        if soundType == "quest" or soundType == "задание" then
            PlaySound(619, "Master") -- Звук QUESTCOMPLETED
            print("|cFF00FF00[ECT] Тест: воспроизведен стандартный звук выполнения задания|r")
        elseif soundType == "honor" or soundType == "честь" then
            local soundPath = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\honor.mp3"
            PlaySoundFile(soundPath, "Master")
            print("|cFF00FF00[ECT] Тест: воспроизведен звук honor.mp3|r")
        elseif soundType == "essence" or soundType == "отвага" then
            local soundPath = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\essence.mp3"
            PlaySoundFile(soundPath, "Master")
            print("|cFF00FF00[ECT] Тест: воспроизведен звук essence.mp3|r")
        else
            print("|cFFFF0000[ECT] Используйте:|r")
            print("|cFF00FF00/ect testsound quest|r - тест стандартного звука")
            print("|cFF00FF00/ect testsound honor|r - тест звука чести")
            print("|cFF00FF00/ect testsound essence|r - тест звука отваги")
        end
    elseif command == "turnin" or command == "сдать" then
        if ECT.TurnInEssences() then
            print("|cFF00FF00[ECT] Используйте эту команду после сдачи квестов Джулии|r")
        end
    elseif command == "addessence" or command == "добавитьэссенцию" then
        ECT.IncrementEssenceProgress()
    elseif command == "checkquests" or command == "проверитьзадания" then
        ECT.UpdateQuestStatus()
        print("|cFF00FF00[ECT] Проверка статуса заданий выполнена|r")
    elseif command == "findquest" or command == "найтизадание" then
		local searchText = strtrim(arg or "очков сражения")
		ECT.FindQuestByObjectiveText(searchText)
    elseif command == "allquests" or command == "всезадания" then
        ECT.ShowAllQuests()
    elseif command == "setquestid" or command == "установитьид" then
        local newId = tonumber(arg)
        if newId then
            ECT.Config.ESSENCE_QUEST_ID = newId
            print("|cFF00FF00[ECT] ID задания установлен: " .. newId .. "|r")
            ECT.UpdateQuestStatus()
        else
            print("|cFFFF0000[ECT] Укажите числовой ID: /ect setquestid 12345|r")
        end
    elseif command == "stats" or command == "статистика" then
        local spent = ECT_SavedVars.crystalsSpent or 0
        local crystalsNow = ECT.GetCrystalsCount()
        local essenceCompleted = ECT_SavedVars.essenceQuestCompleted or false
        local honorCompleted = ECT_SavedVars.honorQuestCompleted or false -- ДОБАВЛЕНО
        local totalCrystals = ECT_SavedVars.totalCrystalsEver or (spent + crystalsNow)
        local isMaxStage = (ECT_SavedVars.currentStage or 1) == #ECT.Config.STAGES
        local progress = spent + crystalsNow
        
        if isMaxStage then
            progress = ECT.Config.TOTAL_CRYSTALS_NEEDED
            pct = 100
        else
            pct = math.floor((progress / ECT.Config.TOTAL_CRYSTALS_NEEDED) * 100)
        end
        
        print("|cFFFFD100=== Статистика ===|r")
        print(string.format("Текущий этап: |cFF00FF00%s|r", ECT.Config.STAGES[ECT_SavedVars.currentStage or 1].name))
        print(string.format("Кристаллов сейчас: |cFF00FF00%d|r | Потрачено: |cFFFFA500%d|r", crystalsNow, spent))
        print(string.format("Исп. Отвагой: %s (%d/3)", essenceCompleted and "|cFF00FF00Выполнено|r" or "|cFFFF0000Не выполнено|r", ECT_SavedVars.essenceCurrent or 0))
        print(string.format("Исп. Честью: %s (%d/500)", honorCompleted and "|cFF00FF00Выполнено|r" or "|cFFFF0000Не выполнено|r", ECT_SavedVars.honorCurrent or 0))
        print(string.format("Общий прогресс: |cFFFFD100%d/%d|r (|cFF00FF00%d%%|r)", progress, ECT.Config.TOTAL_CRYSTALS_NEEDED, pct))
    elseif command == "boss" or command == "босс" then
        local inputStage = strtrim(arg or "")
        if inputStage == "" then
            print("|cFFFF0000Укажите этап: /ect boss 5 или /ect boss ВНЕ КАТЕГОРИЙ|r")
            return
        end
        local searchName = inputStage
        if not string.find(inputStage, "ВНЕ КАТЕГОРИЙ") then
            searchName = inputStage .. " Категория"
        end
        ECT.ShowBossInfo(searchName)
    elseif command == "reset" or command == "сброс" then
        local resetType = strtrim(arg or "все")
        resetType = strlower(resetType)
        
        if resetType == "все" or resetType == "all" then
            ECT.ResetAllQuests()
        elseif resetType == "отвага" or resetType == "essence" then
            ECT.ResetEssenceProgress()
        elseif resetType == "честь" or resetType == "honor" then
            ECT.ResetHonorProgress()
        else
            print("|cFFFF0000[ECT] Неизвестный тип сброса. Используйте:|r")
            print("  |cFF00FF00/ect reset все|r - сбросить все задания")
            print("  |cFF00FF00/ect reset отвага|r - сбросить 'Испытание Отвагой'")
            print("  |cFF00FF00/ect reset честь|r - сбросить 'Испытание Честью'")
        end
    elseif command == "checknow" or command == "проверитьсейчас" then
        ECT.UpdateQuestStatus()
    elseif command == "resettimer" or command == "сброситьтаймер" then
        ECT_SavedVars.questResetTime = nil
        ECT_SavedVars.nextResetCheckTime = nil
        ECT.CheckQuestReset()
        print("|cFF00FF00[ECT] Таймер сброса заданий обновлен|r")
		
	-- В обработчике слэш-команд добавьте:
	elseif command == "debugaura" or command == "отладкаауры" then
		ECT.DebugAuras()

    elseif command == "checkaura" or command == "проверитьауру" then
        local stageIndex, auraId, auraName = ECT.CheckCurrentAura()
        if stageIndex then
            local stageName = ECT.Config.STAGES[stageIndex].name
            print(string.format("|cFF00FF00[ECT] Текущая категория (аура): %s|r", stageName))
            print(string.format("|cFFFFD100[ECT] ID ауры: %d (%s)|r", auraId, auraName or "Без названия"))
            print(string.format("|cFFFFA500[ECT] Этап в сохраненных данных: %s|r", 
                ECT.Config.STAGES[ECT_SavedVars.currentStage or 1].name))
            
            -- Предлагаем обновить если есть расхождение
            if stageIndex ~= (ECT_SavedVars.currentStage or 1) then
                print("|cFFFFFF00[ECT] Обнаружено расхождение! Используйте /ect syncaura для синхронизации|r")
            end
        else
            print("|cFFFF0000[ECT] Не найдена аура категории на игроке|r")
            print(string.format("|cFFFFD100[ECT] Текущая категория в сохраненных данных: %s|r", 
                ECT.Config.STAGES[ECT_SavedVars.currentStage or 1].name))
        end
    elseif command == "syncaura" or command == "синхронизировать" then
        local changed = ECT.UpdateStageFromAura()
        if changed then
            print("|cFF00FF00[ECT] Категория успешно синхронизирована|r")
        else
            print("|cFFFFFF00[ECT] Категория уже актуальна или не найдена аура|r")
        end
	elseif command == "checksound" or command == "проверитьзвук" then
        ECT.CheckSoundFiles()
		
	elseif command == "debugquests" or command == "диагностика" then
        ECT.DebugFindHonorQuest()
	
	elseif command == "forcecheck" or command == "принудительнаяпроверка" then
		local honorCurrent, honorRequired, honorCompleted = ECT.ForceCheckHonorQuest()
		print(string.format("|cFF00FF00[ECT] Испытание Честью: %d/%d очков сражения (%s)|r", 
			honorCurrent, honorRequired, honorCompleted and "Выполнено" or "В процессе"))
    
    -- Также проверяем Испытание Отвагой
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
        
        if not isHeader and title then
            local titleLower = string.lower(title)
            if string.find(titleLower, "испытание") and string.find(titleLower, "отвагой") then
                print(string.format("|cFF00FF00[ECT] Найдено задание: %s|r", title))
            end
        end
    end
	
    elseif command == "help" or command == "помощь" then
        print("|cFFFFD100=== Energy Crystals Tracker ===|r")
        print("|cFF00FF00/ect|r — открыть окно")
        print("|cFF00FF00/ect stats|r — показать статистику")
        print("|cFF00FF00/ect next|r — перейти на следующий этап (после сдачи квестов)")
        print("|cFF00FF00/ect prev|r — вернуться на предыдущий этап")
        print("|cFF00FF00/ect turnin|r — проверить статус заданий (после сдачи квестов)")
        print("|cFF00FF00/ect checkquests|r — проверить статус заданий")
        print("|cFF00FF00/ect reset все|r — сбросить прогресс всех заданий")
        print("|cFF00FF00/ect reset отвага|r — сбросить прогресс 'Испытание Отвагой'")
        print("|cFF00FF00/ect reset честь|r — сбросить прогресс 'Испытание Честью'")
        print("|cFF00FF00/ect stage 6|r — установить 6 Категорию")
        print("|cFF00FF00/ect stage 6+|r — установить 6+ Категорию")
        print("|cFF00FF00/ect stage ВНЕ КАТЕГОРИЙ+|r — для этапов вне категорий")
        print("|cFF00FF00/ect boss 6|r — информация о боссе 6 категории")
        print("|cFF00FF00/ect boss ВНЕ КАТЕГОРИЙ|r — информация о боссе вне категорий")
        print("|cFF00FF00/ect checkaura|r — проверить текущую ауру категории")
        print("|cFF00FF00/ect syncaura|r — синхронизировать категорию с аурой")
        print("|cFFA500Статус заданий проверяется автоматически при:|r")
        print("  • Загрузке аддона")
        print("  • Входе в игру")
        print("  • Смене локации")
        print("  • Обновлении журнала заданий")
        print("|cFF00FF00Важно:|r Используйте команды |cFFFFD100/ect next|r после сдачи квестов Джулии")
    else
        ECT.ToggleMainFrame()
    end
end