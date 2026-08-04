local StageGates = {}

-- Keyed by World number, same convention as TeleportConfig.StagesByWorld.
-- World2/3 are placeholder requirements (World1 * 10 / * 100), same
-- placeholder-scaling convention TeleportConfig used for WinsCost, until
-- real per-world numbers are provided.
StageGates.LevelRequirementsByWorld = {
	[1] = {
		["1"] = 5, --level 5 is needed for gate 1 to open
		["2"] = 10,
		["3"] = 15,
		["4"] = 20,
		["5"] = 40,
		["6"] = 50,
		["7"] = 75,
		["8"] = 100,
		["9"] = 125,
		["10"] = 150,
		["11"] = 175,
		["12"] = 200,
		["13"] = 225,
		["14"] = 250,
		["15"] = 275,
		["16"] = 300,
		["17"] = 325,
		["18"] = 350,
		["19"] = 375,
		["20"] = 400,
	},
	[2] = {
		["1"] = 1,
		["2"] = 425,
		["3"] = 450,
		["4"] = 475,
		["5"] = 500,
		["6"] = 525,
		["7"] = 550,
		["8"] = 575,
		["9"] = 600,
		["10"] = 625,
		["11"] = 650,
		["12"] = 675,
		["13"] = 700,
		["14"] = 725,
		["15"] = 750,
		["16"] = 775,
		["17"] = 800,
		["18"] = 825,
		["19"] = 850,
		["20"] = 875,
	},
	[3] = {
		["1"] = 1,
		["2"] = 900,
		["3"] = 925,
		["4"] = 950,
		["5"] = 975,
		["6"] = 1000,
		["7"] = 1025,
		["8"] = 1050,
		["9"] = 1100,
		["10"] = 1150,
		["11"] = 1200,
		["12"] = 1250,
		["13"] = 1300,
		["14"] = 1350,
		["15"] = 1400,
		["16"] = 1450,
		["17"] = 1500,
		["18"] = 1600,
		["19"] = 1700,
		["20"] = 1800,
	},
}

-- Returns nil for a stage name with no configured requirement - callers
-- should treat that as "stays closed" (fail-safe) rather than "always open".
-- Falls back to World1's table if the given world has no requirements configured.
function StageGates.GetRequiredLevelForStage(stageName: string, world: number?): number?
	local worldNum = (world and tonumber(world)) or 1
	local requirements = StageGates.LevelRequirementsByWorld[worldNum] or StageGates.LevelRequirementsByWorld[1]
	return requirements[stageName]
end

return StageGates
