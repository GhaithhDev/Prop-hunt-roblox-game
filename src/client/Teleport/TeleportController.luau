local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

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

local function wireStage(frame: Frame)
	local stageNumber = tonumber(frame.Name:match("^Stage(%d+)$"))
	if not stageNumber then return end

	local winsButton = frame:FindFirstChild("WinsPrice") and frame.WinsPrice:FindFirstChild("TextButton")
	if winsButton then
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

		local productId = frame:GetAttribute("productId")
		if productId then
			tryShowLivePrice(robuxButton, productId)
		end
	end
end

function TeleportController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local scrollingFrame = playerGui:WaitForChild("Main"):WaitForChild("TeleportStage"):WaitForChild("ScrollingFrame")

	for _, frame in scrollingFrame:GetChildren() do
		if frame:IsA("Frame") then
			wireStage(frame)
		end
	end
end

return TeleportController
