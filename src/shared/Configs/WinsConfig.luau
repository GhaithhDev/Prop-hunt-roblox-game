local WinsConfig = {}

-- Wins-per-stage tables, keyed by World attribute. World 1 is the default/original
-- world. World 2 and 3 are placeholder values (World 1 * 10 / * 100) until real
-- per-world rewards are provided.
WinsConfig.WinsByWorld = {
	[1] = {
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
	},
	[2] = {
		[1] = 10,
		[2] = 30,
		[3] = 100,
		[4] = 200,
		[5] = 500,
		[6] = 1000,
		[7] = 1500,
		[8] = 3000,
		[9] = 5000,
		[10] = 10000,
		[11] = 25000,
		[12] = 100000,
		[13] = 250000,
		[14] = 500000,
		[15] = 1500000,
		[16] = 2500000,
		[17] = 5000000,
		[18] = 10000000,
		[19] = 20000000,
		[20] = 40000000,
	},
	[3] = {
		[1] = 100,
		[2] = 300,
		[3] = 1000,
		[4] = 2000,
		[5] = 5000,
		[6] = 10000,
		[7] = 15000,
		[8] = 30000,
		[9] = 50000,
		[10] = 100000,
		[11] = 250000,
		[12] = 1000000,
		[13] = 2500000,
		[14] = 5000000,
		[15] = 15000000,
		[16] = 25000000,
		[17] = 50000000,
		[18] = 100000000,
		[19] = 200000000,
		[20] = 400000000,
	},
}

function WinsConfig.GetWinsForStage(stage: number, world: number?): number?
	local worldNum = (world and tonumber(world)) or 1
	local stageTable = WinsConfig.WinsByWorld[worldNum] or WinsConfig.WinsByWorld[1]
	return stageTable[stage] or stageTable[tonumber(stage)]
end

return WinsConfig
