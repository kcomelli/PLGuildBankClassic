local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local GuildBankInfoFrame = CreateFrame("Frame")
local GuildBankInfoFrame_MT = {__index = GuildBankInfoFrame}

local Events = PLGuildBankClassic:GetModule("Events")

PLGuildBankClassic.GuildBankInfoFrame = {}
PLGuildBankClassic.GuildBankInfoFrame.defaults = {}
PLGuildBankClassic.GuildBankInfoFrame.prototype = GuildBankInfoFrame
function PLGuildBankClassic.GuildBankInfoFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabInfo", parent, "PLGuildBankFrameTabInfo"), GuildBankInfoFrame_MT)

    -- settings
	frame.displayingCharacterData = nil

	-- components

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
	frame:SetScript("OnHide", frame.OnHide)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabInfo")

    return frame
end 

function GuildBankInfoFrame:OnShow()
end

function GuildBankInfoFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildBankInfoFrame:Update(characterData)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

    PLGuildBankClassic:debug("GuildBankInfoFrame:Update: character: " .. charServerName)

    self.displayingCharacterData = characterData
		
    local class = characterData.class
    if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
    local player = characterData.name
        
    self.configDescriptionLabel.Text:SetText(characterData.description)
    self.configCharLabel.Text:SetText("- " .. (class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player))

    self.configDescriptionLabel:SetWidth(self.configDescriptionLabel.Text:GetWidth())
    self.configCharLabel:SetWidth(self.configCharLabel.Text:GetWidth())
end