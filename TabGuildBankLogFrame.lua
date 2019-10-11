local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local GuildBankLogFrame = CreateFrame("Frame")
local GuildBankLogFrame_MT = {__index = GuildBankLogFrame}

local Events = PLGuildBankClassic:GetModule("Events")

local MAX_SHOWN_TRANSACTIONS = 2000
local GUILDBANK_TRANSACTION_HEIGHT = 10.2
local GUILD_BANK_LOG_TIME_PREPEND = "|cff009999   "

PLGuildBankClassic.GuildBankLogFrame = {}
PLGuildBankClassic.GuildBankLogFrame.defaults = {}
PLGuildBankClassic.GuildBankLogFrame.prototype = GuildBankLogFrame
function PLGuildBankClassic.GuildBankLogFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabLog", parent, "PLGuildBankFrameTabLog"), GuildBankLogFrame_MT)

    -- settings
    frame.displayingCharacterData = nil
    frame.displayingLog = nil
    frame.itemHeight = GUILDBANK_TRANSACTION_HEIGHT

	-- components

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide)
    frame:SetScript("OnSizeChanged", frame.OnSizeChanged)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabLog")

    return frame
end 

function GuildBankLogFrame:OnShow()
    self:MessageFrame_OnLoad(self.messagesFrame)
    Events.Register(self, "PLGBC_GUILD_LOG_UPDATED")
end

function GuildBankLogFrame:OnHide()
    Events.UnregisterAll(self)
end

function GuildBankLogFrame:OnSizeChanged()
    self:DoLogScroll()
end

function GuildBankLogFrame:PLGBC_GUILD_LOG_UPDATED(event, chacaterName)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(chacaterName)

    if self.displayingCharacterData and self.displayingCharacterData.name == charName and self.displayingCharacterData.realm == charRealm then
        self:Update(self.displayingCharacterData)
    end
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
    messageframe:SetFading(false);
    --messageframe:SetFontObject(ChatFontNormal);
    messageframe:SetFontObject(GameFontNormalSmall);
    messageframe:SetJustifyH("LEFT");
    messageframe:SetMaxLines(MAX_SHOWN_TRANSACTIONS);
end

function GuildBankLogFrame:GetMaxShownLogsForFrameSize()
    local newHeight = ceil( self.messagesFrame:GetHeight() / GUILDBANK_TRANSACTION_HEIGHT)
    PLGuildBankClassic:debug("GetMaxShownLogsForFrameSize: Height " .. tostring(newHeight))

    return newHeight
end

function GuildBankLogFrame:DoLogScroll()

    local parentFrame = self

    if not parentFrame.scrollFrame then
        parentFrame = self:GetParent()
    end

    if parentFrame.scrollFrame then
        local offset = FauxScrollFrame_GetOffset(parentFrame.scrollFrame);
        local numTransactions = 0;
        
        if parentFrame.displayingLog then
            numTransactions = getn(parentFrame.displayingLog)
        end
        
        PLGuildBankClassic:debug("DoLogScroll: num transactions " .. tostring(numTransactions) .. " new offset " .. tostring(offset))
        parentFrame.messagesFrame:SetScrollOffset(offset);
        FauxScrollFrame_Update(parentFrame.scrollFrame, numTransactions, parentFrame:GetMaxShownLogsForFrameSize(), GUILDBANK_TRANSACTION_HEIGHT );
    end
end

function GuildBankLogFrame:PrintTransactions()
    local numTransactions = 0;
    
    PLGuildBankClassic:debug("PrintTransactions: num transactions " .. tostring(numTransactions))

    if self.displayingLog then
        numTransactions = getn(self.displayingLog)
        if numTransactions > MAX_SHOWN_TRANSACTIONS then
            -- only log the last MAX_SHOWN_TRANSACTIONS number of transactions even if the log has more
            numTransactions = MAX_SHOWN_TRANSACTIONS
            PLGuildBankClassic:debug("PrintTransactions: cut due to MAX_TRANSACTIONS")
        end
    end
    
    local i = 1
    local money
    local msg
    local record
    local timestamp

    local currentTime = time()

    for i=numTransactions, 1, -1 do
        record = self.displayingLog[i]
        timestamp = record.timestamp
        -- todo: diff current time with dateTable
        local timediff = currentTime - timestamp

        local dateTable = PLGuildBankClassic:SecondsToTimeTable(timediff, true, true)
        local year = dateTable.years
        local month = dateTable.months
        local day = dateTable.days
        local hour = dateTable.hours
        local min = dateTable.minutes
        local sec = dateTable.seconds

        PLGuildBankClassic:debug(format("Converted timedif %d into year=%d, month=%d, day=%d, hour=%d, min=%d, sec=%d", timediff, year, month, day, hour, min, sec))

        name = NORMAL_FONT_COLOR_CODE..record.name..FONT_COLOR_CODE_CLOSE

        if record.type == PLGuildBankClassic.transactionTypes.money then

            moneyValue = (record.goldPerItem or 0) * (record.quantity or 1)
            --money = GetDenominationsFromCopper(moneyValue)
            money = PLGuildBankClassic:PriceToMoneyString(moneyValue, true)

            if record.mode == PLGuildBankClassic.transactionModes.deposit then
                msg = format(L["%s deposited %s"], name, money)

                if record.title then
                    msg = msg .. " " .. ORANGE_FONT_COLOR_CODE .. format(L[" as %s"], record.title) .. " " .. FONT_COLOR_CODE_CLOSE
                end
            else
                msg = format(L["%s |cffff2020withdrew|r %s"], (name or L["unknown"]), (money or L["unknown"]))

                if record.title then
                    msg = msg .. " " .. ORANGE_FONT_COLOR_CODE .. format(L[" for %s"], record.title) .. " " .. FONT_COLOR_CODE_CLOSE
                end
            end

            if record.source then
                msg = msg .. "  " .. NORMAL_FONT_COLOR_CODE .. self:ConvertSourceToExt(record.source) .. FONT_COLOR_CODE_CLOSE
            end

            if msg then
                self.messagesFrame:AddMessage(msg..GUILD_BANK_LOG_TIME_PREPEND..format(L["( %s ago )"], RecentTimeDate(year, month, day, hour)).."|r" )
            end

        elseif record.type == PLGuildBankClassic.transactionTypes.item then

            local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(record.itemId);

            moneyValue = (record.goldPerItem or 0) * (record.quantity or 1)
            --money = GetDenominationsFromCopper(moneyValue)
            money = PLGuildBankClassic:PriceToMoneyString(moneyValue, true)

            if record.mode == PLGuildBankClassic.transactionModes.deposit then
   
                msg = format(L["%s deposited %s"], (name or L["unknown"]), (sLink or L["unknown"]));
                if ( record.quantity > 1 ) then
                    msg = msg..format(L[" x %d"], record.quantity);
                end
            else
                msg = format(L["%s |cffff2020withdrew|r %s"], (name or L["unknown"]), (sLink or L["unknown"]));
                if ( record.quantity > 1 ) then
                    msg = msg..format(L[" x %d"], record.quantity);
                end
            end

            if moneyValue > 0 and PLGuildBankClassic:ShowEstimatedValueForItemLogs() then
                msg = msg .. " " .. GRAY_FONT_COLOR_CODE  .. format(L["( est. value: %s )"], money) .. FONT_COLOR_CODE_CLOSE
            end

            if record.source then
                msg = msg .. " " .. NORMAL_FONT_COLOR_CODE .. self:ConvertSourceToExt(record.source) .. FONT_COLOR_CODE_CLOSE
            end

            if msg then
                self.messagesFrame:AddMessage( msg..GUILD_BANK_LOG_TIME_PREPEND..format(L["( %s ago )"], RecentTimeDate(year, month, day, hour)).."|r" );
            end

        end
    end

    FauxScrollFrame_Update(self.scrollFrame, numTransactions, self:GetMaxShownLogsForFrameSize(), GUILDBANK_TRANSACTION_HEIGHT );
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