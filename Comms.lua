local _, PLGuildBankClassic = ...

local Comms = PLGuildBankClassic:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")
local Events = PLGuildBankClassic:GetModule("Events")

local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibCompress = LibStub:GetLibrary("LibCompress")
local LibCompressAddonEncodeTable = LibCompress:GetAddonEncodeTable()

local COMM_PREFIX_COMPRESSED_MESSAGE = "PLGBCCmprs"
local COMM_PREFIX_CLEARTEXT_MESSAGE = "PLGBCClear"

local COMM_CMD_BUILDCHECK       = "PLGBCBuildCheck"
local COMM_CMD_QUERYVERSIONS    = "PLGBCQVersions"
local COMM_CMD_REQUESTVERSIONS  = "PLGBCRVersions"
local COMM_CMD_SENDCONFIG       = "PLGBCSendConfig"
local COMM_CMD_SENDINVENTORY    = "PLGBCSendInventory"
local COMM_CMD_SENDMONEY        = "PLGBCSendMoney"
local COMM_CMD_SENDLOG          = "PLGBCSendLog"

PLGuildBankClassic.Comms = Comms
Comms.KnownVersions = {}

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX_COMPRESSED_MESSAGE, "OnCommReceived")
    self:RegisterComm(COMM_PREFIX_CLEARTEXT_MESSAGE, "OnCommReceived")

    Comms.comm = {}
    Comms.comm[COMM_CMD_BUILDCHECK] = Comms.BuildCheck
    Comms.comm[COMM_CMD_QUERYVERSIONS] = Comms.QueryVersions
    Comms.comm[COMM_CMD_SENDCONFIG] = Comms.ReceiveConfig
    Comms.comm[COMM_CMD_SENDINVENTORY] = Comms.ReceiveInventory
    Comms.comm[COMM_CMD_SENDMONEY] = Comms.ReceiveMoney
    Comms.comm[COMM_CMD_SENDLOG] = Comms.ReceiveLog


    Events.Register(self, "PLGBC_EVENT_CONFIG_CHANGED")
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

function Comms:QueryVersions(sender, data)

end

function Comms:ReceiveConfig(sender, data)

end

function Comms:ReceiveInventory(sender, data)

end

function Comms:ReceiveMoney(sender, data)

end

function Comms:ReceiveLog(sender, data)

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


-----------------------------------------------------------------------
-- internal event triggers

function Comms:PLGBC_EVENT_CONFIG_CHANGED(event, configTimestamp)
    local configData = Comms:BuildConfigPacket()

    Comms:SendData(COMM_CMD_SENDCONFIG, configData)
end

function Comms:PLGBC_EVENT_BANKCHAR_MONEYCHANGED(event, characterName, value, gainedOrLost, moneyVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then

        -- TODO: threshold impl
        local moneyData = {}
        moneyData.charaterName = characterName
        moneyData.value = value
        moneyData.gainedOrLost = gainedOrLost
        moneyData.moneyVersion = moneyVersion

        -- threshold impl - send data if no other update comes within 2sec
        if PLGuildBankClassic.CommsThresholdTriggers == nil then
            PLGuildBankClassic.CommsThresholdTriggers = {}
        end
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDMONEY] = {}
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDMONEY].trigger = time() + 2
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDMONEY].data = moneyData
        
        --Comms:SendData(COMM_CMD_SENDMONEY, moneyData)
    end
end

function Comms:PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED(event, characterName, hasCachedData, inventoryVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then

        local inventoryData = {}
        inventoryData.charaterName = characterName
        inventoryData.inventoryVersion = inventoryVersion
        inventoryData.data = PLGuildBankClassic:GetInventoryCache(characterName)

        -- threshold impl - send data if no other update comes within 2sec
        if PLGuildBankClassic.CommsThresholdTriggers == nil then
            PLGuildBankClassic.CommsThresholdTriggers = {}
        end

        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDINVENTORY] = {}
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDINVENTORY].trigger = time() + 2
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDINVENTORY].data = inventoryData

        --Comms:SendData(COMM_CMD_SENDINVENTORY, inventoryData)
    end
end

function Comms:PLGBC_GUILD_LOG_UPDATED(event, characterName, logVersion)
    -- this event should only trigger an event if triggered on a bank-char
    if PLGuildBankClassic:IsGuildBankChar() then

        local logData = {}
        logData.charaterName = characterName
        logData.logVersion = logVersion

        -- TODO: log diffs???
        -- logs may be large - so only send diffs which may also allow merging
        logData.log = PLGuildBankClassic:GetLogByName(characterName)

        -- threshold impl - send data if no other update comes within 2sec
        if PLGuildBankClassic.CommsThresholdTriggers == nil then
            PLGuildBankClassic.CommsThresholdTriggers = {}
        end
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDLOG] = {}
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDLOG].trigger = time() + 2
        PLGuildBankClassic.CommsThresholdTriggers[COMM_CMD_SENDLOG].data = logData

        --Comms:SendData(COMM_CMD_SENDLOG, logData)
    end
end

-----------------------------------------------------------------------
-- Data 

function Comms:BuildConfigPacket()
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 

    if guildConfig then
        local configData = {}

        configData.config = guildConfig.config
        configData.bankChars = guildConfig.bankChars

        return configData
    end

    return nil
end

function Comms:BuildVersionsPacket()
    local guildConfig = PLGuildBankClassic:GetGuildConfig() 
    local versionData = {}
    versionData.configVersion = 0

    if guildConfig then
        versionData.configVersion = guildConfig.configTimestamp
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