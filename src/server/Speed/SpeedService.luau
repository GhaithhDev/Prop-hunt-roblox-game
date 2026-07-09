local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local SpeedConfig = require(ReplicatedStorage.Shared.Configs.SpeedConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local SpeedService = {}

-- Session-only: a manually-set custom speed survives respawns but not level-ups
-- or rejoins, so it's kept in memory here rather than in the saved profile.
local customSpeeds = {}

function SpeedService.ApplySpeed(player: Player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local level = DataManager.Get(player, "Level") or 1
	local maxSpeed = SpeedConfig.GetSpeedForLevel(level)
	local customSpeed = customSpeeds[player]

	if customSpeed then
		humanoid.WalkSpeed = math.clamp(customSpeed, SpeedConfig.BaseSpeed, maxSpeed)
	else
		humanoid.WalkSpeed = maxSpeed
	end
end

-- Clears any custom speed override and reapplies the level-based default.
-- Call this whenever the player's level changes.
function SpeedService.ResetCustomSpeed(player: Player)
	customSpeeds[player] = nil
	SpeedService.ApplySpeed(player)
end

local function OnSetCustomSpeed(player: Player, desiredSpeed)
	if typeof(desiredSpeed) ~= "number" or desiredSpeed ~= desiredSpeed then
		warn(`SpeedService: {player.Name} sent a non-numeric/NaN speed`)
		return
	end

	local level = DataManager.Get(player, "Level") or 1
	local maxSpeed = SpeedConfig.GetSpeedForLevel(level)

	if desiredSpeed < SpeedConfig.BaseSpeed or desiredSpeed > maxSpeed then
		warn(`SpeedService: {player.Name} requested {desiredSpeed}, outside allowed range {SpeedConfig.BaseSpeed}-{maxSpeed}`)
		return
	end

	customSpeeds[player] = desiredSpeed

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = desiredSpeed
end

local function OnCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		SpeedService.ApplySpeed(player)
	end
end

local function OnPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)

	if player.Character then
		OnCharacterAdded(player, player.Character)
	end
end

function SpeedService.Start()
	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(OnPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		customSpeeds[player] = nil
	end)

	Net:Connect("SetCustomSpeed", OnSetCustomSpeed)
end

return SpeedService
