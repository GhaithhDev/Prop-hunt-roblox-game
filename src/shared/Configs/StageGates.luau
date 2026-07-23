local StageGates = {}

StageGates.LevelRequriements = {
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
   
}

-- Returns nil for a stage name with no configured requirement - callers
-- should treat that as "stays closed" (fail-safe) rather than "always open".
function StageGates.GetRequiredLevelForStage(stageName: string): number?
    return StageGates.LevelRequriements[stageName]
end

return StageGates