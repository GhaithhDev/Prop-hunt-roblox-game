local StageGates = {}

StageGates.LevelRequriements = {
    ["1"] = 5, --level 5 is needed for gate 1 to open
    ["2"] = 10,
    ["3"] = 15,
    ["4"] = 20
}

-- Returns nil for a stage name with no configured requirement - callers
-- should treat that as "stays closed" (fail-safe) rather than "always open".
function StageGates.GetRequiredLevelForStage(stageName: string): number?
    return StageGates.LevelRequriements[stageName]
end

return StageGates