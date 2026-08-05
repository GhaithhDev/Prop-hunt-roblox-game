local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local LevelConfig = require(ReplicatedStorage.Shared.Configs.LevelConfig)
local XpPerPress = require(ReplicatedStorage.Shared.Packages.XpPerPress)
local ShrinkService = require(ServerScriptService.Server.Shrink.ShrinkService)

local LevelService = {}

local MAX_LEVEL_UPS_PER_CALL = 2000

function LevelService.CheckLevelUp(player: Player)
	local currentLevel = DataManager.Get(player, "Level") or 1
	local currentShrink = DataManager.Get(player, "Shrink") or 0
	local newLevel = currentLevel
	local iterations = 0

	while currentShrink >= LevelConfig.GetXpRequiredForLevel(newLevel + 1) do
		newLevel += 1
		iterations += 1
		if iterations >= MAX_LEVEL_UPS_PER_CALL then
			warn(("LevelService.CheckLevelUp: hit iteration cap for %s at level %d"):format(player.Name, newLevel))
			break
		end
	end

	if newLevel ~= currentLevel then
		DataManager.Set(player, "Level", newLevel)
		ShrinkService.ResetCustomSize(player)
	end
end

function LevelService.GrantXp(player: Player, amount: number)
	local success = DataManager.Add(player, "Shrink", amount)
	if not success then return end
	LevelService.CheckLevelUp(player)
end

function LevelService.GrantClickXp(player: Player)
	LevelService.GrantXp(player, XpPerPress.GetAmountForPlayer(player))
end

function LevelService.ResetProgress(player: Player)
	DataManager.Set(player, "Level", 1)
	DataManager.Set(player, "Shrink", 0)
	ShrinkService.ResetCustomSize(player)
end

return LevelService
