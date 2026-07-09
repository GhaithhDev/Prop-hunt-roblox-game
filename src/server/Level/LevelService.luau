local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local LevelConfig = require(ReplicatedStorage.Shared.Configs.LevelConfig)
local XpPerPress = require(ReplicatedStorage.Shared.Packages.XpPerPress)
local SpeedService = require(ServerScriptService.Server.Speed.SpeedService)

local LevelService = {}

function LevelService.CheckLevelUp(player: Player)
	local currentLevel = DataManager.Get(player, "Level") or 1
	local currentSpeed = DataManager.Get(player, "Speed") or 0
	local newLevel = currentLevel

	while currentSpeed >= LevelConfig.GetXpRequiredForLevel(newLevel + 1) do
		newLevel += 1
	end

	if newLevel ~= currentLevel then
		DataManager.Set(player, "Level", newLevel)
		SpeedService.ResetCustomSpeed(player)
	end
end

function LevelService.GrantXp(player: Player, amount: number)
	local success = DataManager.Add(player, "Speed", amount)
	if not success then return end
	LevelService.CheckLevelUp(player)
end

function LevelService.GrantClickXp(player: Player)
	LevelService.GrantXp(player, XpPerPress.GetAmountForPlayer(player))
end

return LevelService
