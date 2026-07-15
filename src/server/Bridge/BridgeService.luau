--[[
	BridgeService

	Repeating disappearing-platform hazard on Workspace.Functional.Bridge:
	a countdown plays (Timer's PhaseStartTime attribute lets clients derive
	the display locally, see BridgeController), then whatever's sitting in
	IncludeInFadeOut - recomputed fresh every cycle, not cached - fades out
	via ReplicatedTween (still walkable while fading), goes fully intangible
	(and any SurfaceGui on a target part is hidden too) for a stretch, then
	restores and the countdown starts again. Player characters are always
	excluded from the fade/uncollide set - only the bridge geometry itself
	disappears, so a standing player just falls through once it's gone
	rather than fading away themselves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BridgeConfig = require(ReplicatedStorage.Shared.Configs.BridgeConfig)
local ReplicatedTween = require(ReplicatedStorage.Shared.Modules.ReplicatedTween)

local BridgeService = {}

local function collectFadeTargets(includeZone: BasePart): { BasePart }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { includeZone }

	local parts = workspace:GetPartsInPart(includeZone, params)
	local targets = {}
	for _, part in parts do
		local charModel = part:FindFirstAncestorOfClass("Model")
		local isCharacterPart = charModel and Players:GetPlayerFromCharacter(charModel)
		-- Already-transparent parts have nothing to fade/restore - skip them
		-- entirely rather than tweening a 1 -> 1 no-op.
		if not isCharacterPart and part.Transparency < 1 then
			table.insert(targets, part)
		end
	end
	return targets
end

local function findTextLabels(gui: Instance): { TextLabel }
	local labels = {}
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("TextLabel") then
			table.insert(labels, descendant)
		end
	end
	return labels
end

local function runCycle(bridge: Folder, includeZone: BasePart)
	while true do
		bridge:SetAttribute("PhaseStartTime", Workspace:GetServerTimeNow())
		task.wait(BridgeConfig.CountdownDuration)

		local targets = collectFadeTargets(includeZone)
		local originalState: {
			[BasePart]: {
				Transparency: number,
				CanCollide: boolean,
				SurfaceGui: SurfaceGui?,
				GuiEnabled: boolean?,
				LabelTransparency: { [TextLabel]: number },
			},
		} = {}
		for _, part in targets do
			local surfaceGui = part:FindFirstChildOfClass("SurfaceGui")
			local labelTransparency = {}

			if surfaceGui then
				for _, label in findTextLabels(surfaceGui) do
					labelTransparency[label] = label.TextTransparency
					ReplicatedTween.Tween(
						label,
						TweenInfo.new(BridgeConfig.FadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false),
						{ TextTransparency = 1 }
					)
				end
			end

			originalState[part] = {
				Transparency = part.Transparency,
				CanCollide = part.CanCollide,
				SurfaceGui = surfaceGui,
				GuiEnabled = surfaceGui and surfaceGui.Enabled,
				LabelTransparency = labelTransparency,
			}
			ReplicatedTween.Tween(
				part,
				TweenInfo.new(BridgeConfig.FadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false),
				{ Transparency = 1 }
			)
		end
		task.wait(BridgeConfig.FadeDuration)

		for _, part in targets do
			part.CanCollide = false
			local surfaceGui = originalState[part].SurfaceGui
			if surfaceGui then
				surfaceGui.Enabled = false
			end
		end
		task.wait(BridgeConfig.GoneDuration)

		for _, part in targets do
			local original = originalState[part]
			part.Transparency = original.Transparency
			part.CanCollide = original.CanCollide
			if original.SurfaceGui then
				original.SurfaceGui.Enabled = original.GuiEnabled :: boolean
			end
			for label, transparency in original.LabelTransparency do
				label.TextTransparency = transparency
			end
		end
	end
end

function BridgeService.Start()
	local bridge = workspace.Functional:FindFirstChild("Bridge")
	if not bridge then
		warn("BridgeService: Workspace.Functional.Bridge not found - skipping")
		return
	end

	local includeZone = bridge:FindFirstChild("IncludeInFadeOut")
	if not includeZone or not includeZone:IsA("BasePart") then
		warn("BridgeService: Bridge.IncludeInFadeOut is missing or not a BasePart - skipping")
		return
	end

	task.spawn(runCycle, bridge, includeZone)
end

return BridgeService
