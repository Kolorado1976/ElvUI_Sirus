local E = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local L = E.Libs.ACL:NewLocale("ElvUI", "enUS", true, true)
if not L then return end
L["common"] = true
L["commondesc"] = true
L["onorof"] = true
L["onorofdesc"] = true
L["Reflected"] = true
L["Resisted"] = true