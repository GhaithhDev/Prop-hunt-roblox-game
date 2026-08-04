local XpPerPressConfig = {}

-- Matches the option parts under Workspace.Functional.XpPerPressOptions (named "1" through "8"
-- per world). Keyed by World attribute, same convention as WinsConfig.WinsByWorld. World 1 is
-- the default/original world. World 2 and 3 are placeholder values (World 1 * 10 / * 100) until
-- real per-world rewards are provided.
XpPerPressConfig.OptionsByWorld = {
	[1] = {
		[1] = { StepAmount = 1, WinsRequired = 0 },
		[2] = { StepAmount = 2, WinsRequired = 3 },
		[3] = { StepAmount = 5, WinsRequired = 15 },
		[4] = { StepAmount = 10, WinsRequired = 75 },
		[5] = { StepAmount = 25, WinsRequired = 250 },
		[6] = { StepAmount = 50, WinsRequired = 1000 },
		[7] = { StepAmount = 75, WinsRequired = 2500 },
		[8] = { StepAmount = 100, WinsRequired = 7_500 },
		[9] = { StepAmount = 150, WinsRequired = 20_000 },
		[10] = { StepAmount = 300, WinsRequired = 50_000 },
		[11] = { StepAmount = 350, WinsRequired = 100_000 },
		[12] = { StepAmount = 400, WinsRequired = 250_000 },
		[13] = { StepAmount = 500, WinsRequired = 500_000 },
		[14] = { StepAmount = 600, WinsRequired = 750_000 },
		[15] = { StepAmount = 700, WinsRequired = 1_000_000 },
		[16] = { StepAmount = 800, WinsRequired = 2_000_000 },
		[17] = { StepAmount = 900, WinsRequired = 3_000_000 },
		[18] = { StepAmount = 1000,WinsRequired = 3_500_000 },
	},
	[2] = {
		[1] = { StepAmount = 1500, WinsRequired = 0 },
		[2] = { StepAmount = 1750, WinsRequired = 4_000_000 },
		[3] = { StepAmount = 2000, WinsRequired = 10_000_000 },
		[4] = { StepAmount = 2250, WinsRequired = 15_000_000 },
		[5] = { StepAmount = 2500, WinsRequired = 25_000_000 },
		[6] = { StepAmount = 3000, WinsRequired = 45_000_000 },
		[7] = { StepAmount = 3500, WinsRequired = 65_000_000 },
		[8] = { StepAmount = 4000, WinsRequired = 80_000_000 },
		[9] = { StepAmount = 4500, WinsRequired = 100_000_000 },
		[10] = { StepAmount = 5000, WinsRequired = 150_000_000 },
		[11] = { StepAmount = 5500, WinsRequired = 200_000_000 },
		[12] = { StepAmount = 6000, WinsRequired = 250_000_000 },
		[13] = { StepAmount = 7500, WinsRequired =300_000_000 },
		[14] = { StepAmount = 8000, WinsRequired = 350_000_000 },
		[15] = { StepAmount = 8500, WinsRequired = 400_000_000 },
		[16] = { StepAmount = 9000, WinsRequired = 450_000_000 },
		[17] = { StepAmount = 9500, WinsRequired = 500_000_000 },
		[18] = { StepAmount = 10000, WinsRequired = 750_000_000 },
	},
	[3] = {
		[1] = { StepAmount = 20000, WinsRequired = 0 },
		[2] = { StepAmount = 25000, WinsRequired = 1_000_000_000 },
		[3] = { StepAmount = 30000, WinsRequired = 2_500_000_000 },
		[4] = { StepAmount = 35000, WinsRequired = 5_000_000_000 },
		[5] = { StepAmount = 40000, WinsRequired = 10_000_000_000 },
		[6] = { StepAmount = 45000, WinsRequired = 15_000_000_000 },
		[7] = { StepAmount = 50000, WinsRequired = 25_000_000_000 },
		[8] = { StepAmount = 55000, WinsRequired = 35_000_000_000 },
		[9] = { StepAmount = 60000, WinsRequired = 50_000_000_000 },
		[10] = { StepAmount = 70000, WinsRequired = 75_000_000_000 },
		[11] = { StepAmount = 80_000, WinsRequired = 100_000_000_000 },
		[12] = { StepAmount = 90_000, WinsRequired = 150_000_000_000 },
		[13] = { StepAmount = 100_000, WinsRequired = 200_000_000_000 },
		[14] = { StepAmount = 125_000, WinsRequired = 250_000_000_000 },
		[15] = { StepAmount = 150_000, WinsRequired = 500_000_000_000 },
		[16] = { StepAmount = 175_000, WinsRequired = 750_000_000_000 },
		[17] = { StepAmount = 200_000, WinsRequired = 1_000_000_000_000 },
		[18] = { StepAmount = 225_000, WinsRequired = 1_250_000_000_000 },
	},
}

XpPerPressConfig.DefaultOption = 1

function XpPerPressConfig.GetOption(optionIndex: number, world: number?): { StepAmount: number, WinsRequired: number }?
	local worldNum = (world and tonumber(world)) or 1
	local optionsTable = XpPerPressConfig.OptionsByWorld[worldNum] or XpPerPressConfig.OptionsByWorld[1]
	return optionsTable[optionIndex] or optionsTable[tonumber(optionIndex)]
end

function XpPerPressConfig.GetStepAmount(optionIndex: number, world: number?): number
	local option = XpPerPressConfig.GetOption(optionIndex, world)
	if option then
		return option.StepAmount
	end
	local defaultOption = XpPerPressConfig.GetOption(XpPerPressConfig.DefaultOption, world)
	assert(defaultOption, "XpPerPressConfig: DefaultOption is missing from the resolved options table")
	return defaultOption.StepAmount
end

function XpPerPressConfig.GetBestOptionForWins(wins: number, world: number?): number
	local worldNum = (world and tonumber(world)) or 1
	local optionsTable = XpPerPressConfig.OptionsByWorld[worldNum] or XpPerPressConfig.OptionsByWorld[1]

	local best = XpPerPressConfig.DefaultOption
	for index, option in optionsTable do
		if wins >= option.WinsRequired and index > best then
			best = index
		end
	end
	return best
end

return XpPerPressConfig
