local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)

local LocalPlayer = Players.LocalPlayer

local ReviveController = {}

local FADE_IN_TIME = 0.35
local HOLD_TIME = 4
local FADE_OUT_TIME = 0.35
local OFFSCREEN_RISE = 0.2 -- relative Y distance above the template's rest position
local BOB_OFFSET = 0.012 -- relative Y bob amplitude while holding
local BOB_TIME = 1.1 -- seconds per half-cycle of the bob

local mainGui, template

local function ensureLoaded()
	if template then return end
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	mainGui = playerGui:WaitForChild("Main")
	template = mainGui:WaitForChild("ReviveNotification")
end

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
		-- On failure (e.g. still-placeholder shared test product), leave the
		-- existing static label text untouched.
	end)
end

function ReviveController.Show(stageNumber: number)
	ensureLoaded()

	local clone = template:Clone()
	local stageLabel = clone:WaitForChild("StageLabel")
	local reviveButton = clone:WaitForChild("ReviveButton")

	stageLabel.Text = `Revive to Stage {stageNumber}?`

	local reviveProductId = MonetizationConfig.DevProducts.ReviveToPreviousStage
	if reviveProductId and reviveProductId ~= 0 then
		tryShowLivePrice(reviveButton, reviveProductId)
	end

	local revived = false
	reviveButton.Activated:Connect(function()
		if revived then return end
		revived = true
		Net:RemoteEvent("RequestRevive"):FireServer(stageNumber)
	end)

	local restPosition = template.Position
	local offscreenPosition = restPosition - UDim2.new(0, 0, OFFSCREEN_RISE, 0)

	clone.Position = offscreenPosition
	clone.Visible = true
	clone.Parent = mainGui

	local fadeInInfo = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeInTween = TweenService:Create(clone, fadeInInfo, { Position = restPosition })
	fadeInTween:Play()

	-- Gentle floating-on-water bob while it holds - a continuous reversing
	-- sine tween around the rest position, started only once the fade-in
	-- lands so it doesn't fight that tween's own Position goal.
	local bobTween: Tween?
	fadeInTween.Completed:Once(function()
		local bobInfo = TweenInfo.new(BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		bobTween = TweenService:Create(clone, bobInfo, { Position = restPosition + UDim2.new(0, 0, BOB_OFFSET, 0) })
		bobTween:Play()
	end)

	task.delay(FADE_IN_TIME + HOLD_TIME, function()
		if bobTween then
			bobTween:Cancel()
		end

		local fadeOutInfo = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeOutTween = TweenService:Create(clone, fadeOutInfo, { Position = offscreenPosition })
		fadeOutTween:Play()

		fadeOutTween.Completed:Once(function()
			clone:Destroy()
		end)
	end)
end

function ReviveController.Start()
	ensureLoaded()

	Net:Connect("ShowRevivePopup", function(stageNumber)
		ReviveController.Show(stageNumber)
	end)
end

return ReviveController
