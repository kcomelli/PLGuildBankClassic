local _, PLGuildBankClassic = ...

local Events = PLGuildBankClassic:NewModule("Events", "AceEvent-3.0")
Events.Fire = LibStub("CallbackHandler-1.0"):New(Events, "Register", "Unregister", "UnregisterAll").Fire

local ItemCache = LibStub("LibItemCache-2.0")

-- data storage
local slots = {}

function Events:OnEnable()
	self.firstVisit = true
	self.atBank = false

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("BAG_NEW_ITEMS_UPDATED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	self:RegisterEvent("BANKFRAME_OPENED")
	self:RegisterEvent("BANKFRAME_CLOSED")
	self:RegisterEvent("ITEM_LOCK_CHANGED", "GenericEvent")

	--self:UpdateBagSize(BACKPACK_CONTAINER)
	--self:UpdateItems(BACKPACK_CONTAINER)
end

function Events:GenericEvent(event, ...)
	self:Fire(event, ...)
end



-- events
function Events:BAG_UPDATE(event, bag)
    if PLGuildBankClassic:IsGuildBankChar() then
	    --self:UpdateBagSizes()
        --self:UpdateItems(bag)
    end
end

function Events:BAG_NEW_ITEMS_UPDATED(event)
    if PLGuildBankClassic:IsGuildBankChar() then
        --for bag = 0, NUM_BAG_SLOTS do
        --	self:UpdateItems(bag)
        --end
    end
end

function Events:PLAYERBANKSLOTS_CHANGED()
    if PLGuildBankClassic:IsGuildBankChar() then
        --self:UpdateBagSizes()
        --self:UpdateItems(BANK_CONTAINER)
    end
end

function Events:BANKFRAME_OPENED()
    if PLGuildBankClassic:IsGuildBankChar() then
        self.atBank = true
        ItemCache.AtBank = true

        --if self.firstVisit then
        --	self.firstVisit = nil

        --	self:UpdateBagSize(BANK_CONTAINER)
        --	self:UpdateBagSizes()
        --end

        self:Fire("BANK_OPENED")
    end
end

function Events:BANKFRAME_CLOSED()
    if PLGuildBankClassic:IsGuildBankChar() then
        self.atBank = false
        ItemCache.AtBank = false
        self:Fire("BANK_CLOSED")
    end
end

function Events:BAG_UPDATE_COOLDOWN()
    if PLGuildBankClassic:IsGuildBankChar() then
        --self:UpdateCooldowns(BACKPACK_CONTAINER)

        --for bag = 1, NUM_BAG_SLOTS do
        --	self:UpdateCooldowns(bag)
        --end
    end
end