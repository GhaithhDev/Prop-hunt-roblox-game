--[[
	RoundConfig

	Tunables for the round/game-loop system (RoundService). Same spirit as
	MorphConfigs/NotificationConfig - numbers and Studio-instance-name contracts
	live here instead of being hand-set in code.
]]

local RoundConfig = {}

RoundConfig.MinPlayers = 2
RoundConfig.LobbyCountdownDuration = 10
RoundConfig.HidePhaseDuration = 15
RoundConfig.RoundDuration = 180
RoundConfig.RoundEndDelay = 8

-- Tool names (must match Tool.Name under ServerStorage.RoundTools) given to
-- every Seeker at the start of the Active phase.
RoundConfig.DefaultGuns = { "Test Gun", "Test Gun2" }

-- ServerStorage folder/instance name contracts.
RoundConfig.MapsFolderName = "Maps"
RoundConfig.LobbyModelName = "Lobby"
RoundConfig.RoundToolsFolderName = "RoundTools"

-- Per-map marker-part folder names (optional per map - falls back to the map's
-- GetPivot() + a random offset if a map doesn't have these yet).
RoundConfig.HiderSpawnsFolderName = "HiderSpawns"
RoundConfig.SeekerSpawnsFolderName = "SeekerSpawns"

-- Marker instance name inside the Lobby model.
RoundConfig.LobbySpawnName = "LobbySpawn"

return RoundConfig
