local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local TeleportConfig = require(ReplicatedStorage.Shared.Configs.TeleportConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local WINS_KEY = "Wins"

local TeleportService = {}

-- TeleportConfig is the single source of truth for Wins pricing (shared with
-- TeleportController, which generates the stage frames from the same config)
-- - no need to cache it into a separate lookup table, just search it directly.
local function getStageConfig(stageNumber: number): TeleportConfig.StageEntry?
	for _, item in TeleportConfig do
		if item.TeleportTo == stageNumber then
			return item
		end
	end
	return nil
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
	local stage = stageNumber and getStageConfig(stageNumber)
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
	local stage = stageNumber and getStageConfig(stageNumber)
	if not stage then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `Stage {stageNumber} isn't available.`)
		return
	end

	local skipProductId = MonetizationConfig.DevProducts.SkipToStage[tostring(stageNumber)]
	if not skipProductId or skipProductId == 0 then
		warn(`TeleportService: DevProducts.SkipToStage has no valid ProductId for stage {stageNumber} - replace it in MonetizationConfig before shipping`)
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Robux teleport isn't available for this stage yet!")
		return
	end

	MonetizationService.PromptPurchaseById(player, skipProductId)
end

function TeleportService.Start()
	-- Each stage has its own distinct ProductId, so the registered handler
	-- already knows which stage it's for - no need to track per-player intent.
	for stageKey, productId in MonetizationConfig.DevProducts.SkipToStage do
		local stageNumber = tonumber(stageKey)
		if stageNumber and productId ~= 0 then
			MonetizationService.RegisterConsumable(productId, function(player: Player)
				teleportPlayerToStage(player, stageNumber)
				Net:RemoteEvent("Notify"):FireClient(player, "success", `Teleported to Stage {stageNumber}!`)
			end)
		end
	end

	Net:Connect("RequestWinsTeleport", onRequestWinsTeleport)
	Net:Connect("RequestRobuxTeleport", onRequestRobuxTeleport)
end

return TeleportService
