local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local SpeedPassConfig = require(ReplicatedStorage.Shared.Configs.SpeedPassConfig)

local LocalPlayer = Players.LocalPlayer

local SpeedPassController = {}

local function tryShowLivePrice(label: TextLabel, productId: number)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			label.Text = `Only {info.PriceInRobux}`
		end
		-- On failure (e.g. still-placeholder product), leave the existing
		-- static label text untouched.
	end)
end

function SpeedPassController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local x2Speed = playerGui:WaitForChild("Main"):WaitForChild("RightIcons"):WaitForChild("x2Speed")

	local button = x2Speed:WaitForChild("Button")
	local tierLabel = x2Speed:WaitForChild("TierLabel")
	local priceLabel = x2Speed:WaitForChild("PriceLabel")

	local currentNextTierProductId: number? = nil

	local function refresh()
		local status = Net:Invoke("GetShopStatus")
		local owned = (status and status.SpeedPass) or {}
		local nextTier = SpeedPassConfig.GetNextTier(owned)

		if nextTier then
			tierLabel.Text = `{nextTier.Multiplier}x Speed`
			local passes = MonetizationConfig.GamePasses.SpeedPass
			currentNextTierProductId = passes and passes[nextTier.Id]

			priceLabel.Visible = true
			if currentNextTierProductId and currentNextTierProductId ~= 0 then
				tryShowLivePrice(priceLabel, currentNextTierProductId)
			end
		else
			tierLabel.Text = "MAX"
			currentNextTierProductId = nil
			priceLabel.Visible = false
		end
	end

	button.Activated:Connect(function()
		local status = Net:Invoke("GetShopStatus")
		local owned = (status and status.SpeedPass) or {}
		local nextTier = SpeedPassConfig.GetNextTier(owned)
		if not nextTier then return end

		Net:RemoteEvent("RequestGamePassPurchase"):FireServer("SpeedPass", nextTier.Id)
	end)

	-- Roblox's own purchase-finished signal, already fired natively (and
	-- already consumed once by PurchaseLoadingController) - reused here
	-- instead of adding a new "purchase completed" remote.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if not isPurchased or userId ~= LocalPlayer.UserId then return end
		if productId == currentNextTierProductId then
			refresh()
		end
	end)

	refresh()
end

return SpeedPassController
