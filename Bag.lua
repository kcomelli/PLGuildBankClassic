local _, PLGuildBankClassic = ...
local L = LibStub("AceLocale-3.0"):GetLocale("PLGuildBankClassic")

local ItemCache = LibStub("LibItemCache-2.0")

local Bag = CreateFrame("Button")
local Bag_MT = {__index = Bag}

local Events = PLGuildBankClassic:GetModule("Events")

local BAG_SIZE = 22
local TEXTURE_SIZE = 64 * (BAG_SIZE/36)

PLGuildBankClassic.Bag = {}
PLGuildBankClassic.Bag.pool = {}
PLGuildBankClassic.Bag.prototype = Bag

local BagID = 1
function PLGuildBankClassic.Bag:Create()
	local item = next(self.pool)
	if item then
		self.pool[item] = nil
		return item
	end
	local name = ("PLGuildBankClassicBag%d"):format(BagID)
	local bag = setmetatable(CreateFrame("Button", name), Bag_MT)

	bag:SetSize(BAG_SIZE, BAG_SIZE)

	local icon = bag:CreateTexture(name .. "IconTexture", "BORDER")
	icon:SetAllPoints(bag)

	bag.count = bag:CreateFontString(name .. "Count", "OVERLAY")
	bag.count:SetFontObject("NumberFontNormalSmall")
	bag.count:SetJustifyH("RIGHT")
	bag.count:SetPoint("BOTTOMRIGHT", -2, 2)

	local nt = bag:CreateTexture(name .. "NormalTexture")
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(TEXTURE_SIZE)
	nt:SetHeight(TEXTURE_SIZE)
	nt:SetPoint("CENTER", 0, -1)
	bag:SetNormalTexture(nt)

	local pt = bag:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(bag)
	bag:SetPushedTexture(pt)

	local ht = bag:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(bag)
	bag:SetHighlightTexture(ht)

	bag:RegisterForClicks("LeftButtonUp")
	bag:RegisterForDrag("LeftButton")

	bag:SetScript("OnEnter", bag.OnEnter)
	bag:SetScript("OnShow", bag.OnShow)
	bag:SetScript("OnLeave", bag.OnLeave)
	bag:SetScript("OnClick", bag.OnClick)
	--bag:SetScript("OnDragStart", bag.OnDrag)
	--bag:SetScript("OnReceiveDrag", bag.OnClick)
	bag:SetScript("OnEvent", bag.OnEvent)

	BagID = BagID + 1
	return bag
end

function Bag:Free()
	PLGuildBankClassic.Bag.pool[self] = true
	self:Hide()
	self:SetParent(nil)
	self:UnregisterAllEvents()
end

function Bag:Set(parent, id)
	self:SetID(id)
    self:SetParent(parent)

	if self:IsBank() or self:IsBackpack() then
		SetItemButtonTexture(self, [[Interface\Buttons\Button-Backpack-Up]])
		SetItemButtonTextureVertexColor(self, 1, 1, 1)
	else
		self:Update()

        -- only hook events if the bank char is online
        if PLGuildBankClassic:IsGuildBankChar() then
            self:RegisterEvent("ITEM_LOCK_CHANGED")
            self:RegisterEvent("CURSOR_UPDATE")
            self:RegisterEvent("BAG_UPDATE")
            self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

            if self:IsBankBag() then
                self:RegisterEvent("BANKFRAME_OPENED")
                self:RegisterEvent("BANKFRAME_CLOSED")
                self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
                self:RegisterEvent("BANK_BAG_SLOT_FLAGS_UPDATED")
            end

            if self:IsBackpackBag() then
                self:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
            end
        end
	end
end

function Bag:OnEvent(event, ...)
	if event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
		self:Update()
	elseif not self:IsCached() then
		if event == "ITEM_LOCK_CHANGED" then
			self:UpdateLock()
		elseif event == "CURSOR_UPDATE" then
			self:UpdateCursor()
		elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" then
			self:Update()
		elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
			self:Update()
		elseif event == "BAG_SLOT_FLAGS_UPDATED" or event == "BANK_BAG_SLOT_FLAGS_UPDATED" then
			self:Update()
		end
	end
end

function Bag:OnClick(button)
	local link = self:GetInfo()
	if link and HandleModifiedItemClick(link) then
		return
	end

	if self:IsCached() then
		return
	end

	--if self:IsPurchasable() then
	--	self:PurchaseSlot()
	--elseif CursorHasItem() then
	--	if self:IsBackpack() then
	--		PutItemInBackpack()
	--	else
	--		PutItemInBag(self:GetInventorySlot())
	--	end
	--elseif not(self:IsBackpack() or self:IsBank()) then
	--	self:Pickup()
	--end
end

--function Bag:OnDrag()
--	self:Pickup()
--end

function Bag:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end

	self:UpdateTooltip()
	self:HighlightItems()
end

function Bag:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
	self:ClearHighlightItems()
end

function Bag:OnShow()
	self:Update()
end

function Bag:Update()
	if not self:IsVisible() or not self:GetParent() then return end

	self:UpdateLock()
	self:UpdateSlotInfo()
	self:UpdateCursor()
end

function Bag:UpdateLock()
	if self:IsCustomSlot() then
		SetItemButtonDesaturated(self, self:IsLocked())
	end
end

function Bag:UpdateCursor()
	if not self:IsCustomSlot() then return end

	if not self:IsCached() and CursorCanGoInSlot(self:GetInventorySlot()) then
		self:LockHighlight()
	else
		self:UnlockHighlight()
	end
end

function Bag:UpdateSlotInfo()
	if not self:IsCustomSlot() then return end

	local link, count, texture = self:GetInfo()
	if link then
		self.hasItem = link

		SetItemButtonTexture(self, texture or GetItemIcon(link))
		SetItemButtonTextureVertexColor(self, 1, 1, 1)
	else
		self.hasItem = nil

		SetItemButtonTexture(self, [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]])

		--color red if the bag can be purchased
		if self:IsPurchasable() then
			SetItemButtonTextureVertexColor(self, 1, 0.1, 0.1)
		else
			SetItemButtonTextureVertexColor(self, 1, 1, 1)
		end
	end
	self:SetCount(count)
end

function Bag:SetCount(count)
	count = count or 0

	if count > 1 then
		if count > 999 then
			self.count:SetFormattedText("%.1fk", count/1000)
		else
			self.count:SetText(count)
		end
		self.count:Show()
	else
		self.count:Hide()
	end
end

--function Bag:Pickup()
--	PickupBagFromSlot(self:GetInventorySlot())
--end

function Bag:HighlightItems()
	self:GetParent().itemContainer:HighlightBag(self:GetID())
end

function Bag:ClearHighlightItems()
	self:GetParent().itemContainer:HighlightBag(nil)
end

--show the purchase slot dialog
--function Bag:PurchaseSlot()
--	if not StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_INVENTORIAN"] then
--		StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_INVENTORIAN"] = {
--			text = CONFIRM_BUY_BANK_SLOT,
--			button1 = YES,
--			button2 = NO,

--			OnAccept = function(f)
--				PurchaseSlot()
--			end,

--			OnShow = function(f)
--				MoneyFrame_Update(f:GetName().. "MoneyFrame", GetBankSlotCost(GetNumBankSlots()))
--			end,

--			hasMoneyFrame = 1,
--			timeout = 0,
--			hideOnEscape = 1,
--			preferredIndex = STATICPOPUP_NUMDIALOGS,
--		}
--	end

--	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
--	StaticPopup_Show("CONFIRM_BUY_BANK_SLOT_INVENTORIAN")
--end

function Bag:UpdateTooltip()
	GameTooltip:ClearLines()

	if self:IsBackpack() then
		GameTooltip:SetText(BACKPACK_TOOLTIP, 1, 1, 1)
	elseif self:IsBank() then
		GameTooltip:SetText(BANK, 1, 1, 1)
	else
		self:UpdateBagTooltip()
	end

	GameTooltip:Show()
end

function Bag:UpdateBagTooltip()
	if not GameTooltip:SetInventoryItem("player", self:GetInventorySlot()) then
		if self:IsPurchasable() then
			GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
			GameTooltip:AddLine(L["Purchaseable"])
			SetTooltipMoney(GameTooltip, GetBankSlotCost(GetNumBankSlots()))
		else
			GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
		end
	end
end

-----------------------------------------------------------------------
-- Various information getters

function Bag:GetPlayer()
    return self.ownerName
    -- TODO: get owner not player
	--return self:GetParent():GetPlayerName()
end

function Bag:IsCached()
    return true
	--return self:GetParent():IsCached()
end

function Bag:IsBackpack()
	return (self:GetID() == BACKPACK_CONTAINER)
end

function Bag:IsBank()
	return (self:GetID() == BANK_CONTAINER)
end

function Bag:IsBackpackBag()
	return (self:GetID() > 0 and self:GetID() <= NUM_BAG_SLOTS)
end

function Bag:IsBankBag()
	return (self:GetID() > NUM_BAG_SLOTS and self:GetID() <= (NUM_BAG_SLOTS + NUM_BANKBAGSLOTS))
end

function Bag:IsCustomSlot()
	return self:IsBackpackBag() or self:IsBankBag()
end

function Bag:IsPurchasable()
	return not self:IsCached() and (self:GetID() - NUM_BAG_SLOTS) > GetNumBankSlots()
end

function Bag:GetInventorySlot()
	return self:IsCustomSlot() and ContainerIDToInventoryID(self:GetID()) or nil
end

function Bag:GetInfo()
    if self.ownerName then
        local charName, charRealm, charServerName = PLGuildBankClassic:CharaterNameTranslation(self.ownerName)
		local cacheOwnerInfo = ItemCache:GetOwnerInfo(charServerName)

        local info = ItemCache:GetBagInfo(cacheOwnerInfo.name, self:GetID())
        return info.link, 0, info.icon
    else
        return nil, 0, nil
    end
end

function Bag:IsLocked()
	if self:IsCached() then
		return false
	end
	local slot = self:GetInventorySlot()
	if slot then
		return IsInventoryItemLocked(slot)
	end
	return false
end
