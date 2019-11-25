local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")
local Cache = LibStub('LibItemCache-2.0')

local goldicon    = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:4:0|t"
local silvericon  = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:4:0|t"
local coppericon  = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:4:0|t"


function PLGuildBankClassic:GetItemPrice(itemId, forceVendorPrice)
	local itemName, itemLink, itemRarity, _, itemMinLevel, itemType, _, _, _, _, itemVendorPrice, classID = GetItemInfo (itemId);
	local priceInfo = 0

	priceInfo = itemVendorPrice

	if not forceVendorPrice then
		-- Auctionator support
		if Atr_STWP_GetPrices then
			local oldDisenchantValue = AUCTIONATOR_D_TIPS
			
			AUCTIONATOR_D_TIPS = 0
			local vendorPrice, auctionPrice, dePrice = Atr_STWP_GetPrices (itemLink, 1, false, itemVendorPrice, itemName, classID, itemRarity, itemLevel);
			AUCTIONATOR_D_TIPS = oldDisenchantValue

			priceInfo = (auctionPrice or 0)
		end
	end

	return priceInfo
end

function PLGuildBankClassic:GetItemIdFromName(itemName)
	if itemName then
		local itemName, itemLink, itemRarity, _, itemMinLevel, itemType, _, _, _, _, itemVendorPrice, classID = GetItemInfo (itemName);

		local itemId = string.match(itemLink, "Hitem:(%d+):")

		if itemId then
			return tonumber(itemId)
		end
	end

	return nil
end

function PLGuildBankClassic:GetItemIdFromLink(itemLink)
	if itemLink then
		local itemId = string.match(itemLink, "Hitem:(%d+):")

		if itemId then
			return tonumber(itemId)
		end
	end

	return nil
end

function PLGuildBankClassic:TryGetOpenMailData()
	local mailIndex = 0
	
	if (InboxFrame and InboxFrame.openMailID) then
		-- player has an inbox item frame open
		mailIndex = InboxFrame.openMailID
		--PLGuildBankClassic:debug("TryGetOpenMailData: using mailIndex " .. tostring(mailIndex or 0) .. " from open InboxFrame")
	elseif OpenAllMail and OpenAllMail.mailIndex and not OpenAllMail:IsEnabled() then
		-- player currently opening all mails
		mailIndex = OpenAllMail.mailIndex
		--PLGuildBankClassic:debug("TryGetOpenMailData: using mailIndex " .. tostring(mailIndex or 0) .. " from OpenAllMailMixin")
	elseif self.lastClosedMailData then
		-- player recently closed a mail frame - use last saved index
		--PLGuildBankClassic:debug("TryGetOpenMailData: using mail " .. (self.lastClosedMailData.subject or "na") .. " from open lastClosedMailData")
		return self.lastClosedMailData
	end

	if mailIndex > 0 then
		return self.mailData[mailIndex]
	end
 
	return nil
end

function PLGuildBankClassic:GetNormalizedLogTitleFromSubject(subject)
	return subject
end

function PLGuildBankClassic:IsAuctionHouseSender(sender)
	if not sender then
		return false
	end

	local pos = string.find(sender, L["Auction House"])
	PLGuildBankClassic:debug("Finding " .. L["Auction House"] .. " in string " .. sender .. " - pos: " .. (tostring(pos) or "na"))
	return pos ~= nil and pos > 0
end

function PLGuildBankClassic:IsAuctionSuccessful(subject)
	if not subject then
		return false
	end

	local pos = string.find(subject, L["Auction successful:"])
	PLGuildBankClassic:debug("Finding " .. L["Auction successful:"] .. " in string " .. subject .. " - pos: " .. (tostring(pos) or "na"))
	return pos ~= nil and pos > 0
end
function PLGuildBankClassic:IsAuctionCancelled(subject)
	if not subject then
		return false
	end

	local pos = string.find(subject, L["Auction cancelled:"])
	PLGuildBankClassic:debug("Finding " .. L["Auction cancelled:"] .. " in string " .. subject .. " - pos: " .. (tostring(pos) or "na"))
	return pos ~= nil and pos > 0
end
function PLGuildBankClassic:IsAuctionExpired(subject)
	if not subject then
		return false
	end

	local pos = string.find(subject, L["Auction expired:"])
	PLGuildBankClassic:debug("Finding " .. L["Auction expired:"] .. " in string " .. subject .. " - pos: " .. (tostring(pos) or "na"))
	return pos ~= nil and pos > 0
end

function PLGuildBankClassic:IsAuctionOutbid(subject)
	if not subject then
		return false
	end

	local pos = string.find(subject, L["Outbid on "])
	PLGuildBankClassic:debug("Finding " .. L["Outbid on "] .. " in string " .. subject .. " - pos: " .. (tostring(pos) or "na"))
	return pos ~= nil and pos > 0
end

function PLGuildBankClassic:UpdateVersionsInPublicNote()
	if PLGuildBankClassic:IsGuildBankChar() then
		local configVersion = PLGuildBankClassic.atBankChar.modifiedAt or 0
		local inventoryVersion = PLGuildBankClassic.atBankChar.inventoryVersion or 0
		local moneyVersion = PLGuildBankClassic.atBankChar.moneyVersion or 0
		local logVersion = PLGuildBankClassic.atBankChar.logVersion or 0

		local noteString = string.format("GB %s,%s,%s,%s", PLGuildBankClassic:base62Encode(configVersion), 
			PLGuildBankClassic:base62Encode(inventoryVersion), 
			PLGuildBankClassic:base62Encode(moneyVersion),
			PLGuildBankClassic:base62Encode(logVersion))

		local charIndex = PLGuildBankClassic:GetGuildRosterIndexOfBankChar()

		if charIndex then
			GuildRosterSetPublicNote(charIndex, noteString)
			PLGuildBankClassic:debug("UpdateVersionsInPublicNote: Updated public note to: " .. noteString)
			--PLGuildBankClassic:debug("UpdateVersionsInPublicNote: Used versions: " .. tostring(configVersion) .. ", " .. tostring(inventoryVersion) .. ", " .. tostring(moneyVersion) .. ", " .. tostring(logVersion))
		else
			PLGuildBankClassic:debug("UpdateVersionsInPublicNote: could not get guild roster index")
		end
	end
end

function PLGuildBankClassic:GetGuildRosterIndexOfBankChar()
	if PLGuildBankClassic:IsGuildBankChar() then
		local inGuild, name, rank, level, class, note, officernote, index = PLGuildBankClassic:IsPlayerInGuild(PLGuildBankClassic.atBankChar.name .. "-" .. PLGuildBankClassic.atBankChar.realm)
		if inGuild then
			return index
		end
	end

	return nil
end



--[[ Slot Type ]]--

function PLGuildBankClassic:IsBasicBag(bag)
	return self:IsBank(bag) or self:IsBackpack(bag)
end

function PLGuildBankClassic:IsBackpack(bag)
	return bag == BACKPACK_CONTAINER
end

function PLGuildBankClassic:IsBackpackBag(bag)
  return bag > BACKPACK_CONTAINER and bag <= NUM_BAG_SLOTS
end

function PLGuildBankClassic:IsBank(bag)
  return bag == BANK_CONTAINER
end

function PLGuildBankClassic:IsReagents(bag)
	return bag == REAGENTBANK_CONTAINER
end

function PLGuildBankClassic:IsBankBag(bag)
  return bag > NUM_BAG_SLOTS and bag <= (NUM_BAG_SLOTS + NUM_BANKBAGSLOTS)
end


--[[ Bag Type ]]--

PLGuildBankClassic.BAG_TYPES = {
	[-0x0001] = 'reagent',
	[0x00001] = 'quiver',
	[0x00002] = 'quiver',
	[0x00003] = 'soul',
	[0x00004] = 'soul',
	[0x00006] = 'herb',
	[0x00007] = 'enchant',
	[0x00008] = 'leather',
	[0x00010] = 'inscribe',
	[0x00020] = 'herb',
	[0x00040] = 'enchant',
	[0x00080] = 'engineer',
	[0x00200] = 'gem',
	[0x00400] = 'mine',
 	[0x08000] = 'tackle',
 	[0x10000] = 'refrige'
}

function PLGuildBankClassic:GetBagType(...)
	return PLGuildBankClassic.BAG_TYPES[self:GetBagFamily(...)] or 'normal'
end

function PLGuildBankClassic:GetBagFamily(owner, bag)
	if self:IsBank(bag) or self:IsBackpack(bag) then
		return 0
	elseif self:IsReagents(bag) then
		return -1
	end

	local info = self:GetBagInfo(owner, bag)
	return info.link and GetItemFamily(info.link) or 0
end

function PLGuildBankClassic:GetBagInfo(...)
 	return Cache:GetBagInfo(...)
end


---------------------------------------------------------------------
-- function PLGuildBankClassic:pairsByKeys(t, f)
--
-- This function will replace the pairs function in a for statement.
-- Sorts the output by key name
---------------------------------------------------------------------
function PLGuildBankClassic:pairsByKeys (t, f)
	local a = {}
		for n in pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
			i = i + 1
			if a[i] == nil then return nil
			else return a[i], t[a[i]]
			end
		end
	return iter
end

-------------------------------------------------------------------------------
-- player/character functions
-------------------------------------------------------------------------------

---------------------------------------------------------------------
-- function PLGuildBankClassic:GetPlayerName(unitId)
--
-- Returns the unit name
---------------------------------------------------------------------
function PLGuildBankClassic:GetPlayerName(unitId)
	name, realm = UnitName(unitId)

	if(name == nil) then
		return L["unkown-player"]
	end

	if(reaml == nil) then
		realm = GetRealmName()
	end

	return name .. "-" .. realm
end

---------------------------------------------------------------------
-- function PLGuildBankClassic:CharaterNameTranslation(characterName)
--
-- takes a character name and splits/transform the name in the player name
-- and realm name returning
-- nameOnly, realmName, serverName
---------------------------------------------------------------------
function PLGuildBankClassic:CharaterNameTranslation(characterName)
	local nameOnly
	local realmName
	local serverName

	nameOnly = characterName

	local dashIndex = string.find(characterName, "-", 1, true)

	if(dashIndex ~= nil and dashIndex >= 1) then
		nameOnly = string.sub(characterName, 1, dashIndex-1)
		realmName = string.sub(characterName, dashIndex+1)
		serverName = nameOnly .. "-" .. realmName
	else
		nameOnly = characterName
		realmName = GetRealmName()
		serverName = nameOnly .. "-" .. realmName
	end

	return nameOnly, realmName, serverName
end

function PLGuildBankClassic:IsPlayerInGuild(characterName)
    if PLGuildBankClassic:IsInGuild() then
        local numGuildMember = GetNumGuildMembers()
        for i=1, numGuildMember do
            local name, rank, rankIndex, level, class, zone, note, 
                  officernote, online, status, classFileName, 
                  achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)

            if name == characterName then
                return true, name, rank, level, class, note, officernote, i
            end
        end
    end

    return false, nil, nil, nil, nil, nil, nil
end

function PLGuildBankClassic:GetGuildRank(player)
	local name, rank, rankIndex;
	local guildSize;
  
	if IsInGuild() then
	  guildSize = GetNumGuildMembers();
	  for i=1, guildSize do
		name, rank, rankIndex = GetGuildRosterInfo(i)
		name = strsub(name, 1, string.find(name, "-")-1)  -- required to remove server name from player (can remove in classic if this is not an issue)
		if name == player then
		  return rank, rankIndex;
		end
	  end
	  return "NOTINGUILD";
	end
	return "NOGUILD"
  end
  
  function PLGuildBankClassic:GetGuildRankIndex(player)
	local name, rank;
	local guildSize,_,_ = GetNumGuildMembers();
  
	if IsInGuild() then
	  for i=1, tonumber(guildSize) do
		name,_,rank = GetGuildRosterInfo(i)
		name = strsub(name, 1, string.find(name, "-")-1)  -- required to remove server name from player (can remove in classic if this is not an issue)
		if name == player then
		  return rank+1;
		end
	  end
	  return false;
	end
  end

  function PLGuildBankClassic:IsGuildPlayerOnline(player)
	local name, rank, rankIndex;
	local guildSize;
  
	if IsInGuild() then
	  guildSize = GetNumGuildMembers();
	  for i=1, guildSize do
		name, rank, rankIndex, _, _, _, _, _, isOnline, _, _, _, _, isMobile = GetGuildRosterInfo(i)
		name = strsub(name, 1, string.find(name, "-")-1)  -- required to remove server name from player (can remove in classic if this is not an issue)
		if name == player and isOnline == true and isMobile == false then
		  return true
		end
	  end
	  return false
	end
	return false
  end

function PLGuildBankClassic:CheckOfficer()      -- checks if user is an officer IF core.IsOfficer is empty. Use before checks against core.IsOfficer
	if PLGuildBankClassic.IsOfficer == "" then      -- used as a redundency as it should be set on load in init.lua GUILD_ROSTER_UPDATE event
	  if PLGuildBankClassic:GetGuildRankIndex(UnitName("player")) == 1 then       -- automatically gives permissions above all settings if player is guild leader
		PLGuildBankClassic.IsOfficer = true
		return;
	  end
	  if IsInGuild() then
		local curPlayerRank = PLGuildBankClassic:GetGuildRankIndex(UnitName("player"))
		if curPlayerRank then
			PLGuildBankClassic.IsOfficer = C_GuildInfo.GuildControlGetRankFlags(curPlayerRank)[12]
		end
	  else
		PLGuildBankClassic.IsOfficer = false;
	  end
	end
  end


function PLGuildBankClassic:IsGuildBankChar()
    return PLGuildBankClassic.atBankChar ~= nil
end

function PLGuildBankClassic:CharacterOwnedByAccount(characterName)

	if characterName and self.db.factionrealm then
		local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)

		return (self.db.factionrealm.accountChars and self.db.factionrealm.accountChars[charServerName])
	end

	return false
end

function PLGuildBankClassic:IsInGuild()
    return PLGuildBankClassic.isInGuild
end

function PLGuildBankClassic:GuildName()
    return PLGuildBankClassic.guildName
end

function PLGuildBankClassic:GetTimestamp()
	return time()
end

-------------------------------------------------------------------------------
-- icon and texture functions
-------------------------------------------------------------------------------

function PLGuildBankClassic:RefreshPlayerSpellIconInfo()
	if ( PLGuildBankClassic.iconFilenames ) then
		return;
	end
	
	PLGuildBankClassic.iconFilenames = { "INV_MISC_QUESTIONMARK" };

	GetLooseMacroIcons( PLGuildBankClassic.iconFilenames );
	GetLooseMacroItemIcons( PLGuildBankClassic.iconFilenames );
	GetMacroIcons( PLGuildBankClassic.iconFilenames );
	GetMacroItemIcons( PLGuildBankClassic.iconFilenames );
end

function PLGuildBankClassic:GetSpellorMacroIconInfo(index)
	if ( not index ) then
		return;
	end
	local texture = PLGuildBankClassic.iconFilenames[index];
	local texnum = tonumber(texture);
	if (texnum ~= nil) then
		return texnum;
	else
		return texture;
	end
end

function PLGuildBankClassic:GetInventoryCache(characterName)

	if characterName ~= nil then
		local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
		local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)

		local inventoryData = {}

		for bag in PLGBC_COMBINED_INVENTORY_CONFIG do
			inventoryData[bag] = {}
			
			inventoryData[bag].info = ItemCache:GetBagInfo(cacheOwnerInfo.name, bag)

			if inventoryData[bag].info.bagSize ~= nil then
				inventoryData[bag].items = {}

				for slot = 1, inventoryData[bag].info.bagSize do
					inventoryData[bag].items[slot] = ItemCache:GetItemInfo(cacheOwnerInfo.name, bag, slot)
				end
			end
		end

		return inventoryData
	end

	return nil
end

function PLGuildBankClassic:SecondsToTimeTable(seconds, noSeconds, roundUp)
	local tempTime;
	seconds = roundUp and ceil(seconds) or floor(seconds);
	local retYears = 0
	local retMonths = 0
	local retDays = 0
	local retHours = 0
	local retMinutes = 0
	local retSeconds = 0

	maxCount = maxCount or 6;
	if ( seconds >= 86400  ) then
		if ( roundUp ) then
			tempTime = ceil(seconds / 86400);
		else
			tempTime = floor(seconds / 86400);
		end
		retDays = tempTime
		seconds = mod(seconds, 86400);
	end

	if ( retDays > 30  ) then
		if ( roundUp ) then
			tempTime = ceil(retDays / 30);
		else
			tempTime = floor(retDays / 30);
		end
		retMonths = tempTime
		retDays = mod(retDays, 30);
	end

	if ( retMonths >= 12  ) then
		if ( roundUp ) then
			tempTime = ceil(retMonths / 30);
		else
			tempTime = floor(retMonths / 30);
		end
		retYears = tempTime
		retMonths = mod(retMonths, 12);
	end

	if ( seconds >= 3600  ) then
		if (roundUp ) then
			tempTime = ceil(seconds / 3600);
		else
			tempTime = floor(seconds / 3600);
		end
		retHours = tempTime;
		seconds = mod(seconds, 3600);
	end

	if ( seconds >= 60  ) then
		if ( roundUp ) then
			tempTime = ceil(seconds / 60);
		else
			tempTime = floor(seconds / 60);
		end
		retMinutes = tempTime
		seconds = mod(seconds, 60);
	end
	if ( seconds > 0 and not noSeconds ) then
		retSeconds = seconds
	end
	return {
		years = retYears,
		months = retMonts,
		days = retDays,
		hours = retHours,
		minutes = retMinutes,
		seconds = retSeconds
	};
end

function PLGuildBankClassic:PriceToMoneyString (val, noZeroCoppers)
	local gold, silver, copper  = PLGuildBankClassic:val2gsc(val);
  
	local st = "";
  
	if (gold ~= 0) then
	  st = gold..goldicon.."  ";
	end
  
  
	if (st ~= "") then
	  st = st..format("%02i%s  ", silver, silvericon);
	elseif (silver ~= 0) then
	  st = st..silver..silvericon.."  ";
	end
  
	if (noZeroCoppers and copper == 0) then
	  return st;
	end
  
	if (st ~= "") then
	  st = st..format("%02i%s", copper, coppericon);
	elseif (copper ~= 0) then
	  st = st..copper..coppericon;
	end
  
	return st;
  
  end

function PLGuildBankClassic:val2gsc (v)
  local rv = PLGuildBankClassic:round(v)

  local g = math.floor (rv/10000);

  rv = rv - g*10000;

  local s = math.floor (rv/100);

  rv = rv - s*100;

  local c = rv;

  return g, s, c
end

function PLGuildBankClassic:round (v)
	return math.floor (v + 0.5);
  end

function PLGuildBankClassic:base62Encode(number)
local base = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
local index = number % 62 + 1
local result = base:sub(index, index)
local quotient = math.floor(number / 62)
while quotient ~= 0 do
	index = quotient % 62 + 1
	quotient = math.floor(quotient / 62)
	result = base:sub(index, index) .. result
end
return result
end

function PLGuildBankClassic:base62Decode(number)
local base = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
local char = number:sub(1, 1)
local result = base:find(char) - 1
local limit = number:len()
for i=2, limit do
	result = 62 * result + (base:find(number:sub(i, i)) - 1)
end
return result
end

-------------------------------------------------------------------------------
-- printing functions
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- function PLGuildBankClassic:debug( Message)
--
-- Prints a debug message if debug mode is enabled in addon settings
-------------------------------------------------------------------------------
function PLGuildBankClassic:debug(message)
	if (message and PLGuildBankClassic.db.profile.config.debug) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_WHITE .. "PLGBC-DBG: " .. message .. PLGBCLASSIC_CHAT_END, 0.1, 0.1, 1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:println( Message)
--
-- Prints a chatframe message if message output or debug mode is enabled
-------------------------------------------------------------------------------
function PLGuildBankClassic:println(message)
	if (message and PLGuildBankClassic.db.profile.config.printMessage or PLGuildBankClassic.db.profile.config.debug) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_YELLOW .. message .. PLGBCLASSIC_CHAT_END, 1, 1, 1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:info( Message)
--
-- Prints a chatframe message
-------------------------------------------------------------------------------
function PLGuildBankClassic:info(message)
	if message then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_BLUE .. message .. PLGBCLASSIC_CHAT_END, 1, 1, 1);
	end
end
-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:errln( Message)
--
-- Prints an error message if error pronting is enabled
-------------------------------------------------------------------------------
function PLGuildBankClassic:errln(mMessage)
	if (message and PLGuildBankClassic.db.profile.config.printErrors) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_RED .. message .. PLGBCLASSIC_CHAT_END, 1, 0.1, 0.1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:screen( Message)
--
-- Prints a message within the error screen.
-------------------------------------------------------------------------------
function PLGuildBankClassic:screen(message )
	if message then
		UIErrorsFrame:AddMessage(message, 1.0, 1.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
	end
end
