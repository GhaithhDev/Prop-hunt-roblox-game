local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local XpBoostConfig = require(ReplicatedStorage.Shared.Configs.XpBoostConfig)

local LocalPlayer = Players.LocalPlayer

local ShopController = {}

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

local function getDurationLabel(durationMinutes: number): string
	if durationMinutes == 60 then
		return "1 HOUR"
	end
	return `{durationMinutes} MINUTES`
end

-- DevProducts.XpBoost is a plain array, positionally matched to
-- XpBoostConfig (index 1 <-> XpBoostConfig[1], etc.) rather than keyed by
-- duration - configIndex is XpBoostConfig's own iteration index, passed
-- straight through from Start()'s loop.
local function wireTier(frame: Frame, item: XpBoostConfig.BoostEntry, configIndex: number)
	local textLabel = frame:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = getDurationLabel(item.DurationMinutes)
	end

	local buyFrame = frame:FindFirstChild("Buy")
	local buyButton = buyFrame and buyFrame:FindFirstChildOfClass("TextButton")
	if not buyButton then return end

	buyButton.Activated:Connect(function()
		Net:RemoteEvent("RequestXpBoost"):FireServer(item.DurationMinutes)
	end)

	local xpBoostProducts = MonetizationConfig.DevProducts.XpBoost
	local productId = xpBoostProducts and xpBoostProducts[configIndex]
	if productId and productId ~= 0 then
		tryShowLivePrice(buyButton, productId)
	end
end

local function markTreadmillOwned(tile: Frame)
	local buyFrame = tile:FindFirstChild("Buy")
	local buyButton = buyFrame and buyFrame:FindFirstChildOfClass("TextButton")
	if not buyButton then return end

	buyButton.AutoButtonColor = false
	buyButton.Interactable = false
	local priceLabel = buyButton:FindFirstChildOfClass("TextLabel")
	if priceLabel then
		priceLabel.Text = "OWNED"
	end
end

-- Each Frame's Name under TreadMills.Background *is* the passId directly
-- (renamed to match MonetizationConfig.GamePasses.Treadmills' keys) - no
-- name-mapping table needed, just skip the "Padding" layout spacer.
local function wireTreadmills(scrollingFrame: Frame)
	local background = scrollingFrame:WaitForChild("TreadMills"):WaitForChild("Background")
	local status = Net:Invoke("GetShopStatus")
	local owned = status and status.Treadmills or {}

	local tilesByProductId: { [number]: Frame } = {}

	for _, tile in background:GetChildren() do
		if tile:IsA("Frame") and tile.Name ~= "Padding" then
			local passId = tile.Name
			local productId = MonetizationConfig.GamePasses.Treadmills[passId]

			if owned[passId] then
				markTreadmillOwned(tile)
			else
				local buyFrame = tile:FindFirstChild("Buy")
				local buyButton = buyFrame and buyFrame:FindFirstChildOfClass("TextButton")
				if buyButton then
					buyButton.Activated:Connect(function()
						Net:RemoteEvent("RequestGamePassPurchase"):FireServer("Treadmills", passId)
					end)

					if productId and productId ~= 0 then
						tryShowLivePrice(buyButton, productId)
						tilesByProductId[productId] = tile
					end
				end
			end
		end
	end

	-- Roblox's own purchase-finished signal, already fired natively (and
	-- already consumed once by PurchaseLoadingController) - reused here
	-- instead of adding a new "purchase completed" remote.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if not isPurchased or userId ~= LocalPlayer.UserId then return end
		local tile = tilesByProductId[productId]
		if tile then
			markTreadmillOwned(tile)
		end
	end)
end

local function wireServerBoost(scrollingFrame: Frame)
	local background = scrollingFrame:WaitForChild("ServerBoost"):WaitForChild("Background")
	local nextTierLabel = background:WaitForChild("NextTierLabel")
	local currentTierLabel = background:WaitForChild("left")
	local buyFrame = background:WaitForChild("Buy")
	local buyButton = buyFrame:FindFirstChildOfClass("TextButton")
	local priceLabel = buyButton and buyButton:FindFirstChildOfClass("TextLabel")

	local lastPricedProductId: number? = nil

	local function updateUI()
		local currentMultiplier = Workspace:GetAttribute("ServerBoostMultiplier") or 1
		local nextMultiplier = Workspace:GetAttribute("ServerBoostNextTierMultiplier")

		currentTierLabel.Text = `{currentMultiplier}x`

		if nextMultiplier then
			nextTierLabel.Text = `{nextMultiplier}x`

			local nextLevel = nextMultiplier / 2
			local serverBoostProducts = MonetizationConfig.DevProducts.ServerBoost
			local productId = serverBoostProducts and serverBoostProducts[nextLevel]
			if priceLabel and productId and productId ~= 0 and productId ~= lastPricedProductId then
				lastPricedProductId = productId
				tryShowLivePrice(buyButton, productId)
			end
		else
			nextTierLabel.Text = "Max"
			if priceLabel then
				priceLabel.Text = "Max"
			end
		end
	end

	updateUI()
	Workspace:GetAttributeChangedSignal("ServerBoostMultiplier"):Connect(updateUI)
	Workspace:GetAttributeChangedSignal("ServerBoostNextTierMultiplier"):Connect(updateUI)

	if buyButton then
		buyButton.Activated:Connect(function()
			Net:RemoteEvent("RequestServerBoost"):FireServer()
		end)
	end
end

function ShopController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local scrollingFrame = playerGui:WaitForChild("Main"):WaitForChild("Shop"):WaitForChild("ScrollingFrame")

	local x2ShrinkFrame = scrollingFrame:WaitForChild("x2 ShrinkFrame")
	local background = x2ShrinkFrame:WaitForChild("Background")
	local template = background:WaitForChild("BoostTierTemplate")

	for index, item in XpBoostConfig do
		local clone = template:Clone()
		clone.Name = `BoostTier{item.DurationMinutes}`
		clone.LayoutOrder = index
		clone.Visible = true
		clone.Parent = background
		wireTier(clone, item, index)
	end

	-- The template stays in Background as a clone source (rejoining/reloading
	-- this controller needs it again) but shouldn't render as an extra tile -
	-- UIListLayout skips invisible children, so hiding it is enough.
	template.Visible = false

	wireTreadmills(scrollingFrame)
	wireServerBoost(scrollingFrame)
end

return ShopController
