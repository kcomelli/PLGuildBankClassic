local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")
local AceGUI = LibStub("AceGUI-3.0")

local GuildConfigFrame = CreateFrame("Frame")
local GuildConfigFrame_MT = {__index = GuildConfigFrame}

local Events = PLGuildBankClassic:GetModule("Events")

PLGuildBankClassic.GuildConfigFrame = {}
PLGuildBankClassic.GuildConfigFrame.defaults = {}
PLGuildBankClassic.GuildConfigFrame.prototype = GuildConfigFrame
function PLGuildBankClassic.GuildConfigFrame:Create(mainFrame, parent)
	local frame = setmetatable(CreateFrame("Frame", nil, parent), GuildConfigFrame_MT)

    -- settings
    frame.mainFrame = mainFrame

	-- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide) 
    
    --local container = AceGUI:Create("Frame")
    --container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 ,10)
    --container:SetParent(frame)


    --raids_dropdown:SetValue(frame.mainFrame.guildSettings.minGuildRank)
    --raids_dropdown:SetCallback("OnValueChanged", function()
        --if PLGuildBankClassic:IsInGuild() then
            --self:GetParent().mainFrame.guildSettings.minGuildRank = self:GetID()
        --end
    --end)
    --container:AddChild(raids_dropdown)

    --container:Hide()
	return frame
end

function GuildConfigFrame:OnShow()

    local raids_dropdown = AceGUI:Create("Dropdown")
    raids_dropdown:SetWidth(350)
    raids_dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 ,10)
    raids_dropdown:SetList(PLGuildBankClassic:GetGuildRankTable())
    raids_dropdown:SetLabel(L["Select min. guild rank for bank-alt management"])
    raids_dropdown:SetParent(frame)
    
    --container:Show()
	--self:GenerateItemButtons()

	--Events.Register(self, "ITEM_SLOT_ADD", "ITEM_SLOT_UPDATE")
	--Events.Register(self, "ITEM_SLOT_UPDATE")
	--Events.Register(self, "ITEM_SLOT_REMOVE")
	--Events.Register(self, "ITEM_SLOT_UPDATE_COOLDOWN")

	--Events.Register(self, "ITEM_LOCK_CHANGED")
end

function GuildConfigFrame:OnHide()
    Events.UnregisterAll(self)
    --container:Hide()
end
