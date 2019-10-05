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
function PLGuildBankClassic.CreateEditBankAltDialogFrame:Create(parent, settings)
	local frame = setmetatable(CreateFrame("Frame", "CreateEditBankAltDialogFrame", parent, "CreateEditBankAltDialogFrame"), CreateEditBankAltDialogFrame_MT)

    -- settings
    frame.settings = settings.charConfig
    frame.numIconsPerRow = 7
    frame.numIconRows = 6
    frame.numIconsShown = frame.numIconsPerRow * frame.numIconRows
    frame.iconRowHeight = 36

    frame.iconArrayBuilt = false
    frame.iconFilenames = nil

    frame.characterData = {}

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

    if ( not self.iconArrayBuilt ) then
		BuildIconArray(self.selectIconFrame, "BankCharIconPopupButton", "IconPopupButtonTemplate", self.numIconsPerRow, self.numIconRows);
        self.iconArrayBuilt = true;
        local firsticonPopupButton = _G["BankCharIconPopupButton"..1];
        firsticonPopupButton:SetPoint("TOPLEFT", 16, -12);
    end
    
    self:RefreshPlayerSpellIconInfo()
    self:UpdateIconFrame()
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
end

function CreateEditBankAltDialogFrame:InitEditExisting(charaterInfo)
end

function CreateEditBankAltDialogFrame:OnSaveClick()
    print("Save clicked")
end

function CreateEditBankAltDialogFrame:OnCancelClick()
    self:Hide()
    self:InitCreateNew()
end

function CreateEditBankAltDialogFrame:SetCharacterEditFocus(editBox)
    editBox:SetFocus()
end

function CreateEditBankAltDialogFrame:CanUseCharacter(editBox)
    return true
end

function CreateEditBankAltDialogFrame:IconPopupButton_OnClick(iconBtn, button, down)
    self:PopupButton_SelectTexture(iconBtn:GetID() + (FauxScrollFrame_GetOffset(self.selectIconFrame.selectableIcons) * self.numIconsPerRow));
end

function CreateEditBankAltDialogFrame:PopupButton_SelectTexture(selectedIcon)
	self.characterData.icon = selectedIcon;
	-- Clear out selected texture
	self.characterData.iconTexture = nil;
    local curMacroInfo = self:GetSpellorMacroIconInfo(self.characterData.icon);
    
    selectedMacroIcon = _G["CreateEditBankAltDialogFrameSelectedIconButtonIcon"];
    selectedMacroIconButton = _G["CreateEditBankAltDialogFrameSelectedIconButton"];

	if(type(curMacroInfo) == "number") then
		selectedMacroIcon:SetTexture(curMacroInfo);
	else
		selectedMacroIcon:SetTexture("INTERFACE\\ICONS\\"..curMacroInfo);
	end	
	self:UpdateIconFrame()
end

function CreateEditBankAltDialogFrame:UpdateIconFrame()
    local parentFrame = self
    
    if(not parentFrame.iconFilenames) then
        parentFrame = self:GetParent():GetParent()
    end

    local numIcons = #parentFrame.iconFilenames;
	local iconPopupIcon, iconPopupButton;
	local iconPopupOffset = FauxScrollFrame_GetOffset(parentFrame.selectIconFrame.selectableIcons);
	local index;

    -- Icon list
	local texture;
	for i=1, parentFrame.numIconsShown do
		iconPopupIcon = _G["BankCharIconPopupButton"..i.."Icon"];
		iconPopupButton = _G["BankCharIconPopupButton"..i];
		index = (iconPopupOffset * parentFrame.numIconsPerRow) + i;
		texture = parentFrame:GetSpellorMacroIconInfo(index);

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

function CreateEditBankAltDialogFrame:RefreshPlayerSpellIconInfo()
	if ( self.iconFilenames ) then
		return;
	end
	
	-- We need to avoid adding duplicate spellIDs from the spellbook tabs for your other specs.
	local activeIcons = {};
	
	for i = 1, GetNumSpellTabs() do
		local tab, tabTex, offset, numSpells, _ = GetSpellTabInfo(i);
		offset = offset + 1;
		local tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			--to get spell info by slot, you have to pass in a pet argument
			local spellType, ID = GetSpellBookItemInfo(j, "player"); 
			if (spellType ~= "FUTURESPELL") then
				local fileID = GetSpellBookItemTexture(j, "player");
				if (fileID) then
					activeIcons[fileID] = true;
				end
			end
			if (spellType == "FLYOUT") then
				local _, _, numSlots, isKnown = GetFlyoutInfo(ID);
				if (isKnown and numSlots > 0) then
					for k = 1, numSlots do 
						local spellID, overrideSpellID, isKnown = GetFlyoutSlotInfo(ID, k)
						if (isKnown) then
							local fileID = GetSpellTexture(spellID);
							if (fileID) then
								activeIcons[fileID] = true;
							end
						end
					end
				end
			end
		end
	end

	self.iconFilenames = { "INV_MISC_QUESTIONMARK" };
	for fileDataID in pairs(activeIcons) do
		self.iconFilenames[#self.iconFilenames + 1] = fileDataID;
	end

	GetLooseMacroIcons( self.iconFilenames );
	GetLooseMacroItemIcons( self.iconFilenames );
	GetMacroIcons( self.iconFilenames );
	GetMacroItemIcons( self.iconFilenames );
end

function CreateEditBankAltDialogFrame:GetSpellorMacroIconInfo(index)
	if ( not index ) then
		return;
	end
	local texture = self.iconFilenames[index];
	local texnum = tonumber(texture);
	if (texnum ~= nil) then
		return texnum;
	else
		return texture;
	end
end