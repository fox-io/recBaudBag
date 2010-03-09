local format = string.format
local _G = _G
local Config = {
	{
		{
			["AutoOpen"] = true,
			["Name"] = "Inventory",
			["Coords"] = {
				1271.1436723604, -- [1]
				407.6517274993564, -- [2]
			},
		}, -- [1]
		{
			["Name"] = "Ammo",
			["Coords"] = {
				1121.367145398442, -- [1]
				575.6612609847227, -- [2]
			},
			["AutoOpen"] = false,
		}, -- [2]
		{
			["Name"] = "Keyring",
			["Coords"] = {
				1071.876229290778, -- [1]
				392.0227549125754, -- [2]
			},
			["AutoOpen"] = false,
		}, -- [3]
		["Enabled"] = true,
		["Joined"] = {
			[6] = false,
		},
		["ShowBags"] = false,
	}, -- [1]
	{
		{
			["AutoOpen"] = false,
			["Name"] = "Bank",
			["Coords"] = {
				1191.25, -- [1]
				802.5, -- [2]
			},
		}, -- [1]
		["Enabled"] = true,
		["Joined"] = {},
		["ShowBags"] = true,
	}, -- [2]
}
	
local Prefix = "BaudBag"
local SelectedBags = 1
local SelectedContainer = 1
local MaxBags = NUM_BANKBAGSLOTS + 1
local Updating, CfgBackup
local LastBagID = NUM_BANKBAGSLOTS + 4
local SetSize = {6, NUM_BANKBAGSLOTS + 1}
local MaxCont = {1, 1}
local NumCont = {}
local BankOpen = false
local FadeTime = 0.2
local BagsReady

BaudBagIcons = {
	[0]	 = [[Interface\Buttons\Button-Backpack-Up]],
	[-1] = [[Interface\Icons\INV_Box_02]],
	[-2] = [[Interface\ContainerFrame\KeyRing-Bag-Icon]]
}

local function ShowHyperlink(Owner, Link)
	local ItemString = strmatch(Link or "","(item[%d:%-]+)")
	if not ItemString then
		return
	end
	if(Owner:GetRight() >= (GetScreenWidth() / 2))then
		GameTooltip:SetOwner(Owner, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(Owner, "ANCHOR_RIGHT")
	end
	GameTooltip:SetHyperlink(ItemString)
	return true
end

function BaudBagForEachBag(BagSet,Func)
	if(BagSet==1)then
		for Bag = 1, 5 do
			Func(Bag - 1, Bag)
		end
		Func(-2, 6)
	else
		Func(-1, 1)
		for Bag = 1, NUM_BANKBAGSLOTS do
			Func(Bag + 4, Bag + 1)
		end
	end
end

--Adds container name when mousing over bags, aswell as simulating offline bank item mouse over
hooksecurefunc(GameTooltip,"SetInventoryItem",function(Data, Unit, InvID)
	if(Unit~="player")then
		return
	end
	if(InvID >= 20)and(InvID <= 23)then
		if Config and(Config[1].Enabled==false)then
			return
		end
		BaudBagModifyBagTooltip(InvID - 19)

	elseif(InvID >= 68)and(InvID < 68 + NUM_BANKBAGSLOTS)then
		if Config and(Config[2].Enabled==false)then
			return
		end
		BaudBagModifyBagTooltip(4 + InvID - 67)
	end
end)

MainMenuBarBackpackButton:HookScript("OnEnter",function(...)
	if Config and(Config[1].Enabled~=false)then
		BaudBagModifyBagTooltip(0)
	end
end)

function BaudBagModifyBagTooltip(BagID)
	if not GameTooltip:IsShown()then
		return
	end
	local Container = _G[format("BaudBagSubBag%s", BagID)]:GetParent()
	Container = Config[Container.BagSet][Container:GetID()].Name
	if not Container or not strfind(Container,"%S")then
		return
	end	
	local Current, Next
	for Line = GameTooltip:NumLines(), 3, -1 do
		Current, Next = _G[format("GameTooltipTextLeft%s", Line)], _G[format("GameTooltipTextLeft%s", (Line - 1))]
		Current:SetTextColor(Next:GetTextColor())	 
	end
	if Next then
		Next:SetText(Container)
		Next:SetTextColor(1,0.82,0)
	end
	GameTooltip:Show()
	GameTooltip:AppendText("")
end

local EventFuncs = {
	VARIABLES_LOADED = function()
	
		--The rest of the bank slots are cleared in the next event
		BaudBagBankSlotPurchaseButton:Disable()
	end,

	PLAYER_LOGIN = function()
		--Generate bank bag buttons for each bag slot
		local BagSlot, Texture
		for Bag = 1, 4 do
			--Bag name length is restricted.	for this one, the ID is set automatically.
			BagSlot = CreateFrame("CheckButton", format("BaudBInveBag%sSlot", (Bag - 1)) ,BBCont1_1BagsFrame,"BagSlotButtonTemplate")
			BagSlot:SetPoint("TOPLEFT",8,-8 - (Bag - 1) * 39)
			_G[format("%sItemAnim", BagSlot:GetName())]:UnregisterAllEvents()
		end
		BBCont1_1BagsFrame:SetWidth(13 + 39)
		BBCont1_1BagsFrame:SetHeight(13 + 4 * 39 + 20)

		for Bag = 1, NUM_BANKBAGSLOTS do
			--Bag name length is restricted
			BagSlot = CreateFrame("Button", format("BaudBBankBag%s", Bag), BBCont2_1BagsFrame,"BankItemButtonBagTemplate")
			BagSlot:SetID(Bag + 4)
			BagSlot:SetPoint("TOPLEFT",8 + mod(Bag - 1, 2) * 39,-8 - floor((Bag - 1) / 2) * 39)
			Texture = select(2,GetInventorySlotInfo(format("Bag%s", Bag)))
			SetItemButtonTexture(BagSlot,Texture)
		end
		BBCont2_1BagsFrame:SetWidth(91)
		--Height changes depending if there is a purchase button
		BBCont2_1BagsFrame.Height = 13 + ceil(NUM_BANKBAGSLOTS / 2) * 39
		BaudBagBankBags_Update()
		BaudUpdateJoinedBags()
		BaudBagUpdateBagFrames()
		if Config and (Config[2].Enabled == true) then 
			BankFrame:UnregisterEvent("BANKFRAME_OPENED") 
		end 
	end,

	BANKFRAME_CLOSED = function()
		BankOpen = false
		BaudBagBankSlotPurchaseButton:Disable()
		if BBCont2_1.AutoOpened then
			BBCont2_1:Hide()
		else
			--Add offline again to bag name
			for ContNum = 1, NumCont[2]do
				BaudBagUpdateName(_G[format("BBCont2_%s", ContNum)])
			end
		end
		BaudBagAutoOpenSet(1, true)
	end,

	PLAYER_MONEY = function()
		BaudBagBankBags_Update()
	end,

	ITEM_LOCK_CHANGED = function()
		local Bag, Slot = arg1, arg2
		if(Bag == BANK_CONTAINER)then
			if(Slot <= NUM_BANKGENERIC_SLOTS)then
				BankFrameItemButton_UpdateLocked(_G[format("BaudBagSubBag-1Item%s", Slot)])
			else
				BankFrameItemButton_UpdateLocked(_G[format("BaudBBankBag%s", (Slot-NUM_BANKGENERIC_SLOTS))])
			end
		end
	end
}

local Func = function()
	if(event=="BANKFRAME_OPENED")then
		BankOpen = true
	end
	BaudBagBankSlotPurchaseButton:Enable()
	for Index = 1, NUM_BANKGENERIC_SLOTS do
		BankFrameItemButton_Update(_G[format("BaudBagSubBag-1Item%s", Index)])
	end
	for Index = 1, NUM_BANKBAGSLOTS do
		BankFrameItemButton_Update(_G[format("BaudBBankBag%s", Index)])
	end
	BaudBagBankBags_Update()

	if(Config[2].Enabled == false)or(event~="BANKFRAME_OPENED")then
		return
	end
	if BBCont2_1:IsShown()then
		BaudBagUpdateContainer(BBCont2_1)
	else
		BBCont2_1.AutoOpened = true
		BBCont2_1:Show()
	end
	BaudBagAutoOpenSet(1)
	BaudBagAutoOpenSet(2)
end
EventFuncs.BANKFRAME_OPENED = Func
EventFuncs.PLAYERBANKBAGSLOTS_CHANGED = Func

Func = function()
	BaudBagAutoOpenSet(1)
end
EventFuncs.MERCHANT_SHOW = Func
EventFuncs.MAIL_SHOW = Func
EventFuncs.AUCTION_HOUSE_SHOW = Func

Func = function()
	BaudBagAutoOpenSet(1,true)
end
EventFuncs.MERCHANT_CLOSED = Func
EventFuncs.MAIL_CLOSED = Func
EventFuncs.AUCTION_HOUSE_CLOSED = Func

Func = function()
	if(event=="PLAYERBANKSLOTS_CHANGED")then
		if(arg1 > NUM_BANKGENERIC_SLOTS)then
			BankFrameItemButton_Update(_G[format("BaudBBankBag", (arg1-NUM_BANKGENERIC_SLOTS))])
			return
		end
		local BankBag = _G["BaudBagSubBag-1"]
		if BankBag:GetParent():IsShown()then
			BaudBagUpdateSubBag(BankBag)
		end
		BankFrameItemButton_Update(_G[format("%sItem%s", BankBag:GetName(), arg1)])
		BagSet = 2
	else
		BagSet = (arg1 ~= -1)and(arg1 <= 4)and 1 or 2
	end
	local Container = _G[format("BBCont%s_1", BagSet)]
	if not Container:IsShown()then
		return
	end
	Container.UpdateSlots = true
end
EventFuncs.BAG_UPDATE = Func
EventFuncs.BAG_CLOSED = Func
EventFuncs.PLAYERBANKSLOTS_CHANGED = Func

function BaudBag_OnLoad(self)
	BINDING_HEADER_BaudBag = "Baud Bag"
	BINDING_NAME_BaudBagToggleBank = "Toggle Bank"

	for Key, Value in pairs(EventFuncs)do
		self:RegisterEvent(Key)
	end

	local SubBag, Container
	for BagSet = 1, 2 do
		--The first container from each set is different and is created in the XML
		Container = _G[format("BBCont%s_1", BagSet)]
		Container.BagSet = BagSet
		Container:SetID(1)
	end

	--The first bag from the bank is unique and is created in the XML
	for Bag = -2, LastBagID do
		if(Bag == -1)then
			SubBag = _G[format("BaudBagSubBag%s", Bag)]
		else
			SubBag = CreateFrame("Frame", format("BaudBagSubBag%s", Bag), nil,"BaudBagSubBagTemplate")
		end
		SubBag:SetID(Bag)
		SubBag.BagSet = (Bag ~= -1)and(Bag < 5)and 1 or 2
		SubBag:SetParent(format("BBCont%s_1", SubBag.BagSet))
	end
end

function BaudBag_OnEvent(self, event)
	EventFuncs[event]()
end

function BaudBagBagsFrame_OnShow(self)
	--Adjust frame level because of Blizzard's screw up
	local Level = self:GetFrameLevel() + 1
	for Key, Value in pairs(self:GetChildren())do
		if(type(Value)=="table")then
			Value:SetFrameLevel(Level)
		end
	end
end

function BaudBagToggleBank(self)
	if BBCont2_1:IsShown()then
		BBCont2_1:Hide()
	else
		BBCont2_1:Show()
		BaudBagAutoOpenSet(2)
	end
end

--This function updates misc. options for a bag
function BaudUpdateContainerData(BagSet, ContNum)
	local Container = _G[format("BBCont%s_%s", BagSet, ContNum)]
	_G[format("%sName", Container:GetName())]:SetText(Config[BagSet][ContNum].Name or "")
	local Scale = .8
	Container:SetScale(Scale)
	Container:ClearAllPoints()
	local X, Y = unpack(Config[BagSet][ContNum].Coords)
	Container:SetPoint("CENTER",UIParent,"BOTTOMLEFT",(X / .8), (Y / .8))
end

local function HideObject(Object)
	Object = _G[Object]
	if not Object then
		return
	end
	Object:Hide()
end

local TextureFile, TextureWidth, TextureHeight, TextureParent

local function GetTexturePiece(Name, MinX, MaxX, MinY, MaxY, Layer)
	local Texture = _G[format("%s%s", TextureParent:GetName(), Name)]
	if not Texture then
		Texture = TextureParent:CreateTexture(format("%s%s", TextureParent:GetName(), Name))
	end
	Texture:ClearAllPoints()
	Texture:SetTexture(TextureFile)
	Texture:SetTexCoord(MinX / TextureWidth, (MaxX + 1) / TextureWidth, MinY / TextureHeight, (MaxY + 1) / TextureHeight)
	Texture:SetWidth(MaxX - MinX + 1)
	Texture:SetHeight(MaxY - MinY + 1)
	Texture:SetDrawLayer(Layer)
	Texture:Show()
	return Texture
end

function BaudBagUpdateBackground(Container)
	local Backdrop = _G[format("%sBackdrop", Container:GetName())]
	Backdrop:SetFrameLevel(Container:GetFrameLevel())
	local Left, Right, Top, Bottom
	--This shifts the name of the bank frame over to make room for the extra button
	local ShiftName = (Container:GetID()==1)and 25 or 0

	Left, Right, Top, Bottom = 8, 8, 28, 8
	_G[format("%sTextures", Backdrop:GetName())]:Hide()

	_G[format("%sName", Container:GetName())]:SetPoint("TOPLEFT",(2 + ShiftName),18)
	_G[format("%sCloseButton", Container:GetName())]:SetPoint("TOPRIGHT",8,28)

	Backdrop:SetBackdrop({
		bgFile   = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = [[Interface\Addons\recBaudBag\media\glowtex]],
		edgeSize = 4,
		insets   = {
			left   = 3,
			right  = 3,
			top    = 3,
			bottom = 3
		}
	})
	Left, Right, Top, Bottom = Left+8, Right+8, Top+8, Bottom+8
	Backdrop:SetBackdropColor(0,0,0,.5)
	Backdrop:SetBackdropBorderColor(0,0,0)

	_G[format("%sName", Container:GetName())]:SetPoint("RIGHT", format("%sCloseButton", Container:GetName()),"LEFT")

	Backdrop:ClearAllPoints()
	Backdrop:SetPoint("TOPLEFT",-Left,Top)
	Backdrop:SetPoint("BOTTOMRIGHT",Right,-Bottom)
	Container:SetHitRectInsets(-Left,-Right,-Top,-Bottom)
end

--This function updates the parent containers for each bag, according to the options setup
function BaudUpdateJoinedBags()
	local OpenBags = {}
	for Bag = -2, LastBagID do
		OpenBags[Bag] = _G[format("BaudBagSubBag%s", Bag)]:GetParent():IsShown()
	end
	local SubBag, Container, IsOpen, ContNum, BagID
	local function FinishContainer()
		if IsOpen then
			Container:Show()
		else
			Container:Hide()
		end
		BaudBagUpdateContainer(Container)
	end

	for BagSet = 1, 2 do
		ContNum = 0
		BaudBagForEachBag(BagSet, function(Bag, Index)
			if(ContNum==0)or(Config[BagSet].Joined[Index]==false)then
				if(ContNum~=0)then
					FinishContainer()
				end
				IsOpen = false
				ContNum = ContNum + 1
				if(MaxCont[BagSet] < ContNum)then
					Container = CreateFrame("Frame",format("BBCont%s_%s", BagSet, ContNum), UIParent,"BaudBagContainerTemplate")
					Container:SetID(ContNum)
					Container.BagSet = BagSet
					MaxCont[BagSet] = ContNum
				end
				Container = _G[format("BBCont%s_%s", BagSet, ContNum)]
				Container.Bags = {}
				BaudUpdateContainerData(BagSet,ContNum)
			end
			SubBag = _G[format("BaudBagSubBag%s", Bag)]
			tinsert(Container.Bags,SubBag)
			SubBag:SetParent(Container)
			if OpenBags[Bag]then
				IsOpen = true
			end
		end)
		FinishContainer()

		NumCont[BagSet] = ContNum
		--Hide extra containers that were created before
		for ContNum = (ContNum + 1), MaxCont[BagSet]do
			_G[format("BBCont%s_%s", BagSet, ContNum)]:Hide()
		end
	end
	BagsReady = true
end

function BaudBagUpdateOpenBags()
	local Open, Frame, Highlight, Highlight2
	--The bank bag(-1) has no open indicator
	for Bag = -2, LastBagID do
		Frame = _G[format("BaudBagSubBag%s", Bag)]
		Open = Frame:IsShown()and Frame:GetParent():IsShown()and not Frame:GetParent().Closing
		if(Bag == -2)then
			if Open then
				BaudBagKeyRingButton:SetButtonState("PUSHED", 1)
				KeyRingButton:SetButtonState("PUSHED", 1)
			else
				BaudBagKeyRingButton:SetButtonState("NORMAL")
				KeyRingButton:SetButtonState("NORMAL")
			end
		elseif(Bag == 0)then
			MainMenuBarBackpackButton:SetChecked(Open)
		elseif(Bag > 4)then
			Highlight = _G[format("BaudBBankBag%sHighlightFrameTexture", (Bag-4))]
			Highlight2 = _G[format("BankFrameBag%sHighlightFrameTexture", (Bag-4))]
			if Open then
				Highlight:Show()
				Highlight2:Show()
			else
				Highlight:Hide()
				Highlight2:Hide()
			end
		elseif(Bag > 0)then
			_G[format("CharacterBag%sSlot", (Bag-1))]:SetChecked(Open)
			_G[format("BaudBInveBag%sSlot", (Bag-1))]:SetChecked(Open)
		end
	end
end

function BaudBagAutoOpenSet(BagSet, Close)
	--Set 2 doesn't need container 1 to be shown because that's a given
	local Container
	for ContNum = BagSet, NumCont[BagSet]do
		if Config[BagSet][ContNum].AutoOpen then
			Container = _G[format("BBCont%s_%s", BagSet, ContNum)]
			if not Close then
				if not Container:IsShown()then
					Container.AutoOpened = true
					Container:Show()
				end

			elseif Container.AutoOpened then
				Container:Hide()
			end
		end
	end
end

function BaudBagCloseBagSet(BagSet)
	for ContNum = 1, MaxCont[BagSet]do
		_G[format("BBCont%s_%s", BagSet, ContNum)]:Hide()
	end
end

local pre_ToggleBag = ToggleBag
ToggleBag = function(id)
	local self = this
	if(id > 4)then
		if Config and(Config[2].Enabled == false)then
			return pre_ToggleBag(id)
		end
		if not BagsReady then
			return
		end
		--The close button thing allows the original blizzard bags to be closed if they're still open
	elseif(Config[1].Enabled == false)or self and(strsub(self:GetName(),-11)=="CloseButton")then
		return pre_ToggleBag(id)
	end
	--Blizzard's stuff will automaticaly try open the bags at the mailbox and vendor.	Baud Bag will be in charge of that.
	if not BagsReady or(self==MailFrame)or(self==MerchantFrame)then
		return
	end
	local Container = _G[format("BaudBagSubBag%s", id)]
	if not Container then
		return pre_ToggleBag(id)
	end
	Container = Container:GetParent()
	--if the bag to open is inside the main bank container, don't toggle it
	if self and((Container == BBCont2_1)and(strsub(self:GetName(),1,9)=="BaudBBank")or
		(Container == BBCont1_1)and((strsub(self:GetName(),1,9)=="BaudBInve")or(self==BaudBagKeyRingButton)))then
		return
	end

	if Container:IsShown() then
		Container:Hide()
	else
		Container:Show()
	end
end

local pre_OpenAllBags = OpenAllBags
OpenAllBags = function(forceOpen)
	if Config and(Config[1].Enabled == false)then
		return pre_OpenAllBags(forceOpen)
	end
	if not BagsReady then
		return
	end
	local Container, AnyShown
	for Bag = 0, 4 do
		Container = _G[format("BaudBagSubBag%s", Bag)]:GetParent()
		if(GetContainerNumSlots(Bag) > 0)and not Container:IsShown()then
			Container:Show()
			AnyShown = true
		end
	end
	if not AnyShown then
		BaudBagCloseBagSet(1)
	end
end

local pre_BagSlotButton_OnClick = BagSlotButton_OnClick
BagSlotButton_OnClick = function(self)
	if Config and(Config[1].Enabled == false)then
		return pre_BagSlotButton_OnClick(self)
	end
	if not PutItemInBag(self:GetID())then
		ToggleBag(self:GetID() - CharacterBag0Slot:GetID() + 1)
	end
end

local pre_ToggleBackpack = ToggleBackpack
ToggleBackpack = function()
	if Config and(Config[1].Enabled == false)then
		return pre_ToggleBackpack()
	end
	if not BagsReady then
		return
	end
	if this and(this==FuBarPluginBagFuFrame)then
		OpenAllBags()
	else
		ToggleBag(0)
	end
end

local pre_ToggleKeyRing = ToggleKeyRing
ToggleKeyRing = function()
	if Config and(Config[1].Enabled == false)then
		return pre_ToggleKeyRing()
	end
	if not BagsReady then
		return
	end
	ToggleBag(-2)
end

local function IsBagShown(BagID)
	local SubBag = _G[format("BaudBagSubBag%s", BagID)]
	return SubBag:IsShown()and SubBag:GetParent():IsShown()and not SubBag:GetParent().Closing
end

local function UpdateThisHighlight(self)
	if Config and(Config[1].Enabled == false)then
		return
	end
	self:SetChecked(IsBagShown(self:GetID() - CharacterBag0Slot:GetID() + 1))
end

--These function hooks override the bag button highlight changes that Blizzard does
hooksecurefunc("BagSlotButton_OnClick",UpdateThisHighlight)
hooksecurefunc("BagSlotButton_OnDrag",UpdateThisHighlight)
hooksecurefunc("BagSlotButton_OnModifiedClick",UpdateThisHighlight)
hooksecurefunc("BackpackButton_OnClick",function(self)
	if Config and(Config[1].Enabled == false)then
		return
	end
	self:SetChecked(IsBagShown(0))
end)
hooksecurefunc("UpdateMicroButtons",function()
	if Config and(Config[1].Enabled == false)then
		return
	end
	if IsBagShown(KEYRING_CONTAINER)then
		KeyRingButton:SetButtonState("PUSHED", 1)
	else
		KeyRingButton:SetButtonState("NORMAL")
	end
end)

--self is hooked to be able to replace the original bank box with this one
local pre_BankFrame_OnEvent = BankFrame_OnEvent
BankFrame_OnEvent = function(self, event, ...)
	if Config and(Config[2].Enabled == false)then
		return pre_BankFrame_OnEvent(self, event, ...)
	end
end

local SubBagEvents = {
	BAG_UPDATE = function(self)
		if(self:GetID()~=arg1)then
			return
		end
		--BAG_UPDATE is the only event called when a bag is added, so if no bag existed before, refresh
		if(self.size > 0)then
			ContainerFrame_Update(self)
			BaudBagUpdateSubBag(self)
		else
			self:GetParent().Refresh = true
		end
	end,

	BAG_CLOSED = function(self)
		if(self:GetID()~=arg1)then
			return
		end
		--self event occurs when bags are swapped too, but updated information is not immediately
		--available to the addon, so the bag must be updated later.
		self:GetParent().Refresh = true
	end
}

local Func = function(self)
	ContainerFrame_Update(self)
end
SubBagEvents.ITEM_LOCK_CHANGED = Func
SubBagEvents.BAG_UPDATE_COOLDOWN = Func
SubBagEvents.UPDATE_INVENTORY_ALERTS = Func

function BaudBagSubBag_OnLoad(self)
	for Key, Value in pairs(SubBagEvents)do
		self:RegisterEvent(Key)
	end
end

function BaudBagUpdateSubBag(SubBag)
	local Link, Quality, Texture, ItemButton
	SubBag.FreeSlots = 0
	for Slot = 1, SubBag.size do
		Quality = nil
		ItemButton = _G[format("%sItem%s", SubBag:GetName(), Slot)]
		if(SubBag.BagSet~=2)or BankOpen then
			Link = GetContainerItemLink(SubBag:GetID(),Slot)
			if Link then
				Quality = select(3,GetItemInfo(Link))
			end
		end
		if not Link then
			SubBag.FreeSlots = SubBag.FreeSlots + 1
		end
		Texture = _G[format("%sBorder", ItemButton:GetName())]
		if Quality and(Quality > 1) then
			Texture:SetVertexColor(GetItemQualityColor(Quality))
			Texture:Show()
		else
			Texture:Hide()
		end
	end
end

function BaudBagSubBag_OnEvent(self, event)
	if not self:GetParent():IsShown()or(self:GetID() >= 5)and not BankOpen then
		return
	end
	SubBagEvents[event](self)
end

function BaudBagContainer_OnLoad(self)
	tinsert(UISpecialFrames, self:GetName())
	self:RegisterForDrag("LeftButton")
end

function BaudBagContainer_OnUpdate(self)
	if self.Refresh then
		BaudBagUpdateContainer(self)
		BaudBagUpdateOpenBags()
	end
	if self.FadeStart then
		local Alpha = (GetTime() - self.FadeStart) / FadeTime
		if self.Closing then
			Alpha = 1 - Alpha
			if(Alpha < 0)then
				self.FadeStart = nil
				self:Hide()
				self.Closing = nil
				return
			end
		elseif(Alpha > 1)then
			self:SetAlpha(1)
			self.FadeStart = nil
			return
		end
		self:SetAlpha(Alpha)
	end
end

function BaudBagContainer_OnShow(self)
	if self.FadeStart then
		return
	end
	self.FadeStart = GetTime()
	PlaySound("igBackPackOpen")
	BaudBagUpdateContainer(self)
	BaudBagUpdateOpenBags()
end

function BaudBagContainer_OnHide(self)
	if self.Closing then
		if self.FadeStart then
			self:Show()
		end
		return
	end
	self.FadeStart = GetTime()
	self.Closing = true
	PlaySound("igBackPackClose")
	self.AutoOpened = false
	BaudBagUpdateOpenBags()
	if(self.BagSet==2)and(self:GetID()==1)then
		if BankOpen and(Config[2].Enabled==true)then
			CloseBankFrame()
		end
		BaudBagCloseBagSet(2)
	end
	self:Show()
end

local TotalFree, TotalSlots

local function AddFreeSlots(Bag)
	if(Bag<=-2)then
		return
	end
	local NumSlots
	local Free, Family = GetContainerNumFreeSlots(Bag)
	if(Family~=0)then
		return
	end
	TotalFree = TotalFree + Free
	NumSlots = GetContainerNumSlots(Bag)
	TotalSlots = TotalSlots + NumSlots
end

function BaudBagBankBags_Update()
	local Purchase = BaudBagBankSlotPurchaseFrame
	local Slots, Full = GetNumBankSlots()
	local BagSlot

	for Bag = 1, NUM_BANKBAGSLOTS do
		BagSlot = _G[format("BaudBBankBag%s", Bag)]

		if(Bag <= Slots)then
			SetItemButtonTextureVertexColor(BagSlot, 1.0, 1.0, 1.0)
			BagSlot.tooltipText = BANK_BAG
		else
			SetItemButtonTextureVertexColor(BagSlot, 1.0, 0.1, 0.1)
			BagSlot.tooltipText = BANK_BAG_PURCHASE
		end
	end

	if Full then
		Purchase:Hide()
		BBCont2_1BagsFrame:SetHeight(BBCont2_1BagsFrame.Height)
		return
	end

	local Cost = GetBankSlotCost(Slots)

	--This line allows the confirmation box to show the cost
	BankFrame.nextSlotCost = Cost

	if( GetMoney() >= Cost ) then
		SetMoneyFrameColor(format("%sMoneyFrame", Purchase:GetName()), 1.0, 1.0, 1.0)
	else
		SetMoneyFrameColor(format("%sMoneyFrame", Purchase:GetName()), 1.0, 0.1, 0.1)
	end
	MoneyFrame_Update(format("%sMoneyFrame", Purchase:GetName()), Cost)

	Purchase:Show()
	BBCont2_1BagsFrame:SetHeight(BBCont2_1BagsFrame.Height + 40)
end

--This is for the button that toggles the bank bag display
function BaudBagBagsButton_OnClick(self)
	local Set = self:GetParent().BagSet
	--Bank set is automaticaly shown, and main bags are not
	Config[Set].ShowBags = (Config[Set].ShowBags==false)
	BaudBagUpdateBagFrames()
end

function BaudBagUpdateBagFrames()
	local Shown, BagFrame
	for BagSet = 1, 2 do
		Shown = (Config[BagSet].ShowBags ~= false)
		_G[format("BBCont%s_1BagsButton", BagSet)]:SetChecked(Shown)
		BagFrame = _G[format("BBCont%s_1BagsFrame", BagSet)]
		if Shown then
			BagFrame:Show()
		else
			BagFrame:Hide()
		end
	end
end

function BaudBagUpdateName(Container)
	local Name = _G[format("%sName", Container:GetName())]
	Name:SetText(Config[Container.BagSet][Container:GetID()].Name or "")
	Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end

function BaudBagUpdateContainer(Container)
	Container.Refresh = false
	BaudBagUpdateName(Container)
	local SlotLevel = Container:GetFrameLevel() + 1
	local ContCfg = Config[Container.BagSet][Container:GetID()]
	local MaxCols = 10
	local Size, KeyRing
	Container.Slots = 0
	for _, SubBag in ipairs(Container.Bags)do
		Size = GetContainerNumSlots(SubBag:GetID())
		if(SubBag:GetID()==-2)then
			local LastUsed = 0
			local FirstEmpty
			for Slot = 1, Size do
				if GetContainerItemLink(-2, Slot)then
					LastUsed = Slot
				elseif not FirstEmpty then
					FirstEmpty = Slot
				end
			end
			if FirstEmpty and(LastUsed < Size)then
				KeyRing = SubBag
				local Max = Size
				Size = max(FirstEmpty, LastUsed)
				KeyRing.Expandable = Max - Size
			end
		end
		SubBag.size = Size
		Container.Slots = Container.Slots + Size
	end
	
	if Container.Slots <= 0 then
		if Container:IsShown() then
			Container:Hide()
		end
		return
	end
	
	if Container.Slots < MaxCols then
		MaxCols = Container.Slots
	elseif KeyRing and(Container.Slots % MaxCols ~= 0)then
		local Increase = min(KeyRing.Expandable, MaxCols - Container.Slots % MaxCols)
		KeyRing.size = KeyRing.size + Increase
		Container.Slots = Container.Slots + Increase
	end

	local Col, Row = 0, 1
	local ItemButton
	for _, SubBag in pairs(Container.Bags)do
		if(SubBag.size <= 0)then
			SubBag:Hide()
		else
			--Create extra slots if needed
			if(SubBag.size > (SubBag.maxSlots or 0))then
				for Slot = (SubBag.maxSlots or 0) + 1, SubBag.size do
					local Button = CreateFrame("Button", format("%sItem%s", SubBag:GetName(), Slot) ,SubBag,(SubBag:GetID() ~= -1)and "ContainerFrameItemButtonTemplate" or "BankItemButtonGenericTemplate")
					Button:SetID(Slot)
					local Texture = Button:CreateTexture(format("%sBorder", Button:GetName()),"OVERLAY")
					Texture:Hide()
					Texture:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
					Texture:SetPoint("CENTER")
					Texture:SetBlendMode("ADD")
					Texture:SetAlpha(0.8)
					Texture:SetHeight(70)
					Texture:SetWidth(70)
				end
				SubBag.maxSlots = SubBag.size
			end
			if(SubBag:GetID()~=-1)and(BankOpen or(SubBag:GetID() < 5))then
				ContainerFrame_Update(SubBag)
			end
			BaudBagUpdateSubBag(SubBag)
			for Slot = 1, SubBag.maxSlots do
				ItemButton = _G[format("%sItem%s", SubBag:GetName(), Slot)]
				if(Slot <= SubBag.size)then
					Col = Col + 1
					if(Col > MaxCols)then
						Col = 1
						Row = Row + 1
					end
					ItemButton:ClearAllPoints()
					ItemButton:SetPoint("TOPLEFT",Container,"TOPLEFT",(Col-1)*39,(Row-1)*-39)
					ItemButton:SetFrameLevel(SlotLevel)
					ItemButton:Show()
				else
					ItemButton:Hide()
				end
			end
			SubBag:Show()
		end
	end
	Container:SetWidth(MaxCols * 39 - 2)
	Container:SetHeight(Row * 39 - 2)
	BaudBagUpdateBackground(Container)
end

function BaudBagKeyRing_OnLoad(self)
	local Clone = KeyRingButton
	Clone:GetScript("OnLoad")(self)
	self:SetScript("OnClick",       Clone:GetScript("OnClick"))
	self:SetScript("OnReceiveDrag", Clone:GetScript("OnReceiveDrag"))
	self:SetScript("OnEnter",       Clone:GetScript("OnEnter"))
	self:SetScript("OnLeave",       Clone:GetScript("OnLeave"))
	self:GetNormalTexture():SetTexCoord(   0.5625,0,0,0,0.5625,0.60937,0,0.60937)
	self:GetHighlightTexture():SetTexCoord(0.5625,0,0,0,0.5625,0.60937,0,0.60937)
	self:GetPushedTexture():SetTexCoord(   0.5625,0,0,0,0.5625,0.60937,0,0.60937)
end