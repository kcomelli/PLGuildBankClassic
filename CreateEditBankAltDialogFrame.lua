local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local CreateEditBankAltDialogFrame = CreateFrame("Frame")
local CreateEditBankAltDialogFrame_MT = {__index = CreateEditBankAltDialogFrame}

local LibWindow = LibStub("LibWindow-1.1")
local Events = PLGuildBankClassic:GetModule("Events")

--SEND_MAIL_TAB_LIST = {};
--SEND_MAIL_TAB_LIST[1] = "SendMailNameEditBox";
--SEND_MAIL_TAB_LIST[2] = "SendMailSubjectEditBox";
--SEND_MAIL_TAB_LIST[3] = "SendMailBodyEditBox";
--SEND_MAIL_TAB_LIST[4] = "SendMailMoneyGold";
--SEND_MAIL_TAB_LIST[5] = "SendMailMoneyCopper";

PLGuildBankClassic.CreateEditBankAltDialogFrame = {}
PLGuildBankClassic.CreateEditBankAltDialogFrame.defaults = {}
PLGuildBankClassic.CreateEditBankAltDialogFrame.prototype = CreateEditBankAltDialogFrame
function PLGuildBankClassic.CreateEditBankAltDialogFrame:Create(mainFrame, settings)
	local frame = setmetatable(CreateFrame("Frame", "CreateEditBankAltDialogFrame", UIParent, "CreateEditBankAltDialogFrame"), CreateEditBankAltDialogFrame_MT)

    -- settings
    frame.settings = settings.charConfig
    frame.numIconsPerRow = 7
    frame.numIconRows = 6
    frame.numIconsShown = frame.numIconsPerRow * frame.numIconRows
    frame.iconRowHeight = 36

    frame.iconArrayBuilt = false
    frame.modeNew = true
    
    frame.characterData = {}
    frame.mainFrame = mainFrame

    -- scripts
	frame:SetScript("OnShow", frame.OnShow)
    frame:SetScript("OnHide", frame.OnHide)

    frame:SetWidth(frame.settings.width)
    frame:SetHeight(frame.settings.height)
    
    LibWindow.RegisterConfig(frame, frame.settings)
	LibWindow.RestorePosition(frame)

    frame.selectIconFrame.selectableIcons.ScrollBar.scrollStep = 8 * frame.iconRowHeight;

    tinsert(UISpecialFrames, "CreateEditBankAltDialogFrame")
 
    return frame
end

function CreateEditBankAltDialogFrame:OnShow()
    self.dragArea:SetText(L["Add new bank character"])
    self.configCharacterLabel.Text:SetText(L["Name of the bank char (must be member of your guild)"])
    self.configTabDescription.Text:SetText(L["Add a short description (e.g. Consumables or Professions)"])
    self.configIconSelect.Text:SetText(L["Select an icon to use for the tab"])

    self:EnsureIcons()
    self:UpdateIconFrame()
end

function CreateEditBankAltDialogFrame:EnsureIcons()
    if ( not self.iconArrayBuilt ) then
		BuildIconArray(self.selectIconFrame, "BankCharIconPopupButton", "IconPopupButtonTemplate", self.numIconsPerRow, self.numIconRows);
        self.iconArrayBuilt = true;
        local firsticonPopupButton = _G["BankCharIconPopupButton"..1];
        firsticonPopupButton:SetPoint("TOPLEFT", 16, -12);
    end
end

function CreateEditBankAltDialogFrame:OnHide()
    Events.UnregisterAll(self)
    Events.UnregisterAll(self.selectIconFrame.selectableIcons)
end

function CreateEditBankAltDialogFrame:InitCreateNew()
    self.characterData.name = ""
    self.characterData.description = ""
    self.characterData.icon = 0
    self.characterData.iconTexture = ""

    self:InitEditExisting(self.characterData)
    self.modeNew = true
end

function CreateEditBankAltDialogFrame:InitEditExisting(charaterInfo)
    self.characterData.name = charaterInfo.name
    self.characterData.description = charaterInfo.description
    self.characterData.icon = charaterInfo.icon
    self.characterData.iconTexture = charaterInfo.iconTexture

    if(self.characterData.name) then
        self.dragArea:SetText(L["Edit bank character"])
    else
        self.dragArea:SetText(L["Add new bank character"])
    end

    self.configCharacterEditBox:SetText(self.characterData.name)
    self.configDescriptionEditBox:SetText(self.characterData.description)
    if(self.characterData.icon > 0) then
        self:PopupButton_SelectTexture(self.characterData.icon, false)
    end
    self:EnsureIcons()
    self:CanUseCharacter(self.configCharacterEditBox)
    self.modeNew = false
end

function CreateEditBankAltDialogFrame:OnSaveClick()
    if self.callback then
        PLGuildBankClassic:debug("OnSaveClick: calling callback")
        self:callback(self.mainFrame, self.openedByTab, "save", self.characterData, self.modeNew)
        self:Hide()
    else
        PLGuildBankClassic:debug("OnSaveClick: No callback registered")
    end
end

function CreateEditBankAltDialogFrame:OnCancelClick()
    self:Hide()
    if self.callback then
        PLGuildBankClassic:debug("OnCancelClick: calling callback")
        self:callback(self.mainFrame, self.openedByTab, "cancel", self.characterData, self.modeNew)
    else
        PLGuildBankClassic:debug("OnCancelClick: No callback registered")
    end
end

function CreateEditBankAltDialogFrame:SetCharacterEditFocus(editBox)
    editBox:SetFocus()
end

function CreateEditBankAltDialogFrame:CanUseCharacter(editBox)
    local charName = editBox:GetText()
    PLGuildBankClassic:debug("CanUseCharacter: Checking character usage - " .. charName)
    if(self.characterData.name ~= charName) then
        self.characterData.name = charName
    end

    local newName, newRealm, newServerName = PLGuildBankClassic:CharaterNameTranslation(self.characterData.name)
    PLGuildBankClassic:debug("CanUseCharacter: Translated to: " .. newName .. ", " .. newRealm .. ", " .. newServerName)
    local isInGuild, name, rank, level, class, note, officerNote = PLGuildBankClassic:IsPlayerInGuild(newServerName)
    PLGuildBankClassic:debug("CanUseCharacter: Guild check retruned: " .. tostring(isInGuild))

    if charName == nil or carName == "" or not isInGuild then
        self.saveButton:Disable()
        self.characterData.class = nil
        self.characterData.note = nil
        self.characterData.officerNote = nil
    else
        self.saveButton:Enable()
        self.characterData.class = class
        self.characterData.note = note
        self.characterData.officerNote = officerNote
    end
end

function CreateEditBankAltDialogFrame:DescriptionEditBox_OnTextChanged(editBox)
    self.characterData.description = editBox:GetText()
end

function CreateEditBankAltDialogFrame:IconPopupButton_OnClick(iconBtn, button, down)
    self:PopupButton_SelectTexture(iconBtn:GetID() + (FauxScrollFrame_GetOffset(self.selectIconFrame.selectableIcons) * self.numIconsPerRow), true);
end

function CreateEditBankAltDialogFrame:PopupButton_SelectTexture(selectedIcon, doUpdateIconFrame)
	self.characterData.icon = selectedIcon
	-- Clear out selected texture
	self.characterData.iconTexture = nil
    local curMacroInfo = PLGuildBankClassic:GetSpellorMacroIconInfo(self.characterData.icon)
    
    local buttonSelectedIcon = _G["CreateEditBankAltDialogFrameSelectedIconButtonIcon"]
    local buttonSelectedIconButton = _G["CreateEditBankAltDialogFrameSelectedIconButton"]

	if(type(curMacroInfo) == "number") then
		buttonSelectedIcon:SetTexture(curMacroInfo)
	else
		buttonSelectedIcon:SetTexture("INTERFACE\\ICONS\\"..curMacroInfo)
    end	
    if doUpdateIconFrame then
        self:UpdateIconFrame()
    end
end

function CreateEditBankAltDialogFrame:UpdateIconFrame()
    local parentFrame = self
    
    if(not parentFrame.characterData) then
        parentFrame = self:GetParent():GetParent()
    end

    local numIcons = #PLGuildBankClassic.iconFilenames;
	local iconPopupIcon, iconPopupButton;
	local iconPopupOffset = FauxScrollFrame_GetOffset(parentFrame.selectIconFrame.selectableIcons);
	local index;

    -- Icon list
	local texture;
	for i=1, parentFrame.numIconsShown do
		iconPopupIcon = _G["BankCharIconPopupButton"..i.."Icon"];
		iconPopupButton = _G["BankCharIconPopupButton"..i];
		index = (iconPopupOffset * parentFrame.numIconsPerRow) + i;
		texture = PLGuildBankClassic:GetSpellorMacroIconInfo(index);

		if ( index <= numIcons and texture ) then
			if(type(texture) == "number") then
				iconPopupIcon:SetTexture(texture);
			else
				iconPopupIcon:SetTexture("INTERFACE\\ICONS\\"..texture);
			end		
			iconPopupButton:Show();
		else
			iconPopupIcon:SetTexture("");
			iconPopupButton:Hide();
		end
		if ( parentFrame.characterData.icon and (index == parentFrame.characterData.icon) ) then
			iconPopupButton:SetChecked(true);
		elseif ( parentFrame.characterData.iconTexture == texture ) then
			iconPopupButton:SetChecked(true);
		else
			iconPopupButton:SetChecked(false);
		end
	end
	
	-- Scrollbar stuff
	FauxScrollFrame_Update(parentFrame.selectIconFrame.selectableIcons, ceil(numIcons / parentFrame.numIconsPerRow) + 1, parentFrame.numIconRows, parentFrame.iconRowHeight );
end
