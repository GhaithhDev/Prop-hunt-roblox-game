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
			Gold = 3621711302,
			Diamond = 3621708551,
			Zombie = 3621709875,
			Admin = 3621712968,
		},
		Trails = {
			Green = 3621788392,
			Blue = 3621782984,
			Purple = 3621785544,
			Red = 3621784570,
			Yellow = 3621790259
		},
		Auras = {
			Purple = 3621773060,
			Red = 3621775198,
			Yellow = 3621777713,
			Green = 3621776370,
			Blue = 3621772009
		},
		ShrinkPass = {
        	Tier2 = 3621750917,
        	Tier4 = 3621752244,
        	Tier8 = 3621753744,
        	Tier16 = 3621754687,
    	},
    	WinsMultiplier = {
        	Double = 3621749953,
    	},
    	KeycapSounds = {
        	Unlock = 3621769877,
    	},
	},

	DevProducts = {
		RebirthSkip = 3621764754,
		
		SkipToStage = {
			["2"] = 3621718277,
			["3"] = 3621718936, 
			["4"] = 3621719795,
			["5"] = 3621720909,
			["6"] = 3621721877,
			["7"] = 3621722750,
			["8"] = 3621723722,
			["9"] = 3621725229,
			["10"] = 3621726765,

			["11"] = 3621728256,
			["12"] = 3621729024, 
			["13"] = 3621729778,
			["14"] = 3621730531,
			["15"] = 3621731348,
			["16"] = 3621732104,
			["17"] = 3621732971,
			["18"] = 3621733966,
			["19"] = 3621735576,
			["20"] = 3621736418
		},

		XpBoost = {
			3621737238, --10 minutes
			3621741924, --30 minutes
			3621742999 --60 minutes
		},

		ServerBoost = {
        	3621757001, --2x
        	3621758065, --4x
        	3621758941, -- 6x
        	3621760068, --8x
        	3621760864, --10x
    	},

		PlusPercentShrink = {
			FirstOption = 3621766654,
			SecondOption = 3621767360,
			ThirdOption = 3621768409
		},

		x2Win = 3611329999
	},
}
