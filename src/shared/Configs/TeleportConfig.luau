export type StageEntry = {
	TeleportTo: number,
	WinsCost: number,
	UIcolor: Color3,
}

-- Each entry drives one auto-generated frame in the Teleport Stage menu (see
-- TeleportController.Start, which clones StageTemplateFrame once per entry)
-- and the matching server-side Wins price (see TeleportService).
--
-- TeleportTo: destination stage number - must match a
--   workspace.Functional.TeleportStages part AND a
--   MonetizationConfig.DevProducts.SkipToStage entry (for the Robux skip).
-- WinsCost: Wins price for the free/grind path.
-- UIcolor: background tint applied to the generated frame.
local Stages = {
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
}

-- Fixed, hand-placed positions to teleport a player back to (e.g. after a Win)
-- without relying on streamed-in Workspace parts like PlayerSpawners, which
-- aren't guaranteed to have streamed in yet under StreamingEnabled. Keyed by
-- world number - only World 1 exists so far.
local WorldTeleportPositions = {
	[1] = Vector3.new(0.555, 8.786, 87.534),
}

return {
	Stages = Stages,
	WorldTeleportPositions = WorldTeleportPositions,
}
