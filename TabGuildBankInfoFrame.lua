local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local GuildBankInfoFrame = CreateFrame("Frame")
local GuildBankInfoFrame_MT = {__index = GuildBankInfoFrame}

local Events = PLGuildBankClassic:GetModule("Events")

local MAX_SHOWN_LINES = 200
local GUILDBANK_INFO_LINE_HEIGHT = 14.2

PLGuildBankClassic.GuildBankInfoFrame = {}
PLGuildBankClassic.GuildBankInfoFrame.defaults = {}
PLGuildBankClassic.GuildBankInfoFrame.prototype = GuildBankInfoFrame
function PLGuildBankClassic.GuildBankInfoFrame:Create(parent)
	local frame = setmetatable(CreateFrame("Frame", "PLGuildBankFrameTabInfo", parent, "PLGuildBankFrameTabInfo"), GuildBankInfoFrame_MT)

    -- settings
    frame.displayingCharacterData = nil
    frame.editMode = false
    frame.itemHeight = GUILDBANK_INFO_LINE_HEIGHT

	-- components

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide)
    frame:SetScript("OnSizeChanged", frame.OnSizeChanged)

    tinsert(UISpecialFrames, "PLGuildBankFrameTabInfo")

    return frame
end 

function GuildBankInfoFrame:OnShow() 
    self:MessageFrame_OnLoad(self.infoReadContainer.guildInfoMessages)
    self.infoReadContainer:Show()
    self.infoEditContainer:Hide()

    -- do not allow other chars than bacnk char to alter info in order to avoid config info corruption
    --if PLGuildBankClassic:CanConfigureBankAlts() or PLGuildBankClassic:IsGuildBankChar() then
    if PLGuildBankClassic:IsGuildBankChar() then
        self.infoReadContainer.editButton:Enable()
        self.infoEditContainer.saveButton:Enable()
    else
        self.infoReadContainer.editButton:Disable()
        self.infoEditContainer.saveButton:Disable()
    end
end

function GuildBankInfoFrame:OnHide()
    Events.UnregisterAll(self)
    if self.editMode then
        self:ToggleEditMode()
    end
end

function GuildBankInfoFrame:Update(characterData)
    local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

    PLGuildBankClassic:debug("GuildBankInfoFrame:Update: character: " .. charServerName)

    self.displayingCharacterData = characterData
		
    local class = characterData.class
    if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
    local player = characterData.name
        
    self.configDescriptionLabel.Text:SetText(characterData.description)
    self.configCharLabel.Text:SetText("- " .. (class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player))

    self.configDescriptionLabel:SetWidth(self.configDescriptionLabel.Text:GetWidth())
    self.configCharLabel:SetWidth(self.configCharLabel.Text:GetWidth())

    if self.editMode then
        self:ToggleEditMode()
    end

    self.infoReadContainer.guildInfoMessages:Clear()
    self:PrintGuildInfo()
end

function GuildBankInfoFrame:OnSizeChanged()
    local scrollHeight = self:GetHeight()/2
    self.infoEditContainer.scrollFrame:SetHeight(scrollHeight);
    self.infoEditContainer.scrollFrame:SetWidth(self:GetWidth()-20);

    self.infoEditContainer.scrollFrame.SendScrollBarBackgroundTop:SetHeight(min(scrollHeight, 256));
	self.infoEditContainer.scrollFrame.SendScrollBarBackgroundTop:SetTexCoord(0, 0.484375, 0, min(scrollHeight, 256) / 256);
	self.infoEditContainer.scrollFrame.SendStationeryBackgroundLeft:SetHeight(min(scrollHeight, 256));
	self.infoEditContainer.scrollFrame.SendStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256);
	self.infoEditContainer.scrollFrame.SendStationeryBackgroundRight:SetHeight(min(scrollHeight, 256));
    self.infoEditContainer.scrollFrame.SendStationeryBackgroundRight:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256);
    
    self:Update(self.displayingCharacterData)
    self:DoLogScroll()
end

function GuildBankInfoFrame:ToggleEditMode()
    if self.editMode then
        self.infoReadContainer:Show()
        self.infoEditContainer:Hide()
        self.editMode = false
        self.infoEditContainer.scrollFrame.editBox:SetText("")
    else
        if self.displayingCharacterData then
            self.infoEditContainer.scrollFrame.editBox:SetText(self.displayingCharacterData.guildInfoText or "")
        else
            self.infoEditContainer.scrollFrame.editBox:SetText("")
        end
        self.infoEditContainer.scrollFrame.editBox:SetFocus()

        self.infoReadContainer:Hide()
        self.infoEditContainer:Show()
        self.editMode = true
    end
end

function GuildBankInfoFrame:PrintGuildInfo()
    local staticInfo = ""
    local numLines = self:CalculateNumberOfInfoLines()

    if self.displayingCharacterData and self.displayingCharacterData.guildInfoText then
        staticInfo = self.displayingCharacterData.guildInfoText
    end

    if staticInfo then
        local tbl = { strsplit("\n", staticInfo) }

        for i=1, #tbl do
            local txt = tbl[i]
            if not txt then
                txt = " "
            end
            --txt = NORMAL_FONT_COLOR_CODE..txt..FONT_COLOR_CODE_CLOSE
            self.infoReadContainer.guildInfoMessages:AddMessage( txt.."|r" );
        end
    end

    -- TODO: render item requests

    local maxShown = self:GetMaxShownLogsForFrameSize()-2
    if numLines < maxShown then
        -- append empty lines in order to align the text at the top of the frame
        for i=numLines+1, maxShown do
            self.infoReadContainer.guildInfoMessages:AddMessage( " |r" );
            numLines = numLines+1
        end
    end

    FauxScrollFrame_Update(self.infoReadContainer.scrollFrame, numLines, self:GetMaxShownLogsForFrameSize(), GUILDBANK_INFO_LINE_HEIGHT );
end

function GuildBankInfoFrame:OnSaveClick()
    if self.displayingCharacterData then
        local guildConfig = PLGuildBankClassic:GetGuildConfig() 
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(UnitName("player"))

        local infoText = self.infoEditContainer.scrollFrame.editBox:GetText()
        self.displayingCharacterData.guildInfoText = infoText
        self.displayingCharacterData.modifiedBy = charServerName
        self.displayingCharacterData.modifiedAt = PLGuildBankClassic:GetTimestamp()

        guildConfig.config.charConfigTimestamp = timestamp
        PLGuildBankClassic:UpdateVersionsInPublicNote()

        self.Events:Fire("PLGBC_EVENT_CHAR_CONFIG_CHANGED", timestamp)

        -- fire updated event because guild info of this char has been updated
        Events:Fire("PLGBC_EVENT_BANKCHAR_UPDATED", PLGuildBankClassic:IndexOfBankCharData(self.displayingCharacterData), self.displayingCharacterData, false)
    end

    self:ToggleEditMode()
    self:Update(self.displayingCharacterData)
end

function GuildBankInfoFrame:OnCancelClick()
    self:ToggleEditMode()
end

function GuildBankInfoFrame:OnEditClick()
    self:ToggleEditMode()
end

function GuildBankInfoFrame:MessageFrame_OnLoad(messageframe)
    --messageframe:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM);
    messageframe:SetFading(false);
    messageframe:SetFontObject(ChatFontNormal);
    messageframe:SetJustifyH("LEFT");
    messageframe:SetMaxLines(MAX_SHOWN_LINES);
end

function GuildBankInfoFrame:GetMaxShownLogsForFrameSize()
    local newHeight = ceil( self.infoReadContainer.guildInfoMessages:GetHeight() / GUILDBANK_INFO_LINE_HEIGHT)
    PLGuildBankClassic:debug("GetMaxShownLogsForFrameSize: Height " .. tostring(newHeight))

    return newHeight
end

function GuildBankInfoFrame:CalculateNumberOfInfoLines()
    local calculatedLines = 0

    if self.displayingCharacterData and self.displayingCharacterData.guildInfoText then
        local _, count = self.displayingCharacterData.guildInfoText:gsub('\n', '\n')

        calculatedLines = calculatedLines + (count or 0)
    end

    return calculatedLines
end

function GuildBankInfoFrame:DoLogScroll()

    local parentFrame = self

    if not parentFrame.infoReadContainer or not parentFrame.infoReadContainer.scrollFrame then
        parentFrame = self:GetParent():GetParent()
    end

    if parentFrame.infoReadContainer.scrollFrame then
        local offset = FauxScrollFrame_GetOffset(parentFrame.infoReadContainer.scrollFrame)
        local numLines = parentFrame:CalculateNumberOfInfoLines()
        
        PLGuildBankClassic:debug("DoLogScroll: num lines " .. tostring(numLines) .. " new offset " .. tostring(offset))
        parentFrame.infoReadContainer.guildInfoMessages:SetScrollOffset(offset);
        FauxScrollFrame_Update(parentFrame.infoReadContainer.scrollFrame, numLines, parentFrame:GetMaxShownLogsForFrameSize(), GUILDBANK_INFO_LINE_HEIGHT );
    end
end