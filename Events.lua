local _, PLGuildBankClassic = ...

local Events = PLGuildBankClassic:NewModule("Events", "AceEvent-3.0")
Events.Fire = LibStub("CallbackHandler-1.0"):New(Events, "Register", "Unregister", "UnregisterAll").Fire

local ItemCache = LibStub("LibItemCache-2.0")

PLGBC_EVENT_BANKCHAR_ENTERED_WORLD = "PLGBC_EVENT_BANKCHAR_ENTERED_WORLD"
PLGBC_EVENT_BANKCHAR_ADDED = "PLGBC_EVENT_BANKCHAR_ADDED"
PLGBC_EVENT_BANKCHAR_UPDATED = "PLGBC_EVENT_BANKCHAR_UPDATED"
PLGBC_EVENT_BANKCHAR_REMOVED = "PLGBC_EVENT_BANKCHAR_REMOVED"

PLGBC_EVENT_BANKCHAR_SLOT_SELECTED = "PLGBC_EVENT_BANKCHAR_SLOT_SELECTED"
PLGBC_EVENT_BANKCHAR_MONEYCHANGED = "PLGBC_EVENT_BANKCHAR_MONEYCHANGED"
PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED = "PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED"

-- data storage
local slots = {}

function Events:OnEnable()
	self.atBank = false

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("BAG_NEW_ITEMS_UPDATED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	self:RegisterEvent("BANKFRAME_OPENED")
	self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "GenericEvent")

    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_TRADE_MONEY", "PLAYER_MONEY");
    self:RegisterEvent("TRADE_MONEY_CHANGED", "PLAYER_MONEY")
    self:RegisterEvent("SEND_MAIL_MONEY_CHANGED", "PLAYER_MONEY")
    self:RegisterEvent("SEND_MAIL_COD_CHANGED", "PLAYER_MONEY")
    self:RegisterEvent("TRIAL_STATUS_UPDATE", "PLAYER_MONEY")

    self:RegisterEvent("MAIL_SHOW")
end

function Events:GenericEvent(event, ...)
	self:Fire(event, ...)
end

-- events
function Events:BAG_UPDATE(event, bag)
    if PLGuildBankClassic:IsGuildBankChar() then
	    PLGuildBankClassic:UpdateInventoryVersion()
    end
end

function Events:BAG_NEW_ITEMS_UPDATED(event)
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:UpdateInventoryVersion()
    end
end

function Events:PLAYERBANKSLOTS_CHANGED()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:UpdateInventoryVersion()
    end
end

function Events:BANKFRAME_OPENED()
    if PLGuildBankClassic:IsGuildBankChar() then
        self.atBank = true
        ItemCache.AtBank = true
        
        self:Fire("BANK_OPENED")
    end
end

function Events:BANKFRAME_CLOSED()
    if PLGuildBankClassic:IsGuildBankChar() then
        self.atBank = false
        ItemCache.AtBank = false
        self:Fire("BANK_CLOSED")

        PLGuildBankClassic:UpdateInventoryVersion()
    end
end

function Events:PLAYER_MONEY()
    PLGuildBankClassic:UpdatePlayerMoney()
end

