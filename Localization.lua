-- PL GuildBank Classic Locale
-- Please use the Localization App on WoWAce to Update this

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
L["Character %s:"] = true
L["Guild capital:"] = true
L["Money available on the selected bank character."] = true
L["Cumulated capital of all configured bank characters."] = true
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
L["The bank character must install this AddOn and accept the state of being a guild-bank character!\n \nThis is required because the character's inventory, bank \nand money will be synced with all guild-members which are using this AddOn!"] = true
L["Accept"] = true
L["Decline"] = true
L["Decide later"] = true
L["%s has configured your char as guild-bank character!\nDo you accept this state of the character?\n \nNote: All your inventory, bank and money will be shared across the guild!"] = true
L["Purchaseable"] = true
L["unknown"] = true

L["via direct trade"] = true
L["as %s"] = true
L["for %s"] = true
L["( %s ago )"] = true 
L[" x %d"] = true
L["%s deposited %s"] = true
L["%s |cffff2020withdrew|r %s"] = true
L["via mail"] = true
L["via COD"] = true
L["via auction"] = true
L["via loot"] = true
L["via (unkown)"] = true
L["(est. value: %s)"] = true