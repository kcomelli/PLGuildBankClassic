local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

local GuildBankContentFrame = CreateFrame("Frame")
local GuildBankContentFrame_MT = {__index = GuildBankContentFrame}

local Events = PLGuildBankClassic:GetModule("Events")

PLGuildBankClassic.GuildBankContentFrame = {}
PLGuildBankClassic.GuildBankContentFrame.defaults = {}
PLGuildBankClassic.GuildBankContentFrame.prototype = GuildBankContentFrame
function PLGuildBankClassic.GuildBankContentFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabContents", parent, "PLGuildBankFrameTabContents"), GuildBankContentFrame_MT)

    -- settings
 
    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabContents")

    return frame
end 

function GuildBankContentFrame:OnShow()
end

function GuildBankContentFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildBankContentFrame:Update(characterData)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

    local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)
    if cacheOwnerInfo.class then

        local class = characterData.class
        if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
        local player = characterData.name
            
        self.configDescriptionLabel.Text:SetText(characterData.description)
        self.configCharLabel.Text:SetText("- " .. (class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player))

        self.configDescriptionLabel:SetWidth(self.configDescriptionLabel.Text:GetWidth())
        self.configCharLabel:SetWidth(self.configCharLabel.Text:GetWidth())
        
        PLGuildBankClassic:debug("BAG DATA")
		for _, bagId in pairs(PLGBC_BAG_CONFIG) do
			local info = ItemCache:GetBagInfo(cacheOwnerInfo.name, bagId)
			for slot = 1, (info.count or 0) do
				local id = ItemCache:GetItemID(cacheOwnerInfo.name, bagId, slot)
				local itemInfo = ItemCache:GetItemInfo(cacheOwnerInfo.name, bagId, slot)

				PLGuildBankClassic:debug("   BAG#" .. tostring(bagId) .. " " .. tostring(itemInfo.count) .. "x " .. (itemInfo.link or itemInfo.readable or "EMPTY"))
			end
		end
		PLGuildBankClassic:debug("---")
		PLGuildBankClassic:debug("BANK DATA")
		for _, bagId in pairs(PLGBC_BANK_CONFIG) do
			local info = ItemCache:GetBagInfo(cacheOwnerInfo.name, bagId)
			for slot = 1, (info.count or 0) do
				local id = ItemCache:GetItemID(cacheOwnerInfo.name, bagId, slot)
				local itemInfo = ItemCache:GetItemInfo(cacheOwnerInfo.name, bagId, slot)

				PLGuildBankClassic:debug("   BAG#" .. tostring(bagId) .. " " .. tostring(itemInfo.count) .. "x " .. (itemInfo.link or itemInfo.readable or "EMPTY"))
			end
		end
		PLGuildBankClassic:debug("---")
		PLGuildBankClassic:debug("End of cache info")
    else
        -- clear items

    end
end