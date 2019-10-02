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

PLGuildBankClassic.Frame = {}
PLGuildBankClassic.Frame.defaults = {}
PLGuildBankClassic.Frame.prototype = Frame
function PLGuildBankClassic.Frame:Create(name, titleText, settings, guildSettings)
	local frame = setmetatable(CreateFrame("Frame", name, UIParent, "PLGuildBankFrame"), Frame_MT)

	-- settings
	frame.settings = settings
	frame.guildSettings = guildSettings
	frame.titleText = titleText
	frame.bagButtons = {}

	frame.currentTab = 0
	frame.currentAltTab = 0

	-- components
	frame.guildConfigFrame = PLGuildBankClassic.GuildConfigFrame:Create(frame, frame.tabContentContainer)
	frame.guildConfigFrame:SetPoint("TOPLEFT", 10, 10)

	--frame.itemContainer = PLGuildBankClassic.ItemContainer:Create(frame)
	--frame.itemContainer:SetPoint("TOPLEFT", 10, -64)
	--frame.itemContainer:SetBags(config[1].bags)
	--frame.itemContainer:Show()

    -- scripts
    frame:SetScript("OnLoad", frame.OnLoad)
	frame:SetScript("OnShow", frame.OnShow)
	frame:SetScript("OnHide", frame.OnHide)
	frame:SetScript("OnEvent", frame.OnEvent)
	frame:SetScript("OnSizeChanged", frame.OnSizeChanged)

	-- non-bag events
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")

	-- load and apply config
	frame:SetWidth(settings.width)
	frame:SetHeight(settings.height)

	LibWindow.RegisterConfig(frame, settings)
	LibWindow.RestorePosition(frame)

    --frame:UpdateTitleText()
	--frame:UpdateBags()

	tinsert(UISpecialFrames, name)

	return frame
end

function Frame:ApplyLocalization()
	self.availableMoneyLabel:SetText(L["Available money"])
	self.tabBankItems:SetText(L["Bank items"])
	self.tabBankLog:SetText(L["Bank logs"])
	self.tabBankInfo:SetText(L["Guild info"])
	self.tabBankConfig:SetText(L["Configuration"])

    if PLGuildBankClassic:IsInGuild() == false then
        self.guildBankTitleLabel:SetText("")
        self.errorMessage:SetText(L["You are not in a guild!"])
		self.errorMessage:Show()
		self:HideFrames()
    else
        self.guildBankTitleLabel:SetFormattedText(L["%s's Guild Bank"], PLGuildBankClassic:GuildName())
    end

    if PLGuildBankClassic:CanConfigureBankAlts() == false then
        self.errorMessage:SetText(L["Addon requires bank-character configuration which can only be done by the guild master!"])
        self.errorMessage:Show()
    end
end

function Frame:OnLoad()
    self:UpdateTabard()
end

function Frame:OnShow()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    self:ApplyLocalization()
    self:UpdateTabard()
end

function Frame:OnHide()
	PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)

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

function Frame:PLGuildBankFrameTab_OnClick(tabButton, id)
	if PLGuildBankClassic:IsInGuild() then
		local parent = tabButton:GetParent()
		parent.currentTab = id

		if parent.currentTab == 1 then
			parent:ShowBankItems()
		end
		if parent.currentTab == 2 then
			parent:ShowBankLog()
		end
		if parent.currentTab == 3 then
			parent:ShowGuildInfo()
		end
		if parent.currentTab == 4 then
			parent:ShowConfig()
		end
	end
end

function Frame:ShowBankItems()
	if(self.currentTab ~= 1) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
end

function Frame:ShowBankLog()
	if(self.currentTab ~= 2) then
		return
	end

	self:HideFrames()
	self.logFrame:Show()
	self:SetTabContentVisibility(true)
end

function Frame:ShowGuildInfo()
	if(self.currentTab ~= 3) then
		return
	end

	self:HideFrames()
	self:SetTabContentVisibility(true)
end

function Frame:ShowConfig()
	if(self.currentTab ~= 4) then
		return
	end

	self:HideFrames()
	--self.configFrame:Show()
	--self:GuildRanksDropDown_DoLoad(self.configRankDropDown, self)
	self.guildConfigFrame:Show()
	self:SetTabContentVisibility(true)
end

function Frame:HideFrames()
	self:SetTabContentVisibility(false)
	self.logFrame:Hide()
	--self.configFrame:Hide()
	self.guildConfigFrame:Hide()
end

function Frame:SetTabContentVisibility(visible)
	if visible then
		self.tabContentContainer:Show()
	else
		self.tabContentContainer:Hide()
	end
end

function Frame:GuildRanksDropDown_DoLoad(dropDown, mainFrame)
	UIDropDownMenu_SetWidth(dropDown, 90);
	UIDropDownMenu_Initialize(dropDown, PLGuildRanksDropDown_Initialize)
	if PLGuildBankClassic:IsInGuild() then
		UIDropDownMenu_SetSelectedID(dropDown, mainFrame.guildSettings.minGuildRank);
	end
end

function PLGuildRanksDropDown_Initialize(self)
	if PLGuildBankClassic:IsInGuild() then
		local frame = self:GetParent():GetParent()
		local numRanks = GuildControlGetNumRanks()
		local info;

		for i = 0, numRanks do
			info = {
				text = GuildControlGetRankName(i);
				func = PLGuildRanksDropDown_OnClick;
			};
			UIDropDownMenu_AddButton(info);	
		end
	else
		self:Hide()
	end
end

function PLGuildRanksDropDown_OnClick(dropDown)
	if PLGuildBankClassic:IsInGuild() then
		local frame = self:GetParent():GetParent()
		local oldID = UIDropDownMenu_GetSelectedID(dropDown)
		UIDropDownMenu_SetSelectedID(dropDown, dropDown:GetID())
		local newID = dropDown:GetID()

		if(oldID ~= newID) then
			frame.guildSettings.minGuildRank = newId
		end
	end
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
