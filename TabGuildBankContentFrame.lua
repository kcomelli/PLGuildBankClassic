local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

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