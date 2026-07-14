return {
	Wins = {
		WinAwarded = { Name = "WinAwarded", Type = "Event" },
	},

	Speed = {
		SetCustomSpeed = { Name = "SetCustomSpeed", Type = "Event" },
	},

	Treadmill = {
		ToggleSpawn = { Name = "ToggleSpawn", Type = "Event" },
	},

	Notifications = {
		Notify = { Name = "Notify", Type = "Event" },
	},

	Monetization = {
		ShowPurchaseLoading = { Name = "ShowPurchaseLoading", Type = "Event" },
	},

	GroupRewards = {
		GetStatus = { Name = "GetStatus", Type = "Function" },
		-- Function (not Event) so the client can await completion before
		-- refreshing status - same reasoning as Rebirth/Inventory's remotes.
		ClaimReward = { Name = "ClaimReward", Type = "Function" },
	},

	Rebirth = {
		GetRebirthStatus = { Name = "GetRebirthStatus", Type = "Function" },
		-- Function (not Event) so the client can await completion before
		-- refreshing status - same reasoning as Inventory's BuyWithWins/EquipItem.
		PerformRebirth = { Name = "PerformRebirth", Type = "Function" },
		RequestSkipRebirth = { Name = "RequestSkipRebirth", Type = "Event" },
	},

	Teleport = {
		RequestWinsTeleport = { Name = "RequestWinsTeleport", Type = "Event" },
		RequestRobuxTeleport = { Name = "RequestRobuxTeleport", Type = "Event" },
	},

	Inventory = {
		GetInventoryStatus = { Name = "GetInventoryStatus", Type = "Function" },
		-- BuyWithWins/EquipItem are Functions (not Events) so the client can
		-- await server completion before refreshing status - an Event fired
		-- right before a status refresh isn't guaranteed to have finished
		-- processing yet.
		BuyWithWins = { Name = "BuyWithWins", Type = "Function" },
		RequestRobuxPurchase = { Name = "RequestRobuxPurchase", Type = "Event" },
		EquipItem = { Name = "EquipItem", Type = "Function" },
	},

	Death = {
		ShowRevivePopup = { Name = "ShowRevivePopup", Type = "Event" },
		RequestRevive = { Name = "RequestRevive", Type = "Event" },
	},

	Animations = {
		PlayAnimation = { Name = "PlayAnimation", Type = "Event" },
		StopAnimation = { Name = "StopAnimation", Type = "Event" },
		ResumeAnimation = { Name = "ResumeAnimation", Type = "Event" },
	},

	Shop = {
		RequestXpBoost = { Name = "RequestXpBoost", Type = "Event" },
		RequestGamePassPurchase = { Name = "RequestGamePassPurchase", Type = "Event" },
		-- Function (not Event) so the client can await the answer before
		-- marking Treadmill tiles owned - same reasoning as Inventory's
		-- GetInventoryStatus.
		GetShopStatus = { Name = "GetShopStatus", Type = "Function" },
		RequestServerBoost = { Name = "RequestServerBoost", Type = "Event" },
	},
}