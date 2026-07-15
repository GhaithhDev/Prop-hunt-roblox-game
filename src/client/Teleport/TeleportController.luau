local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local TeleportConfig = require(ReplicatedStorage.Shared.Configs.TeleportConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local TeleportController = {}

local function tryShowLivePrice(robuxButton: TextButton, productId: number)
	local label = robuxButton:FindFirstChildOfClass("TextLabel")
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

local function wireStage(frame: Frame, item: TeleportConfig.StageEntry)
	local stageNumber = item.TeleportTo

	local stageNumberLabel = frame:FindFirstChild("StageNumber")
	if stageNumberLabel and stageNumberLabel:IsA("TextLabel") then
		stageNumberLabel.Text = `Stage {stageNumber}`
	end

	frame.BackgroundColor3 = item.UIcolor

	local winsPriceFrame = frame:FindFirstChild("WinsPrice")
	local winsButton = winsPriceFrame and winsPriceFrame:FindFirstChild("TextButton")
	if winsButton then
		local winsLabel = winsButton:FindFirstChildOfClass("TextLabel")
		if winsLabel then
			winsLabel.Text = NumberFormat.Format(item.WinsCost)
		end

		winsButton.Activated:Connect(function()
			Net:RemoteEvent("RequestWinsTeleport"):FireServer(stageNumber)
		end)
	end

	local robuxFrame = frame:FindFirstChild("RobuxFrame")
	local robuxButton = robuxFrame and robuxFrame:FindFirstChild("TextButton")
	if robuxButton then
		robuxButton.Activated:Connect(function()
			Net:RemoteEvent("RequestRobuxTeleport"):FireServer(stageNumber)
		end)

		local skipProductId = MonetizationConfig.DevProducts.SkipToStage[tostring(stageNumber)]
		if skipProductId and skipProductId ~= 0 then
			tryShowLivePrice(robuxButton, skipProductId)
		end
	end
end

function TeleportController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local scrollingFrame = playerGui:WaitForChild("Main"):WaitForChild("TeleportStage"):WaitForChild("ScrollingFrame")
	local template = scrollingFrame:WaitForChild("UIListLayout"):WaitForChild("StageTemplateFrame")

	for index, item in TeleportConfig do
		local clone = template:Clone()
		clone.Name = `Stage{item.TeleportTo}`
		clone.LayoutOrder = index
		clone.Parent = scrollingFrame
		wireStage(clone, item)
	end
end

return TeleportController
