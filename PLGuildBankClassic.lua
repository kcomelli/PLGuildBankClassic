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
        minGuildRank = 1,
        configTimestamp = 0
    }
}

PLGBC_BAG_CONFIG = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
PLGBC_BANK_CONFIG = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }
PLGBC_COMBINED_INVENTORY_CONFIG = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, BACKPACK_CONTAINER, 1, 2, 3, 4 }

StaticPopupDialogs["PLGBC_POPUP_ACCEPT_BANKCHARSTATE"] = {
    text = L["%s has configured your char as guild-bank character!\nDo you accept this state of the character?\n \nNote: All your inventory, bank and money will be shared across the guild!"],
    button1 = L["Accept"],
    button2 = L["Decline"],
    OnAccept = function()
        PLGuildBankClassic:AcceptOrDeclineState("accept")
    end,
    OnCancel = function (_,reason)
        if reason == "clicked" then
            PLGuildBankClassic:AcceptOrDeclineState("decline")
        end
    end,
    sound = 888,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
  }

-- guild master can change the min required guild rank
-- for bank character configuration
local minGuildRankForRankConfig = 1 

function PLGuildBankClassic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PLGuildBankClassicDB", defaults, true)
    dbProfile = self.db.profile
    dbFactionRealm = self.db.factionrealm
    self.isInGuild = false

    self.iconFilenames = nil
    self.atBankChar = nil
    self.atBankCharIndex = 0

    self:RefreshPlayerSpellIconInfo()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
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
    PLGuildBankClassic:debug("Scaning guild status")
    self:ScanGuildStatus()
    self:UpdateAtBankCharState()
    self:CheckIfAcceptenceIsPending()
end

function PLGuildBankClassic:PlayerEnteringWorld()
    PLGuildBankClassic:debug("Entering world")
    self:ScanGuildStatus()
    self:UpdateAtBankCharState()
    self:CheckIfAcceptenceIsPending()
end

function PLGuildBankClassic:CheckIfAcceptenceIsPending()
    if self.atBankChar and (self.atBankChar.acceptState == nil or self.atBankChar.acceptState == 0) then
        PLGuildBankClassic:debug("CheckIfAcceptenceIsPending: Sending popup for initiator " .. self.atBankChar.createdBy)

        local initiatorName, initiatorRealm, initiatorServerName = PLGuildBankClassic:CharaterNameTranslation(self.atBankChar.createdBy)

        StaticPopup_Show("PLGBC_POPUP_ACCEPT_BANKCHARSTATE", initiatorName)
    else
        if not self.atBankChar then
            PLGuildBankClassic:debug("CheckIfAcceptenceIsPending: Not logged in with bank char")
        else
            PLGuildBankClassic:debug("CheckIfAcceptenceIsPending: Acceptance state is " .. tostring(self.atBankChar.acceptState or 0))
        end
    end
end

function PLGuildBankClassic:UpdateAtBankCharState()
    self.atBankChar = self:GetBankCharDataByName(UnitName("player"))
    self.atBankCharIndex = self:IndexOfBankCharData(self.atBankChar)
end

function PLGuildBankClassic:AcceptOrDeclineState(state)
    if PLGuildBankClassic.atBankChar then
        if state == "accept" then
            PLGuildBankClassic.atBankChar.acceptState = 1
        elseif state == "decline" then
            PLGuildBankClassic.atBankChar.acceptState = -1
        end

        local Events = self:GetModule("Events")
        Events:GenericEvent("PLGBC_EVENT_BANKCHAR_SLOT_SELECTED", PLGuildBankClassic.atBankCharIndex, PLGuildBankClassic.atBankChar)
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
        dbFactionRealm.guildConfig[self:GuildName()] = {}
        dbFactionRealm.guildConfig[self:GuildName()].config = {}
        dbFactionRealm.guildConfig[self:GuildName()].config = defaults.factionrealm
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

function PLGuildBankClassic:CreateBankChar(name, realm, description, class, icon, texture, acceptState)
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig ~= nil and guildConfig.bankChars == nil then
        guildConfig.bankChars = {}
    end

    local charData = {}
    local timestamp = time()
    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))

    charData.name = name
    charData.realm = realm
    charData.description = description
    charData.class = class
    charData.icon = icon
    charData.iconTexture = texture
    charData.createdAt = timestamp
    charData.modifiedAt = timestamp
    charData.createdBy = myServerName
    charData.modifiedBy = myServerName
    charData.acceptState = acceptState or 0
    charData.inventoryVersion = 0
    charData.moneyVersion = 0
    charData.money = 0
    
    guildConfig.bankChars[getn(guildConfig.bankChars)+1] = charData
end

function PLGuildBankClassic:EditBankChar(index, name, realm, description, class, icon, texture, acceptState)
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
    charData.realm = realm
    charData.description = description
    charData.class = class
    charData.icon = icon
    charData.iconTexture = texture
    charData.modifiedAt = timestamp
    charData.modifiedBy = myServerName
    charData.acceptState = acceptState
 
    if charChanged then
        charData.inventoryVersion = 0
        charData.moneyVersion = 0
        charData.money = 0
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

function PLGuildBankClassic:GetBankCharDataByName(characterName)
    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)

    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil or guildConfig.bankChars == nil then
        return nil
    end

    for i=1, getn(guildConfig.bankChars) do
        local checkData = guildConfig.bankChars[i]
        if checkData.name == myName and checkData.realm == myRealm then
            return guildConfig.bankChars[i]
        end
    end

    return nil
end

function PLGuildBankClassic:IndexOfBankCharData(characterData)
    if not characterData then
        return 0
    end

    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil or guildConfig.bankChars == nil then
        return 0
    end

    for i=1, getn(guildConfig.bankChars) do
        local checkData = guildConfig.bankChars[i]
        if checkData == characterData then
            return i
        end
    end

    return 0
end

function PLGuildBankClassic:CanConfigureBankAlts()
    if self:IsInGuild() then
        return self.guildRank <= dbFactionRealm.guildConfig[self:GuildName()].config.minGuildRank
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
        dbFactionRealm.guildConfig[self:GuildName()].config.minGuildRank = newRank
    end
end

function PLGuildBankClassic:GetMinRankForAlts()
    if self:IsInGuild() then
        return dbFactionRealm.guildConfig[self:GuildName()].config.minGuildRank
    end

    return minGuildRankForRankConfig
end
