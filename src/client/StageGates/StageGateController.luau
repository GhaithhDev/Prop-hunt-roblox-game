local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local StageGates = require(ReplicatedStorage.Shared.Configs.StageGates)

local LocalPlayer = Players.LocalPlayer

local StageGateController = {}

local levelValue

-- CanCollide only needs to differ per-player, and a shared gate Part is one
-- instance in the world - so this is a purely local (this client's own
-- physics view) override, not something the server replicates. A gate with
-- no configured requirement stays blocking (fail-safe) rather than open.
local function UpdateGate(gate: BasePart)
	local requiredLevel = StageGates.GetRequiredLevelForStage(gate.Name)
	if requiredLevel == nil then
		gate.CanCollide = true
		return
	end

	gate.CanCollide = levelValue.Value < requiredLevel
end

local function UpdateAllGates()
	for _, gate in CollectionService:GetTagged(Tags.StageGate) do
		UpdateGate(gate)
	end
end

function StageGateController.Start()
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	levelValue = playerData:WaitForChild("Level")

	UpdateAllGates()
	levelValue:GetPropertyChangedSignal("Value"):Connect(UpdateAllGates)

	-- StreamingEnabled is on - gates far from the player won't exist locally
	-- until they stream in, so newly-streamed ones need the same treatment.
	CollectionService:GetInstanceAddedSignal(Tags.StageGate):Connect(UpdateGate)
end

return StageGateController
