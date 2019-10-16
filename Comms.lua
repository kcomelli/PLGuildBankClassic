local _, PLGuildBankClassic = ...

local Comms = PLGuildBankClassic:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")

local COMM_PREFIX = "PLGBC-"

local COMM_CMD_QUERYVERSIONS = "QUERYVERSIONS"
local COMM_CMD_RESPONSEVERSIONS = "RESPONSEVERSIONS"

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX, "OnCommReceived")

    Comms.comm = {}
    Comms.comm[COMM_CMD_QUERYVERSIONS] = Comms.QueryVersions
    Comms.comm[COMM_CMD_RESPONSEVERSIONS] = Comms.ResponseVersions
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