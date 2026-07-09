local XpPerPressConfig = {}

-- Matches the option parts under Workspace.Functional.XpPerPressOptions (named "1" through "8").
XpPerPressConfig.Options = {
	[1] = { StepAmount = 1, WinsRequired = 0 },
	[2] = { StepAmount = 2, WinsRequired = 3 },
	[3] = { StepAmount = 5, WinsRequired = 15 },
	[4] = { StepAmount = 25, WinsRequired = 100 },
	[5] = { StepAmount = 50, WinsRequired = 500 },
	[6] = { StepAmount = 100, WinsRequired = 2500 },
	[7] = { StepAmount = 250, WinsRequired = 15000 },
	[8] = { StepAmount = 500, WinsRequired = 50000 },
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