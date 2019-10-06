local _, PLGuildBankClassic = ...
PLGuildBankClassic = LibStub("AceAddon-3.0"):NewAddon(PLGuildBankClassic, "PLGuildBankClassic", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local dbProfile
local dbFactionRealm
local defaults = {
	profile = {
		vault = {
			x = 220,
			y = 128,
			point = "LEFT",
			width = 690,
			height = 455,
			showBags = false,
        },
        charConfig = {
			x = 220,
			y = 120,
			point = "LEFT",
			width = 400,
			height = 475,
        },
        config = {
            debug = false,
            printMessage = false,
            printErrors = true
        }
    },
    factionrealm  = {
        minGuildRank = 1
    }
}

PLGBC_BAG_CONFIG = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
PLGBC_BANK_CONFIG = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }


-- guild master can change the min required guild rank
-- for bank character configuration
local minGuildRankForRankConfig = 1 

function PLGuildBankClassic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PLGuildBankClassicDB", defaults, true)
    dbProfile = self.db.profile
    dbFactionRealm = self.db.factionrealm
    self.isInGuild = false

    self.iconFilenames = nil

    self:RefreshPlayerSpellIconInfo()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InitializePlayerStatus")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "InitializePlayerStatus")
end

function PLGuildBankClassic:OnEnable()
    local guildSettings = PLGuildBankClassic:GetGuildConfig()
	self.guildVault = PLGuildBankClassic.Frame:Create("PLGuildBankClassicFrame", "PLGuildBankClassicFrame", dbProfile, guildSettings)

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

function PLGuildBankClassic:InitializePlayerStatus()
    print("saccing guild status")
    self:ScanGuildStatus()
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
        self.guildRank = guildRankIndex+1
        self.rankTable = {}


        self:PrepareGuildConfig()
        if self.guildVault ~= nil then
            self.guildVault:UpdateGuildSettings(PLGuildBankClassic:GetGuildConfig())
        end
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

function PLGuildBankClassic:NumberOfConfiguredAlts()
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 
    
    if guildConfig ~= nil and guildConfig.bankChars ~= nill then
        return getn(guildConfig.bankChars)
    end
    
    return 0
end

function PLGuildBankClassic:CreateBankChar(name, description, class, icon, texture)
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig ~= nil and guildConfig.bankChars == nil then
        guildConfig.bankChars = {}
    end

    local charData = {}
    local timestamp = time()
    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))

    charData.name = name
    charData.description = description
    charData.class = class
    charData.icon = icon
    charData.iconTexture = texture
    charData.createdAt = timestamp
    charData.modifiedAt = timestamp
    charData.createdBy = myServerName
    charData.modifiedBy = myServerName
    charData.log = {}
    charData.items = {}
    
    guildConfig.bankChars[getn(guildConfig.bankChars)+1] = charData
end

function PLGuildBankClassic:EditBankChar(index, name, description, class, icon, texture)
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig ~= nil and guildConfig.bankChars == nil then
        guildConfig.bankChars = {}
    end

    if( getn(guildConfig.bankChars) < index ) then
        return false
    end

    local charData = guildConfig.bankChars[index]
    local timestamp = time()
    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
    local charChanged = charData.name ~= name

    charData.name = name
    charData.description = description
    charData.class = class
    charData.icon = icon
    charData.iconTexture = texture
    charData.modifiedAt = timestamp
    charData.modifiedBy = myServerName
    if charChanged then
        -- may save log somewhere else
        -- only retained in the addon
        -- or global log not char based
        charData.log = {}
        charData.items = {}
    end

    return charChanged
end

function PLGuildBankClassic:GetBankCharDataByIndex(index)
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil or guildConfig.bankChars == nil or getn(guildConfig.bankChars) < index then
        return nil
    end

    return guildConfig.bankChars[index]
end

function PLGuildBankClassic:CanConfigureBankAlts()
    if self:IsInGuild() then
        return self.guildRank <= dbFactionRealm.guildConfig[self:GuildName()].minGuildRank
    else
        return false
    end
end

function PLGuildBankClassic:CanConfigureRank()
    if self:IsInGuild() then
        return self.guildRank <= minGuildRankForRankConfig
    else
        return false
    end
end

function PLGuildBankClassic:GetGuildRankTable()
    if self:IsInGuild() then
        if self.rankTable == nil or table.getn(self.rankTable) <= 0 then
            self.rankTable = {}
            local numRanks = GuildControlGetNumRanks()
    		for i = 1, numRanks do
	    		self.rankTable[i] = GuildControlGetRankName(i)
		    end
        end

        return self.rankTable
    end

    return {}
end

function PLGuildBankClassic:RebuildGuildRankTable()
    self.rankTable = {}
    self:GetGuildRankTable()
end





function PLGuildBankClassic:UpdateMinRankForAlts(newRank)
    if self:IsInGuild() then
        dbFactionRealm.guildConfig[self:GuildName()].minGuildRank = newRank
    end
end

function PLGuildBankClassic:GetMinRankForAlts()
    if self:IsInGuild() then
        return dbFactionRealm.guildConfig[self:GuildName()].minGuildRank
    end

    return minGuildRankForRankConfig
end
