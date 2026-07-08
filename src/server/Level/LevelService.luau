local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local LevelConfig = require(ReplicatedStorage.Shared.Configs.LevelConfig)

local LevelService = {}

function LevelService.CheckLevelUp(player: Player)
	local currentLevel = DataManager.Get(player, "Level") or 1
	local currentXp = DataManager.Get(player, "Xp") or 0
	local newLevel = currentLevel

	while currentXp >= LevelConfig.GetXpRequiredForLevel(newLevel + 1) do
		newLevel += 1
	end

	if newLevel ~= currentLevel then
		DataManager.Set(player, "Level", newLevel)
	end
end

function LevelService.GrantXp(player: Player, amount: number)
	local success = DataManager.Add(player, "Xp", amount)
	if not success then return end
	LevelService.CheckLevelUp(player)
end

function LevelService.GrantClickXp(player: Player)
	LevelService.GrantXp(player, LevelConfig.XpPerClick)
end

return LevelService
