local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

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
    return false
end

function PLGuildBankClassic:IsInGuild()
    return self.isInGuild
end

function PLGuildBankClassic:GuildName()
    return self.guildName
end


-------------------------------------------------------------------------------
-- icon and texture functions
-------------------------------------------------------------------------------

function PLGuildBankClassic:RefreshPlayerSpellIconInfo()
	if ( PLGuildBankClassic.iconFilenames ) then
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

	PLGuildBankClassic.iconFilenames = { "INV_MISC_QUESTIONMARK" };
	for fileDataID in pairs(activeIcons) do
		PLGuildBankClassic.iconFilenames[#PLGuildBankClassic.iconFilenames + 1] = fileDataID;
	end

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
