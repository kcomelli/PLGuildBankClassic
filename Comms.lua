local _, PLGuildBankClassic = ...

local Comms = PLGuildBankClassic:NewModule("Comms", "AceComm-3.0", "AceSerializer-3.0")

local COMM_PREFIX = "PLGBC-"

function Comms:OnEnable()
    self:RegisterComm(COMM_PREFIX, "OnCommReceived")
end

-----------------------------------------------------------------------
-- Command receivers

function Comms:OnCommReceived(prefix, message, distribution, sender)
    self:RouteCommand(self:Deserialize(message))
end

function Comms:RouteCommand(ok,command,...)
    if not ok then
        return
    elseif Comms.comm[command] then
        Comms.comm[command](...)
    end
end