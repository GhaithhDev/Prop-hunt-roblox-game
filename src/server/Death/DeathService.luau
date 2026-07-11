local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Tags = require(ReplicatedStorage.Shared.Configs.Tags)

local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local DEBOUNCE_TIME = 1

local DeathService = {}

local debounce = {}

local function OnDeathPartTouched(part, hit)
	print(hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	local spawner = workspace.Functional.PlayerSpawners:GetChildren()[1]
	if spawner then
		character:PivotTo(spawner.CFrame + TELEPORT_OFFSET)
	end
end

function DeathService.Start()
	for _, part in CollectionService:GetTagged(Tags.DeathPart) do
		part.Touched:Connect(function(hit)
			OnDeathPartTouched(part, hit)
		end)
	end
end

return DeathService
