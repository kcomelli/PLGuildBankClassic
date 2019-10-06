-- PL GuildBank Classic Locale
-- Please use the Localization App on WoWAce to Update this
-- http://www.wowace.com/projects/inventorian/localization/

local debug = false
--[===[@debug@
debug = true
--@end-debug@]===]

-------------------------------------------------------------------------------
-- the constants for the mod (non localized)
-------------------------------------------------------------------------------

PLGBCLASSIC_CHAT_RED = "|cFFFF0000";
PLGBCLASSIC_CHAT_GREEN = "|cFF00FF00";
PLGBCLASSIC_CHAT_BLUE = "|cFF0000FF";
PLGBCLASSIC_CHAT_YELLOW = "|cFFFFFF00";
PLGBCLASSIC_CHAT_WHITE = "|cFFFFFFFF";
PLGBCLASSIC_CHAT_END = "|r";

local L = LibStub("AceLocale-3.0"):NewLocale("PLGuildBankClassic", "enUS", true, debug)

L["Save"] = true
L["Cancel"] = true
L["%s's Guild Bank"] = true
L["Available money"] = true
L["You are not in a guild!"] = true 
L["Addon requires bank-character configuration\nwhich can only be done by rank '%s' or higher!"] = true;
L["Bank items"] = true
L["Bank logs"] = true
L["Guild info"] = true
L["Configuration"] = true
L["Select min. guild rank for bank-alt management"] = true
L["Currently there are no guild bank-alt's configured.\nPlease use the right + button to add a new character."] = true
L["Add a new bank character"] = true
L["Add new bank character"] = true
L["Edit bank character"] = true
L["Name of the bank char (must be member of your guild)"] = true
L["Add a short description (e.g. Consumables or Professions)"] = true
L["Select an icon to use for the tab"] = true
L["unkown-player"] = true
L["Bank: %s\nChar: %s"] = true
L["Common"] = true
L["No cached or received data found for this character.\nIf you are the owner of the character, log on and visit the bank!\nIf not, then you will receive bank information as soon as the ownser visited the bank!"] = true
 