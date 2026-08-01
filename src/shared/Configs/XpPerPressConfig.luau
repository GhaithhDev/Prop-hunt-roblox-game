local XpPerPressConfig = {}

-- Matches the option parts under Workspace.Functional.XpPerPressOptions (named "1" through "8").
XpPerPressConfig.Options = {
	[1] = { StepAmount = 1, WinsRequired = 0 },
	[2] = { StepAmount = 2, WinsRequired = 3 },
	[3] = { StepAmount = 5, WinsRequired = 15 },
	[4] = { StepAmount = 10, WinsRequired = 100 },
	[5] = { StepAmount = 15, WinsRequired = 500 },
	[6] = { StepAmount = 20, WinsRequired = 2500 },
	[7] = { StepAmount = 25, WinsRequired = 10_000 },
	[8] = { StepAmount = 50, WinsRequired = 25_000 },
	[9] = { StepAmount = 75, WinsRequired = 100_000 },
	[10] = { StepAmount = 100, WinsRequired = 250_000 },

	[11] = { StepAmount = 150, WinsRequired = 500_000 },
	[12] = { StepAmount = 300, WinsRequired = 1_000_000 },
	[13] = { StepAmount = 600, WinsRequired = 5_000_000 },
	[14] = { StepAmount = 1000, WinsRequired = 10_000_000 },
	[15] = { StepAmount = 2500, WinsRequired = 25_000_000 },
	[16] = { StepAmount = 5000, WinsRequired = 50_000_000 },
	[17] = { StepAmount = 7500, WinsRequired = 75_000_000 },
	[18] = { StepAmount = 10_000, WinsRequired = 100_000_000 },
}

XpPerPressConfig.DefaultOption = 1

function XpPerPressConfig.GetStepAmount(optionIndex: number): number
	local option = XpPerPressConfig.Options[optionIndex]
	return option and option.StepAmount or XpPerPressConfig.Options[XpPerPressConfig.DefaultOption].StepAmount
end

function XpPerPressConfig.GetBestOptionForWins(wins: number): number
	local best = XpPerPressConfig.DefaultOption
	for index, option in XpPerPressConfig.Options do
		if wins >= option.WinsRequired and index > best then
			best = index
		end
	end
	return best
end

return XpPerPressConfig