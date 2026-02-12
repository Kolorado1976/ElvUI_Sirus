-- Fix for missing Blizzard APIs in older WoW versions
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "ElvUI" then
        -- Fix for C_GlobalStorageSecure missing
        if C_GlobalStorageSecure == nil then
            C_GlobalStorageSecure = {
                GetPlayerInfo = function(unit, infoType)
                    if infoType == "playtime" then
                        return 0, 0, 0 -- total, level, rested
                    end
                    return nil
                end
            }
        end
        
        -- Fix for C_PlayerInfo.GetVar missing (used by MoneyFrame)
        if C_PlayerInfo and type(C_PlayerInfo.GetVar) ~= "function" then
            C_PlayerInfo.GetVar = function(varName)
                -- Mock implementation for MoneyFrame
                if varName == "PLAYER_MONEY" then
                    return GetMoney() -- Return actual player money
                end
                return nil
            end
        elseif C_PlayerInfo == nil then
            C_PlayerInfo = {
                GetVar = function(varName)
                    if varName == "PLAYER_MONEY" then
                        return GetMoney()
                    end
                    return nil
                end
            }
        end
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)