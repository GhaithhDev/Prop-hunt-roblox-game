local UFOEventConfig = {}

-- How long a player must wait before this (or any) UFO will abduct them again.
UFOEventConfig.CooldownSeconds = 1

-- Matches the phase durations of the reference abduction sequence: the
-- player's character rises into the beam, holds while the reward VFX plays,
-- then lowers back down. Shared by server (reward timing) and client
-- (visual sequence) so they always agree.
UFOEventConfig.CharacterMovingUpDuration = 2
UFOEventConfig.ApplyingRewardDuration = 1
UFOEventConfig.CharacterMovingDownDuration = 0.5
UFOEventConfig.TotalSequenceDuration = UFOEventConfig.CharacterMovingUpDuration
	+ UFOEventConfig.ApplyingRewardDuration
	+ UFOEventConfig.CharacterMovingDownDuration

-- Per-world spawn area. Each world runs its own independent pool of UFOs
-- within its own Hub Ground bounds - World 1 keeps the original hand-picked
-- bounds; World 2/3 are placeholder (cloned from World 1) until real
-- per-world hub coordinates are provided, same "placeholder until real
-- numbers given" convention as WinsConfig/TeleportConfig's per-world tables.
-- SpawnHeight is the world Y every UFO in that world hovers at (hand-picked
-- in Studio); X/Z are randomized per spawn within that world's Min/Max bounds
-- (inset from the actual Ground part's edges so UFOs don't spawn inside
-- walls or other Hub landmarks). MaxConcurrentUFOs is how many UFOs are kept
-- active in that world's Hub at once while the event is on - whenever one is
-- used (or would otherwise be missing at Start), a replacement spawns
-- elsewhere in the same world to keep that world's pool topped up.
UFOEventConfig.Worlds = {
	[1] = {
		SpawnHeight = 31.09,
		SpawnAreaMinX = -52,
		SpawnAreaMaxX = 52,
		SpawnAreaMinZ = 12.698,
		SpawnAreaMaxZ = 171,
		MaxConcurrentUFOs = 5,
	},
	[2] = { 
		SpawnHeight = 31.09,
		SpawnAreaMinX = 3980,
		SpawnAreaMaxX = 4093,
		SpawnAreaMinZ = 12.698,
		SpawnAreaMaxZ = 171,
		MaxConcurrentUFOs = 5,
	},
	[3] = { 
		SpawnHeight = 31.09,
		SpawnAreaMinX = -4077.071,
		SpawnAreaMaxX = -3920.361,
		SpawnAreaMinZ = 12.698,
		SpawnAreaMaxZ = 171,
		MaxConcurrentUFOs = 5,
	},
}

-- Minimum X/Z distance kept between two active UFOs so spawns don't stack.
UFOEventConfig.MinSpawnSeparation = 50

-- Studs/second an unclaimed UFO drifts horizontally around the Hub at - stays
-- at SpawnHeight (Y never changes) and only within the spawn area bounds
-- above. Stops entirely the instant a UFO is claimed.
UFOEventConfig.WanderSpeed = 8

UFOEventConfig.BracketSize = 10
UFOEventConfig.MaxLevel = 150

-- Wins granted, keyed by the top level of each 10-level bracket. Anchored on
-- three hand-given values (10 -> 1,000, 20 -> 30,000, 100 -> 1,000,000) with a
-- decelerating curve filling in the rest, so max level doesn't blow up to an
-- absurd number.
UFOEventConfig.WinsByBracket = {
	[10] = 1_000,
	[20] = 30_000,
	[30] = 75_000,
	[40] = 150_000,
	[50] = 275_000,
	[60] = 450_000,
	[70] = 650_000,
	[80] = 800_000,
	[90] = 920_000,
	[100] = 1_000_000,
	[110] = 1_150_000,
	[120] = 1_350_000,
	[130] = 1_600_000,
	[140] = 1_900_000,
	[150] = 2_250_000,
}

function UFOEventConfig.GetWinsForLevel(level: number): number
	local bracketTop = math.ceil(math.max(level, 1) / UFOEventConfig.BracketSize) * UFOEventConfig.BracketSize
	bracketTop = math.min(bracketTop, UFOEventConfig.MaxLevel)
	return UFOEventConfig.WinsByBracket[bracketTop] or UFOEventConfig.WinsByBracket[UFOEventConfig.MaxLevel]
end

return UFOEventConfig
