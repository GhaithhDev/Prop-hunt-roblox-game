local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local ShrinkPassConfig = require(ReplicatedStorage.Shared.Configs.ShrinkPassConfig)

local LocalPlayer = Players.LocalPlayer

local ShrinkPassController = {}

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

function ShrinkPassController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local x2Shrink = playerGui:WaitForChild("Main"):WaitForChild("RightIcons"):WaitForChild("x2Shrink")

	local button = x2Shrink:WaitForChild("Button")
	local tierLabel = x2Shrink:WaitForChild("TierLabel")
	local priceLabel = x2Shrink:WaitForChild("PriceLabel")

	local currentNextTierProductId: number? = nil

	local function refresh()
		local status = Net:Invoke("GetShopStatus")
		local owned = (status and status.ShrinkPass) or {}
		local nextTier = ShrinkPassConfig.GetNextTier(owned)

		if nextTier then
			tierLabel.Text = `{nextTier.Multiplier}x Shrink`
			local passes = MonetizationConfig.GamePasses.ShrinkPass
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
		local owned = (status and status.ShrinkPass) or {}
		local nextTier = ShrinkPassConfig.GetNextTier(owned)
		if not nextTier then return end

		Net:RemoteEvent("RequestGamePassPurchase"):FireServer("ShrinkPass", nextTier.Id)
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

return ShrinkPassController
