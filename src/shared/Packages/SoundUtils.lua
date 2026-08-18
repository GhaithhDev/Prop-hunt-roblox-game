--[[
	SoundUtils

	PlayProximitySound creates a fresh, self-cleaning Part+Sound pair at a world
	position for every call (no caching/reuse) — so overlapping calls (e.g. two
	players triggering the same sound at once) layer as independent, overlapping
	playback instead of one shared instance retriggering and cutting the other off.

	PlayLocalSound plays a non-positional sound (e.g. a UI/feedback cue that
	should always be audible regardless of world position) the same
	overlap-safe way — cloning sourceSound into SoundService for every call
	instead of calling :Play() on one shared instance, which would cut off
	an already-playing copy if triggered again before it finishes.
]]

local SoundService = game:GetService("SoundService")

local SoundUtils = {}

function SoundUtils.PlayProximitySound(position: Vector3, soundId: string?, options: {
	RollOffMinDistance: number?,
	RollOffMaxDistance: number?,
	Volume: number?,
}?)
	if not soundId or soundId == "" then
		return
	end
	options = options or {}

	local part = Instance.new("Part")
	part.Name = "ProximitySound"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = options.RollOffMinDistance or 10
	sound.RollOffMaxDistance = options.RollOffMaxDistance or 150
	sound.Volume = options.Volume or 0.5
	sound.Parent = part
	sound:Play()

	sound.Ended:Once(function()
		part:Destroy()
	end)
end

function SoundUtils.PlayLocalSound(sourceSound: Sound?)
	if not sourceSound then
		return
	end

	local sound = sourceSound:Clone()
	sound.Parent = SoundService
	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

--[[
	PlayFromPart clones sourceSound and plays it parented to `part`, giving positional
	audio that follows a moving world part (e.g. a gun's Handle) while preserving the
	source Sound's own Volume/SoundGroup/RollOff settings - same overlap-safe
	clone-per-call pattern as the other functions here.
]]
function SoundUtils.PlayFromPart(sourceSound: Sound?, part: BasePart)
	if not sourceSound then
		return
	end

	local sound = sourceSound:Clone()
	sound.Parent = part
	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

return SoundUtils
