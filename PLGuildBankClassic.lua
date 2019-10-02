local _, PLGuildBankClassic = ...
PLGuildBankClassic = LibStub("AceAddon-3.0"):NewAddon(PLGuildBankClassic, "PLGuildBankClassic", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local dbProfile
local dbFactionRealm
local defaults = {
	profile = {
		vault = {
			x = 220,
			y = 120,
			point = "LEFT",
			width = 512,
			height = 512,
			showBags = false,
		},
    },
    factionrealm  = {
        minGuildRank = 0
    }
}

-- guild master can change the min required guild rank
-- for bank character configuration
local minGuildRankForRankConfig = 0

function PLGuildBankClassic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PLGuildBankClassicDB", defaults, true)
    dbProfile = self.db.profile
    dbFactionRealm = self.db.factionrealm
    self.isInGuild = false
    self:ScanGuildStatus()
end

function PLGuildBankClassic:OnEnable()
    local guildSettings = PLGuildBankClassic:GetGuildConfig()
	self.guildVault = PLGuildBankClassic.Frame:Create("PLGuildBankClassicFrame", "PLGuildBankClassicFrame", dbProfile.vault, guildSettings)

	self:RegisterChatCommand("plgb", "HandleSlash")
end

function PLGuildBankClassic:HandleSlash(cmd)
	if strtrim(cmd) == "show" then
		self.guildVault:Show()
	else
		self:Print("Available Commands:")
		self:Print(" /plgb show: Show the guild bank")
	end
end

function PLGuildBankClassic:ToggleFrame()
    if self.guildVault:IsShown() then
        self.guildVault:HideFrame()
    else
        self.guildVault:ShowFrame()
    end
end

function PLGuildBankClassic:ScanGuildStatus()
    guildName, guildRankName, guildRankIndex = GetGuildInfo("player")

    if guildName and guildRankName then
        self.isInGuild = true
        self.guildName = guildName

        self:PrepareGuildConfig()
    end
end

function PLGuildBankClassic:PrepareGuildConfig() 
    if dbFactionRealm.guildConfig == nil or dbFactionRealm.guildConfig[self:GuildName()] == nil then
        dbFactionRealm.guildConfig = {}
        dbFactionRealm.guildConfig[self:GuildName()] = defaults.factionrealm
    end
end

function PLGuildBankClassic:GetGuildConfig() 
    if dbFactionRealm.guildConfig ~= nil and dbFactionRealm.guildConfig[self:GuildName()] ~= nil then
        return dbFactionRealm.guildConfig[self:GuildName()]
    end

    return nil
end

function PLGuildBankClassic:IsGuildBankChar()
    return false
end

function PLGuildBankClassic:IsInGuild()
    return self.isInGuild
end

function PLGuildBankClassic:GuildName()
    return self.guildName
end

function PLGuildBankClassic:UpdateMinRankForAlts(newIndex)
    if self:IsInGuild() then
        dbFactionRealm.guildConfig[self:GuildName()].minGuildRank = newIndex
    end
end

function PLGuildBankClassic:GetMinRankForAlts()
    if self:IsInGuild() then
        return dbFactionRealm.guildConfig[self:GuildName()].minGuildRank
    end

    return 0
end

function PLGuildBankClassic:CanConfigureBankAlts()
    if self:IsInGuild() then
        guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
        return guildRankIndex <= dbFactionRealm.guildConfig[self:GuildName()].minGuildRank
    else
        return false
    end
end

function PLGuildBankClassic:CanConfigureRank()
    if self:IsInGuild() then
        guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
        return guildRankIndex <= minGuildRankForRankConfig
    else
        return false
    end
end