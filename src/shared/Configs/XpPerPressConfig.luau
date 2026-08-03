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
		[8] = { StepAmount = 100, WinsRequired = 10_000 },
		[9] = { StepAmount = 150, WinsRequired = 50_000 },
		[10] = { StepAmount = 300, WinsRequired = 150_000 },
		[11] = { StepAmount = 450, WinsRequired = 500_000 },
		[12] = { StepAmount = 750, WinsRequired = 1_000_000 },
		[13] = { StepAmount = 1000, WinsRequired = 2_500_000 },
		[14] = { StepAmount = 1500, WinsRequired = 5_000_000 },
		[15] = { StepAmount = 2500, WinsRequired = 10_000_000 },
		[16] = { StepAmount = 5000, WinsRequired = 15_000_000 },
		[17] = { StepAmount = 10000, WinsRequired = 25_000_000 },
		[18] = { StepAmount = 25000, WinsRequired = 50_000_000 },
	},
	[2] = {
		[1] = { StepAmount = 10, WinsRequired = 0 },
		[2] = { StepAmount = 20, WinsRequired = 30 },
		[3] = { StepAmount = 50, WinsRequired = 150 },
		[4] = { StepAmount = 100, WinsRequired = 750 },
		[5] = { StepAmount = 250, WinsRequired = 2500 },
		[6] = { StepAmount = 500, WinsRequired = 10_000 },
		[7] = { StepAmount = 750, WinsRequired = 25_000 },
		[8] = { StepAmount = 1000, WinsRequired = 100_000 },
		[9] = { StepAmount = 1500, WinsRequired = 500_000 },
		[10] = { StepAmount = 3000, WinsRequired = 1_500_000 },
		[11] = { StepAmount = 4500, WinsRequired = 5_000_000 },
		[12] = { StepAmount = 7500, WinsRequired = 10_000_000 },
		[13] = { StepAmount = 10000, WinsRequired = 25_000_000 },
		[14] = { StepAmount = 15000, WinsRequired = 50_000_000 },
		[15] = { StepAmount = 25000, WinsRequired = 100_000_000 },
		[16] = { StepAmount = 50000, WinsRequired = 150_000_000 },
		[17] = { StepAmount = 100000, WinsRequired = 250_000_000 },
		[18] = { StepAmount = 250000, WinsRequired = 500_000_000 },
	},
	[3] = {
		[1] = { StepAmount = 100, WinsRequired = 0 },
		[2] = { StepAmount = 200, WinsRequired = 300 },
		[3] = { StepAmount = 500, WinsRequired = 1500 },
		[4] = { StepAmount = 1000, WinsRequired = 7500 },
		[5] = { StepAmount = 2500, WinsRequired = 25_000 },
		[6] = { StepAmount = 5000, WinsRequired = 100_000 },
		[7] = { StepAmount = 7500, WinsRequired = 250_000 },
		[8] = { StepAmount = 10000, WinsRequired = 1_000_000 },
		[9] = { StepAmount = 15000, WinsRequired = 5_000_000 },
		[10] = { StepAmount = 30000, WinsRequired = 15_000_000 },
		[11] = { StepAmount = 45000, WinsRequired = 50_000_000 },
		[12] = { StepAmount = 75000, WinsRequired = 100_000_000 },
		[13] = { StepAmount = 100000, WinsRequired = 250_000_000 },
		[14] = { StepAmount = 150000, WinsRequired = 500_000_000 },
		[15] = { StepAmount = 250000, WinsRequired = 1_000_000_000 },
		[16] = { StepAmount = 500000, WinsRequired = 1_500_000_000 },
		[17] = { StepAmount = 1000000, WinsRequired = 2_500_000_000 },
		[18] = { StepAmount = 2500000, WinsRequired = 5_000_000_000 },
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
