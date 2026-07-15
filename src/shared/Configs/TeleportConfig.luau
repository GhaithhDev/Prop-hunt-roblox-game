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
return {
	{ TeleportTo = 2, WinsCost = 2, UIcolor = Color3.fromRGB(60, 245, 255) },
	{ TeleportTo = 3, WinsCost = 6, UIcolor = Color3.fromRGB(60, 255, 140) },
	{ TeleportTo = 4, WinsCost = 20, UIcolor = Color3.fromRGB(100, 255, 80) },
	{ TeleportTo = 5, WinsCost = 40, UIcolor = Color3.fromRGB(200, 255, 60) },
	{ TeleportTo = 6, WinsCost = 100, UIcolor = Color3.fromRGB(255, 200, 60) },
	{ TeleportTo = 7, WinsCost = 200, UIcolor = Color3.fromRGB(255, 140, 60) },
	{ TeleportTo = 8, WinsCost = 300, UIcolor = Color3.fromRGB(255, 80, 120) },
	{ TeleportTo = 9, WinsCost = 600, UIcolor = Color3.fromRGB(121, 22, 102) },
	{ TeleportTo = 10, WinsCost = 1000, UIcolor = Color3.fromRGB(60, 5, 34) },
}
