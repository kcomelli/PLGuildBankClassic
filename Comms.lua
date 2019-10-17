local _, PLGuildBankClassic = ...

local Comms = PLGuildBankClassic:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")
local Events = PLGuildBankClassic:GetModule("Events")

local COMM_PREFIX = "PLGBC-"

local COMM_CMD_QUERYVERSIONS = "QUERYVERSIONS"
local COMM_CMD_RESPONSEVERSIONS = "RESPONSEVERSIONS"

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX, "OnCommReceived")

    Comms.comm = {}
    Comms.comm[COMM_CMD_QUERYVERSIONS] = Comms.QueryVersions
    Comms.comm[COMM_CMD_RESPONSEVERSIONS] = Comms.ResponseVersions


    Events.Register(self, "PLGBC_EVENT_CONFIG_CHANGED")
    Events.Register(self, "PLGBC_EVENT_BANKCHAR_MONEYCHANGED")
    Events.Register(self, "PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED")
    Events.Register(self, "PLGBC_GUILD_LOG_UPDATED")
end

-----------------------------------------------------------------------
-- Command receivers

function Comms:OnCommReceived(prefix, message, distribution, sender)
    self:RouteCommand(self:Deserialize(message))
end

function Comms:RouteCommand(ok,command,sender, ...)
    if not ok then
        return
    elseif Comms.comm[command] then
        Comms.comm[command](sender, ...)
    end
end

function Comms:QueryVersions(sender)

end

function Comms:ResponseVersions(sender)

end

-----------------------------------------------------------------------
-- Data 

function Comms:CreateMessage(ok, command, sender, ...)
    return self:Serialize(ok, command, sender, ...)
end

-----------------------------------------------------------------------
-- internal event triggers

function Comms:PLGBC_EVENT_CONFIG_CHANGED(event, configTimestamp)
end

function Comms:PLGBC_EVENT_BANKCHAR_MONEYCHANGED(event, characterName, value, gainedOrLost, moneyVersion)
end

function Comms:PLGBC_EVENT_BANKCHAR_INVENTORYCHANGED(event, characterName, hasCachedData, inventoryVersion)
end

function Comms:PLGBC_GUILD_LOG_UPDATED(event, characterName, logVersion)
end