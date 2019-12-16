local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")
local Cache = LibStub('LibItemCache-2.0')


function PLGuildBankClassic:GetInventoryCache(characterName)

	if characterName ~= nil then
		local cacheOwnerInfo = PLGuildBankClassic:GetCachedOwnerInfo(characterName)

		local inventoryData = {}
		inventoryData.ownerInfo = cacheOwnerInfo
		inventoryData.bags = {}

		for i, bag in ipairs(PLGBC_COMBINED_INVENTORY_CONFIG) do
			inventoryData.bags[bag] = {}
			
			inventoryData.bags[bag].info = Cache:GetBagInfo(cacheOwnerInfo.name, bag)

			if inventoryData.bags[bag].info.bagSize ~= nil then
				inventoryData.bags[bag].items = {}

				for slot = 1, inventoryData.bags[bag].info.bagSize do
					inventoryData.bags[bag].items[slot] = Cache:GetItemInfo(cacheOwnerInfo.name, bag, slot)
				end
			end
		end

		return inventoryData
	end

	return nil
end


function PLGuildBankClassic:GetCachedOwnerInfo(characterName)
    if characterName ~= nil then
		local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(characterName)
		return  Cache:GetOwnerInfo(charServerName)
    end
    
    return nil
end


function PLGuildBankClassic:SetCacheInventoryInfo(ownerInfo, bagData)
    local setCache = false

    if not ownerInfo or not bagData then
        PLGuildBankClassic:debug("SetCacheInventoryInfo - Error: ownerInfo and/or bagData is nil")
        return false
    end

    if not setCache then
        setCache = SetBagBrotherCache(ownerInfo, bagData)
    end

    -- TODO: Support other cache AddOns

    if not setCache then
        PLGuildBankClassic:errln("PLDBC: " .. L["No supported cache AddOn found. Could NOT update local cache!"])
        PLGuildBankClassic:debug("SetCacheInventoryInfo - Warn: No supported cache found! Could NOT update local cache!")
    end

    return setCache
end

function PLGuildBankClassic:SetCachedMoneyInfo(ownerInfo, money)
    local setCache = false

    if not ownerInfo or not bagData then
        PLGuildBankClassic:debug("SetCachedMoneyInfo - Error: ownerInfo and/or bagData is nil")
        return false
    end

    if not setCache then
        setCache = SetBagBrotherMoneyCache(ownerInfo, money)
    end

    -- TODO: Support other cache AddOns

    if not setCache then
        PLGuildBankClassic:errln("PLDBC: " .. L["No supported cache AddOn found. Could NOT update local cache!"])
        PLGuildBankClassic:debug("SetCachedMoneyInfo - Warn: No supported cache found! Could NOT update local cache!")
    end

    return setCache
end

local function SetBagBrotherCache(ownerInfo, bagData)
    if BrotherBags ~= nil and ownerInfo.name ~= nil and ownerInfo.realm ~= nil then
        BrotherBags[ownerInfo.realm] = BrotherBags[ownerInfo.realm] or {}
        local realmCache = BrotherBags[ownerInfo.realm]
        realmCache[player] = realmCache[player] or {equip = {}}
        local playerCache = realmCache[player]

        playerCache.faction = ownerInfo.faction
        playerCache.class = ownerInfo.class
        playerCache.race = ownerInfo.race
        playerCache.sex = ownerInfo.sex
        playerCache.guild = ownerInfo.guild
        playerCache.money = ownerInfo.money
        playerCache.equip = ownerInfo.equip

        for bagId, contents in pairs(bagData) do
            playerCache[bagId] = {}
            if contents then
                for idx=1, #contents do
                    -- only itemstring;quantity
                    local bagbrotherItemInfo = nil

                    if BagBrother.ParseItem and contents[idx].link then

                        -- use bagbrothers parseItem method to produce a saveable / compatible string
                        bagbrotherItemInfo = BagBrother:ParseItem(contents[idx].link, contents[idx].count or 1)

                    elseif contents[idx].id then
                        local itemString PLGuildBankClassic:GetItemStringFromId(contents[idx].id)

                        if itemString then
                            bagbrotherItemInfo = itemString

                            if contents[idx].count > 1 then
                                bagbrotherItemInfo = bagbrotherItemInfo .. ";" .. tostring(contents[idx].count)
                            end
                        end
                    end

                    if bagbrotherItemInfo then
                        playerCache[bagId][idx] = bagbrotherItemInfo
                    end
                end
            end
        end

        PLGuildBankClassic:debug("PLGBC-BagBrother: Set or updated local player cache received via comms")
    end

    return false
end

local function SetBagBrotherMoneyCache(ownerInfo, money)
    if BrotherBags ~= nil and ownerInfo.name ~= nil and ownerInfo.realm ~= nil then
        BrotherBags[ownerInfo.realm] = BrotherBags[ownerInfo.realm] or {}
        local realmCache = BrotherBags[ownerInfo.realm]
        realmCache[player] = realmCache[player] or {equip = {}}
        local playerCache = realmCache[player]

        playerCache.faction = ownerInfo.faction
        playerCache.class = ownerInfo.class
        playerCache.race = ownerInfo.race
        playerCache.sex = ownerInfo.sex
        playerCache.guild = ownerInfo.guild
        playerCache.money = money
        playerCache.equip = ownerInfo.equip

        PLGuildBankClassic:debug("PLGBC-BagBrother: Set or updated local player cache/money received via comms")
    end

    return false
end