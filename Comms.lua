local _, PLGuildBankClassic = ...

local Comms = PLGuildBankClassic:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")
local Events = PLGuildBankClassic:GetModule("Events")

local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibCompress = LibStub:GetLibrary("LibCompress")
local LibCompressAddonEncodeTable = LibCompress:GetAddonEncodeTable()

local COMM_PREFIX_COMPRESSED_MESSAGE = "PLGBCCmprs"
local COMM_PREFIX_CLEARTEXT_MESSAGE = "PLGBCClear"

local COMM_CMD_BUILDCHECK               = "PLGBCBuildCheck"
local COMM_CMD_QUERYVERSIONS            = "PLGBCQVersions"
local COMM_CMD_REQUESTVERSIONS          = "PLGBCRVersions"
local COMM_CMD_SENDCONFIG               = "PLGBCSendConfig"
local COMM_CMD_SENDCHARCONFIG           = "PLGBCSendCharConfig"
local COMM_CMD_SENDINVENTORY            = "PLGBCSendInventory"
local COMM_CMD_SENDMONEY                = "PLGBCSendMoney"
local COMM_CMD_SENDLOG                  = "PLGBCSendLog"
local COMM_CMD_QUERY_BANKCHARONLINE     = "PLGBCQueryCharOnline"
local COMM_CMD_RESPONSE_BANKCHARONLINE  = "PLGBCResponseCharOnline"

PLGuildBankClassic.Comms = Comms
Comms.KnownVersions = {}
Comms.KnownBankCharOwners = {}
Comms.RequestedVersions = {}
Comms.SendStack = {}

-- limit log entries to broadcast to latest 250
local MAX_LOG_ENTRIES_TO_SEND = 250

local DEFAULT_LOG_SEND_TRIGGER_SEC = 5
local DEFAULT_INVENTORY_SEND_TRIGGER_SEC = 5
local DEFAULT_MONEY_SEND_TRIGGER_SEC = 5
local DEFAULT_VREQUEST_SEND_TRIGGER_SEC = 5

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX_COMPRESSED_MESSAGE, "OnCommReceived")
    self:RegisterComm(COMM_PREFIX_CLEARTEXT_MESSAGE, "OnCommReceived")

    Comms.comm = {}
    Comms.comm[COMM_CMD_BUILDCHECK] = Comms.BuildCheck
    Comms.comm[COMM_CMD_QUERYVERSIONS] = Comms.QueryVersions
    Comms.comm[COMM_CMD_REQUESTVERSIONS] = Comms.RequestVersions
    Comms.comm[COMM_CMD_SENDCONFIG] = Comms.ReceiveConfig
    Comms.comm[COMM_CMD_SENDCHARCONFIG] = Comms.ReceiveCharConfig
    Comms.comm[COMM_CMD_SENDINVENTORY] = Comms.ReceiveInventory
    Comms.comm[COMM_CMD_SENDMONEY] = Comms.ReceiveMoney
    Comms.comm[COMM_CMD_SENDLOG] = Comms.ReceiveLog
    Comms.comm[COMM_CMD_QUERY_BANKCHARONLINE] = Comms.QueryBankCharOnline
    Comms.comm[COMM_CMD_RESPONSE_BANKCHARONLINE] = Comms.ResponseBankCharOnline


    Events.Register(self, "PLGBC_EVENT_CONFIG_CHANGED")
    Events.Register(self, "PLGBC_EVENT_CHAR_CONFIG_CHANGED")
    Events.Register(self, "PLGBC_EVENT_BANKCHAR_MONEYCHANGED")
    Events.Register(self, "PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED")
    Events.Register(self, "PLGBC_GUILD_LOG_UPDATED")
end

-----------------------------------------------------------------------
-- Command receivers

function Comms:OnCommReceived(prefix, message, distribution, sender)
    PLGuildBankClassic:debug("Receiving comms with prefix '" .. (prefix or "nil") .. "' from player '" .. (sender or "nil") .. "' ...")
    if prefix and sender ~= UnitName("player") then
        if prefix == COMM_PREFIX_COMPRESSED_MESSAGE then
            decoded = LibCompress:Decompress(LibCompressAddonEncodeTable:Decode(message))
            local success, deserialized = LibAceSerializer:Deserialize(decoded);
            if success then
                PLGuildBankClassic:debug("Subcommand '" .. (deserialized.command or "nil") .. "'")
                self:RouteCommand(sender, deserialized.command, deserialized)
            else
                print(deserialized)  -- error reporting if string doesn't get deserialized correctly
            end
        elseif prefix == COMM_PREFIX_CLEARTEXT_MESSAGE then
            local success, deserialized = LibAceSerializer:Deserialize(message);
            if success then
                PLGuildBankClassic:debug("Subcommand '" .. (deserialized.command or "nil") .. "'")
                self:RouteCommand(sender, deserialized.command, deserialized.data)
            else
                print(deserialized)  -- error reporting if string doesn't get deserialized correctly
            end
        else
            PLGuildBankClassic:debug("Error - unknown message receivied!")
        end
    else
        PLGuildBankClassic:debug("Ignore comms because prefix is null or sent by own")
    end
end

function Comms:RouteCommand(sender,command, data)
    if not ok then
        return
    elseif Comms.comm[command] then
        Comms.comm[command](sender, data)
    end
end

function Comms:BuildVersionsPacket()
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 
    local versionData = {}
    versionData.configVersion = 0
    versionData.charConfigVersion = 0

    if guildConfig then
        versionData.configVersion = guildConfig.configTimestamp
        versionData.charConfigVersion = guildConfig.cahrConfigTimestamp
        versionData.bankChars = {}
        for idx, char in ipairs(guildConfig.bankChars) do
            versionData.bankChars[char] = {}
            versionData.bankChars[char].inventoryVersion = guildConfig.bankChars[char].inventoryVersion
            versionData.bankChars[char].logVersion = guildConfig.bankChars[char].logVersion
            versionData.bankChars[char].moneyVersion = guildConfig.bankChars[char].moneyVersion
            versionData.bankChars[char].dataVersion = guildConfig.bankChars[char].modifiedAt
        end
    end

    return versionData
end

-- ------------------------------------------------------------------
-- merging known version information with full or partial version data of sender
--

local function MergeKnownVersionData(sender, data)
    if not Comms.KnownVersions[sender] then
        Comms.KnownVersions[sender] = data
    else
        Comms.KnownVersions[sender].configVersion = data.configVersion or Comms.KnownVersions[sender].configVersion
        Comms.KnownVersions[sender].charConfigVersion = data.charConfigVersion or Comms.KnownVersions[sender].charConfigVersion

        if data.bankChars then
            if not Comms.KnownVersions[sender].bankChars then
                Comms.KnownVersions[sender].bankChars = data.bankChars
                return
            end

            for char, vdata in pairs(data.bankChars) do
                if not Comms.KnownVersions[sender].bankChars[char] then
                    Comms.KnownVersions[sender].bankChars[char] = data.bankChars[char]
                else
                    Comms.KnownVersions[sender].bankChars[char].inventoryVersion = data.bankChars[char].inventoryVersion or Comms.KnownVersions[sender].bankChars[char].inventoryVersion
                    Comms.KnownVersions[sender].bankChars[char].logVersion = data.bankChars[char].logVersion or Comms.KnownVersions[sender].bankChars[char].logVersion
                    Comms.KnownVersions[sender].bankChars[char].moneyVersion = data.bankChars[char].moneyVersion or Comms.KnownVersions[sender].bankChars[char].moneyVersion
                    Comms.KnownVersions[sender].bankChars[char].dataVersion = data.bankChars[char].dataVersion or Comms.KnownVersions[sender].bankChars[char].dataVersion
                end
            end
        end
    end
end

function Comms:QueryVersions(sender, data)
    MergeKnownVersionData(sender, data)

    local myVersionsData = Comms:BuildVersionsPacket()
    local requestVersionData = {}
    local doRequestVersion = false
    local doSendVersion = false
    local strippedVersionQuery = {} -- will only contain versions where this account has greater versions than the requested once

    if data.configVersion ~= nil and data.configVersion > myVersionsData.configVersion and (Comms.RequestedVersions.configVersion == nil or Comms.RequestedVersions.configVersion < data.configVersion) then
        -- request new config data
        -- do not check bank chars now, because we will receive new 
        requestVersionData.configVersion = data.configVersion
        doRequestVersion = true
        Comms.RequestedVersions.configVersion = requestVersionData.configVersion
    end

    if data.configVersion ~= nil and data.configVersion < myVersionsData.configVersion then
        -- the requested ver
        doSendVersion = true
    end


    if data.charConfigVersion ~= nil and data.charConfigVersion > myVersionsData.charConfigVersion and (Comms.RequestedVersions.charConfigVersion == nil or Comms.RequestedVersions.charConfigVersion < data.charConfigVersion) then
        -- request new config data
        -- do not check bank chars now, because we will receive new 
        requestVersionData.charConfigVersion = data.charConfigVersion
        doRequestVersion = true
        Comms.RequestedVersions.charConfigVersion = requestVersionData.charConfigVersion
    end

    if data.charConfigVersion ~= nil and data.charConfigVersion < myVersionsData.charConfigVersion then
        -- the requested ver
        doSendVersion = true
    end

    for charR, valR in pairs(data.bankChars) do
        local foundCharLocally = false
        for charL, valL in pairs(myVersionsData.bankChars) do
            if charR == charL then
                myVersionsData.bankChars[charL].found = true
                foundCharLocally = true

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].inventoryVersion ~= nil and data.bankChars[charR].inventoryVersion > myVersionsData.bankChars[charR].inventoryVersion and (Comms.RequestedVersions.bankChars == nil or Comms.RequestedVersions.bankChars[charR] == nil or Comms.RequestedVersions.bankChars[charR].inventoryVersion < data.bankChars[charR].inventoryVersion) then
                    if requestVersionData.bankChars[charR] == nil then
                        requestVersionData.bankChars[charR] = {}
                    end

                    -- request a version higher or equal the currently sent version
                    requestVersionData.bankChars[charR].inventoryVersion = data.bankChars[charR].inventoryVersion
                    doRequestVersion = true

                    if Comms.RequestedVersions.bankChars == nil then
                        Comms.RequestedVersions.bankChars = {}
                    end
                    if Comms.RequestedVersions.bankChars[charR] == nil then
                        Comms.RequestedVersions.bankChars[charR] = {}
                    end
                    Comms.RequestedVersions.bankChars[charR].inventoryVersion = data.bankChars[charR].inventoryVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].inventoryVersion ~= nil and data.bankChars[charR].inventoryVersion < myVersionsData.bankChars[charR].inventoryVersion then
                    doSendVersion = true
                    if strippedVersionQuery.bankChars[charR] == nil then
                        strippedVersionQuery.bankChars[charR] = {}
                    end
                    -- only sent this version info in the query version data
                    -- in order to avoid version ping-pong
                    strippedVersionQuery.bankChars[charR].inventoryVersion = VersionsData.bankChars[charR].inventoryVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].logVersion ~= nil and data.bankChars[charR].logVersion > myVersionsData.bankChars[charR].logVersion and (Comms.RequestedVersions.bankChars == nil or Comms.RequestedVersions.bankChars[charR] == nil or Comms.RequestedVersions.bankChars[charR].logVersion < data.bankChars[charR].logVersion) then
                    if requestVersionData.bankChars[charR] == nil then
                        requestVersionData.bankChars[charR] = {}
                    end

                    -- request a version higher or equal the currently sent version
                    requestVersionData.bankChars[charR].logVersion = data.bankChars[charR].logVersion
                    doRequestVersion = true

                    if Comms.RequestedVersions.bankChars == nil then
                        Comms.RequestedVersions.bankChars = {}
                    end
                    if Comms.RequestedVersions.bankChars[charR] == nil then
                        Comms.RequestedVersions.bankChars[charR] = {}
                    end
                    Comms.RequestedVersions.bankChars[charR].logVersion = data.bankChars[charR].logVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].logVersion ~= nil and data.bankChars[charR].logVersion < myVersionsData.bankChars[charR].logVersion then
                    doSendVersion = true
                    if strippedVersionQuery.bankChars[charR] == nil then
                        strippedVersionQuery.bankChars[charR] = {}
                    end
                    -- only sent this version info in the query version data
                    -- in order to avoid version ping-pong
                    strippedVersionQuery.bankChars[charR].logVersion = VersionsData.bankChars[charR].logVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].moneyVersion ~= nil and data.bankChars[charR].moneyVersion > myVersionsData.bankChars[charR].moneyVersion and (Comms.RequestedVersions.bankChars == nil or Comms.RequestedVersions.bankChars[charR] == nil or Comms.RequestedVersions.bankChars[charR].moneyVersion < data.bankChars[charR].moneyVersion) then
                    if requestVersionData.bankChars[charR] == nil then
                        requestVersionData.bankChars[charR] = {}
                    end

                    -- request a version higher or equal the currently sent version
                    requestVersionData.bankChars[charR].moneyVersion = data.bankChars[charR].moneyVersion
                    doRequestVersion = true

                    if Comms.RequestedVersions.bankChars == nil then
                        Comms.RequestedVersions.bankChars = {}
                    end
                    if Comms.RequestedVersions.bankChars[charR] == nil then
                        Comms.RequestedVersions.bankChars[charR] = {}
                    end
                    Comms.RequestedVersions.bankChars[charR].moneyVersion = data.bankChars[charR].moneyVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].moneyVersion ~= nil and data.bankChars[charR].moneyVersion < myVersionsData.bankChars[charR].moneyVersion then
                    doSendVersion = true
                    if strippedVersionQuery.bankChars[charR] == nil then
                        strippedVersionQuery.bankChars[charR] = {}
                    end
                    -- only sent this version info in the query version data
                    -- in order to avoid version ping-pong
                    strippedVersionQuery.bankChars[charR].moneyVersion = VersionsData.bankChars[charR].moneyVersion
                end


                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].dataVersion ~= nil and data.bankChars[charR].dataVersion > myVersionsData.bankChars[charR].dataVersion and (Comms.RequestedVersions.bankChars == nil or Comms.RequestedVersions.bankChars[charR] == nil or Comms.RequestedVersions.bankChars[charR].dataVersion < data.bankChars[charR].dataVersion) then
                    if requestVersionData.bankChars[charR] == nil then
                        requestVersionData.bankChars[charR] = {}
                    end

                    -- request a version higher or equal the currently sent version
                    requestVersionData.bankChars[charR].dataVersion = data.bankChars[charR].dataVersion
                    doRequestVersion = true

                    if Comms.RequestedVersions.bankChars == nil then
                        Comms.RequestedVersions.bankChars = {}
                    end
                    if Comms.RequestedVersions.bankChars[charR] == nil then
                        Comms.RequestedVersions.bankChars[charR] = {}
                    end
                    Comms.RequestedVersions.bankChars[charR].dataVersion = data.bankChars[charR].dataVersion
                end

                if data.bankChars[charR].isDeleted ~= true and data.bankChars[charR].dataVersion ~= nil and data.bankChars[charR].dataVersion < myVersionsData.bankChars[charR].dataVersion then
                    doSendVersion = true
                    if strippedVersionQuery.bankChars[charR] == nil then
                        strippedVersionQuery.bankChars[charR] = {}
                    end
                    -- only sent this version info in the query version data
                    -- in order to avoid version ping-pong
                    strippedVersionQuery.bankChars[charR].dataVersion = VersionsData.bankChars[charR].dataVersion
                end
            end
        end

        if foundCharLocally == false then
            if requestVersionData.bankChars[charR] == nil then
                requestVersionData.bankChars[charR] = {}
            end

            -- request all data from this bank char
            requestVersionData.bankChars[charR].moneyVersion = 0
            requestVersionData.bankChars[charR].logVersion = 0
            requestVersionData.bankChars[charR].inventoryVersion = 0
            doRequestVersion = true
        end
    end

    if doRequestVersion == true then
        -- remove current request versions queue if any
        -- just to make sure not sending multiple requests within the trigger frame
        Comms:ScheduleSendComms(COMM_CMD_REQUESTVERSIONS, requestVersionData, nil)
        -- add request version sent queue delayed
        Comms:ScheduleSendComms(COMM_CMD_REQUESTVERSIONS, requestVersionData, DEFAULT_VREQUEST_SEND_TRIGGER_SEC)
        --Comms:SendData(COMM_CMD_REQUESTVERSIONS, requestVersionData)
    end

    if doSendVersion == true then
        -- if any of the received data is LOWER than the data I have
        -- send a version info in order to let the client request data
        Comms:SendData(COMM_CMD_QUERYVERSIONS, strippedVersionQuery)
    end
end

function Comms:RequestVersions(sender, data)
    local haveDataWhichShouldBeSended = Comms:BuildSendStack(data)

    if not haveDataWhichShouldBeSended then
        return
    end
    
    -- algorithm selecting who should send data
    -- for characters - prio1 bank char
    if Comms.SendStack.configVersion ~= nil and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("config", Comms.SendStack.configVersion)) then
        Comms:PLGBC_EVENT_CONFIG_CHANGED("PLGBC_EVENT_CONFIG_CHANGED", Comms.SendStack.configVersion)
    end
    Comms.SendStack.configVersion = nil 

    if Comms.SendStack.charConfigVersion ~= nil and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("charconfig", Comms.SendStack.charConfigVersion)) then
        Comms:PLGBC_EVENT_CHAR_CONFIG_CHANGED("PLGBC_EVENT_CHAR_CONFIG_CHANGED", Comms.SendStack.charConfigVersion)
    end
    Comms.SendStack.charConfigVersion = nil

    if Comms.SendStack.bankChars ~= nil then
        for charR, valR in pairs(Comms.SendStack.bankChars) do
            if PLGuildBankClassic:CharacterOwnedByAccount(charR) then
                -- i'm owning this bank char so I will send the data
                if valR.inventoryVersion ~= nil then
                    -- send inventory
                    Comms:ScheduleSendInventory(charR, valR.inventoryVersion)
                end

                if valR.moneyVersion ~= nil then
                    -- send money
                    Comms:ScheduleSendInventory(charR, nil, valR.moneyVersion)
                end

                if valR.logVersion ~= nil then
                    -- send log
                    Comms:ScheduleSendLog(charR, valR.logVersion)
                end

                --if valR.dataVersion ~= nil then 
                    -- TODO: send config portion as a single record per character!
                --end

            elseif Comms.KnownBankCharOwners[charR] ~= nil and PLGuildBankClassic:IsGuildPlayerOnline(Comms.KnownBankCharOwners[charR]) then
                -- the bank char owner is online
                -- he/she should send data
                -- do not send
                PLGuildBankClassic:debug("Skip sending data for character '" .. charR .. "' since '" .. Comms.KnownBankCharOwners[charR] .. "' is online and owning the char!")
            else
                -- select one character with the same version
                -- by guild rank, name and online status
                if valR.inventoryVersion ~= nil and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("inventory", valR.inventoryVersion)) then
                    -- send inventory
                    Comms:ScheduleSendInventory(charR, valR.inventoryVersion)
                end

                if valR.moneyVersion ~= nil  and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("money", valR.inventoryVersion)) then
                    -- send money
                    Comms:ScheduleSendInventory(charR, nil, valR.moneyVersion)
                end

                if valR.logVersion ~= nil  and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("log", valR.inventoryVersion)) then
                    -- send log
                    Comms:ScheduleSendLog(charR, valR.logVersion)
                end

                --if valR.dataVersion ~= nil  and Comms:ShouldISend(Comms:ListOfCharsWhichMaySendData("data", valR.inventoryVersion)) then 
                    -- TODO: send config portion as a single record per character!
                --end
            end

            -- delete sendstack
            -- will be rebuild if additional version requests received
            Comms.SendStack.bankChars[charR] = nil
        end
    end
end

-- ---------------------------------------------------------------------------------------
-- takes a list of other characters which have the same data version
-- select a player based on online-status, guild rank and name which will send the data
function Comms:ShouldISend(otherCharacters)
    -- algorithm electing one character to send data
    -- prio 1 - is online
    -- prio 2 - guild rank
    -- prio 3 - name sort
    local myRankIndex = PLDKPBids:GetGuildRankIndex(UnitName("player"))

    if otherCharacters and #otherCharacters > 0 then
        for idx, char in ipairs(otherCharacters) then
            local otherRankIndex = PLDKPBids:GetGuildRankIndex(char)

            if PLDKPBids:IsGuildPlayerOnline(char) and (otherRankIndex < myRankIndex or char < UnitName("player")) then
                return false
            end
        end
    end

    return true
end


-- ---------------------------------------------------------------------------------------
-- cross check requested versions with self owning versions and build a send stack
-- which versions of which data should/can be sent by this account
-- algorithm for account choosing will be done afterwards
function Comms:BuildSendStack(data)
    if data == nil then
        -- clear stack
        Comms.SendStack = {}
        return false
    end

    local myVersions = Comms:BuildVersionsPacket()
    local eligableToSendDat = false

    if data.configVersion ~= nil then
        if Comms:DoIHaveGreaterOrEqualVersion("config", data.configVersion, nil, true) then
            Comms.SendStack.configVersion = myVersions.configVersion
            eligableToSendDat = true
        else
            Comms.SendStack.configVersion = nil
        end

        if Comms:DoIHaveGreaterOrEqualVersion("charconfig", data.charConfigVersion, nil, true) then
            Comms.SendStack.charConfigVersion = myVersions.charConfigVersion
            eligableToSendDat = true
        else
            Comms.SendStack.charConfigVersion = nil
        end

        if data.bankChars ~= nil then
            for charR, valR in pairs(data.bankChars) do
                if Comms:DoIHaveGreaterOrEqualVersion("inventory", valR.inventoryVersion, charR, true) then
                    Comms.SendStack.bankChars[charR] = Comms.SendStack.bankChars[charR] or {}
                    Comms.SendStack.bankChars[charR].inventoryVersion = valR.inventoryVersion
                    eligableToSendDat = true
                else
                    if Comms.SendStack.bankChars[charR] then
                        Comms.SendStack.bankChars[charR].inventoryVersion = nil
                    end
                end

                if Comms:DoIHaveGreaterOrEqualVersion("money", valR.moneyVersion, charR, true) then
                    Comms.SendStack.bankChars[charR] = Comms.SendStack.bankChars[charR] or {}
                    Comms.SendStack.bankChars[charR].moneyVersion = valR.moneyVersion
                    eligableToSendDat = true
                else
                    if Comms.SendStack.bankChars[charR] then
                        Comms.SendStack.bankChars[charR].moneyVersion = nil
                    end
                end

                if Comms:DoIHaveGreaterOrEqualVersion("log", valR.logVersion, charR, true) then
                    Comms.SendStack.bankChars[charR] = Comms.SendStack.bankChars[charR] or {}
                    Comms.SendStack.bankChars[charR].logVersion = valR.logVersion
                    eligableToSendDat = true
                else
                    if Comms.SendStack.bankChars[charR] then
                        Comms.SendStack.bankChars[charR].logVersion = nil
                    end
                end

                if Comms:DoIHaveGreaterOrEqualVersion("data", valR.dataVersion, charR, true) then
                    Comms.SendStack.bankChars[charR] = Comms.SendStack.bankChars[charR] or {}
                    Comms.SendStack.bankChars[charR].dataVersion = valR.dataVersion
                    eligableToSendDat = true
                else
                    if Comms.SendStack.bankChars[charR] then
                        Comms.SendStack.bankChars[charR].dataVersion = nil
                    end
                end
            end
        end
    end

    return eligableToSendDat
end


-- ---------------------------------------------------------------------------------------
-- check if this character or account have a higher or equal version of the requested one
-- if useKnownVersionsAsWell == true, then the method will only return true if no one else
-- in the known version list has a higher version
function Comms:DoIHaveGreaterOrEqualVersion(type, version, characterName, useKnownVersionsAsWell)
    if type == nil or version == nil then
        return false
    end

    local myVersions = Comms:BuildVersionsPacket()
    if useKnownVersionsAsWell and Comms:AnyOtherWithHigherVersion(type, version, characterName) then
        return false
    end

    if type == "config" then
        return myVersions.configVersion >= version
    elseif type == "charconfig" then
        return myVersions.charConfigVersion >= version
    elseif type == "inventory" then
        return myVersions.bankChars[char] ~= nul and myVersions.bankChars[char].inventoryVersion >= version
    elseif type == "log" then
        return myVersions.bankChars[char] ~= nul and myVersions.bankChars[char].logVersion >= version
    elseif type == "money" then
        return myVersions.bankChars[char] ~= nul and myVersions.bankChars[char].moneyVersion >= version
    elseif type == "data"  then
        return myVersions.bankChars[char] ~= nul and myVersions.bankChars[char].dataVersion >= version
    else
        PLGuildBankClassic:errln(string.format(L["Unkown version comparison type received: '%s'."], type))
    end

    return false
end

-- ---------------------------------------------------------------------------------------
-- check if any other known player has a higher version as the given one
function Comms:AnyOtherWithHigherVersion(type, version, characterName)
    if type == nil or version == nil then
        return false
    end

    for char, knowData in paris(Comms.KnownVersions) do
        if type == "config" then
            if knowData.configVersion > version then
                return true
            end
        elseif type == "charconfig" then
            if knowData.charConfigVersion > version then
                return true
            end
        elseif type == "inventory" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].inventoryVersion > version then
                return true
            end
        elseif type == "log" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].logVersion > version then
                return true
            end
        elseif type == "money" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].moneyVersion > version then
                return true
            end
        elseif type == "data"  then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].dataVersion > version then
                return true
            end
        else
            PLGuildBankClassic:errln(string.format(L["Unkown version comparison type received: '%s'."], type))
        end
    end

    return false
end

-- ---------------------------------------------------------------------------------------
-- generates a list of character names which have the requested version number or higher
function Comms:ListOfCharsWhichMaySendData(type, version)
    local chars = {}

    if type == nil or version == nil then
        return chars
    end

    for char, knowData in paris(Comms.KnownVersions) do
        if type == "config" then
            if knowData.configVersion >= version then
                tinsert(chars, char)
            end
        elseif type == "charconfig" then
            if knowData.charConfigVersion >= version then
                tinsert(chars, char)
            end
        elseif type == "inventory" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].inventoryVersion >= version then
                tinsert(chars, char)
            end
        elseif type == "log" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].logVersion >= version then
                tinsert(chars, char)
            end
        elseif type == "money" then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].moneyVersion >= version then
                tinsert(chars, char)
            end
        elseif type == "data"  then
            if knowData.bankChars[char] ~= nul and knowData.bankChars[char].dataVersion >= version then
                tinsert(chars, char)
            end
        else
            PLGuildBankClassic:errln(string.format(L["Unkown version comparison type received: '%s'."], type))
        end
    end

    return chars
end

function Comms:ReceiveConfig(sender, data)
    -- received if the main configuration changed
    -- like min rank required
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig then
        if data.config.configTimestamp > guildConfig.configTimestamp and data.config.minGuildRank ~= nil then
            PLGuildBankClassic:debug("Updating rank config from sync source")
            guildConfig.minGuildRank = data.config.minGuildRank
            guildConfig.configTimestamp = data.config.configTimestamp

            -- TODO: Update local UI
        end
    end
end

function Comms:ReceiveCharConfig(sender, data)
-- received if the main configuration changed
    -- like min rank required
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig then
        if data.config.charConfigTimestamp > guildConfig.charConfigTimestamp then
            PLGuildBankClassic:debug("Updating character config from sync source")
            guildConfig.charConfigTimestamp = data.config.charConfigTimestamp

            local foundChars = {}

            for charR, valR in pairs(data.bankChars) do
                local foundCharLocally = false
                for charL, valL in pairs(guildConfig.bankChars) do
                    if charR == charL then
                        foundCharLocally = true
                        if valR.modifiedAt > valL.modifiedAt then
                            PLGuildBankClassic:debug("Updatiung character config of '" .. charL .. "' and use newer data from sync")
                            valL.guildInfoText = valR.guildInfoText
                            valL.description = valR.description
                            valL.icon = valR.icon
                            valL.acceptState = valR.acceptState
                            valL.isDeleted = valR.isDeleted
                        end
                    end
                end

                if foundCharLocally == false then
                    PLGuildBankClassic:debug("Adding bank character with name '" .. charL .. "'")
                    local requireQueryVersions = not guildConfig.bankChars[charR]
                    
                    guildConfig.bankChars[charR] = valR
                    guildConfig.bankChars[charR].inventoryVersion = 0
                    guildConfig.bankChars[charR].logVersion = 0

                    if requireQueryVersions then
                        -- TODO: need query versions in order to receive log and inventory data
                    end

                    -- TODO: Update local UI, ask accept if ?!?!?
                end
            end

            -- eventually remove logs and data for deleted chars
            -- if they are not owned by the player
            for charL, valL in pairs(guildConfig.bankChars) do
                if valL.isDeleted == true and PLGuildBankClassic:CharacterOwnedByAccount(charL) == false then
                    PLGuildBankClassic:ClearBankCharData(charL)
                end
            end
        end

        local haveAddedNewChars = false
        for charL, valL in pairs(guildConfig.bankChars) do
            local foundInRemotePackage = false
            for charR, valR in pairs(data.bankChars) do
                if charR == charL then
                    foundInRemotePackage = true
                end
            end

            if foundInRemotePackage == false then
                haveAddedNewChars = true
            end
        end

        if haveAddedNewChars == true then
            -- this character hab been added on the local account between the last changes
            -- update last char info version and broadcast version query
            guildConfig.charConfigTimestamp = PLGuildBankClassic:GetTimestamp()
            Comms:SendVersionQuery()
        end

        -- TODO: Update local UI
    end
end

function Comms:ReceiveInventory(sender, data)
    if data ~= nil and data.charaterName ~= nil and data.ownerInfo ~= nil and data.bags ~= nil then
        local bankCharData = PLGuildBankClassic:GetBankCharDataByName(data.charaterName)
        if bankCharData ~= nil then
            PLGuildBankClassic:debug("Updating inventory information for '" ..  data.charaterName .. "'")
            bankCharData.inventoryVersion = data.inventoryVersion or bankCharData.inventoryVersion
            PLGuildBankClassic:SetCacheInventoryInfo(data.ownerInfo, data.bags)

            -- TODO: Update local UI
        else
            PLGuildBankClassic:debug("No local bank char data found for '" ..  data.charaterName .. "'")
        end
    else
        PLGuildBankClassic:debug("ReceiveInventory: missing data or cached owner info / bags '" ..  (data.charaterName or "unknown") .. "'")
    end
end

function Comms:ReceiveMoney(sender, data)
    if data ~= nil and data.charaterName ~= nil and data.ownerInfo ~= nil then
        local bankCharData = PLGuildBankClassic:GetBankCharDataByName(data.charaterName)

        if bankCharData ~= nil then
            PLGuildBankClassic:debug("Updating money information for '" ..  data.charaterName .. "'")
            bankCharData.money = data.value or bankCharData.money
            bankCharData.moneyVersion = data.moneyVersion or bankCharData.moneyVersion
            PLGuildBankClassic:SetCachedMoneyInfo(data.ownerInfo, bankCharData.money)

            -- TODO: Update local UI
        else
            PLGuildBankClassic:debug("No local bank char data found for '" ..  data.charaterName .. "'")
        end
    else
        PLGuildBankClassic:debug("ReceiveMoney: missing data or cached owner info '" ..  (data.charaterName or "unknown") .. "'")
    end
end

function Comms:ReceiveLog(sender, data)
    if data ~= nil and data.charaterName ~= nil and data.logVersion ~= nil then
        local bankCharData = PLGuildBankClassic:GetBankCharDataByName(data.charaterName)
        local logForChar = PLGuildBankClassic:GetLogByName(data.charaterName)

        if logForChar ~= nil and bankCharData ~= nil then
            PLGuildBankClassic:debug("Updating log for '" ..  data.charaterName .. "'")
            bankCharData.logVersion = data.logVersion or bankCharData.logVersion
            PLGuildBankClassic:MergeLogEntries(logForChar, data.data)

            -- TODO: Update local UI
        else
            PLGuildBankClassic:debug("No local log or bank char data found for '" ..  data.charaterName .. "'")
        end
    else
        PLGuildBankClassic:debug("ReceiveLog: missing data or cached owner info '" ..  (data.charaterName or "unknown") .. "'")
    end
end

function Comms:QueryBankCharOnline(sender, data)
    local imOwningBankChars = false
    local owningCharsData = {}
    owningCharsData.currentCharName = UnitName("player")
    owningCharsData.bankChars = {}

    -- check saved variabled with owning characters
    -- required to have logged in at all chars at least once
    if PLGuildBankClassic.db.factionrealm.accountChars ~= nil then
        for characterName, v in pairs(PLGuildBankClassic.db.factionrealm.accountChars) do
            -- if this character has configured bank data
            -- add it to my owned chars list
            local bankCharData = PLGuildBankClassic:GetBankCharDataByName(characterName)
            if bankCharData ~= nil then
                tinsert(owningCharsData.bankChars, characterName)
                imOwningBankChars = true
            end
        end
    end

    if imOwningBankChars == true then
        Comms:SendData(COMM_CMD_RESPONSE_BANKCHARONLINE, owningCharsData)
    end
end

function Comms:ResponseBankCharOnline(sender, data)
    if data.bankChars ~= nil and #data.bankChars > 0 then
        for i=1, #data.bankChars do
            -- saving that the bank char is owned by the player 
            Comms.KnownBankCharOwners[data.bankChars[i]] = data.currentCharName
        end
    end
end

function Comms:BuildCheck(sender, data)
    local LastVerCheck = time() - PLGuildBankClassic.LastVerCheck;

    if LastVerCheck > 1800 then   					-- limits the Out of Date message from firing more than every 30 minutes 
        PLGuildBankClassic.LastVerCheck = time();
        PLGuildBankClassic:debug("Buildnumber received is: " .. data .. ", local buildnumber is: " .. tostring(PLGBC_BUILD_NUMBER))
        if tonumber(data) > PLGBC_BUILD_NUMBER then
            PLGuildBankClassic:info(L["Your version of PL GuildBank classic is out-of-date! Please update to latest version!"])
        end
    end

    if tonumber(data) < PLGBC_BUILD_NUMBER then
        Comms:SendData(COMM_CMD_BUILDCHECK, tostring(PLGBC_BUILD_NUMBER))
    end
end

-----------------------------------------------------------------------
-- sending

function Comms:SendVersionQuery()
    local versionsData = Comms:BuildVersionsPacket()

    Comms:SendData(COMM_CMD_QUERYVERSIONS, versionsData)
end

function Comms:SendQueryBankcharOnline()
    Comms:SendData(COMM_CMD_QUERY_BANKCHARONLINE, "")
end

function Comms:ScheduleSendInventory(characterName, inventoryVersion)
    local inventoryData = {}
    inventoryData.charaterName = characterName
    inventoryData.inventoryVersion = inventoryVersion
    inventoryData.data = PLGuildBankClassic:GetInventoryCache(characterName)

    Comms:ScheduleSendComms(COMM_CMD_SENDINVENTORY, inventoryData, DEFAULT_INVENTORY_SEND_TRIGGER_SEC)
end

function Comms:ScheduleSendMoney(characterName, value, moneyVersion)
    local moneyData = {}
    moneyData.charaterName = characterName
    moneyData.value = value
    moneyData.moneyVersion = moneyVersion
    moneyData.ownerInfo = PLGuildBankClassic:GetCachedOwnerInfo(characterName)
    
    if value == nil then -- use cached value
        moneyData.value = moneyData.ownerInfo.money
    end
    
    Comms:ScheduleSendComms(COMM_CMD_SENDMONEY, moneyData, DEFAULT_MONEY_SEND_TRIGGER_SEC)
end

function Comms:ScheduleSendLog(characterName, logVersion)
    local logData = {}
    logData.charaterName = characterName
    logData.logVersion = logVersion

    -- TODO: log diffs???
    -- logs may be large - so only send diffs which may also allow merging
    local fullLog = PLGuildBankClassic:GetLogByName(characterName)

    -- limit log size
    if fullLog ~= nil and #fullLog > MAX_LOG_ENTRIES_TO_SEND then
        logData.data = PLGuildBankClassic:sliceTable(fullLog, 1, MAX_LOG_ENTRIES_TO_SEND)
    else
        logData.data = fullLog
    end

    Comms:ScheduleSendComms(COMM_CMD_SENDLOG, logData, DEFAULT_LOG_SEND_TRIGGER_SEC)
end

-----------------------------------------------------------------------
-- internal event triggers

function Comms:PLGBC_EVENT_CONFIG_CHANGED(event, configTimestamp)
    local configData = Comms:BuildConfigPacket(false)

    Comms:SendData(COMM_CMD_SENDCONFIG, configData)
end

function Comms:PLGBC_EVENT_CHAR_CONFIG_CHANGED(event, configTimestamp)
    local configData = Comms:BuildConfigPacket(true)

    Comms:SendData(COMM_CMD_SENDCHARCONFIG, configData)
end

function Comms:ScheduleSendComms(subCommand, data, threshold)
     -- threshold impl - send data if no other update comes within 2sec
     if PLGuildBankClassic.CommsThresholdTriggers == nil then
        PLGuildBankClassic.CommsThresholdTriggers = {}
    end

    if threshold == nil then
        -- remove scheduled sending command
        PLGuildBankClassic.CommsThresholdTriggers[subCommand] = nil
    else
        PLGuildBankClassic.CommsThresholdTriggers[subCommand] = {}
        local sendInfo = {}
        sendInfo.trigger = time() + threshold
        sendInfo.data = data
        -- insert send data at top of the array (FIFO list)
        tinsert(PLGuildBankClassic.CommsThresholdTriggers[subCommand], 1, sendInfo)
        --PLGuildBankClassic.CommsThresholdTriggers[subCommand].trigger = time() + threshold
        --PLGuildBankClassic.CommsThresholdTriggers[subCommand].data = data
    end
end


function Comms:PLGBC_EVENT_BANKCHAR_MONEYCHANGED(event, characterName, value, gainedOrLost, moneyVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDMONEY] = nil
        Comms:ScheduleSendMoney(characterName, value, moneyVersion)
    end
end

function Comms:PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED(event, characterName, hasCachedData, inventoryVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDINVENTORY] = nil
        Comms:ScheduleSendInventory(characterName, inventoryVersion)
    end
end

function Comms:PLGBC_GUILD_LOG_UPDATED(event, characterName, logVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDLOG] = nil
        Comms:ScheduleSendLog(characterName, logVersion)
    end
end

-----------------------------------------------------------------------
-- Data 

function Comms:BuildConfigPacket(includeCharaterData)
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig then
        local configData = {}

        configData.config = guildConfig.config
        if includeCharaterData == true then
            configData.bankChars = guildConfig.bankChars
        end

        return configData
    end

    return nil
end

function Comms:BuildVersionsPacket()
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 
    local versionData = {}
    versionData.configVersion = 0
    versionData.charConfigVersion = 0

    if guildConfig then
        versionData.configVersion = guildConfig.configTimestamp
        versionData.charConfigVersion = guildConfig.cahrConfigTimestamp
        versionData.bankChars = {}
        for idx, char in ipairs(guildConfig.bankChars) do
            versionData.bankChars[char] = {}
            versionData.bankChars[char].inventoryVersion = guildConfig.bankChars[char].inventoryVersion
            versionData.bankChars[char].logVersion = guildConfig.bankChars[char].logVersion
            versionData.bankChars[char].moneyVersion = guildConfig.bankChars[char].moneyVersion
            versionData.bankChars[char].dataVersion = guildConfig.bankChars[char].modifiedAt
        end
    end

    return versionData
end


function Comms:BuildCommsPacket(command, data)
    local commsData = {}
    commsData.command = command
    commsData.data = data

    return commsData
end

function Comms:SendData(prefix, data)
    PLGuildBankClassic:CheckOfficer()

    local commsData = Comms:BuildCommsPacket(prefix, data)

	if IsInGuild() then
        if prefix == COMM_CMD_BUILDCHECK or prefix == COMM_CMD_QUERYVERSIONS then
            PLGuildBankClassic:debug("Broadcasted " .. prefix)
            -- cleartext message
			Comms:SendCommMessage(COMM_PREFIX_CLEARTEXT_MESSAGE, data, "GUILD")
			return;
		end
	end

    if IsInGuild() then
		local serialized = nil;
		local packet = nil;
		local verInteg1 = false;
		local verInteg2 = false;

		if commsData then
			serialized = LibAceSerializer:Serialize(commsData);	-- serializes tables to a string
		end

		-- compress serialized string with both possible compressions for comparison
		-- I do both in case one of them doesn't retain integrity after decompression and decoding, the other is sent
		local huffmanCompressed = LibCompress:CompressHuffman(serialized);
		if huffmanCompressed then
			huffmanCompressed = LibCompressAddonEncodeTable:Encode(huffmanCompressed);
		end
		local lzwCompressed = LibCompress:CompressLZW(serialized);
		if lzwCompressed then
			lzwCompressed = LibCompressAddonEncodeTable:Encode(lzwCompressed);
		end

		-- Decode to test integrity
		local test1 = LibCompress:Decompress(LibCompressAddonEncodeTable:Decode(huffmanCompressed))
		if test1 == serialized then
			verInteg1 = true
		end
		local test2 = LibCompress:Decompress(LibCompressAddonEncodeTable:Decode(lzwCompressed))
		if test2 == serialized then
			verInteg2 = true
		end
		-- check which string with verified integrity is shortest. Huffman usually is
		if (strlen(huffmanCompressed) < strlen(lzwCompressed) and verInteg1 == true) then
			packet = huffmanCompressed;
		elseif (strlen(huffmanCompressed) > strlen(lzwCompressed) and verInteg2 == true) then
			packet = lzwCompressed
		elseif (strlen(huffmanCompressed) == strlen(lzwCompressed)) then
			if verInteg1 == true then packet = huffmanCompressed
			elseif verInteg2 == true then packet = lzwCompressed end
		end

		--debug lengths, uncomment to see string lengths of each uncompressed, Huffman and LZQ compressions
		--[[print("Uncompressed: ", strlen(serialized))
		print("Huffman: ", strlen(huffmanCompressed))
		print("LZQ: ", strlen(lzwCompressed)) --]]

        local channel = "GUILD"
        PLGuildBankClassic:debug("Sending packet using prefix '" .. COMM_PREFIX_COMPRESSED_MESSAGE .. "' and subcommand .. '" .. prefix .. "' in channel '" ..  channel .. "' ...")
        -- send compressed message
		Comms:SendCommMessage(COMM_PREFIX_COMPRESSED_MESSAGE, packet, channel)
	end
end