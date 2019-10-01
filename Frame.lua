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
function PLGuildBankClassic.Frame:Create(name, titleText, settings)
	local frame = setmetatable(CreateFrame("Frame", name, UIParent, "PLGuildBankFrame"), Frame_MT)

	-- settings
	frame.settings = settings
	frame.titleText = titleText
	frame.bagButtons = {}

	-- components
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

function Frame:OnLoad()
    Frame:UpdateTabard()
end

function Frame:OnShow()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    Frame:UpdateTabard()
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

-----------------------------------------------------------------------
-- Guild emblem and tabard functions
function Frame:ChangeBackground(id)
	if ( id > 50 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 50;
	end
	TABARDBACKGROUNDID = id;
	Frame:UpdateEmblem();
end
function Frame:ChangeEmblem(id)
	if ( id > 169 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 169;
	end
	TABARDEMBLEMID = id;
	Frame:UpdateEmblem();
end
function Frame:ChangeBorder(id)
	if ( id > 9 ) then
		id = 1;
	elseif ( id < 0 ) then
		id = 9;
	end
	TABARDBORDERID = id;
	Frame:UpdateEmblem();
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
	GuildBankEmblemBackgroundUL:SetTexture(format(TABARDBACKGROUNDUPPER, tabardBGID));
	GuildBankEmblemBackgroundUR:SetTexture(format(TABARDBACKGROUNDUPPER, tabardBGID));
	GuildBankEmblemBackgroundBL:SetTexture(format(TABARDBACKGROUNDLOWER, tabardBGID));
	GuildBankEmblemBackgroundBR:SetTexture(format(TABARDBACKGROUNDLOWER, tabardBGID));

	GuildBankEmblemUL:SetTexture(format(TABARDEMBLEMUPPER, tabardEmblemID));
	GuildBankEmblemUR:SetTexture(format(TABARDEMBLEMUPPER, tabardEmblemID));
	GuildBankEmblemBL:SetTexture(format(TABARDEMBLEMLOWER, tabardEmblemID));
	GuildBankEmblemBR:SetTexture(format(TABARDEMBLEMLOWER, tabardEmblemID));

	GuildBankEmblemBorderUL:SetTexture(format(TABARDBORDERUPPER, tabardBorderID));
	GuildBankEmblemBorderUR:SetTexture(format(TABARDBORDERUPPER, tabardBorderID));
	GuildBankEmblemBorderBL:SetTexture(format(TABARDBORDERLOWER, tabardBorderID));
	GuildBankEmblemBorderBR:SetTexture(format(TABARDBORDERLOWER, tabardBorderID));
end

function Frame:UpdateTabard()
	--Set the tabard images
	local tabardBackgroundUpper, tabardBackgroundLower, tabardEmblemUpper, tabardEmblemLower, tabardBorderUpper, tabardBorderLower = GetGuildTabardFileNames();
	if ( not tabardEmblemUpper ) then
		tabardBackgroundUpper = "Textures\\GuildEmblems\\Background_49_TU_U";
		tabardBackgroundLower = "Textures\\GuildEmblems\\Background_49_TL_U";
	end
	GuildBankEmblemBackgroundUL:SetTexture(tabardBackgroundUpper);
	GuildBankEmblemBackgroundUR:SetTexture(tabardBackgroundUpper);
	GuildBankEmblemBackgroundBL:SetTexture(tabardBackgroundLower);
	GuildBankEmblemBackgroundBR:SetTexture(tabardBackgroundLower);

	GuildBankEmblemUL:SetTexture(tabardEmblemUpper);
	GuildBankEmblemUR:SetTexture(tabardEmblemUpper);
	GuildBankEmblemBL:SetTexture(tabardEmblemLower);
	GuildBankEmblemBR:SetTexture(tabardEmblemLower);

	GuildBankEmblemBorderUL:SetTexture(tabardBorderUpper);
	GuildBankEmblemBorderUR:SetTexture(tabardBorderUpper);
	GuildBankEmblemBorderBL:SetTexture(tabardBorderLower);
	GuildBankEmblemBorderBR:SetTexture(tabardBorderLower);
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
