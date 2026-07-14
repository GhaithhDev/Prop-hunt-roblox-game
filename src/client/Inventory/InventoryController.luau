local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local TrailsConfig = require(ReplicatedStorage.Shared.Configs.TrailsConfig)
local AurasConfig = require(ReplicatedStorage.Shared.Configs.AurasConfig)

local LocalPlayer = Players.LocalPlayer

local InventoryController = {}

local EQUIP_COLOR = Color3.fromRGB(80, 200, 60)
local UNEQUIP_COLOR = Color3.fromRGB(220, 60, 60)

local function tryShowLivePrice(button: TextButton, productId: number)
	local label = button:FindFirstChildOfClass("TextLabel")
	if not label then return end

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			label.Text = tostring(info.PriceInRobux)
		end
		-- On failure (e.g. still-placeholder product), leave the existing
		-- static label text untouched.
	end)
end

-- Category = the Net-remote "Trail"/"Aura" string InventoryService expects;
-- GamePassCategory = the plural MonetizationConfig.GamePasses/status key,
-- also the name of the frame's ScrollingFrame (Inventory.Trails,
-- Inventory.Auras - item cards are direct children, no nested folder).
local CATEGORIES = {
	{ Category = "Trail", GamePassCategory = "Trails", Config = TrailsConfig },
	{ Category = "Aura", GamePassCategory = "Auras", Config = AurasConfig },
}

function InventoryController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local inventoryFrame = playerGui:WaitForChild("Main"):WaitForChild("Inventory")

	local lastStatus = nil
	local refreshStatus -- forward-declared: button handlers below close over this
	local cardsByProductId: { [number]: Frame } = {}
	local cardsByCategory: { [string]: { [string]: Frame } } = {}

	local function applyCardState(card: Frame, owned: boolean, equipped: boolean)
		local buyWinsFrame = card:FindFirstChild("BuywithWins")
		local buyRobuxFrame = card:FindFirstChild("BuywithRobux")
		local equipFrame = card:FindFirstChild("Equip")

		if buyWinsFrame then
			buyWinsFrame.Visible = not owned
		end
		if buyRobuxFrame then
			buyRobuxFrame.Visible = not owned
		end

		if equipFrame then
			equipFrame.Visible = owned

			local equipButton = equipFrame:FindFirstChildOfClass("TextButton")
			if equipButton then
				equipButton.TextLabel.Text = equipped and "UnEquip" or "Equip"
				equipButton.BackgroundColor3 = equipped and UNEQUIP_COLOR or EQUIP_COLOR
				equipButton.BackgroundTransparency = 0
			end
		end
	end

	local function buildCard(categoryEntry, itemId: string, scrollingFrame: Instance): Frame?
		local card = scrollingFrame:FindFirstChild(itemId)
		if not card then return nil end

		local item = categoryEntry.Config.Items[itemId]

		local buyWinsFrame = card:FindFirstChild("BuywithWins")
		local buyWinsButton = buyWinsFrame and buyWinsFrame:FindFirstChildOfClass("TextButton")
		if buyWinsButton then
			local priceLabel = buyWinsButton:FindFirstChildOfClass("TextLabel")
			if priceLabel then
				priceLabel.Text = NumberFormat.Format(item.WinsCost)
			end

			buyWinsButton.Activated:Connect(function()
				Net:Invoke("BuyWithWins", categoryEntry.Category, itemId)
				refreshStatus()
			end)
		end

		local buyRobuxFrame = card:FindFirstChild("BuywithRobux")
		local buyRobuxButton = buyRobuxFrame and buyRobuxFrame:FindFirstChildOfClass("TextButton")
		if buyRobuxButton then
			buyRobuxButton.Activated:Connect(function()
				Net:RemoteEvent("RequestRobuxPurchase"):FireServer(categoryEntry.Category, itemId)
			end)

			local passes = MonetizationConfig.GamePasses[categoryEntry.GamePassCategory]
			local productId = passes and passes[itemId]
			if productId and productId ~= 0 then
				tryShowLivePrice(buyRobuxButton, productId)
				cardsByProductId[productId] = card
			end
		end

		-- Server toggles equip/unequip on the same remote based on current
		-- equipped state, so the button always just re-invokes EquipItem.
		local equipFrame = card:FindFirstChild("Equip")
		local equipButton = equipFrame and equipFrame:FindFirstChildOfClass("TextButton")
		if equipButton then
			equipButton.Activated:Connect(function()
				Net:Invoke("EquipItem", categoryEntry.Category, itemId)
				refreshStatus()
			end)
		end

		return card
	end

	for _, categoryEntry in CATEGORIES do
		local scrollingFrame = inventoryFrame:WaitForChild(categoryEntry.GamePassCategory)
		cardsByCategory[categoryEntry.Category] = {}

		for itemId in categoryEntry.Config.Items do
			local card = buildCard(categoryEntry, itemId, scrollingFrame)
			if card then
				cardsByCategory[categoryEntry.Category][itemId] = card
			end
		end
	end

	local function applyStatus()
		if not lastStatus then return end

		for _, categoryEntry in CATEGORIES do
			local statusList = lastStatus[categoryEntry.GamePassCategory] or {}
			local statusById = {}
			for _, statusItem in statusList do
				statusById[statusItem.Id] = statusItem
			end

			local equippedId = categoryEntry.Category == "Trail" and lastStatus.EquippedTrail or lastStatus.EquippedAura

			for itemId, card in cardsByCategory[categoryEntry.Category] do
				local statusItem = statusById[itemId]
				local owned = statusItem ~= nil and statusItem.Owned
				applyCardState(card, owned, owned and itemId == equippedId)
			end
		end
	end

	refreshStatus = function()
		lastStatus = Net:Invoke("GetInventoryStatus")
		applyStatus()
	end

	-- Robux purchases resolve async via Roblox's own purchase-finished signal
	-- (already fired natively) - refresh so the card flips to Owned without
	-- the player needing to close/reopen Inventory.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if not isPurchased or userId ~= LocalPlayer.UserId then return end
		if cardsByProductId[productId] then
			refreshStatus()
		end
	end)

	local toggleButton = inventoryFrame:WaitForChild("ToggleButton").Value
	if toggleButton then
		toggleButton.Activated:Connect(refreshStatus)
	end

	local trailsScrolling = inventoryFrame:WaitForChild("Trails")
	local aurasScrolling = inventoryFrame:WaitForChild("Auras")
	local openTrailButton = inventoryFrame:WaitForChild("OpenTrailButton"):FindFirstChildOfClass("TextButton")
	local openAurasButton = inventoryFrame:WaitForChild("OpenAurasButton"):FindFirstChildOfClass("TextButton")

	if openTrailButton then
		openTrailButton.Activated:Connect(function()
			trailsScrolling.Visible = true
			aurasScrolling.Visible = false
		end)
	end

	if openAurasButton then
		openAurasButton.Activated:Connect(function()
			aurasScrolling.Visible = true
			trailsScrolling.Visible = false
		end)
	end

	refreshStatus()
end

return InventoryController
