-- GamePasses: permanent one-time unlocks (ownership-tracked, idempotent).
-- Names must be globally unique across all GamePasses categories - they all
-- write into the same flat DataManager "OwnedPasses" store.

-- DevProducts: repeatable/consumable purchases, fulfilled dynamically via
-- MonetizationService.RegisterConsumable by whichever feature owns them.

-- PLACEHOLDER ProductIds (0) - replace with real Developer Product IDs from
-- the Creator Dashboard. MonetizationService.Start() warns loudly for any
-- entry still at 0.
return {
	GamePasses = {
		Treadmills = {
			Gold = 3609493313,
			Diamond = 3609298248,
			Zombie = 3609493357,
			Admin = 3609493388,
		},
		Trails = {
			Ember = 3609493687,
			Frost = 3609493720,
			Toxic = 3609494226,
			Void = 3609494338,
		},
		Auras = {
			Spark = 3609494450,
			Glow = 3609494511,
			Storm = 3609494562,
			Radiant = 3609494603,
		},
	},

	DevProducts = {
		RebirthSkip = 3609494646,
		
		SkipToStage = {
			["2"] = 3609491513,
			["3"] = 3609491647, 
			["4"] = 3609492814,
			["5"] = 3609493005,
			["6"] = 3609493035,
			["7"] = 3609493067,
			["8"] = 3609493093,
		},

		ReviveToPreviousStage = 3609681251,

		XpBoost = {
			3609881067,
			3609881433,
			3609881495
		}
	},
}
