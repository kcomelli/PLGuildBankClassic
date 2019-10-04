local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local GuildConfigFrame = CreateFrame("Frame")
local GuildConfigFrame_MT = {__index = GuildConfigFrame}

local Events = PLGuildBankClassic:GetModule("Events")

PLGuildBankClassic.GuildConfigFrame = {}
PLGuildBankClassic.GuildConfigFrame.defaults = {}
PLGuildBankClassic.GuildConfigFrame.prototype = GuildConfigFrame
function PLGuildBankClassic.GuildConfigFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabConfig", parent, "PLGuildBankFrameTabConfig"), GuildConfigFrame_MT)

    -- settings
 
    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabConfig")

    return frame
end

function GuildConfigFrame:OnShow()
    self:InitUI()
	--self:GenerateItemButtons()

	--Events.Register(self, "ITEM_SLOT_ADD", "ITEM_SLOT_UPDATE")
	--Events.Register(self, "ITEM_SLOT_UPDATE")
	--Events.Register(self, "ITEM_SLOT_REMOVE")
	--Events.Register(self, "ITEM_SLOT_UPDATE_COOLDOWN")

	--Events.Register(self, "ITEM_LOCK_CHANGED")
end

function GuildConfigFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildConfigFrame:InitUI()
    self:ApplyLocalization()
    --self:GuildRanksDropDown_DoLoad(self.configRankDropDown)
    if PLGuildBankClassic:CanConfigureRank() then
        UIDropDownMenu_EnableDropDown(self.configRankDropDown)
    else
        UIDropDownMenu_DisableDropDown(self.configRankDropDown)
    end
end

function GuildConfigFrame:ApplyLocalization()
    self.configRankLabel.Text:SetText(L["Select min. guild rank for bank-alt management"])
end


local function PLGuildRanksDropDown_Initialize(dropDown)
    if PLGuildBankClassic:IsInGuild() then
        local numRanks = GuildControlGetNumRanks()
        local info = UIDropDownMenu_CreateInfo()
        local selInfo
        for i = 1, numRanks do
            info.text = GuildControlGetRankName(i)
            info.value = i
            info.func = function(self, arg1) 
                GuildConfigFrame:PLGuildRanksDropDown_OnClick(dropDown, arg1) 
            end
            info.arg1 = i
            info.checked = false
            if PLGuildBankClassic:IsInGuild() and PLGuildBankClassic.guildVault.guildSettings.minGuildRank == i then
                info.checked = true
            end
            UIDropDownMenu_AddButton(info);	
        end

        if PLGuildBankClassic:IsInGuild() and PLGuildBankClassic.guildVault.guildSettings.minGuildRank > 0 then
            UIDropDownMenu_SetSelectedValue(dropDown, PLGuildBankClassic.guildVault.guildSettings.minGuildRank)
        end
    else
        self:Hide()
    end
end

function GuildConfigFrame:PLGuildRanksDropDown_OnClick(dropDown, selId)
    if PLGuildBankClassic:IsInGuild() then
        UIDropDownMenu_SetSelectedValue(dropDown,selId)

        if(PLGuildBankClassic.guildVault.guildSettings.minGuildRank ~= selId) then
            PLGuildBankClassic.guildVault.guildSettings.minGuildRank = selId
        end
    end
end

function GuildConfigFrame:GuildRanksDropDownLoad(self)
	UIDropDownMenu_SetWidth(self, 170);
	UIDropDownMenu_Initialize(self, PLGuildRanksDropDown_Initialize)
end
