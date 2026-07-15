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
			Green = 3609493687,
			Blue = 3609494338,
			Purple = 3609494226,
			Red = 3609493720,
			Yellow = 3610057268
		},
		Auras = {
			Purple = 3609494603,
			Red = 3609494562,
			Yellow = 3609494511,
			Green = 3609494450,
			Blue = 3610059576
		},
		SpeedPass = {
        	Tier2 = 3610006200,
        	Tier4 = 3610006259,
        	Tier8 = 3610006311,
        	Tier16 = 3610006357,
    	},
    	WinsMultiplier = {
        	Double = 3610006417,
    	},
    	KeycapSounds = {
        	Unlock = 3610033745,
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
			["9"] = 3610013543,
			["10"] = 3610013603
		},

		ReviveToPreviousStage = 3609681251,

		XpBoost = {
			3609881067,
			3609881433,
			3609881495
		},

		ServerBoost = {
        	3610006541, --2x
        	3610006599, --4x
        	3610007385, -- 6x
        	3610007433, --8x
        	3610007469, --10x
    	},

		PlusPercentSpeed = {
			FirstOption = 3610053456,
			SecondOption = 3610053532,
			ThirdOption = 3610053582
		}
	},
}
