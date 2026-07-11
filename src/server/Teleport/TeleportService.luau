local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local WINS_KEY = "Wins"

local TeleportService = {}

type StageInfo = { WinsCost: number, ProductId: number }
local stages: { [number]: StageInfo } = {}
local pendingIntent: { [Player]: number } = {}

-- Discovers StageN frames under the StarterGui template (server-readable static
-- content, not client-mutable networked state) once at Start(). Stage6..Stage13
-- etc. added later in Studio with the same template need zero code changes here.
local function scanStages()
	local scrollingFrame = StarterGui.Main.TeleportStage.ScrollingFrame

	for _, frame in scrollingFrame:GetChildren() do
		if not frame:IsA("Frame") then continue end

		local stageNumber = tonumber(frame.Name:match("^Stage(%d+)$"))
		if not stageNumber then continue end

		local productId = frame:GetAttribute("productId")
		local winsButton = frame:FindFirstChild("WinsPrice") and frame.WinsPrice:FindFirstChild("TextButton")
		local winsLabel = winsButton and winsButton:FindFirstChildOfClass("TextLabel")
		local winsCost = winsLabel and tonumber(winsLabel.Text)

		if not (productId and winsCost) then
			warn(`TeleportService: {frame.Name} is missing a productId attribute or a valid WinsPrice - skipping`)
			continue
		end

		stages[stageNumber] = { WinsCost = winsCost, ProductId = productId }
	end
end

local function teleportPlayerToStage(player: Player, stageNumber: number)
	local character = player.Character
	if not character then
		warn(`TeleportService: {player.Name} has no character to teleport`)
		return
	end

	local part = workspace.Functional.TeleportStages:FindFirstChild(tostring(stageNumber))
	if not part then
		warn(`TeleportService: no TeleportStages part found for stage {stageNumber}`)
		return
	end

	character:PivotTo(part.CFrame + TELEPORT_OFFSET)
end

local function onRequestWinsTeleport(player: Player, stageNumber: number)
	stageNumber = tonumber(stageNumber) :: number
	local stage = stageNumber and stages[stageNumber]
	if not stage then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `Stage {stageNumber} isn't available.`)
		return
	end

	local wins = DataManager.Get(player, WINS_KEY) or 0
	if wins < stage.WinsCost then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You need {stage.WinsCost} Wins to teleport to Stage {stageNumber}!`)
		return
	end

	DataManager.Add(player, WINS_KEY, -stage.WinsCost)
	teleportPlayerToStage(player, stageNumber)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Teleported to Stage {stageNumber}!`)
end

local function onRequestRobuxTeleport(player: Player, stageNumber: number)
	stageNumber = tonumber(stageNumber) :: number
	local stage = stageNumber and stages[stageNumber]
	if not stage then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `Stage {stageNumber} isn't available.`)
		return
	end

	pendingIntent[player] = stageNumber
	MonetizationService.PromptPurchaseById(player, stage.ProductId)
end

-- Shared across every distinct ProductId found among the scanned stages (there
-- may be just one, if stages currently share a placeholder productId).
local function onConsumablePurchased(player: Player, receiptInfo)
	local stageNumber = pendingIntent[player]
	pendingIntent[player] = nil

	if not stageNumber then
		warn(`TeleportService: consumable purchase confirmed for {player.Name} (ProductId {receiptInfo.ProductId}) but no pendingIntent - skipping teleport`)
		return
	end

	local stage = stages[stageNumber]
	if not stage or stage.ProductId ~= receiptInfo.ProductId then
		warn(`TeleportService: pendingIntent stage {stageNumber} for {player.Name} doesn't match purchased ProductId {receiptInfo.ProductId} - skipping teleport`)
		return
	end

	teleportPlayerToStage(player, stageNumber)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Teleported to Stage {stageNumber}!`)
end

function TeleportService.Start()
	scanStages()

	local registeredProductIds: { [number]: boolean } = {}
	for _, stage in stages do
		if registeredProductIds[stage.ProductId] then continue end
		registeredProductIds[stage.ProductId] = true
		MonetizationService.RegisterConsumable(stage.ProductId, onConsumablePurchased)
	end

	Net:Connect("RequestWinsTeleport", onRequestWinsTeleport)
	Net:Connect("RequestRobuxTeleport", onRequestRobuxTeleport)

	Players.PlayerRemoving:Connect(function(player)
		pendingIntent[player] = nil
	end)
end

return TeleportService
