local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

local GuildBankContentFrame = CreateFrame("Frame")
local GuildBankContentFrame_MT = {__index = GuildBankContentFrame}

local Events = PLGuildBankClassic:GetModule("Events")

local ITEM_CONTAINER_OFFSET_W = -22
local ITEM_CONTAINER_OFFSET_H = -25

PLGuildBankClassic.GuildBankContentFrame = {}
PLGuildBankClassic.GuildBankContentFrame.defaults = {}
PLGuildBankClassic.GuildBankContentFrame.prototype = GuildBankContentFrame
function PLGuildBankClassic.GuildBankContentFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabContents", parent, "PLGuildBankFrameTabContents"), GuildBankContentFrame_MT)

    -- settings
	frame.bagButtons = {}
	frame.displayingCharacterData = nil

	-- components
	frame.itemContainer = PLGuildBankClassic.ItemContainer:Create(frame)
	frame.itemContainer:SetPoint("TOPLEFT", 0, ITEM_CONTAINER_OFFSET_H)
	frame.itemContainer:SetBags(PLGBC_COMBINED_INVENTORY_CONFIG)
	frame.itemContainer:Show()

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
	frame:SetScript("OnHide", frame.OnHide)
	frame:SetScript("OnSizeChanged", frame.OnSizeChanged)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabContents")

    return frame
end 

function GuildBankContentFrame:OnShow()
end

function GuildBankContentFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildBankContentFrame:OnSizeChanged(width, height)
	self:UpdateItemContainer()
end

function GuildBankContentFrame:ApplySearch(searchText)
	self.itemContainer:Search(searchText)
end

function GuildBankContentFrame:UpdateBags(characterData)
	for i, bag in pairs(self.bagButtons) do
		self.bagButtons[i] = nil
        bag:Free()
        bag.ownerName = ""
	end

    for _, bagID in ipairs(PLGBC_COMBINED_INVENTORY_CONFIG) do
		local bag = PLGuildBankClassic.Bag:Create()
		bag:Set(self, bagID)
		bag.bagID = bagID
		tinsert(self.bagButtons, bag)
	end
	
    self:LeftAlignBags(characterData)
	self:UpdateItemContainer()
end

function GuildBankContentFrame:RightAlignBags(characterData)
    -- right align bags
	for i = #self.bagButtons, 1, -1 do
        local bag = self.bagButtons[i]
		bag:ClearAllPoints()
		if i == #self.bagButtons then
			bag:SetPoint("TOPRIGHT", 0, 0)
		else
			local space = -4
			if bag.bagID == 10 then
				space = -20
			end
			bag:SetPoint("RIGHT", self.bagButtons[i+1], "LEFT", space, 0)
        end
        bag.ownerName = characterData.name .. "-" .. characterData.realm
        bag:Show()
        bag:Update()
    end
end

function GuildBankContentFrame:LeftAlignBags(characterData)
     -- left align bags
     for i, bag in ipairs(self.bagButtons) do
        bag:ClearAllPoints()
        if i == 1 then
            bag:SetPoint("TOPLEFT", 5, 0)
        else
            local space = 4
            if bag.bagID == BACKPACK_CONTAINER then
                space = 20
            end
            bag:SetPoint("LEFT", self.bagButtons[i-1], "RIGHT", space, 0)
        end
        bag.ownerName = characterData.name .. "-" .. characterData.realm
        bag:Show()
        bag:Update()
    end
end

function GuildBankContentFrame:UpdateItemContainer(force)
	local width = self:GetWidth() + ITEM_CONTAINER_OFFSET_W
	local height = self:GetHeight() + ITEM_CONTAINER_OFFSET_H

    if width ~= self.itemContainer:GetWidth() or height ~= self.itemContainer:GetHeight() then
		self.itemContainer:SetWidth(width)
		self.itemContainer:SetHeight(height)
		self.itemContainer:Layout()
	end
end

function GuildBankContentFrame:Update(characterData)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

    local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)
    if cacheOwnerInfo.class then
		self.displayingCharacterData = characterData
		
        local class = characterData.class
        if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
        local player = characterData.name
            
        self.configDescriptionLabel.Text:SetText(characterData.description)
        self.configCharLabel.Text:SetText("- " .. (class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player))

        self.configDescriptionLabel:SetWidth(self.configDescriptionLabel.Text:GetWidth())
        self.configCharLabel:SetWidth(self.configCharLabel.Text:GetWidth())
		
        self:UpdateBags(characterData)
        self.itemContainer.ownerName = characterData.name .. "-" .. characterData.realm
		self.itemContainer:UpdateBags()
    else
        -- clear items

    end
end