local WinsConfig = {}

-- Placeholder values (stage * 100) until real per-stage rewards are provided.
WinsConfig.WinsByStage = {
	[1] = 1,
	[2] = 3,
	[3] = 10,
	[4] = 20,
	[5] = 50,
	[6] = 100,
	[7] = 150,
	[8] = 300,
	[9] = 500,
	[10] = 1000,
	[11] = 2500,
	[12] = 10000,
	[13] = 25000,
	[14] = 50000,
	[15] = 150000,
	[16] = 250000,
	[17] = 500000,
	[18] = 1000000,
	[19] = 2000000,
	[20] = 4000000,
}

function WinsConfig.GetWinsForStage(stage: number): number?
	return WinsConfig.WinsByStage[stage] or WinsConfig.WinsByStage[tonumber(stage)]
end

return WinsConfig
