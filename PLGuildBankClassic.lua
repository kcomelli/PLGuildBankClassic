local _, PLGuildBankClassic = ...
PLGuildBankClassic = LibStub("AceAddon-3.0"):NewAddon(PLGuildBankClassic, "PLGuildBankClassic", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local db
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
    guildDefaults = {
        minGuildRank = 0
    }
}

function PLGuildBankClassic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PLGuildBankClassicDB", defaults, true)
    db = self.db
    self.isInGuild = false
    self:ScanGuildStatus()
end

function PLGuildBankClassic:OnEnable()
	self.guildVault = PLGuildBankClassic.Frame:Create("PLGuildBankClassicFrame", "PLGuildBankClassicFrame", db.vault)

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
    if not db.guildConfig or not db.guildConfig[self:GuildName()] then
        db.guildConfig[self:GuildName()] = defaults.guildDefaults
    end
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

function PLGuildBankClassic:IGuildMaster()
    if self:IsGuildBankChar() then
        guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
        return guildRankIndex <= db.guildConfig[self:GuildName()].minGuildRank
    else
        return false
    end
end