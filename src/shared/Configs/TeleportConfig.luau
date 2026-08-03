export type StageEntry = {
	TeleportTo: number,
	WinsCost: number,
	UIcolor: Color3,
}

-- Each entry drives one auto-generated frame in the Teleport Stage menu (see
-- TeleportController.Start, which clones StageTemplateFrame once per entry)
-- and the matching server-side Wins price (see TeleportService). Keyed by
-- World attribute, same convention as WinsConfig.WinsByWorld. World 1 is the
-- default/original world. World 2 and 3 are placeholder WinsCosts (World 1 *
-- 10 / * 100) until real per-world prices are provided.
--
-- TeleportTo: destination stage number - must match a
--   workspace.Functional.TeleportStages.WorldN part AND a
--   MonetizationConfig.DevProducts.SkipToStage entry (for the Robux skip,
--   shared/flat across worlds).
-- WinsCost: Wins price for the free/grind path.
-- UIcolor: background tint applied to the generated frame.
local TeleportConfig = {}

TeleportConfig.StagesByWorld = {
	[1] = {
		{ TeleportTo = 2, WinsCost = 3, UIcolor = Color3.fromRGB(60, 245, 255) },
		{ TeleportTo = 3, WinsCost = 10, UIcolor = Color3.fromRGB(60, 255, 140) },
		{ TeleportTo = 4, WinsCost = 20, UIcolor = Color3.fromRGB(100, 255, 80) },
		{ TeleportTo = 5, WinsCost = 50, UIcolor = Color3.fromRGB(200, 255, 60) },
		{ TeleportTo = 6, WinsCost = 100, UIcolor = Color3.fromRGB(255, 200, 60) },
		{ TeleportTo = 7, WinsCost = 150, UIcolor = Color3.fromRGB(255, 140, 60) },
		{ TeleportTo = 8, WinsCost = 300, UIcolor = Color3.fromRGB(255, 80, 120) },
		{ TeleportTo = 9, WinsCost = 500, UIcolor = Color3.fromRGB(121, 22, 102) },
		{ TeleportTo = 10, WinsCost = 1000, UIcolor = Color3.fromRGB(60, 5, 34) },
		{ TeleportTo = 11, WinsCost = 2500, UIcolor = Color3.fromRGB(60, 53, 26) },
		{ TeleportTo = 12, WinsCost = 10000, UIcolor = Color3.fromRGB(148, 125, 34) },
		{ TeleportTo = 13, WinsCost = 25000, UIcolor = Color3.fromRGB(192, 158, 22) },
		{ TeleportTo = 14, WinsCost = 50000, UIcolor = Color3.fromRGB(255, 204, 0) },
		{ TeleportTo = 15, WinsCost = 150000, UIcolor = Color3.fromRGB(250, 115, 144) },
		{ TeleportTo = 16, WinsCost = 250000, UIcolor = Color3.fromRGB(245, 81, 116) },
		{ TeleportTo = 17, WinsCost = 500000, UIcolor = Color3.fromRGB(248, 33, 80) },
		{ TeleportTo = 18, WinsCost = 1000000, UIcolor = Color3.fromRGB(63, 90, 148) },
		{ TeleportTo = 19, WinsCost = 2000000, UIcolor = Color3.fromRGB(30, 66, 143) },
		{ TeleportTo = 20, WinsCost = 4000000, UIcolor = Color3.fromRGB(3, 47, 141) },
	},
	[2] = {
		{ TeleportTo = 2, WinsCost = 30, UIcolor = Color3.fromRGB(60, 245, 255) },
		{ TeleportTo = 3, WinsCost = 100, UIcolor = Color3.fromRGB(60, 255, 140) },
		{ TeleportTo = 4, WinsCost = 200, UIcolor = Color3.fromRGB(100, 255, 80) },
		{ TeleportTo = 5, WinsCost = 500, UIcolor = Color3.fromRGB(200, 255, 60) },
		{ TeleportTo = 6, WinsCost = 1000, UIcolor = Color3.fromRGB(255, 200, 60) },
		{ TeleportTo = 7, WinsCost = 1500, UIcolor = Color3.fromRGB(255, 140, 60) },
		{ TeleportTo = 8, WinsCost = 3000, UIcolor = Color3.fromRGB(255, 80, 120) },
		{ TeleportTo = 9, WinsCost = 5000, UIcolor = Color3.fromRGB(121, 22, 102) },
		{ TeleportTo = 10, WinsCost = 10000, UIcolor = Color3.fromRGB(60, 5, 34) },
		{ TeleportTo = 11, WinsCost = 25000, UIcolor = Color3.fromRGB(60, 53, 26) },
		{ TeleportTo = 12, WinsCost = 100000, UIcolor = Color3.fromRGB(148, 125, 34) },
		{ TeleportTo = 13, WinsCost = 250000, UIcolor = Color3.fromRGB(192, 158, 22) },
		{ TeleportTo = 14, WinsCost = 500000, UIcolor = Color3.fromRGB(255, 204, 0) },
		{ TeleportTo = 15, WinsCost = 1500000, UIcolor = Color3.fromRGB(250, 115, 144) },
		{ TeleportTo = 16, WinsCost = 2500000, UIcolor = Color3.fromRGB(245, 81, 116) },
		{ TeleportTo = 17, WinsCost = 5000000, UIcolor = Color3.fromRGB(248, 33, 80) },
		{ TeleportTo = 18, WinsCost = 10000000, UIcolor = Color3.fromRGB(63, 90, 148) },
		{ TeleportTo = 19, WinsCost = 20000000, UIcolor = Color3.fromRGB(30, 66, 143) },
		{ TeleportTo = 20, WinsCost = 40000000, UIcolor = Color3.fromRGB(3, 47, 141) },
	},
	[3] = {
		{ TeleportTo = 2, WinsCost = 300, UIcolor = Color3.fromRGB(60, 245, 255) },
		{ TeleportTo = 3, WinsCost = 1000, UIcolor = Color3.fromRGB(60, 255, 140) },
		{ TeleportTo = 4, WinsCost = 2000, UIcolor = Color3.fromRGB(100, 255, 80) },
		{ TeleportTo = 5, WinsCost = 5000, UIcolor = Color3.fromRGB(200, 255, 60) },
		{ TeleportTo = 6, WinsCost = 10000, UIcolor = Color3.fromRGB(255, 200, 60) },
		{ TeleportTo = 7, WinsCost = 15000, UIcolor = Color3.fromRGB(255, 140, 60) },
		{ TeleportTo = 8, WinsCost = 30000, UIcolor = Color3.fromRGB(255, 80, 120) },
		{ TeleportTo = 9, WinsCost = 50000, UIcolor = Color3.fromRGB(121, 22, 102) },
		{ TeleportTo = 10, WinsCost = 100000, UIcolor = Color3.fromRGB(60, 5, 34) },
		{ TeleportTo = 11, WinsCost = 250000, UIcolor = Color3.fromRGB(60, 53, 26) },
		{ TeleportTo = 12, WinsCost = 1000000, UIcolor = Color3.fromRGB(148, 125, 34) },
		{ TeleportTo = 13, WinsCost = 2500000, UIcolor = Color3.fromRGB(192, 158, 22) },
		{ TeleportTo = 14, WinsCost = 5000000, UIcolor = Color3.fromRGB(255, 204, 0) },
		{ TeleportTo = 15, WinsCost = 15000000, UIcolor = Color3.fromRGB(250, 115, 144) },
		{ TeleportTo = 16, WinsCost = 25000000, UIcolor = Color3.fromRGB(245, 81, 116) },
		{ TeleportTo = 17, WinsCost = 50000000, UIcolor = Color3.fromRGB(248, 33, 80) },
		{ TeleportTo = 18, WinsCost = 100000000, UIcolor = Color3.fromRGB(63, 90, 148) },
		{ TeleportTo = 19, WinsCost = 200000000, UIcolor = Color3.fromRGB(30, 66, 143) },
		{ TeleportTo = 20, WinsCost = 400000000, UIcolor = Color3.fromRGB(3, 47, 141) },
	},
}

function TeleportConfig.GetStageConfig(stageNumber: number, world: number?): StageEntry?
	local worldNum = (world and tonumber(world)) or 1
	local stages = TeleportConfig.StagesByWorld[worldNum] or TeleportConfig.StagesByWorld[1]
	for _, item in stages do
		if item.TeleportTo == stageNumber then
			return item
		end
	end
	return nil
end

-- Fixed, hand-placed positions to teleport a player back to (e.g. after a Win)
-- without relying on streamed-in Workspace parts like PlayerSpawners, which
-- aren't guaranteed to have streamed in yet under StreamingEnabled. Keyed by
-- world number - only World 1 exists so far.
TeleportConfig.WorldTeleportPositions = {
	[1] = Vector3.new(0.555, 8.786, 87.534),
}

return TeleportConfig
