local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local GuildBankLogFrame = CreateFrame("Frame")
local GuildBankLogFrame_MT = {__index = GuildBankLogFrame}

local Events = PLGuildBankClassic:GetModule("Events")

local MAX_SHOWN_TRANSACTIONS = 200
local GUILDBANK_TRANSACTION_HEIGHT = 13
local GUILD_BANK_LOG_TIME_PREPEND = "|cff009999   "

PLGuildBankClassic.GuildBankLogFrame = {}
PLGuildBankClassic.GuildBankLogFrame.defaults = {}
PLGuildBankClassic.GuildBankLogFrame.prototype = GuildBankLogFrame
function PLGuildBankClassic.GuildBankLogFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabLog", parent, "PLGuildBankFrameTabLog"), GuildBankLogFrame_MT)

    -- settings
    frame.displayingCharacterData = nil
    frame.displayingLog = nil

	-- components

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
	frame:SetScript("OnHide", frame.OnHide)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabLog")

    return frame
end 

function GuildBankLogFrame:OnShow()
    self:MessageFrame_OnLoad(self.messagesFrame)
end

function GuildBankLogFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildBankLogFrame:Update(characterData)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

    PLGuildBankClassic:debug("GuildBankLogFrame:Update: character: " .. charServerName)

    self.displayingCharacterData = characterData
    self.displayingLog = PLGuildBankClassic:GetLogByName(charServerName)
    
    local class = characterData.class
    if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
    local player = characterData.name
        
    self.configDescriptionLabel.Text:SetText(characterData.description)
    self.configCharLabel.Text:SetText("- " .. (class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player))

    self.configDescriptionLabel:SetWidth(self.configDescriptionLabel.Text:GetWidth())
    self.configCharLabel:SetWidth(self.configCharLabel.Text:GetWidth())

    self.messagesFrame:Clear()
    self:PrintTransactions()
end

function GuildBankLogFrame:MessageFrame_OnLoad(messageframe)
    messageframe:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP);
    messageframe:SetMaxLines(MAX_SHOWN_TRANSACTIONS);
    messageframe:SetFading(false);
    messageframe:SetFontObject(ChatFontNormal);
    messageframe:SetJustifyH("LEFT");
end

function GuildBankLogFrame:DoLogScroll()
    local offset = FauxScrollFrame_GetOffset(GuildBankLogFrame.scrollFrame);
	local numTransactions = 0;
    
    if GuildBankLogFrame.displayingLog then
        numTransactions = getn(GuildBankLogFrame.displayingLog)
    end
    
	GuildBankLogFrame.scrollFrame:SetScrollOffset(offset);
	FauxScrollFrame_Update(GuildBankLogFrame.scrollFrame, numTransactions, MAX_SHOWN_TRANSACTIONS, GUILDBANK_TRANSACTION_HEIGHT );
end

function GuildBankLogFrame:PrintTransactions()
    local numTransactions = 0;
    
    if self.displayingLog then
        numTransactions = getn(self.displayingLog)
    end

    PLGuildBankClassic:debug("PrintTransactions: num transactions " .. tostring(numTransactions))

    local i = 1
    local money
    local msg
    local record
    local timestamp

    for i=numTransactions, 1, -1 do
        record = self.displayingLog[i]
        timestamp = record.timestamp

        local year, month, day, _, _, hour, min, sec, _ = date("*t", timestamp)

        PLGuildBankClassic:debug(format("Converted timestamp %d into year=%d, month=%d, day=%d, hour=%d, min=%d, sec=%d", timestamp, year, month, day, hour, min, sec))

        name = NORMAL_FONT_COLOR_CODE..record.name..FONT_COLOR_CODE_CLOSE

        if record.type == PLGuildBankClassic.transactionTypes.money then

            money = GetDenominationsFromCopper((record.goldPerItem or 0) * (record.quantity or 1))

            if record.mode == PLGuildBankClassic.transactionModes.deposit then
                msg = format(L["%s deposited %s"], name, money)
            else
                msg = format(L["%s |cffff2020withdrew|r %s"], name, money)
            end

            if record.source then
                msg = msg .. " " .. NORMAL_FONT_COLOR_CODE .. self:ConvertSourceToExt(record.source) .. FONT_COLOR_CODE_CLOSE
            end

            if msg then
                self.messagesFrame:AddMessage(msg..GUILD_BANK_LOG_TIME_PREPEND..format(L["( %s ago )"], RecentTimeDate(year, month, day, hour)).."|r" )
            end

        elseif record.type == PLGuildBankClassic.transactionTypes.item then

            local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(record.itemId);
            moneyValue = (record.goldPerItem or 0) * (record.quantity or 1)
            money = GetDenominationsFromCopper(moneyValue)

            if record.mode == PLGuildBankClassic.transactionModes.deposit then
   
                msg = format(L["%s deposited %s"], name, sLink);
                if ( record.quantity > 1 ) then
                    msg = msg..format(L[" x %d"], record.quantity);
                end
            else
                msg = format(L["%s |cffff2020withdrew|r %s"], name, itemLink);
                if ( record.quantity > 1 ) then
                    msg = msg..format(L[" x %d"], record.quantity);
                end
            end

            if moneyValue > 0 then
                msg = msg.." " .. format(L["(est. value: %s)"], money)
            end

            if record.source then
                msg = msg .. " " .. NORMAL_FONT_COLOR_CODE .. self:ConvertSourceToExt(record.source) .. FONT_COLOR_CODE_CLOSE
            end

            if msg then
                self.messagesFrame:AddMessage( msg..GUILD_BANK_LOG_TIME_PREPEND..format(L["( %s ago )"], RecentTimeDate(year, month, day, hour)).."|r" );
            end

        end
    end

    FauxScrollFrame_Update(self.scrollFrame, numTransactions, MAX_SHOWN_TRANSACTIONS, GUILDBANK_TRANSACTION_HEIGHT );
end

function GuildBankLogFrame:ConvertSourceToExt(source)
    if source == PLGuildBankClassic.transactionSource.directTrade then
        return L["via direct trade"]
    elseif source == PLGuildBankClassic.transactionSource.mail then
        return L["via mail"]
    elseif source == PLGuildBankClassic.transactionSource.cod then
        return L["via COD"]
    elseif source == PLGuildBankClassic.transactionSource.auction then
        return L["via auction"]
    elseif source == PLGuildBankClassic.transactionSource.loot then
        return L["via loot"]
    end

    return L["via (unkown)"]
end