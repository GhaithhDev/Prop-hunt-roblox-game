local WinsConfig = {}

-- Placeholder values (stage * 100) until real per-stage rewards are provided.
WinsConfig.WinsByStage = {
	[1] = 1,
	[2] = 3,
	[3] = 10,
	[4] = 100,
	[5] = 500,
	[6] = 600,
	[7] = 700,
	[8] = 800,
	[9] = 900,
	[10] = 1000,
	[11] = 1100,
	[12] = 1200,
	[13] = 1300,
}

function WinsConfig.GetWinsForStage(stage: number): number?
	return WinsConfig.WinsByStage[stage]
end

return WinsConfig
