local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

local Frame = CreateFrame("Frame")
local Frame_MT = {__index = Frame}

local LibWindow = LibStub("LibWindow-1.1")
local Events = PLGuildBankClassic:GetModule("Events")

local ITEM_CONTAINER_OFFSET_W = -22
local ITEM_CONTAINER_OFFSET_H = -95

local PLAYER_NAME = string.format("%s - %s", UnitName("player"), GetRealmName())

local TABARDBACKGROUNDUPPER = "Textures\\GuildEmblems\\Background_%s_TU_U";
local TABARDBACKGROUNDLOWER = "Textures\\GuildEmblems\\Background_%s_TL_U";
local TABARDEMBLEMUPPER = "Textures\\GuildEmblems\\Emblem_%s_15_TU_U";
local TABARDEMBLEMLOWER = "Textures\\GuildEmblems\\Emblem_%s_15_TL_U";
local TABARDBORDERUPPER = "Textures\\GuildEmblems\\Border_%s_02_TU_U";
local TABARDBORDERLOWER = "Textures\\GuildEmblems\\Border_%s_02_TL_U";
local TABARDBACKGROUNDID = 1;
local TABARDEMBLEMID = 1;
local TABARDBORDERID = 1;

MoneyTypeInfo["PLGUILDBANKCLASSIC"] = {
	UpdateFunc = function(self)
		return ItemCache:GetPlayerMoney(self:GetParent():GetPlayerName())
	end,

	collapse = 1,
	showSmallerCoins = "Backpack"
};

PLGuildBankClassic.CommsThresholdTriggers = {}
PLGuildBankClassic.LastBankCharOnlineQuery = 0

PLGuildBankClassic.Frame = {}
PLGuildBankClassic.Frame.defaults = {}
PLGuildBankClassic.Frame.prototype = Frame
function PLGuildBankClassic.Frame:Create(name, titleText, settings, guildSettings)
	local frame = setmetatable(CreateFrame("Frame", name, UIParent, "PLGuildBankFrame"), Frame_MT)

	-- settings
	frame.settings = settings.vault
	frame.guildSettings = guildSettings
	frame.titleText = titleText
	frame.bagButtons = {}

	frame.currentTab = 0
	frame.currentAltTab = 0

	-- components
	frame.guildConfigFrame = PLGuildBankClassic.GuildConfigFrame:Create(frame.tabContentContainer)
	frame.addEditBankAltChar = PLGuildBankClassic.CreateEditBankAltDialogFrame:Create(frame, settings)
	frame.bankContents = PLGuildBankClassic.GuildBankContentFrame:Create(frame.tabContentContainer)
	frame.bankLog = PLGuildBankClassic.GuildBankLogFrame:Create(frame.tabContentContainer)
	frame.bankInfo = PLGuildBankClassic.GuildBankInfoFrame:Create(frame.tabContentContainer)

    -- scripts
    frame:SetScript("OnLoad", frame.OnLoad)
	frame:SetScript("OnShow", frame.OnShow)
	frame:SetScript("OnHide", frame.OnHide)
	frame:SetScript("OnEvent", frame.OnEvent)
	frame:SetScript("OnSizeChanged", frame.OnSizeChanged)

	-- non-bag events
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")

	-- load and apply config
	frame:SetWidth(frame.settings.width)
	frame:SetHeight(frame.settings.height)

	frame:ConfigureTabs(frame)

	LibWindow.RegisterConfig(frame, frame.settings)
	LibWindow.RestorePosition(frame)

    --frame:UpdateTitleText()
	--frame:UpdateBags()

	tinsert(UISpecialFrames, name)

	return frame
end

function Frame:AddEditBankCharDialogResult(initiator, tab, mode, characterData, createNew)
	if mode == "save" then
		local changedName = false
		local existingDeleted = PLGuildBankClassic:GetBankCharDataByName(characterData.name)

		--local tab = initiator.addEditBankAltChar.openedByTab
		if createNew and existingDeleted == nil then
			PLGuildBankClassic:debug("Creating new bank character config using char: " .. characterData.name)
			PLGuildBankClassic:CreateBankChar(characterData.name, characterData.realm, characterData.description, characterData.class, characterData.icon, characterData.iconTexture, characterData.acceptState)
		else
			PLGuildBankClassic:debug("Updating bank character config using char: " .. characterData.name)
			if existingDeleted and existingDeleted.isDeleted then
				PLGuildBankClassic:debug("Reactivate deleted char: " .. characterData.name)
			end

			changedName = PLGuildBankClassic:EditBankChar(tab:GetID(), characterData.name, characterData.realm, characterData.description, characterData.class, characterData.icon, characterData.iconTexture, characterData.acceptState)
		end

		initiator:UpdateBankAltTabs(false)

		if createNew then
			Events:Fire("PLGBC_EVENT_BANKCHAR_ADDED", tab:GetID(), characterData)
		else
			Events:Fire("PLGBC_EVENT_BANKCHAR_UPDATED", tab:GetID(), characterData, changedName)
		end

		initiator:UpdateCurrentTab()

		if initiator.currentTab == 1 then
			initiator:PLGBC_EVENT_BANKCHAR_SLOT_SELECTED("PLGBC_EVENT_BANKCHAR_SLOT_SELECTED", tab:GetID(), characterData)
		end
	elseif mode == "delete" or mode=="delete-with-log" then
		PLGuildBankClassic:debug("Deleting character '" .. characterData.name .. "' ..")
		local existingDeleted = PLGuildBankClassic:GetBankCharDataByName(characterData.name)
		if existingDeleted then
			existingDeleted.isDeleted = true
			existingDeleted.acceptState = 0 -- reset accept state

			if mode=="delete-with-log" then
				-- delete log!
				PLGuildBankClassic:debug("Deleting character " .. characterData.name .. "'s LOG ..")
			end

			if not PLGuildBankClassic:CharacterOwnedByAccount(characterData.name) then
				-- remove cache
				PLGuildBankClassic:debug("Deleting character " .. characterData.name .. "'s cached-Inventory ..")
			end

			initiator:UpdateBankAltTabs(false)
			Events:Fire("PLGBC_EVENT_BANKCHAR_REMOVED", tab:GetID(), characterData)

			initiator:UpdateCurrentTab()
			if initiator.currentTab == tab:GetID() then
				local changedData = PLGuildBankClassic.GetBankCharDataByIndex(tab:GetID())
				if changedData then
					initiator:PLGBC_EVENT_BANKCHAR_SLOT_SELECTED("PLGBC_EVENT_BANKCHAR_SLOT_SELECTED", tab:GetID(), changedData)
				end
			end
		else
			PLGuildBankClassic:debug("Deleting character " .. characterData.name .. "' not possible - char not found !")
		end
	end
end

function Frame:ApplyLocalization()
	self.moneyFrameBankChar.tooltip = L["Money available on the selected bank character."]
	self.moneyFrameGuild.tooltip = L["Cumulated capital of all configured bank characters."]

	self.availableMoneyLabel.Text:SetText(L["Available money"])
	self.availableMoneyLabel:SetWidth(self.availableMoneyLabel.Text:GetWidth() + 2)

	self.tabBankItems:SetText(L["Bank items"])
	self.tabBankLog:SetText(L["Bank logs"])
	self.tabBankInfo:SetText(L["Guild info"])
	self.tabBankConfig:SetText(L["Configuration"])
	self.availableMoneyBankCharLabel.Text:SetFormattedText(L["Character %s:"], "")
	self.availableMoneyBankCharLabel:SetWidth(self.availableMoneyBankCharLabel.Text:GetWidth() + 2)
	self.availableMoneyGuildLabel.Text:SetText(L["Guild capital:"])
	self.availableMoneyGuildLabel:SetWidth(self.availableMoneyGuildLabel.Text:GetWidth() + 2)

    if PLGuildBankClassic:IsInGuild() == false then
        self.guildBankTitleLabel:SetText("")
        self.errorMessage:SetText(L["You are not in a guild!"])
		self.errorMessage:Show()
		self:HideFrames()
    else
		self.guildBankTitleLabel:SetFormattedText(L["%s's Guild Bank"], PLGuildBankClassic:GuildName())
		self.guildBankTitleBackground:SetWidth(self.guildBankTitleLabel:GetWidth() + 20)
    end
end

function Frame:ConfigureTabs(frame)
	frame.numTabs = 4
	frame.maxTabWidth = 110
	frame.Tabs = {}
	frame.Tabs[1] = frame.tabBankItems
	frame.Tabs[2] = frame.tabBankLog
	frame.Tabs[3] = frame.tabBankInfo
	frame.Tabs[4] = frame.tabBankConfig

	frame.CharTabs = {}
	frame.CharTabs[1] = frame.tabBankAlt1
	frame.CharTabs[2] = frame.tabBankAlt2
	frame.CharTabs[3] = frame.tabBankAlt3
	frame.CharTabs[4] = frame.tabBankAlt4
	frame.CharTabs[5] = frame.tabBankAlt5
	frame.CharTabs[6] = frame.tabBankAlt6
	frame.CharTabs[7] = frame.tabBankAlt7
	frame.CharTabs[8] = frame.tabBankAlt8
end

function Frame:OnLoad()
    self:UpdateTabard()
end

function Frame:OnShow()
	PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_ADDED")
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_UPDATED")
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_REMOVED")
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_SLOT_SELECTED")
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_MONEYCHANGED")
	Events.Register(self, "PLGBC_EVENT_BANKCHAR_ENTERED_WORLD")

	Events.Register(self, "PLGBC_RECEVIED_CONFIG")
	Events.Register(self, "PLGBC_RECEVIED_CHARCONFIG")
	Events.Register(self, "PLGBC_RECEVIED_INVENTORY")
	Events.Register(self, "PLGBC_RECEVIED_MONEY")
	Events.Register(self, "PLGBC_RECEVIED_LOG")

	self.addEditBankAltChar.callback = self.AddEditBankCharDialogResult
	self:InitializeUi(true)
	self:PLGuildBankFrameTab_OnClick(self.tabBankItems, 1)
end

function Frame:InitializeUi(firstInit)
	self:ApplyLocalization()
	self:UpdateTabard()
	MoneyFrame_Update(self.moneyFrameBankChar:GetName(), 0)
	self:UpdateBankAltTabs(firstInit or false)
	self:SetSumGuildMoney()
end

function Frame:OnHide()
	PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
	Events.UnregisterAll(self)
	-- clear search on hide
	--self.SearchBox.clearButton:Click()
end

function Frame:OnEvent(event, ...)
	--if event == "UNIT_PORTRAIT_UPDATE" and self:IsShown() then
	--	SetPortraitTexture(self.portrait, "player")
	--end
end

function Frame:OnSizeChanged(width, height)
	self.settings.width = width
	self.settings.height = height
	LibWindow.SavePosition(self)

	--self:UpdateItemContainer()
end

function Frame:UpdateGuildSettings(guildSettings)
	self.guildSettings = guildSettings
end

function Frame:DisplayErrorMessage(message)
	self.errorMessage:SetText(message)
	self.errorMessage:Show()
	self.acceptStateButton:Hide()
	self:HideFrames();

	if PLGuildBankClassic:IsGuildBankChar() and 
		(message == L["The bank character must install this AddOn and accept the state of being a guild-bank character!\n \nThis is required because the character's inventory, bank \nand money will be synced with all guild-members which are using this AddOn!"] or
		 message == L["You have declined that your character is a bank-guild char! No inventory and money data will be shared!\n \nYou can change this state by accepting the state now by clicking the button below."]) then
		-- show an additional accept button
		self.acceptStateButton:Show()
	end
end

function Frame:OnAcceptClick()
	PLGuildBankClassic:AcceptOrDeclineState("accept")
	self.acceptStateButton:Hide()
end

function Frame:HideError()
	self.errorMessage:Hide()
	self.acceptStateButton:Hide()
	self:DisplayTab(self.currentTab)
end

function Frame:CheckBankAlts()
	if PLGuildBankClassic:NumberOfConfiguredAlts() <= 0 or PLGuildBankClassic:CanConfigureBankAlts() == false then
		if PLGuildBankClassic:NumberOfConfiguredAlts() <= 0 then
			self:DisplayErrorMessage(L["Currently there are no guild bank-alt's configured.\nPlease use the right + button to add a new character."])

			return false
		end

		if PLGuildBankClassic:NumberOfConfiguredAlts() <= 0 and PLGuildBankClassic:CanConfigureBankAlts() == false then
			local minRank = PLGuildBankClassic:GetGuildRankTable()[PLGuildBankClassic:GetMinRankForAlts()]

			self:DisplayErrorMessage(string.format(L["Addon requires bank-character configuration\nwhich can only be done by rank '%s' or higher!"], minRank))

			return false
		end
	
	end

	return true
end

function Frame:PLGuildBankFrameTab_OnClick(tabButton, id)
	local parent = tabButton:GetParent()

	PanelTemplates_SetTab(self, id);

	if PLGuildBankClassic:IsInGuild() then
		parent.currentTab = id
		parent:DisplayTab(parent.currentTab)
	end
end

function Frame:UpdateCurrentTab()
	self:DisplayTab(self.currentTab)
end

function Frame:DisplayTab(id)
	if self.currentTab == 0 then
		self:HideFrames()
	end
	if self.currentTab == 1 then
		self:ShowBankItems()
	end
	if self.currentTab == 2 then
		self:ShowBankLog()
	end
	if self.currentTab == 3 then
		self:ShowGuildInfo()
	end
	if self.currentTab == 4 then
		self:ShowConfig()
	end
end

function Frame:ShowBankItems()
	if(self.currentTab ~= 1) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
	if self:CheckBankAlts() then
		-- fill bank items
		self.bankContents:Show()
	end
end

function Frame:ShowBankLog()
	if(self.currentTab ~= 2) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
	if self:CheckBankAlts() then
		-- fill bank log
		self.bankLog:Show()
	end
end

function Frame:ShowGuildInfo()
	if(self.currentTab ~= 3) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
	if self:CheckBankAlts() then
		-- fill bank info
		self.bankInfo:Show()
	end
end

function Frame:ShowConfig()
	if(self.currentTab ~= 4) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
	self.guildConfigFrame:Show()
end

function Frame:HideFrames()
	self:SetTabContentVisibility(false)
	self.guildConfigFrame:Hide()
	self.bankContents:Hide()
	self.bankLog:Hide()
	self.bankInfo:Hide()
end

function Frame:SetTabContentVisibility(visible)
	if visible then
		self.tabContentContainer:Show()
	else
		self.tabContentContainer:Hide()
	end
end

function Frame:OnSearchTextChanged(editBox, text)
	self.bankContents:ApplySearch(text)
end

-----------------------------------------------------------------------
-- Bank character tab buttons

function Frame:UpdateBankAltTabs(initializing)
	local disableAll = false
	local numberOfBankAlts = PLGuildBankClassic:NumberOfConfiguredAlts()
	for i = 1, 8 do
		self.CharTabs[i].addMode = false

		if i > numberOfBankAlts then
			if i == numberOfBankAlts + 1 and PLGuildBankClassic:CanConfigureBankAlts() then
				self.CharTabs[i]:Show()
				self.CharTabs[i].checkButton.iconTexture:SetTexture("Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab");
				self.CharTabs[i].checkButton.tooltip = L["Add a new bank character"]
				self.CharTabs[i].addMode = true
			else
				self.CharTabs[i].checkButton.tooltip = ""
				self.CharTabs[i]:Hide()
			end
		else
			local charData = PLGuildBankClassic:GetBankCharDataByIndex(i)
			local class = charData.class
			if not RAID_CLASS_COLORS[class] or not RAID_CLASS_COLORS[class].colorStr then class = nil end
			local player = charData.name

			-- todo configure tab button icon, text etc
			self.CharTabs[i].checkButton.iconTexture:SetTexture(PLGuildBankClassic:GetSpellorMacroIconInfo(charData.icon));
			self.CharTabs[i].checkButton.tooltip = string.format(L["Bank: %s\nChar: %s"], charData.description or L["Common"], class and ("|c%s%s|r"):format(RAID_CLASS_COLORS[class].colorStr, player) or player)
			self.CharTabs[i].addMode = false
			self.CharTabs[i]:Show()
		end

		if disableAll then
			self.CharTabs[i].checkButton:Disable()
		end
	end

	if initializing == true and numberOfBankAlts > 0 then
		self:PLGuildBankTab_OnClick(self.CharTabs[1].checkButton, "LeftButton", 1)
	end
end

function Frame:PLGuildBankTab_OnClick(checkButton, mouseButton, currentTabId)
	local tab = checkButton:GetParent()

	if tab.addMode then
		-- this tab is currently displaying the + symbol allowing the
		-- player to add a new bank character
		self.addEditBankAltChar:InitCreateNew()
		self.addEditBankAltChar:Show()
		self.addEditBankAltChar.openedByTab = tab
		checkButton:SetChecked(false)
	else
		self.currentAltTab = currentTabId
		-- clear character money info - will be set later if data is available
		MoneyFrame_Update(self.moneyFrameBankChar:GetName(), 0)
		local charData = PLGuildBankClassic:GetBankCharDataByIndex(currentTabId)

		for i=1, #self.CharTabs do
			self.CharTabs[i].checkButton:SetChecked(false)
		end
		checkButton:SetChecked(true)

		if mouseButton == "RightButton" then
			PLGuildBankClassic:debug("Changeing character info by index: " .. currentTabId)

			if charData then
				PLGuildBankClassic:debug("Changeing character name: " .. charData.name)
				self.addEditBankAltChar:InitEditExisting(charData)
				self.addEditBankAltChar:Show()
				self.addEditBankAltChar.openedByTab = tab
			else
				PLGuildBankClassic:debug("Could not load bank character data by index: " .. currentTabId)
			end
			checkButton:SetChecked(false)
		else
			Events:Fire("PLGBC_EVENT_BANKCHAR_SLOT_SELECTED", currentTabId, charData)
		end
	end
end

-----------------------------------------------------------------------
-- event handlers

function Frame:PLGBC_RECEVIED_CONFIG(event)
	PLGuildBankClassic:debug("RECEIVED new config via comms - update UI")
	-- cought if new config data received via comms
	Frame:InitializeUi(false)
end

function Frame:PLGBC_RECEVIED_CHARCONFIG(event)
	PLGuildBankClassic:debug("RECEIVED new char-config via comms - update UI")
	-- cought if new char config data received via comms
	local currentAltTab = Frame.currentAltTab
	Frame:InitializeUi(false)

	-- check if there is still a char config at the given index
	local charData = PLGuildBankClassic:GetBankCharDataByIndex(Frame.currentAltTab)
	local numberOfBankAlts = PLGuildBankClassic:NumberOfConfiguredAlts()
	if charData then
		Frame:PLGuildBankTab_OnClick(Frame.CharTabs[currentAltTab].checkButton, "LeftButton", currentAltTab)
	elseif numberOfBankAlts > 0 then
		-- if not - select the first one (reset)
		Frame:PLGuildBankTab_OnClick(Frame.CharTabs[1].checkButton, "LeftButton", 1)
	end

	PLGuildBankClassic:CheckIfAcceptenceIsPending()
end

function Frame:PLGBC_RECEVIED_INVENTORY(event, characterName)
	PLGuildBankClassic:debug("RECEIVED new inventory via comms for '" .. characterName .. "' - update UI")
	
	local charData = PLGuildBankClassic:GetBankCharDataByIndex(Frame.currentAltTab)

	if charData and charData.characterName == characterName then
		-- fire button click will trigger a char selected event which will update the frames with data
		Frame:PLGuildBankTab_OnClick(Frame.CharTabs[Frame.currentAltTab].checkButton, "LeftButton", Frame.currentAltTab)
	end
end

function Frame:PLGBC_RECEVIED_MONEY(event, characterName)
	PLGuildBankClassic:debug("RECEIVED new money via comms for '" .. characterName .. "' - update UI")
	
	local charData = PLGuildBankClassic:GetBankCharDataByIndex(Frame.currentAltTab)

	if charData and charData.characterName == characterName then
		-- fire button click will trigger a char selected event which will update the frames with data
		Frame:PLGuildBankTab_OnClick(Frame.CharTabs[Frame.currentAltTab].checkButton, "LeftButton", Frame.currentAltTab)
	end
end

function Frame:PLGBC_RECEVIED_LOG(event, characterName)
	PLGuildBankClassic:debug("RECEIVED new log via comms for '" .. characterName .. "' - update UI")

	local charData = PLGuildBankClassic:GetBankCharDataByIndex(Frame.currentAltTab)

	if charData and charData.characterName == characterName then
		-- fire button click will trigger a char selected event which will update the frames with data
		Frame:PLGuildBankTab_OnClick(Frame.CharTabs[Frame.currentAltTab].checkButton, "LeftButton", Frame.currentAltTab)
	end
end

function Frame:PLGBC_EVENT_BANKCHAR_ADDED(event, index, characterData)
	PLGuildBankClassic:debug("Bankchar added at index " .. tostring(index) .. " using name " .. characterData.name)
	PLGuildBankClassic:UpdateAtBankCharState()
end

function Frame:PLGBC_EVENT_BANKCHAR_UPDATED(event, index, characterData, nameChanged)
	PLGuildBankClassic:debug("Bankchar updated at index " .. tostring(index) .. " using name " .. characterData.name .. " (Name changed: " ..  tostring(nameChanged) .. ")")
	PLGuildBankClassic:UpdateAtBankCharState()
end

function Frame:PLGBC_EVENT_BANKCHAR_REMOVED(event, index, characterData)
	PLGuildBankClassic:debug("Bankchar removed at index " .. tostring(index) .. " using name " .. characterData.name)
	PLGuildBankClassic:UpdateAtBankCharState()
end

function Frame:PLGBC_EVENT_BANKCHAR_SLOT_SELECTED(event, index, characterData)
	self:HideError()

	PLGuildBankClassic:debug("Bankchar selected at index " .. tostring(index) .. " using name " .. characterData.name)
	local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterData.name)

	self.availableMoneyBankCharLabel.Text:SetFormattedText(L["Character %s:"], "")
	self.availableMoneyBankCharLabel:SetWidth(self.availableMoneyBankCharLabel.Text:GetWidth() + 2)

	local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)

	if characterData.acceptState ~= 1 then
		if cacheOwnerInfo.class then
			PLGuildBankClassic:debug("Cached data found")
		else
			PLGuildBankClassic:debug("No cached data found")
		end

		if characterData.acceptState == -1 then
			self:DisplayErrorMessage(L["You have declined that your character is a bank-guild char! No inventory and money data will be shared!\n \nYou can change this state by accepting the state now by clicking the button below."])
		else
			self:DisplayErrorMessage(L["The bank character must install this AddOn and accept the state of being a guild-bank character!\n \nThis is required because the character's inventory, bank \nand money will be synced with all guild-members which are using this AddOn!"])
		end
		return
	end

	if cacheOwnerInfo.class then
		PLGuildBankClassic:debug("Found cached data!")
		PLGuildBankClassic:debug(cacheOwnerInfo.name .. " (" .. cacheOwnerInfo.race .. " " .. cacheOwnerInfo.class .. ") Money: " .. tostring(cacheOwnerInfo.money))

		self.bankContents:Update(characterData)
		self.bankLog:Update(characterData)
		self.bankInfo:Update(characterData)
	else
		PLGuildBankClassic:debug("No cached data found")

		self:DisplayErrorMessage(L["No cached or received data found for this character.\nIf you are the owner of the character, log on and visit the bank!\nIf not, then you will receive bank information as soon as the ownser visited the bank!"])
		return
	end

	MoneyFrame_Update(self.moneyFrameBankChar:GetName(), characterData.money)
end

function Frame:PLGBC_EVENT_BANKCHAR_MONEYCHANGED(event, characterName, value, gainedOrLost, valueVersion)
	PLGuildBankClassic:debug("PLGBC_EVENT_BANKCHAR_MONEYCHANGED: character: " .. characterName .. " new amount: " .. tostring(value))
	self:SetSumGuildMoney()
	local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
	if self.bankContents.displayingCharacterData and self.bankContents.displayingCharacterData.name == charName and self.bankContents.displayingCharacterData.realm then
		MoneyFrame_Update(self.moneyFrameBankChar:GetName(), value)
	end
end

function Frame:PLGBC_EVENT_BANKCHAR_ENTERED_WORLD(event)
	PLGuildBankClassic:debug("PLGBC_EVENT_BANKCHAR_ENTERED_WORLD recevied")
	MoneyFrame_UpdateMoney(self.moneyFrameBankChar)
end

function Frame:SetSumGuildMoney()
	local capital = PLGuildBankClassic:SumBankCharMoney()
	PLGuildBankClassic:debug("SetSumGuildMoney: Calculated guild capital: " .. tostring(capital))
	MoneyFrame_Update(self.moneyFrameGuild:GetName(), capital)
end

-----------------------------------------------------------------------
-- Guild emblem and tabard functions

function Frame:ChangeBackground(id)
	if ( id > 50 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 50;
	end
	TABARDBACKGROUNDID = id;
	self:UpdateEmblem();
end
function Frame:ChangeEmblem(id)
	if ( id > 169 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 169;
	end
	TABARDEMBLEMID = id;
	self:UpdateEmblem();
end
function Frame:ChangeBorder(id)
	if ( id > 9 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 9;
	end
	TABARDBORDERID = id;
	self:UpdateEmblem();
end

function Frame:UpdateEmblem()
	local tabardBGID = TABARDBACKGROUNDID;
	if ( tabardBGID < 10 ) then
		tabardBGID = "0"..tabardBGID;
	end
	local tabardEmblemID = TABARDEMBLEMID;
	if ( tabardEmblemID < 10 ) then
		tabardEmblemID = "0"..tabardEmblemID;
	end
	local tabardBorderID = TABARDBORDERID;
	if ( tabardBorderID < 10 ) then
		tabardBorderID = "0"..tabardBorderID;
	end
	self.EmblemFrame.BackgroundUL:SetTexture(format(TABARDBACKGROUNDUPPER, tabardBGID));
	self.EmblemFrame.BackgroundUR:SetTexture(format(TABARDBACKGROUNDUPPER, tabardBGID));
	self.EmblemFrame.BackgroundBL:SetTexture(format(TABARDBACKGROUNDLOWER, tabardBGID));
	self.EmblemFrame.BackgroundBR:SetTexture(format(TABARDBACKGROUNDLOWER, tabardBGID));

	self.EmblemFrame.UL:SetTexture(format(TABARDEMBLEMUPPER, tabardEmblemID));
	self.EmblemFrame.UR:SetTexture(format(TABARDEMBLEMUPPER, tabardEmblemID));
	self.EmblemFrame.BL:SetTexture(format(TABARDEMBLEMLOWER, tabardEmblemID));
	self.EmblemFrame.BR:SetTexture(format(TABARDEMBLEMLOWER, tabardEmblemID));

	self.EmblemFrame.BorderUL:SetTexture(format(TABARDBORDERUPPER, tabardBorderID));
	self.EmblemFrame.BorderUR:SetTexture(format(TABARDBORDERUPPER, tabardBorderID));
	self.EmblemFrame.BorderBL:SetTexture(format(TABARDBORDERLOWER, tabardBorderID));
	self.EmblemFrame.BorderBR:SetTexture(format(TABARDBORDERLOWER, tabardBorderID));
end

function Frame:UpdateTabard()

	--Set the tabard images
	local tabardBackgroundUpper, tabardBackgroundLower, tabardEmblemUpper, tabardEmblemLower, tabardBorderUpper, tabardBorderLower = GetGuildTabardFileNames();
	if ( not tabardEmblemUpper ) then
		tabardBackgroundUpper = "Textures\\GuildEmblems\\Background_49_TU_U";
		tabardBackgroundLower = "Textures\\GuildEmblems\\Background_49_TL_U";
	end
	self.EmblemFrame.BackgroundUL:SetTexture(tabardBackgroundUpper);
	self.EmblemFrame.BackgroundUR:SetTexture(tabardBackgroundUpper);
	self.EmblemFrame.BackgroundBL:SetTexture(tabardBackgroundLower);
	self.EmblemFrame.BackgroundBR:SetTexture(tabardBackgroundLower);

	self.EmblemFrame.UL:SetTexture(tabardEmblemUpper);
	self.EmblemFrame.UR:SetTexture(tabardEmblemUpper);
	self.EmblemFrame.BL:SetTexture(tabardEmblemLower);
	self.EmblemFrame.BR:SetTexture(tabardEmblemLower);

	self.EmblemFrame.BorderUL:SetTexture(tabardBorderUpper);
	self.EmblemFrame.BorderUR:SetTexture(tabardBorderUpper);
	self.EmblemFrame.BorderBL:SetTexture(tabardBorderLower);
	self.EmblemFrame.BorderBR:SetTexture(tabardBorderLower);
end

-----------------------------------------------------------------------
-- Various information getters

function Frame:SetPlayer(player)
	if not player or not ItemCache:IsPlayerCached(player) then
		self.playerName = nil
	else
		self.playerName = player
	end
	self:Update()
end

function Frame:GetPlayerName()
	local name = self.playerName or PLAYER_NAME

	-- only return the realm name if its not the current realm
	local realm, player = ItemCache:GetPlayerAddress(name)
	if realm == GetRealmName() then
		name = player
	end
	return name
end

function Frame:IsCached()
	return ItemCache:IsPlayerCached(self:GetPlayerName()) or (self:IsBank() and not self:AtBank())
end

function Frame:IsBank()
	return self.currentConfig.isBank
end

function Frame:AtBank()
	return Events.atBank
end
