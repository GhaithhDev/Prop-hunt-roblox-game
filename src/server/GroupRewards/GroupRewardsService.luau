local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local GroupRewardsConfig = require(ReplicatedStorage.Shared.Configs.GroupRewardsConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local LevelService = require(ServerScriptService.Server.Level.LevelService)

local OWNED_CATEGORY = "GroupRewards"
local REWARD_ID = "GroupJoinLike"

local GroupRewardsService = {}

local function hasClaimed(player: Player): boolean
	return DataManager.Owns(player, OWNED_CATEGORY, REWARD_ID)
end

local function getStatus(player: Player)
	return {
		InGroup = player:IsInGroup(GroupRewardsConfig.GroupId),
		Claimed = hasClaimed(player),
	}
end

local function claimReward(player: Player)
	if hasClaimed(player) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "You've already claimed this reward!")
		return
	end
	if not player:IsInGroup(GroupRewardsConfig.GroupId) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Join the group first!")
		return
	end

	LevelService.GrantXp(player, GroupRewardsConfig.XpReward)
	DataManager.SetOwned(player, OWNED_CATEGORY, REWARD_ID, true)

	Net:RemoteEvent("Notify"):FireClient(player, "success", `+{NumberFormat.Format(GroupRewardsConfig.XpReward)} XP! Thanks for joining the group!`)
end

function GroupRewardsService.Start()
	if GroupRewardsConfig.GroupId == 0 then
		warn("GroupRewardsService: GroupId has a placeholder value (0) - replace it in GroupRewardsConfig before shipping")
	end

	Net:Handle("GetStatus", getStatus)
	Net:Handle("ClaimReward", claimReward)
end

return GroupRewardsService
