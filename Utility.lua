local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")
local Cache = LibStub('LibItemCache-2.0')

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
                return true, name, rank, level, class, note, officernote
            end
        end
    end

    return false, nil, nil, nil, nil, nil, nil
end

function PLGuildBankClassic:IsGuildBankChar()
    return PLGuildBankClassic.atBankChar ~= nil
end

function PLGuildBankClassic:IsInGuild()
    return PLGuildBankClassic.isInGuild
end

function PLGuildBankClassic:GuildName()
    return PLGuildBankClassic.guildName
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

-------------------------------------------------------------------------------
-- printing functions
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- function PLGuildBankClassic:debug( Message)
--
-- Prints a debug message if debug mode is enabled in addon settings
-------------------------------------------------------------------------------
function PLGuildBankClassic:debug(message)
	if (PLGuildBankClassic.db.profile.config.debug) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_WHITE .. message .. PLGBCLASSIC_CHAT_END, 0.1, 0.1, 1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:println( Message)
--
-- Prints a chatframe message if message output or debug mode is enabled
-------------------------------------------------------------------------------
function PLGuildBankClassic:println(message)
	if (PLGuildBankClassic.db.profile.config.printMessage or PLGuildBankClassic.db.profile.config.debug) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_YELLOW .. message .. PLGBCLASSIC_CHAT_END, 1, 1, 1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:info( Message)
--
-- Prints a chatframe message
-------------------------------------------------------------------------------
function PLGuildBankClassic:info(message)
	DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_BLUE .. message .. PLGBCLASSIC_CHAT_END, 1, 1, 1);
end
-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:errln( Message)
--
-- Prints an error message if error pronting is enabled
-------------------------------------------------------------------------------
function PLGuildBankClassic:errln(mMessage)
	if (PLGuildBankClassic.db.profile.config.printErrors) then
		DEFAULT_CHAT_FRAME:AddMessage(PLGBCLASSIC_CHAT_RED .. message .. PLGBCLASSIC_CHAT_END, 1, 0.1, 0.1);
	end
end

-------------------------------------------------------------------------------
-- function  PLGuildBankClassic:screen( Message)
--
-- Prints a message within the error screen.
-------------------------------------------------------------------------------
function PLGuildBankClassic:screen(message )
	UIErrorsFrame:AddMessage(message, 1.0, 1.0, 0.0, 1.0, UIERRORS_HOLD_TIME);
end
