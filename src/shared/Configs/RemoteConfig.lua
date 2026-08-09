return {
	Notifications = {
		Notify = { Name = "Notify", Type = "Event" },
	},

	Monetization = {
		ShowPurchaseLoading = { Name = "ShowPurchaseLoading", Type = "Event" },
	},

	GroupRewards = {
		GetStatus = { Name = "GetStatus", Type = "Function" },
		-- Function (not Event) so the client can await completion before
		-- refreshing status.
		ClaimReward = { Name = "ClaimReward", Type = "Function" },
	},

	Animations = {
		PlayAnimation = { Name = "PlayAnimation", Type = "Event" },
		StopAnimation = { Name = "StopAnimation", Type = "Event" },
		ResumeAnimation = { Name = "ResumeAnimation", Type = "Event" },
	},

	UIEffects = {
		FlashWhiteScreen = { Name = "FlashWhiteScreen", Type = "Event" },
	},

	Morph = {
		RequestMorph = { Name = "RequestMorph", Type = "Event" },
		RequestUnmorph = { Name = "RequestUnmorph", Type = "Event" },
	},
}