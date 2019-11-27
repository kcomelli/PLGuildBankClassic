local _, PLGuildBankClassic = ...
PLGuildBankClassic = LibStub("AceAddon-3.0"):NewAddon(PLGuildBankClassic, "PLGuildBankClassic", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

-- 1.00.00
PLGBC_BUILD_NUMBER = 10000

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
        configTimestamp = 0,
        charConfigTimestamp = 0,
        showValueEstimationInLogs = true,
        accountChars = nil
    }
}

PLGuildBankClassic.transactionModes = {
    deposit = 0,        -- something was put into the bank
    withdraw = 1        -- something was taken out of the bank
}

PLGuildBankClassic.transactionTypes = {
    money = 0,          -- log entry describes a money transaction
    item = 1            -- log entry describes an item transaction
}

PLGuildBankClassic.transactionSource = {
    directTrade = 0,    -- item or money was player-traded
    mail = 1,           -- item or money was sent/received via mail
    cod = 2,            -- money sent because of a COD
    auction = 3,        -- money item spend/received because of an auction
    vendor = 4,         -- money spent, item looted at the vendor
    enchanting = 5,     -- item was withdrawn (destroyed) because of disentchanting. materials gained through disentchanting, materials withdrawn because of enchanting an item
    loot = 10,          -- money or item looted
    destroy = 98,       -- item has been destroyed
    other = 99          -- other sources (e.g. mail sending costs)
}

PLGuildBankClassic.moneyValueSource = {
    vendor = 0,         -- calculated per item value represents vendor price
    auction = 1,        -- calculated per item value represents current auction price (at time of transaction)
    unknown = 99
}

PLGBC_BAG_CONFIG = { BACKPACK_CONTAINER, 1, 2, 3, 4 }
PLGBC_BANK_CONFIG = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10 }
PLGBC_COMBINED_INVENTORY_CONFIG = { BANK_CONTAINER, 5, 6, 7, 8, 9, 10, BACKPACK_CONTAINER, 1, 2, 3, 4 }

StaticPopupDialogs["PLGBC_POPUP_ACCEPT_BANKCHARSTATE"] = {
    text = L["%s has configured your char as guild-bank character!\nDo you accept this state of the character?\n \nNote: All your inventory, bank and money will be shared across the guild!"],
    button1 = L["Accept"],
    button3 = L["Decline"],
    button2 = L["Decide later"],
    OnAccept = function()
        PLGuildBankClassic:AcceptOrDeclineState("accept")
    end,
    OnAlt = function (_,reason)
        PLGuildBankClassic:AcceptOrDeclineState("decline")
    end,
    OnCancel = function() end,
    sound = 888,
    timeout = 30,
    whileDead = 1,
    hideOnEscape = 1,
  }

  StaticPopupDialogs["PLGBC_POPUP_TRADE_ENTERLOGTITLE"] = {
    text = L["You have traded the following items and/or money with a guild-bank char:\n%s\n \nYou can enter a reason for the trade which will be shown in the guild log below:"],
    button1 = OK,
    button3 = OK,
    button2 = CANCEL,
    hasEditBox = 1,
	maxLetters = 50,
    OnAccept = function(self)
        PLGuildBankClassic.tradeLogTitle = self:GetParent().editBox:GetText();
    end,
    EditBoxOnEnterPressed = function(self)
		PLGuildBankClassic.tradeLogTitle = self:GetText();
		self:GetParent():Hide();
	end,
    OnShow = function(self)
        if PLGuildBankClassic.tradeLogTitle then
            self.editBox:SetText(PLGuildBankClassic.tradeLogTitle); 
        end
		self.editBox:SetFocus();
	end,
    OnHide = function(self)
        --PLGuildBankClassic.tradeLogTitle = self.editBox:GetText();
		ChatEdit_FocusActiveWindow();
        self.editBox:SetText("");
        PLGuildBankClassic:ExecuteTradeLog()
	end,
    timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
  }

-- guild master can change the min required guild rank
-- for bank character configuration
local minGuildRankForRankConfig = 1 

-- timeout waiting waiting after a trade window closes and has been accepted from either side
local timeoutTradeScanInSeconds = 2

PLGuildBankClassic.IsOfficer = ""
PLGuildBankClassic.LastVerCheck = 0


function PLGuildBankClassic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PLGuildBankClassicDB", defaults, true)
    dbProfile = self.db.profile
    dbFactionRealm = self.db.factionrealm
    self.isInGuild = false

    self.iconFilenames = nil
    self.atBankChar = nil
    self.atBankCharIndex = 0

    self.scanningMails = false
    self.mailsTransaction = false
    self.mailData = {}
    self.mailTransactionLog = {}
    self.mailItemLootStack = {}
    self.mailMoneyLootStack = {}
    self.sendMailData = nil
    self.tradeData = nil
    self.ignoreLootItemMessage = false
    self.executingTradeDataLog = false

    self.tradeLogTitle = nil
    self.canEditPublicNote = false

    self:RefreshPlayerSpellIconInfo()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "PlayerLeavingWorld")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "InitializePlayerStatus")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "InitializePlayerStatus")

    
end

function PLGuildBankClassic:OnEnable()
    local guildSettings = PLGuildBankClassic:GetGuildConfig()
	self.guildVault = PLGuildBankClassic.Frame:Create("PLGuildBankClassicFrame", "PLGuildBankClassicFrame", dbProfile, guildSettings)


    self:RegisterChatCommand("plgb", "HandleSlash")
    
    self.Events = self:GetModule("Events")
    self.Events.Register(self, "PLGBC_EVENT_BANKCHAR_ENTERED_WORLD", "UpdatePlayerMoney")
    self.Events.Register(self, "PLGBC_MAILBOX_OPENED", "MailboxOpened")
    self.Events.Register(self, "PLGBC_MAILBOX_CLOSED", "MailboxClosed")
    self.Events.Register(self, "PLGBC_MAILBOX_ITEM_CLOSED", "MailboxItemClosed")
    self.Events.Register(self, "PLGBC_EVENT_BANKCHAR_MONEYCHANGED", "LogPlayerMoneyGainOrLoss")
    self.Events.Register(self, "PLGBC_RECEVIED_ITEM", "LogPlayerGotItem")
    self.Events.Register(self, "PLGBC_MAIL_SUCCESS", "MailSuccessfullySent")
    
    self.Events.Register(self, "PLGBC_TRADE_OPENED", "InitiateTradeOverride")
    self.Events.Register(self, "PLGBC_TRADE_CLOSED", "TradeFinished")
    self.Events.Register(self, "PLGBC_TRADE_UPDATE", "ScanTradeInfo")
    self.Events.Register(self, "PLGBC_TRADE_ACCEPT_UPDATE", "AcceptTradeUpdate")

    self:Hook("TakeInboxItem", "TakeInboxItemOverride", true)
    self:Hook("TakeInboxMoney", "TakeInboxMoneyOverride", true)
    self:Hook("SendMail", "SendMailOverride", true)

    self:Hook("PostAuction", "PostAuctionOverride", true)

    self.scanFrame = CreateFrame("Frame", "test12333", UIParent)
    self.scanFrame:SetScript("OnUpdate", function (frame, elapsed) PLGuildBankClassic:OnUpdate(frame, elapsed) end)
end

function PLGuildBankClassic:HandleSlash(cmd)
	if strtrim(cmd) == "show" then
		self.guildVault:Show()
	else
		self:Print("Available Commands:")
		self:Print(" /plgb show: Show the guild bank")
	end
end


function PLGuildBankClassic:OnUpdate(frame, elapsed)

    if PLGuildBankClassic.CommsThresholdTriggers ~= nil and PLGuildBankClassic:countDictionaryKeys(PLGuildBankClassic.CommsThresholdTriggers, false) > 0 then
        for cmd, data in pairs(PLGuildBankClassic.CommsThresholdTriggers) do
			if data ~= nil and data.trigger > 0 and data.trigger <= time() then
				-- ensure not sending data twice
				data.trigger = 0
				PLGuildBankClassic:debug("Executeing sync command '" .. cmd .. "' ...")
				-- send command and data
				PLGuildBankClassic.Comms:SendData(cmd, data.data)
				-- delete key from 
				PLGuildBankClassic.CommsThresholdTriggers[cmd] = nil
			end
		end
	end
end


function PLGuildBankClassic:UpdatePlayerMoney()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("UpdatePlayerMoney: updating player money")
        local curMoney = GetMoney()

        if PLGuildBankClassic.atBankChar.money ~= curMoney then
            local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
            local diff = GetMoney() - PLGuildBankClassic.atBankChar.money
            PLGuildBankClassic.atBankChar.money = GetMoney()
            PLGuildBankClassic.atBankChar.moneyVersion = PLGuildBankClassic:GetTimestamp()
            PLGuildBankClassic:UpdateVersionsInPublicNote()

            PLGuildBankClassic.Events:Fire("PLGBC_EVENT_BANKCHAR_MONEYCHANGED", charServerName, GetMoney(), diff, PLGuildBankClassic.atBankChar.moneyVersion)

            -- check if inventory update was triggered by a trade
            PLGuildBankClassic:CheckPendingTradeData()
        end
    end
end

function PLGuildBankClassic:UpdateInventoryVersion()
    PLGuildBankClassic:debug("UpdateInventoryVersion: updating player inventory version info")
    if PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
        local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)
        local hasCachedData = cacheOwnerInfo.class ~= nil

        PLGuildBankClassic.atBankChar.inventoryVersion = PLGuildBankClassic:GetTimestamp()
        PLGuildBankClassic:UpdateVersionsInPublicNote()

        PLGuildBankClassic.Events:Fire("PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED", charServerName, hasCachedData, PLGuildBankClassic.atBankChar.inventoryVersion)

        -- check if inventory update was triggered by a trade
        PLGuildBankClassic:CheckPendingTradeData()
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
    self:SetOwnedCharacters()
end

function PLGuildBankClassic:PlayerLeavingWorld()
    self:CheckPendingTradeData("trade")
end

function PLGuildBankClassic:SetOwnedCharacters()
    if not dbFactionRealm.accountChars then
        dbFactionRealm.accountChars = {}
    end

    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
    dbFactionRealm.accountChars[myServerName] = true
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

    if self.atBankChar ~= nil then
        PLGuildBankClassic:debug("UpdateAtBankCharState: Logged in with bank char")
        self.Events:Fire("PLGBC_EVENT_BANKCHAR_ENTERED_WORLD")
    end
end

function PLGuildBankClassic:AcceptOrDeclineState(state)
    local myName, myRealm, myServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
    if PLGuildBankClassic.atBankChar then
        local guildConfig = PLGuildBankClassic:GetGuildConfig() 
        local timestamp = PLGuildBankClassic:GetTimestamp()
    
        if state == "accept" then
            PLGuildBankClassic.atBankChar.acceptState = 1
            PLGuildBankClassic.atBankChar.modifiedAt = timestamp
            PLGuildBankClassic.atBankChar.modifiedBy = myServerName
        elseif state == "decline" then
            PLGuildBankClassic.atBankChar.acceptState = -1
            PLGuildBankClassic.atBankChar.modifiedAt = timestamp
            PLGuildBankClassic.atBankChar.modifiedBy = myServerName
        end
        guildConfig.config.charConfigTimestamp = timestamp
        PLGuildBankClassic:UpdateVersionsInPublicNote()

        self.Events.Fire("PLGBC_EVENT_CHAR_CONFIG_CHANGED", timestamp)
        self.Events:Fire("PLGBC_EVENT_BANKCHAR_SLOT_SELECTED", PLGuildBankClassic.atBankCharIndex, PLGuildBankClassic.atBankChar)
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
        self.canEditPublicNote = CanEditPublicNote()

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
        dbFactionRealm.guildConfig[self:GuildName()].bankChars = {}
        dbFactionRealm.guildConfig[self:GuildName()].logs = {}
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
    local timestamp = PLGuildBankClassic:GetTimestamp()
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
    charData.isDeleted = false
    
    guildConfig.bankChars[getn(guildConfig.bankChars)+1] = charData

    guildConfig.config.charConfigTimestamp = timestamp
    PLGuildBankClassic:UpdateVersionsInPublicNote()

    self.Events:Fire("PLGBC_EVENT_CHAR_CONFIG_CHANGED", timestamp)
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
    local timestamp = PLGuildBankClassic:GetTimestamp()
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
    charData.isDeleted = false
 
    if charChanged then
        charData.inventoryVersion = 0
        charData.moneyVersion = 0
        charData.money = 0
    end
    
    guildConfig.config.charConfigTimestamp = timestamp
    PLGuildBankClassic:UpdateVersionsInPublicNote()

    self.Events:Fire("PLGBC_EVENT_CHAR_CONFIG_CHANGED", timestamp)
    
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

function PLGuildBankClassic:GetLogByIndex(index)
    local bankCharData = self:GetBankCharDataByIndex(index)

    if bankCharData then
        return self:GetLogByName(bankCharData.name .. "-" .. charData.realm)
    end

    return nil
end

function PLGuildBankClassic:GetLogByName(characterName)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)

    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil then
        return nil
    end

    if guildConfig.logs == nil then
        guildConfig.logs = {}
    end

    if guildConfig.logs[charServerName] == nil then
        guildConfig.logs[charServerName] = {}
    end

    return guildConfig.logs[charServerName]
end

function PLGuildBankClassic:DeleteLogByName(characterName)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)

    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil then
        return false
    end

    if guildConfig.logs == nil then
        return false
    end

    if guildConfig.logs[charServerName] ~= nil then
        guildConfig.logs[charServerName] = nil

        return true
    end

    return false
end

function PLGuildBankClassic:MergeLogEntries(currentLog, entriesToMerge)
    if entriesToMerge and currentLog then
        if #currentLog == 0 then
            for i=1, #entriesToMerge do
                tinsert(currentLog, entriesToMerge[i])
            end    
            return
        end

        local added = 0

        for i=1, #entriesToMerge do
            local mergeEntry = entriesToMerge[i]

            local existingIndex = PLGuildBankClassic:FindLogEntryIndex(currentLog, mergeEntry)
            if not existingIndex then
                local insertionIndex = PLGuildBankClassic:FindInsertionIndex(currentLog, mergeEntry)

                if insertionIndex then
                    tinsert(currentLog, insertionIndex, mergeEntry)
                    added = added + 1
                end
            else
                -- TODO: check title or note change?!?
            end
        end
        
        PLGuildBankClassic:debug("MergeLogEntries: Added '" .. tostring(added) .. "' new entries!")
    end
end

function PLGuildBankClassic:FindLogEntryIndex(currentLog, logEntryToSearch)
    if logEntryToSearch and currentLog then
        for l=1, #currentLog do
            local curEntry = currentLog[i]
            if curEntry.type == logEntryToSearch.type and curEntry.source == logEntryToSearch.source and curEntry.goldPerItem == logEntryToSearch.goldPerItem and curEntry.quantity == logEntryToSearch.quantity and curEntry.name == logEntryToSearch.name and 
                curEntry.timestamp == logEntryToSearch.timestamp and curEntry.mode == logEntryToSearch.mode and curEntry.itemId == logEntryToSearch.itemId then
                
                return l
            end
        end
    end

    return nil
end

function PLGuildBankClassic:FindInsertionIndex(currentLog, logEntryToInsert)
    if logEntryToInsert and currentLog then
        for l=1, #currentLog do
            local curEntry = currentLog[i]
            if logEntryToInsert.timestamp >= curEntry.timestamp then
                return l
            end
        end

        return #currentLog
    end

    return 1
end

function PLGuildBankClassic:SumBankCharMoney()
    local capital = 0

    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig == nil or guildConfig.bankChars == nil then
        return capital
    end

    for i=1, getn(guildConfig.bankChars) do
        local checkData = guildConfig.bankChars[i]
        if checkData.money then
            capital = capital + checkData.money or 0
        end
    end

    return capital
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
        return (dbFactionRealm.guildConfig[self:GuildName()].config.minGuildRank or minGuildRankForRankConfig)
    end

    return minGuildRankForRankConfig
end

function PLGuildBankClassic:UpdateShowEstimatedValueForItemLogs(showValue)
    if self:IsInGuild() then
        dbFactionRealm.guildConfig[self:GuildName()].config.showValueEstimationInLogs = showValue
    end
end

function PLGuildBankClassic:ShowEstimatedValueForItemLogs()
    if self:IsInGuild() then
        return (dbFactionRealm.guildConfig[self:GuildName()].config.showValueEstimationInLogs or true)
    end

    return minGuildRankForRankConfig
end

function PLGuildBankClassic:ClearBankCharData(characterName, setTimestamps)
    if characterName == nil then
        return
    end

    local timestamp = PLGuildBankClassic:GetTimestamp()
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
    local bankCharData = PLGuildBankClassic:GetBankCharDataByName(characterName)

    if bankCharData ~= nil then
        if PLGuildBankClassic:CharacterOwnedByAccount(characterName) == false then
            -- removing log and inventory data
            local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)
            if cacheOwnerInfo ~= nil then
                ItemCache:DeleteOwnerInfo(charServerName)
                bankCharData.inventoryVersion = 0
            end

            if PLGuildBankClassic:DeleteLogByName(characterName) == true then
                bankCharData.logVersion = 0
            end

            PLGuildBankClassic:debug("ClearBankCharData: Deleted inventory data and log of character " .. (characterName or "n/a"))
        end

        if setTimestamps == true then
            guildConfig.config.charConfigTimestamp = timestamp
        else
            timestamp = guildConfig.config.charConfigTimestamp
        end
        PLGuildBankClassic:UpdateVersionsInPublicNote()

        self.Events:Fire("PLGBC_EVENT_CHAR_CONFIG_CHANGED", timestamp)
    else
        PLGuildBankClassic:debug("ClearBankCharData: No bank data found for character " .. (characterName or "n/a"))
    end
end

function PLGuildBankClassic:TakeInboxItemOverride(mailIndex, itemIndex)
    PLGuildBankClassic:debug("TakeInboxItemOverride mailIndex: " .. tostring(mailIndex) .. " - itemIndex: " .. tostring(itemIndex))
    if PLGuildBankClassic:IsGuildBankChar() then
        if self.mailData and self.mailData[mailIndex] then
            -- save mail ref
            -- CHAT_LOOT_MSG will be fired afterwars - using this stack we can determine the sender 
            self.mailItemLootStack[#self.mailItemLootStack + 1] = self.mailData[mailIndex]
        end
    end
end

function PLGuildBankClassic:TakeInboxMoneyOverride(mailIndex)
    PLGuildBankClassic:debug("TakeInboxMoneyOverride mailIndex: " .. tostring(mailIndex))
    if PLGuildBankClassic:IsGuildBankChar() then
        if self.mailData and self.mailData[mailIndex] then
            -- save mail ref
            -- PLAYER_MONEY_UPDATE will be fired afterwars - using this stack we can determine the sender 
            self.mailMoneyLootStack[#self.mailMoneyLootStack + 1] = self.mailData[mailIndex]
        end
    end
end

function PLGuildBankClassic:SendMailOverride(recipient, subject, body)
    PLGuildBankClassic:debug("SendMailOverride subject: " .. subject or "na")
    if PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
        -- use recipient
        self.sendMailData = {}
        self.sendMailData.sender = charName
        self.sendMailData.recipient = recipient
        self.sendMailData.subject = subject
        self.sendMailData.body = body
        

        
        self.sendMailData.money = GetSendMailMoney()
        self.sendMailData.cod = GetSendMailCOD()
        self.sendMailData.cost = GetSendMailPrice()
        self.sendMailData.hasItems = false
        self.sendMailData.attachments = nil

        if self.sendMailData.money > 0 then
            -- money sent is included in costs ? 
            self.sendMailData.cost = self.sendMailData.cost - self.sendMailData.money
        end

        PLGuildBankClassic:debug("SendMailOverride: money: " .. (self.sendMailData.money or "na") .. " cod: " ..  (self.sendMailData.cod or "na") .. " cost: " .. (self.sendMailData.cost or "na"))

        for i=1, 12 do
            local name, texture, quality, count = GetSendMailItem(i)
            if name then
                PLGuildBankClassic:debug("SendMailOverride name: " .. (name or "na") .. " count: " .. (tostring(count) or "-1") .. " quality: " .. (tostring(quality) or "na"))
                self.sendMailData.hasItems = true
                if not self.sendMailData.attachments then
                    self.sendMailData.attachments = {}
                end

                self.sendMailData.attachments[i] = {}
                self.sendMailData.attachments[i].name = name
                self.sendMailData.attachments[i].count = count
                self.sendMailData.attachments[i].itemLink = GetSendMailItemLink(i)

                if self.sendMailData.subject and name then
                    if string.find(self.sendMailData.subject, name) or string.find(self.sendMailData.subject, "(" .. tostring(count or 1) .. ")") then
                    -- override standard item-name-based subject info
                    -- in order to not add this to the logs
                    self.sendMailData.subject = nil
                    end
                end
            end
        end
    end
end

function PLGuildBankClassic:PostAuctionOverride(minBid, buyoutPrice, runTime, count)
    PLGuildBankClassic:debug("PostAuctionOverride starting auction")
    if PLGuildBankClassic:IsGuildBankChar() then
        -- log withdraw
        local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount = GetAuctionSellItemInfo()
        local itemId = self:GetItemIdFromName(name)

        if itemId then
            local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
            local playerLog = PLGuildBankClassic:GetLogByName(charServerName)
            
            if playerLog then
                local added = false
                local logEntry = {}

                logEntry.name = charName
                logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                logEntry.source = PLGuildBankClassic.transactionSource.auction
                logEntry.type = PLGuildBankClassic.transactionTypes.item
                logEntry.itemId = itemId
                logEntry.quantity = totalCount
                logEntry.goldPerItem = PLGuildBankClassic:GetItemPrice(itemId, false)
                logEntry.mode = PLGuildBankClassic.transactionModes.withdraw
                logEntry.title = L["Auction creation"]

                if #playerLog > 0 then
                    table.insert(playerLog, 1, logEntry)
                else
                    playerLog[1] = logEntry
                end

                PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
                PLGuildBankClassic:UpdateVersionsInPublicNote()
                PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
            end
        else
            PLGuildBankClassic:debug("StartAuctionOverride: could not get itemId of item " .. name)
        end
    end
end

function PLGuildBankClassic:ScanTradeInfo()
    PLGuildBankClassic:debug("ScanTradeInfo trading")
    if PLGuildBankClassic:IsGuildBankChar() then
        if not self.tradeData then
            self.tradeData = {}
        end

        if self.tradeData.accepted then
            PLGuildBankClassic:debug("Already accepted trade ")
            return
        end


        local receive_money = GetTargetTradeMoney()
        local send_money = GetPlayerTradeMoney()

        self.tradeData.accepted = false
        self.tradeData.moneyOut = send_money
        self.tradeData.moneyIn = receive_money
        if not self.tradeData.send then
            self.tradeData.send = {}
        end

        if not self.tradeData.receive then
            self.tradeData.receive = {}
        end

        --self.tradeData.recipient = 
        for i=1, 7 do
            PLGuildBankClassic:debug("Scanning item " .. tostring(i))
            -- i=7 ... will-not-be-traded-slot
            local receive_name, receive_texture, receive_quantity, receive_quality, receive_isUsable, receive_enchant = GetTradeTargetItemInfo(i)
            local receive_itemLink = GetTradeTargetItemLink(i)
            
            local send_name, send_texture, send_quantity, send_quality, send_isUsable, send_enchant = GetTradePlayerItemInfo(i)
            local send_itemLink = GetTradePlayerItemLink(i)

            if receive_name then
                local idx = i --#self.tradeData.receive + 1
                self.tradeData.receive[idx] = {}
                self.tradeData.receive[idx].name = receive_name
                self.tradeData.receive[idx].quantity = receive_quantity
                self.tradeData.receive[idx].itemLink = receive_itemLink
                self.tradeData.receive[idx].itemId = PLGuildBankClassic:GetItemIdFromLink(receive_itemLink)
                self.tradeData.receive[idx].notTradeAction = receive_enchant

                PLGuildBankClassic:debug("Set Receive-item " .. tostring(idx) .. " " .. (receive_name or "na") .. " - " .. (receive_itemLink or "na"))
            else
                PLGuildBankClassic:debug("Receive-item name not set")
            end
            if send_name then
                local idx = i --#self.tradeData.send + 1
                self.tradeData.send[idx] = {}
                self.tradeData.send[idx].name = send_name
                self.tradeData.send[idx].quantity = send_quantity
                self.tradeData.send[idx].itemLink = send_itemLink
                self.tradeData.send[idx].itemId = PLGuildBankClassic:GetItemIdFromLink(send_itemLink)
                self.tradeData.send[idx].notTradeAction = send_enchant

                PLGuildBankClassic:debug("Set Send-item " .. tostring(idx) .. " " .. (send_name or "na") .. " - " .. (send_itemLink or "na"))
            else
                PLGuildBankClassic:debug("Send-item name not set")
            end
        end
    end
end

function PLGuildBankClassic:AcceptTradeUpdate(event, playerAccepted, targetAccepted)
    PLGuildBankClassic:debug("AcceptTradeUpdate trading")
    if PLGuildBankClassic:IsGuildBankChar() and self.tradeData then
        self.tradeData.accepted = false
        self.tradeData.acceptedState = 0

        if targetAccepted == 1 and playerAccepted == 1 then
            self.tradeData.acceptedState = 2
            self.tradeData.accepted = true
        elseif playerAccepted == 1 then
            self.tradeData.acceptedState = 1
            self.tradeData.accepted = true
        end
    end
end

function PLGuildBankClassic:InitiateTradeOverride(event, unitId)
    PLGuildBankClassic:debug("InitiateTrade: " .. (event or "na") .. ", " .. tostring(unitTd or "na"))
    PLGuildBankClassic:ResetTradeInfo()

    local target = UnitName(unitId)
    PLGuildBankClassic:debug("InitiateTrade: " .. UnitName(unitId))
    if PLGuildBankClassic:IsGuildBankChar() then
        self.tradeData = {}
        self.tradeData.target = target
        self.ignoreLootItemMessage = true
    end
end

function PLGuildBankClassic:ResetTradeInfo()
    PLGuildBankClassic:debug("ResetTradeInfo")

    self.tradeData = nil
    self.tradeDataFinish = nil
    self.ignoreLootItemMessage = false
    self.executingTradeDataLog = false
end

function PLGuildBankClassic:TradeFinished(event)
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("TradeFinished: received")

        if self.tradeDataFinish then
            PLGuildBankClassic:debug("TradeFinished: skip event since unfinished data is in queue")
            return
        end

        if self.tradeData and self.tradeData.accepted then
            self.tradeDataFinish = self.tradeData
            self.tradeDataFinish.finishTime = PLGuildBankClassic:GetTimestamp()
            local tradeSummary = ""

            if (self.tradeDataFinish.send and #self.tradeDataFinish.send > 0) or (self.tradeDataFinish.moneyOut and self.tradeDataFinish.moneyOut > 0 ) then
                tradeSummary = tradeSummary .. "\n" .. L["gave"] .. ": "

                if (self.tradeDataFinish.moneyOut and self.tradeDataFinish.moneyOut > 0 ) then
                    tradeSummary = tradeSummary ..  PLGuildBankClassic:PriceToMoneyString(self.tradeDataFinish.moneyOut, false) .. "\n"
                end

                if self.tradeDataFinish.send then
                    local itemidx=1
                    for i=1, #self.tradeDataFinish.send do
                        if itemidx > 1 then
                            tradeSummary = tradeSummary .. ", "
                        end
                        tradeSummary = tradeSummary .. self.tradeDataFinish.send[i].itemLink
                        itemidx = itemidx + 1
                    end

                    tradeSummary = tradeSummary .. "\n"
                end
            end

            if (self.tradeDataFinish.receive and #self.tradeDataFinish.receive > 0) or (self.tradeDataFinish.moneyIn and self.tradeDataFinish.moneyIn > 0) then
                tradeSummary = tradeSummary .. "\n" .. L["got"] .. ": "

                if (self.tradeDataFinish.moneyIn and self.tradeDataFinish.moneyIn > 0) then
                    tradeSummary = tradeSummary ..  PLGuildBankClassic:PriceToMoneyString(self.tradeDataFinish.moneyIn, false) .. "\n"
                end

                if self.tradeDataFinish.receive then
                    local itemidx=1
                    for i=1, #self.tradeDataFinish.receive do
                        if itemidx > 1 then
                            tradeSummary = tradeSummary .. ", "
                        end
                        tradeSummary = tradeSummary .. self.tradeDataFinish.receive[i].itemLink
                        itemidx = itemidx + 1
                    end

                    tradeSummary = tradeSummary .. "\n"
                end
            end

            self.tradeDataFinish.tradeSummary = tradeSummary
            -- everything else will be handled if player's money or inventory changes
        else
            PLGuildBankClassic:debug("TradeFinished: no trade-data or trade aborted")
        end
    end
end

function PLGuildBankClassic:CheckPendingTradeData(tradeLogTitle)

    if self.executingTradeDataLog then
        return
    end

    -- this function will be triggered if a an inventory or player update occured
    if self.tradeDataFinish then
        local curTime = PLGuildBankClassic:GetTimestamp()

        if (curTime - self.tradeDataFinish.finishTime) <= timeoutTradeScanInSeconds or tradeLogTitle ~= nil then
            self.executingTradeDataLog = true
            if tradeLogTitle ~= nil then
                self.tradeLogTitle = tradeLogTitle
                PLGuildBankClassic:ExecuteTradeLog()
            else
                -- ask for log title
                StaticPopup_Show("PLGBC_POPUP_TRADE_ENTERLOGTITLE", self.tradeDataFinish.tradeSummary)
            end
        else
            PLGuildBankClassic:ResetTradeInfo()
        end
    end

    self.executingTradeDataLog = false
end

function PLGuildBankClassic:ExecuteTradeLog()
    PLGuildBankClassic:debug("ExecuteTradeLog: executing trade log")
    if self.tradeDataFinish then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
        local playerLog = PLGuildBankClassic:GetLogByName(charServerName)
        local alreadyAdded = {}
        local bChanged = false

        if playerLog and (self.tradeDataFinish.send or self.tradeDataFinish.receive) then
            PLGuildBankClassic:debug("ExecuteTradeLog: using title: " .. (self.tradeLogTitle or "na"))

            if (self.tradeDataFinish.moneyOut and self.tradeDataFinish.moneyOut > 0) then
                PLGuildBankClassic:debug("TradeFinished: Money withdrawl  " .. tostring(self.tradeDataFinish.moneyOut))
                local logEntry = {}
                bChanged = true

                logEntry.name = self.tradeDataFinish.target
                logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                logEntry.source = PLGuildBankClassic.transactionSource.trade
                logEntry.type = PLGuildBankClassic.transactionTypes.money
                logEntry.quantity = 1
                logEntry.goldPerItem = self.tradeDataFinish.moneyOut
                logEntry.mode = PLGuildBankClassic.transactionModes.withdraw
                logEntry.title = self.tradeLogTitle

                if #playerLog > 0 then
                    table.insert(playerLog, 1, logEntry)
                else
                    playerLog[1] = logEntry
                end
            end 

            for i=1, #self.tradeDataFinish.send do
                -- items withdrawn by the target
                local checkItem = self.tradeDataFinish.send[i]
                local itemId = checkItem.itemId

                if itemId then
                    -- calculate log key - create only one log per itemid and recipient
                    local logKey = self.tradeDataFinish.target .. ":withdraw:" .. tostring(itemId)
                    
                    PLGuildBankClassic:debug("TradeFinished: Created logKey: " .. logKey)

                    if alreadyAdded[logKey] then
                        PLGuildBankClassic:debug("TradeFinished: Update existing log entry using key: " .. logKey )

                        alreadyAdded[logKey].quantity = alreadyAdded[logKey].quantity + (checkItem.quantity or 0)
                    else
                        local logEntry = {}
                        bChanged = true

                        logEntry.name = self.tradeDataFinish.target
                        logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                        logEntry.source = PLGuildBankClassic.transactionSource.trade
                        logEntry.type = PLGuildBankClassic.transactionTypes.item
                        logEntry.itemId = itemId
                        logEntry.quantity = checkItem.quantity or 0
                        logEntry.goldPerItem = PLGuildBankClassic:GetItemPrice(itemId, false)
                        logEntry.mode = PLGuildBankClassic.transactionModes.withdraw
                        logEntry.title = self.tradeLogTitle

                        if #playerLog > 0 then
                            table.insert(playerLog, 1, logEntry)
                        else
                            playerLog[1] = logEntry
                        end

                        PLGuildBankClassic:debug("TradeFinished: Create new log entry using key: " .. logKey)
                        alreadyAdded[logKey] = logEntry
                    end
                else
                    PLGuildBankClassic:debug("TradeFinished: could not get itemId of item " .. name)
                end
            end

            if (self.tradeDataFinish.moneyIn and self.tradeDataFinish.moneyIn > 0) then
                PLGuildBankClassic:debug("TradeFinished: Money disposal  " .. tostring(self.tradeDataFinish.moneyOut))
                local logEntry = {}
                bChanged = true

                logEntry.name = self.tradeDataFinish.target
                logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                logEntry.source = PLGuildBankClassic.transactionSource.trade
                logEntry.type = PLGuildBankClassic.transactionTypes.money
                logEntry.quantity = 1
                logEntry.goldPerItem = self.tradeDataFinish.moneyOut
                logEntry.mode = PLGuildBankClassic.transactionModes.disposal
                logEntry.title = self.tradeLogTitle

                if #playerLog > 0 then
                    table.insert(playerLog, 1, logEntry)
                else
                    playerLog[1] = logEntry
                end
            end 

            for i=1, #self.tradeDataFinish.receive do
                -- items withdrawn by the target
                local checkItem = self.tradeDataFinish.receive[i]
                local itemId = checkItem.itemId

                if itemId then
                    -- calculate log key - create only one log per itemid and recipient
                    local logKey = self.tradeDataFinish.target .. ":deposit:" .. tostring(itemId)
                    
                    PLGuildBankClassic:debug("TradeFinished: Created logKey: " .. logKey)

                    if alreadyAdded[logKey] then
                        PLGuildBankClassic:debug("TradeFinished: Update existing log entry using key: " .. logKey )

                        alreadyAdded[logKey].quantity = alreadyAdded[logKey].quantity + (checkItem.quantity or 0)
                    else
                        local logEntry = {}
                        bChanged = true

                        logEntry.name = self.tradeDataFinish.target
                        logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                        logEntry.source = PLGuildBankClassic.transactionSource.trade
                        logEntry.type = PLGuildBankClassic.transactionTypes.item
                        logEntry.itemId = itemId
                        logEntry.quantity = checkItem.quantity or 0
                        logEntry.goldPerItem = PLGuildBankClassic:GetItemPrice(itemId, false)
                        logEntry.mode = PLGuildBankClassic.transactionModes.deposit
                        logEntry.title = self.tradeLogTitle

                        if #playerLog > 0 then
                            table.insert(playerLog, 1, logEntry)
                        else
                            playerLog[1] = logEntry
                        end

                        PLGuildBankClassic:debug("TradeFinished: Create new log entry using key: " .. logKey)
                        alreadyAdded[logKey] = logEntry
                    end
                else
                    PLGuildBankClassic:debug("TradeFinished: could not get itemId of item " .. name)
                end
            end

            

            if bChanged then
                PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
                PLGuildBankClassic:UpdateVersionsInPublicNote()
                PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
            end
        end
    end

    PLGuildBankClassic:ResetTradeInfo()
end


function PLGuildBankClassic:MailboxOpened()
    self.mailData = {}
    self.sendMailData = nil
    self.mailTransactionLog = {}
    self.mailsTransaction = true
    self.mailItemLootStack = {}
    self.mailMoneyLootStack = {}
end

function PLGuildBankClassic:MailboxClosed()
    self.mailData = {}
    self.mailsTransaction = false

    if #self.mailTransactionLog > 0 and PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
        local playerLog = PLGuildBankClassic:GetLogByName(charServerName)

        if playerLog then
            -- item and money looting done during a mail session
            -- try to comulate items from receivers in order do not create 
            -- a log entry for each item or stack

            local logAddedCnt = 0
            local alreadyAdded = {}
            PLGuildBankClassic:debug("MailboxClosed: Processing " .. tostring(#self.mailTransactionLog) .. " mail transaction log entries")

            for i=1, #self.mailTransactionLog do
                local logEntry = self.mailTransactionLog[i]
                local logKey = logEntry.name .. ":" .. tostring(logEntry.type) .. ":" .. tostring(logEntry.mode) .. ":" .. tostring(logEntry.source)
                if logEntry.type == PLGuildBankClassic.transactionTypes.item then
                    logKey = logKey .. ":" .. logEntry.itemId
                end
                
                PLGuildBankClassic:debug("MailboxClosed: Created logKey: " .. logKey)

                if alreadyAdded[logKey] then
                    PLGuildBankClassic:debug("MailboxClosed: Update existing log entry using key: " .. logKey )

                    -- add quantity or gold looted to first entry found
                    if logEntry.type == PLGuildBankClassic.transactionTypes.item then
                        alreadyAdded[logKey].quantity = alreadyAdded[logKey].quantity + logEntry.quantity
                    else
                        alreadyAdded[logKey].goldPerItem = alreadyAdded[logKey].goldPerItem + logEntry.goldPerItem
                    end

                    if alreadyAdded[logKey].player == charName and charName ~= logEntry.player then
                        alreadyAdded[logKey].player = logEntry.player
                    end
                else
                    -- create a new log entry
                    if #playerLog > 0 then
                        table.insert(playerLog, 1, logEntry)
                    else
                        playerLog[1] = logEntry
                    end

                    PLGuildBankClassic:debug("MailboxClosed: Create new log entry using key: " .. logKey)
                    alreadyAdded[logKey] = logEntry
                end
            end

            PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
            PLGuildBankClassic:UpdateVersionsInPublicNote()
            PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
        end

    end

    self.mailTransactionLog = {}
    self.mailItemLootStack = {}
    self.mailMoneyLootStack = {}
    self.sendMailData = nil
end

function PLGuildBankClassic:MailboxItemClosed(event, itemIndex)
    if self.mailData and self.mailData[itemIndex] then
        self.lastClosedMailData = self.mailData[itemIndex]
        self.lastClosedMailIndex = itemIndex
    end
end

function PLGuildBankClassic:ScanMailbox()
    if self.scannngMails then
        return
    end

    if (InboxFrame and InboxFrame.openMailID) or (OpenAllMail and not OpenAllMail:IsEnabled()) then
        PLGuildBankClassic:debug("ScanMailbox: scanning mails SKIPPED - Mailframe opened or all mails read")
    end

    PLGuildBankClassic:debug("ScanMailbox: scanning mails")
    local numItems = GetInboxNumItems()
    self.scanningMails = true

    if self.lastClosedMailIndex and self.lastClosedMailIndex <= numItems and self.mailData then
        self.lastClosedMailData = self.mailData[self.lastClosedMailIndex]
    end

    self.mailData = {}

    PLGuildBankClassic:debug("ScanMailbox: nr of items: " .. (numItems or 0))
    for i=1, numItems do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, 
            textCreated, canReply, isGM = GetInboxHeaderInfo(i);

        local bodyText, texture, isTakeable, isInvoice = GetInboxText(i);

        self.mailData[i] = {}
        self.mailData[i].sender = sender
        self.mailData[i].subject = subject
        self.mailData[i].money = money
        self.mailData[i].cod = CODAmount
        self.mailData[i].hasItem = hasItem
        self.mailData[i].returned = wasReturned
        self.mailData[i].isGM = isGM

        self.mailData[i].body = bodyText
        self.mailData[i].isAHInvoice = isInvoice

        if isInvoice then
            local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(i)

            self.mailData[i].invoice = {}
            self.mailData[i].invoice.type = invoiceType --  ("buyer", "seller", or "seller_temp_invoice").
            self.mailData[i].invoice.itemName = itemName
            self.mailData[i].invoice.player = playerName 
            self.mailData[i].invoice.bid = bid
            self.mailData[i].invoice.buyout = buyout
            self.mailData[i].invoice.deposit = deposit
            self.mailData[i].invoice.fee = consignment
        end

        self.mailData[i].attachments = nil
        if hasItem then
            self.mailData[i].attachments = {}
            for a=1, ATTACHMENTS_MAX_RECEIVE do
                local name, itemTexture, quality, count, canUse = GetInboxItem(i, a)
                
                if name then
                    self.mailData[i].attachments[a] = {}
                    self.mailData[i].attachments[a].name = name
                    self.mailData[i].attachments[a].count = count
                    --self.mailData[i].attachments[a].quality = quality
                    self.mailData[i].attachments[a].itemLink = GetInboxItemLink(i,a)

                    if self.mailData[i].subject and name then
                        if (string.find(self.mailData[i].subject, name) or string.find(self.mailData[i].subject, "(" .. tostring(count or 1) .. ")"))then
                            -- override standard item-name-based subject info
                            -- in order to not add this to the logs
                            self.mailData[i].subject = nil
                        end
                    end
                else
                    self.mailData[i].attachments[a] = nil
                end
            end
        end

        --self:printMailData(self.mailData[i])
    end

    self.scanningMails = false
end

function PLGuildBankClassic:printMailData(mailData)
    PLGuildBankClassic:debug("Mail info:")
    PLGuildBankClassic:debug("   from: " .. (mailData.sender or "na") .. " subject: " .. (mailData.subject or "none") .. " returned: " .. (mailData.returned or "no"))
    if mailData.money then
        PLGuildBankClassic:debug("   sending money: " .. (mailData.money or "0"))
    end
    if mailData.hasItem then
        PLGuildBankClassic:debug("   Nr of attachments: " .. tostring(#mailData.attachments))
        for a=1, #mailData.attachments do
            if mailData.attachments[a] then
                PLGuildBankClassic:debug("       Att [" .. tostring(a) .. "]: name: " .. (mailData.attachments[a].name or "na"))
                PLGuildBankClassic:debug("       Att [" .. tostring(a) .. "]: count: " .. (mailData.attachments[a].count or "na"))
                --PLGuildBankClassic:debug("       Att [" .. tostring(a) .. "]: quality: " .. (mailData.attachments[a].quality or "na"))
                PLGuildBankClassic:debug("       Att [" .. tostring(a) .. "]: itemLink: " .. (mailData.attachments[a].itemLink or "na"))
            else
                -- this attachment has been taken or removed
            end
        end
    end
    if mailData.isAHInvoice then
        PLGuildBankClassic:debug("   AH Invoice: type:" .. (mailData.invoice.type or "na"))
        PLGuildBankClassic:debug("   AH Invoice: player:" .. (mailData.invoice.player or "na"))
        PLGuildBankClassic:debug("   AH Invoice: item:" .. (mailData.invoice.itemName or "na"))
        PLGuildBankClassic:debug("   AH Invoice: bid:" .. tostring(mailData.invoice.bid or -1))
        PLGuildBankClassic:debug("   AH Invoice: buyout:" .. tostring(mailData.invoice.buyout or -1))
        PLGuildBankClassic:debug("   AH Invoice: deposit:" .. tostring(mailData.invoice.deposit or -1))
        PLGuildBankClassic:debug("   AH Invoice: fee:" .. tostring(mailData.invoice.fee or -1))
    end
end

function PLGuildBankClassic:MailSuccessfullySent()
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic:debug("MailSuccessfullySent received")
        if self.sendMailData and self.sendMailData.attachments and #self.sendMailData.attachments > 0 then
            PLGuildBankClassic:debug("MailSuccessfullySent: processing sent mail data")
            local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))
            local playerLog = PLGuildBankClassic:GetLogByName(charServerName)

            local alreadyAdded = {}
            local bChanged = false

            if playerLog then
                for i=1, #self.sendMailData.attachments do
                    local itemId = self:GetItemIdFromLink(self.sendMailData.attachments[i].itemLink)

                    if itemId then
                        -- calculate log key - create only one log per itemid and recipient
                        local logKey = self.sendMailData.recipient .. ":" .. tostring(itemId)
                        
                        PLGuildBankClassic:debug("MailSuccessfullySent: Created logKey: " .. logKey)

                        if alreadyAdded[logKey] then
                            PLGuildBankClassic:debug("MailSuccessfullySent: Update existing log entry using key: " .. logKey )

                            alreadyAdded[logKey].quantity = alreadyAdded[logKey].quantity + (self.sendMailData.attachments[i].count or 0)
                        else
                            local logEntry = {}
                            bChanged = true

                            logEntry.name = self.sendMailData.recipient
                            logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
                            logEntry.source = PLGuildBankClassic.transactionSource.mail
                            logEntry.type = PLGuildBankClassic.transactionTypes.item
                            logEntry.itemId = itemId
                            logEntry.quantity = self.sendMailData.attachments[i].count or 0
                            logEntry.goldPerItem = PLGuildBankClassic:GetItemPrice(itemId, false)
                            logEntry.mode = PLGuildBankClassic.transactionModes.withdraw
                            logEntry.title = PLGuildBankClassic:GetNormalizedLogTitleFromSubject(self.sendMailData.subject)

                            if #playerLog > 0 then
                                table.insert(playerLog, 1, logEntry)
                            else
                                playerLog[1] = logEntry
                            end

                            PLGuildBankClassic:debug("MailSuccessfullySent: Create new log entry using key: " .. logKey)
                            alreadyAdded[logKey] = logEntry
                        end
                    else
                        PLGuildBankClassic:debug("MailSuccessfullySent: could not get itemId of item " .. name)
                    end
                end
            end

            if bChanged then
                PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
                PLGuildBankClassic:UpdateVersionsInPublicNote()
                PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
            end
        end
    end
end

function PLGuildBankClassic:LogPlayerGotItem(event, characterName, itemId, itemQuantity)
    PLGuildBankClassic:debug("LogPlayerGotItem: " .. characterName .. " itemId: " .. tostring(itemId) .. " quantity: " .. tostring(itemQuantity))

    if self.ignoreLootItemMessage then
        PLGuildBankClassic:debug("LogPlayerGotItem: ignorint loot item message")
        return
    end

    if PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
        local playerLog = PLGuildBankClassic:GetLogByName(charServerName)
        
        if playerLog then
            local added = false
            local logEntry = {}

            logEntry.name = charName
            logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
            logEntry.source = PLGuildBankClassic.transactionSource.loot
            logEntry.type = PLGuildBankClassic.transactionTypes.item
            logEntry.itemId = itemId
            logEntry.quantity = itemQuantity
            logEntry.goldPerItem = PLGuildBankClassic:GetItemPrice(itemId, false)
            logEntry.mode = PLGuildBankClassic.transactionModes.deposit

            if PLGuildBankClassic.Events.atMailbox then
                logEntry.source = PLGuildBankClassic.transactionSource.mail

                -- todo check cod or auction
                local openMailData = PLGuildBankClassic:TryGetOpenMailData()

                if self.mailItemLootStack and #self.mailItemLootStack > 0 then
                    PLGuildBankClassic:debug("Use mail from item loot stack")
                    openMailData = self.mailItemLootStack[1]
                    table.remove(self.mailItemLootStack, 1)
                else
                    PLGuildBankClassic:debug("Use item loot mail stack has " .. tostring(#self.mailItemLootStack) .. " mails")
                end

                if openMailData then
                    logEntry.name = openMailData.sender or charName
                    logEntry.title = openMailData.subject or nil

                    if PLGuildBankClassic:IsAuctionHouseSender(openMailData.sender) then
                        logEntry.source = PLGuildBankClassic.transactionSource.auction
                        logEntry.name = charName
                    end

                    if PLGuildBankClassic:IsAuctionSuccessful(logEntry.title) then
                        logEntry.title = L["Auction won"]
                    elseif PLGuildBankClassic:IsAuctionCancelled(logEntry.title) then
                        logEntry.title = L["Auction aborted"]
                    elseif PLGuildBankClassic:IsAuctionExpired(logEntry.title) then
                        logEntry.title = L["Auction expired"]
                    end
                else
                    PLGuildBankClassic:debug("Mail " .. tostring(mailIndex) .. " not found")
                end

            elseif PLGuildBankClassic.Events.atVendor then
                logEntry.source = PLGuildBankClassic.transactionSource.vendor
            elseif PLGuildBankClassic.Events.atTrade then
                logEntry.source = PLGuildBankClassic.transactionSource.directTrade
            elseif PLGuildBankClassic.Events.atAuctionHouse then
                logEntry.source = PLGuildBankClassic.transactionSource.auction
            end

            if PLGuildBankClassic.mailsTransaction then
                if #self.mailTransactionLog > 0 then
                    table.insert(self.mailTransactionLog, 1, logEntry)
                else
                    self.mailTransactionLog[1] = logEntry
                end
            else
                if #playerLog > 0 then
                    table.insert(playerLog, 1, logEntry)
                else
                    playerLog[1] = logEntry
                end

                PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
                PLGuildBankClassic:UpdateVersionsInPublicNote()
                PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
            end
        end
    end
end

function PLGuildBankClassic:LogPlayerMoneyGainOrLoss(event, characterName, value, gainedOrLost, valueVersion)
    PLGuildBankClassic:debug("LogPlayerMoneyGainOrLoss: " .. (characterName or "na") .. " value: " .. tostring(value or 0) .. " gl: " .. tostring(gainedOrLost or 0))

    if PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
        local playerLog = PLGuildBankClassic:GetLogByName(charServerName)
        local moneySplitMailCost = nil

        if playerLog then
            local added = false
            local logEntry = {}
            logEntry.name = charName
            logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
            logEntry.source = PLGuildBankClassic.transactionSource.loot
            logEntry.type = PLGuildBankClassic.transactionTypes.money
            logEntry.quantity = 1 


            --PLGuildBankClassic.transactionSource = {
            --    directTrade = 0,    -- item or money was player-traded
            --    mail = 1,           -- item or money was sent/received via mail
            --    cod = 2,            -- money sent because of a COD
            --    auction = 3,        -- money item spend/received because of an auction
            --    vendor = 4,         -- money spent, item looted at the vendor
            --    enchanting = 5,     -- item was withdrawn (destroyed) because of disentchanting. materials gained through disentchanting, materials withdrawn because of enchanting an item
            --    loot = 10,          -- money or item looted
            --    destroy = 98,       -- item has been destroyed
            --    other = 99          -- other sources (e.g. mail sending costs)
            --}

            if PLGuildBankClassic.Events.atMailbox then
                logEntry.source = PLGuildBankClassic.transactionSource.mail

                -- todo check cod or auction
                local openMailData = PLGuildBankClassic:TryGetOpenMailData()

                if self.mailMoneyLootStack and #self.mailMoneyLootStack > 0 then
                    PLGuildBankClassic:debug("Use mail from money loot stack")
                    openMailData = self.mailMoneyLootStack[1]
                    table.remove(self.mailMoneyLootStack, 1)
                else
                    PLGuildBankClassic:debug("Use money loot mail stack has " .. tostring(#self.mailMoneyLootStack) .. " mails")
                end

                if openMailData then
                    logEntry.name = openMailData.sender or charName
                    logEntry.title = openMailData.subject or nil
                    
                    if PLGuildBankClassic:IsAuctionHouseSender(openMailData.sender) then
                        logEntry.source = PLGuildBankClassic.transactionSource.auction
                        logEntry.name = charName

                        if PLGuildBankClassic:IsAuctionSuccessful(openMailData.subject) then
                            logEntry.title = L["Auction income"]

                            if gainedOrLost < 0 then
                                logEntry.title = L["Auction expense"]
                            end
                        elseif PLGuildBankClassic:IsAuctionOutbid(openMailData.subject) then
                            logEntry.title = L["Auction outbid return"]
                        end
                    end

                    if gainedOrLost < 0 and openMailData.cod then
                        logEntry.source = PLGuildBankClassic.transactionSource.cod
                    end
                else
                    PLGuildBankClassic:debug("Opened mail data not found")
                end

                if gainedOrLost < 0 and self.sendMailData and self.sendMailData.money > 0 and (self.sendMailData.money + self.sendMailData.cost) == (gainedOrLost*-1)   then
                    PLGuildBankClassic:debug("Using sent mail data for money withdrawel")
                    -- set the recipient for withdrawel
                    logEntry.name = self.sendMailData.recipient
                    logEntry.title = self.sendMailData.subject
                    logEntry.title = PLGuildBankClassic:GetNormalizedLogTitleFromSubject(self.sendMailData.subject)

                    -- subtract mailing costs - need extra log entry
                    gainedOrLost = gainedOrLost + self.sendMailData.cost
                    moneySplitMailCost = (self.sendMailData.cost * -1)
                    if moneySplitMailCost == 0 then
                        moneySplitMailCost = nil
                    end
                end

            elseif PLGuildBankClassic.Events.atVendor then
                logEntry.source = PLGuildBankClassic.transactionSource.vendor
            elseif PLGuildBankClassic.Events.atTrade then
                logEntry.source = PLGuildBankClassic.transactionSource.directTrade
            elseif PLGuildBankClassic.Events.atAuctionHouse then
                logEntry.source = PLGuildBankClassic.transactionSource.auction
            end

            if self.tradeData and (gainedOrLost == self.tradeData.moneyIn) then
                logEntry.source = PLGuildBankClassic.transactionSource.directTrade
                logEntry.name = self.tradeData.target
            elseif self.tradeData and ((gainedOrLost*-1) == self.tradeData.moneyOut) then
                logEntry.source = PLGuildBankClassic.transactionSource.directTrade
                logEntry.name = self.tradeData.target
            end
                
            logEntry.goldPerItem = gainedOrLost
            if logEntry.goldPerItem < 0 then
                logEntry.goldPerItem = logEntry.goldPerItem * -1
            end

            if gainedOrLost > 0 then
                logEntry.mode = PLGuildBankClassic.transactionModes.deposit
                added = true
            else --if gainedOrLost < 0 then
                logEntry.mode = PLGuildBankClassic.transactionModes.withdraw
                added = true
            end

            if added then
                if PLGuildBankClassic.mailsTransaction then
                    if #self.mailTransactionLog > 0 then
                        table.insert(self.mailTransactionLog, 1, logEntry)
                    else
                        self.mailTransactionLog[1] = logEntry
                    end
                else
                    if #playerLog > 0 then
                        table.insert(playerLog, 1, logEntry)
                    else
                        playerLog[1] = logEntry
                    end
    
                    PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
                    PLGuildBankClassic:UpdateVersionsInPublicNote()
                    PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName, PLGuildBankClassic.atBankChar.logVersion)
                end
            end

            if moneySplitMailCost ~= nil then
                -- log mail costs in case of money sent as separate entry
                self:LogPlayerMoneyGainOrLoss(event, characterName, value, moneySplitMailCost, PLGuildBankClassic.atBankChar.logVersion)
            end
        end
    end 
end