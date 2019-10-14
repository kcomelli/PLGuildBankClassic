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

PLGBC_MAILBOX_OPENED = "PLGBC_MAILBOX_OPENED"
PLGBC_MAILBOX_CLOSED = "PLGBC_MAILBOX_CLOSED"

PLGBC_RECEVIED_ITEM = "PLGBC_RECEVIED_ITEM"
PLGBC_GUILD_LOG_UPDATED = "PLGBC_GUILD_LOG_UPDATED"

-- data storage
local slots = {}

function Events:OnEnable()
    self.atBank = false
    self.atMailbox = false
    self.atVendor = false
    self.atTrade = false
    self.atAuctionHouse = false

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
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    self:RegisterEvent("CLOSE_INBOX_ITEM")

    self:RegisterEvent("CHAT_MSG_LOOT")

    self:RegisterEvent("AUCTION_HOUSE_SHOW")
    self:RegisterEvent("AUCTION_HOUSE_CLOSED")
    
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

function Events:MAIL_SHOW()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("MAIL_SHOW: fireing at mailbox event")
        self.atMailbox = true
        self.lastMailIndexClosed = 0
        self:Fire("PLGBC_MAILBOX_OPENED")
    end
end

function Events:MAIL_CLOSED()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("MAIL_CLOSED: fireing mailbox closed event")
        self.atMailbox = false
        self:Fire("PLGBC_MAILBOX_CLOSED")
    end
end

function Events:PLAYER_LEAVING_WORLD()
    if PLGuildBankClassic:IsGuildBankChar() and self.atMailbox then
        PLGuildBankClassic:debug("PLAYER_LEAVING_WORLD: fireing mailbox closed event")
        self.atMailbox = false
        self:Fire("PLGBC_MAILBOX_CLOSED")
    end
end

function Events:MAIL_INBOX_UPDATE()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:ScanMailbox()
    end
end

function Events:CLOSE_INBOX_ITEM(event, mailIndex)
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("CLOSE_INBOX_ITEM: index " .. tostring(mailIndex))
        self.lastMailIndexClosed = mailIndex
        self:Fire("PLGBC_MAILBOX_ITEM_CLOSED", mailIndex)
    end
end

function Events:CHAT_MSG_LOOT(event, lootstring, arg2, arg3, arg4, player)
    --PLGuildBankClassic:debug("CHAT_MSG_LOOT: lootstring: " .. (lootstring or "na"))
    PLGuildBankClassic:debug("CHAT_MSG_LOOT: player: " .. (player or "na"))

    local itemLink = string.match(lootstring,"|%x+|Hitem:.-|h.-|h|r")
    local itemId, itemQuantity
    if itemLink then
        itemId = string.match(itemLink, "Hitem:(%d+):")  
        itemQuantity = tonumber(string.match(lootstring, "x(%d+).") or "1")

        PLGuildBankClassic:debug("CHAT_MSG_LOOT: looted itemId " .. itemId .. " with quantity " .. tostring(itemQuantity))
    end

    if itemLink and PLGuildBankClassic:IsGuildBankChar() and UnitName("player") == player then
        PLGuildBankClassic:debug("CHAT_MSG_LOOT: BY ME")
        self:Fire("PLGBC_RECEVIED_ITEM", player, tonumber(itemId), itemQuantity)
    end
end

function Events:AUCTION_HOUSE_SHOW()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("AUCTION_HOUSE_SHOW: ah show event")
        self.atAuctionHouse = true
        self:Fire("PLGBC_AUCTION_HOUSE_SHOW")
    end
end


function Events:AUCTION_HOUSE_CLOSED()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("AUCTION_HOUSE_CLOSED: ah closed event")
        self.atAuctionHouse = false
        self:Fire("PLGBC_AUCTION_HOUSE_CLOSED")
    end
end
