local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)

local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local DEBOUNCE_TIME = 1

local DeathService = {}

local debounce = {}

-- Teleports the player back to the hub spawner and, if a stage is given,
-- offers a paid revive back to it (one shared DevProducts.ReviveToPreviousStage
-- product for every stage, independent of Skip to Stage pricing - see
-- TeleportService.onRequestRevive, which the client's Revive button fires
-- into directly). Debounced per-player so repeated triggers (e.g. a zombie
-- landing several contact ticks in a row) can't spam it.
function DeathService.KillPlayer(player: Player, stageNumber: number?)
	local character = player.Character
	if not character then return end

	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	local spawner = workspace.Functional.PlayerSpawners:GetChildren()[1]
	if spawner then
		character:PivotTo(spawner.CFrame + TELEPORT_OFFSET)
	end

	if stageNumber then
		local reviveProductId = MonetizationConfig.DevProducts.ReviveToPreviousStage
		if reviveProductId and reviveProductId ~= 0 then
			Net:RemoteEvent("ShowRevivePopup"):FireClient(player, stageNumber)
		end
	end
end

local function OnDeathPartTouched(part, hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	DeathService.KillPlayer(player, part:GetAttribute("Stage"))
end

function DeathService.Start()
	for _, part in CollectionService:GetTagged(Tags.DeathPart) do
		part.Touched:Connect(function(hit)
			OnDeathPartTouched(part, hit)
		end)
	end
end

return DeathService
