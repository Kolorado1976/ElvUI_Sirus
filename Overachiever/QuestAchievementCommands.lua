-- QuestAchievementCommands.lua
-- Дополнительные команды для управления базой данных

SLASH_OVERACHIEVER_FINDQUEST1 = "/oafindquest"
SlashCmdList["OVERACHIEVER_FINDQUEST"] = function(msg)
    local questID = tonumber(msg)
    if questID then
        local achievements = Overachiever.GetAchievementsForQuest(questID)
        if achievements then
            chatprint("Квест " .. questID .. " связан с достижениями:")
            for _, ach in ipairs(achievements) do
                local link = GetAchievementLink(ach.id)
                chatprint("  - " .. link .. " (" .. ach.name .. ")")
            end
        else
            chatprint("Квест " .. questID .. " не связан с достижениями.")
        end
    else
        chatprint("Использование: /oafindquest <ID квеста>")
    end
end

SLASH_OVERACHIEVER_QUESTSFORACH1 = "/oaquestsforach"
SlashCmdList["OVERACHIEVER_QUESTSFORACH"] = function(msg)
    local achID = tonumber(msg)
    if achID then
        local _, achName = GetAchievementInfo(achID)
        if achName then
            chatprint("Поиск квестов для достижения: " .. GetAchievementLink(achID))
            
            -- Простой поиск по сохраненной базе данных
            local foundQuests = {}
            for questID, achList in pairs(Overachiever.QuestAchievementDB or {}) do
                for _, achInfo in ipairs(achList) do
                    if achInfo.id == achID then
                        table.insert(foundQuests, questID)
                    end
                end
            end
            
            if #foundQuests > 0 then
                chatprint("Найдены квесты: " .. table.concat(foundQuests, ", "))
            else
                chatprint("Квесты не найдены в базе данных.")
            end
        else
            chatprint("Неверный ID достижения.")
        end
    else
        chatprint("Использование: /oaquestsforach <ID достижения>")
    end
end