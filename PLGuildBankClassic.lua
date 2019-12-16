local _, PLGuildBankClassic = ...
PLGuildBankClassic = LibStub("AceAddon-3.0"):NewAddon(PLGuildBankClassic, "PLGuildBankClassic", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

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
        showValueEstimationInLogs = true
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

    self.scanningMails = false
    self.mailsTransaction = false
    self.mailData = {}
    self.mailTransactionLog = {}

    self:RefreshPlayerSpellIconInfo()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
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
end

function PLGuildBankClassic:HandleSlash(cmd)
	if strtrim(cmd) == "show" then
		self.guildVault:Show()
	else
		self:Print("Available Commands:")
		self:Print(" /plgb show: Show the guild bank")
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

            PLGuildBankClassic.Events:Fire("PLGBC_EVENT_BANKCHAR_MONEYCHANGED", charServerName, GetMoney(), diff, PLGuildBankClassic.atBankChar.moneyVersion)
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
        PLGuildBankClassic.Events:Fire("PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED", charServerName, hasCachedData, PLGuildBankClassic.atBankChar.inventoryVersion)
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

    if self.atBankChar ~= nil then
        PLGuildBankClassic:debug("UpdateAtBankCharState: Logged in with bank char")
        self.Events:Fire("PLGBC_EVENT_BANKCHAR_ENTERED_WORLD")
    end
end

function PLGuildBankClassic:AcceptOrDeclineState(state)
    if PLGuildBankClassic.atBankChar then
        if state == "accept" then
            PLGuildBankClassic.atBankChar.acceptState = 1
        elseif state == "decline" then
            PLGuildBankClassic.atBankChar.acceptState = -1
        end

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

function PLGuildBankClassic:MailboxOpened()
    self.mailData = {}
    self.mailTransactionLog = {}
    self.mailsTransaction = true
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
            PLGuildBankClassic:debug("Processing " .. tostring(#self.mailTransactionLog) .. " mail transaction log entries")

            for i=1, #self.mailTransactionLog do
                local logEntry = self.mailTransactionLog[i]
                local logKey = logEntry.name .. ":" .. tostring(logEntry.type) .. ":" .. tostring(logEntry.mode) .. ":" .. tostring(logEntry.source)
                if logEntry.type == PLGuildBankClassic.transactionTypes.item then
                    logKey = logKey .. ":" .. logEntry.itemId
                end
                
                PLGuildBankClassic:debug("Created logKey: " .. logKey)

                if alreadyAdded[logKey] then
                    PLGuildBankClassic:debug("Update existing log entry using key: " .. logKey )

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

                    PLGuildBankClassic:debug("Create new log entry using key: " .. logKey)
                    alreadyAdded[logKey] = logEntry
                end
            end

            PLGuildBankClassic.atBankChar.logVersion = PLGuildBankClassic:GetTimestamp()
            PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName)
        end

    end

    self.mailTransactionLog = {}
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


function PLGuildBankClassic:LogPlayerGotItem(event, characterName, itemId, itemQuantity)
    PLGuildBankClassic:debug("LogPlayerGotItem: " .. characterName .. " itemId: " .. tostring(itemId) .. " quantity: " .. tostring(itemQuantity))

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
 
                 if openMailData then
                    logEntry.name = openMailData.sender or charName
                    logEntry.title = openMailData.subject or nil
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
                PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName)
            end
        end
    end
end

function PLGuildBankClassic:LogPlayerMoneyGainOrLoss(event, characterName, value, gainedOrLost, valueVersion)
    PLGuildBankClassic:debug("LogPlayerMoneyGainOrLoss: " .. characterName .. " value: " .. tostring(value) .. " gl: " .. tostring(gainedOrLost))

    if PLGuildBankClassic:IsGuildBankChar() then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
        local playerLog = PLGuildBankClassic:GetLogByName(charServerName)
        
        if playerLog then
            local added = false
            local logEntry = {}
            logEntry.name = charName
            logEntry.timestamp = PLGuildBankClassic:GetTimestamp()
            logEntry.source = PLGuildBankClassic.transactionSource.loot
            logEntry.type = PLGuildBankClassic.transactionTypes.money
            logEntry.goldPerItem = gainedOrLost
            if logEntry.goldPerItem < 0 then
                logEntry.goldPerItem = logEntry.goldPerItem * -1
            end
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

                if openMailData then
                    logEntry.name = openMailData.sender or charName
                    logEntry.title = openMailData.subject or nil

                    if gainedOrLost < 0 and openMailData.cod then
                        logEntry.source = PLGuildBankClassic.transactionSource.cod
                    elseif string.match(openMailData.sender, L["(Horde|Alliance)+ Auction House"]) then
                        logEntry.source = PLGuildBankClassic.transactionSource.auction
                        logEntry.name = charName
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
                    PLGuildBankClassic.Events:Fire("PLGBC_GUILD_LOG_UPDATED", charServerName)
                end
            end
        end
    end 
end