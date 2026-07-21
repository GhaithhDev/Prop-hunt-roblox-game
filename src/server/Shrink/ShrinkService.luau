local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local ShrinkConfig = require(ReplicatedStorage.Shared.Configs.ShrinkConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local ShrinkService = {}

-- Session-only: a manually-set custom size survives respawns but not level-ups
-- or rejoins, so it's kept here rather than in the saved profile. Replicated
-- to the owning client via the "CustomScale" attribute on the Player - the
-- client (which owns its own character's physics) is what actually calls
-- character:ScaleTo now, not the server; doing it server-side left the
-- character's movement drifty/floaty instead of stopping instantly on key
-- release, since it fought the client's own physics simulation of its
-- network-owned character.
local customSizes = {}

local function syncCustomScale(player: Player)
	player:SetAttribute("CustomScale", customSizes[player])
end

-- Clears any custom size override, letting the client fall back to the
-- level-based default. Call this whenever the player's level changes.
function ShrinkService.ResetCustomSize(player: Player)
	customSizes[player] = nil
	syncCustomScale(player)
end

local function OnSetCustomSize(player: Player, desiredScale)
	if typeof(desiredScale) ~= "number" or desiredScale ~= desiredScale then
		warn(`ShrinkService: {player.Name} sent a non-numeric/NaN scale`)
		return
	end

	local level = DataManager.Get(player, "Level") or 1
	local minScale = ShrinkConfig.GetScaleForLevel(level)

	if desiredScale < minScale or desiredScale > ShrinkConfig.BaseScale then
		warn(`ShrinkService: {player.Name} requested {desiredScale}, outside allowed range {minScale}-{ShrinkConfig.BaseScale}`)
		return
	end

	customSizes[player] = desiredScale
	syncCustomScale(player)
end

function ShrinkService.Start()
	Players.PlayerRemoving:Connect(function(player)
		customSizes[player] = nil
	end)

	Net:Connect("SetCustomSize", OnSetCustomSize)
end

return ShrinkService
