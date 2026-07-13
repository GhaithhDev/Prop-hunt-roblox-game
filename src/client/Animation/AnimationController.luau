--[[
	AnimationController

	The only place in the codebase allowed to call Animator:LoadAnimation.
	Other client Controllers call AnimationController.Play(...) directly (no
	remote round-trip needed, already client-side); server Services go through
	AnimationService, which just relays the request here over a remote — both
	paths converge on this same Play function, so there's one source of truth
	for how animations actually get played.
]]

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local AnimationsConfig = require(ReplicatedStorage.Shared.Configs.Animations.AnimationsConfig)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local AnimationController = {}
local loadedTracks = {} -- [Animator] = { [animationName] = AnimationTrack }
local markerRegistrations = {} -- [animationName] = { {markerName, callback}, ... }

-- Waits (bounded) rather than giving up instantly - a just-spawned NPC's
-- Humanoid/Animator can still be mid-replication when the very first
-- Play/Resume remote for it arrives, especially right after PathfindingAgent
-- parents a freshly cloned model.
local function getAnimator(character: Model?): Animator?
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then return nil end
	return humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
end

-- Registers a callback fired whenever ANY character's track for animationName crosses
-- markerName. Runs on every client independently (including bystanders watching someone
-- else's animation) since it's wired at track-creation time, not per-Play-call — see getTrack.
function AnimationController.OnMarkerReached(animationName: string, markerName: string, callback: (character: Model, ...any) -> ())
	local registrations = markerRegistrations[animationName]
	if not registrations then
		registrations = {}
		markerRegistrations[animationName] = registrations
	end
	table.insert(registrations, { markerName = markerName, callback = callback })
end

-- Lazily creates an animator's track cache, wired to self-clean when the
-- animator is destroyed (otherwise every destroyed NPC's loaded tracks would
-- leak forever, given how often this codebase destroys zombies/customers).
local function getCache(animator: Animator)
	local cache = loadedTracks[animator]
	if not cache then
		cache = {}
		loadedTracks[animator] = cache
		animator.Destroying:Connect(function()
			loadedTracks[animator] = nil
		end)
	end
	return cache
end

local function getTrack(animator: Animator, animationName: string): AnimationTrack?
	local cache = getCache(animator)

	local track = cache[animationName]
	if track then
		return track
	end

	local animationId = AnimationsConfig[animationName]
	if not animationId or animationId == "" then
		warn("AnimationController: no animation configured for", animationName)
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	track = animator:LoadAnimation(animation)
	cache[animationName] = track

	local registrations = markerRegistrations[animationName]
	if registrations then
		local humanoid = animator.Parent :: Humanoid?
		local character = humanoid and humanoid.Parent
		for _, registration in registrations do
			track:GetMarkerReachedSignal(registration.markerName):Connect(function(...)
				registration.callback(character, ...)
			end)
		end
	end

	return track
end

function AnimationController.Play(
	character: Model?,
	animationName: string,
	looped: boolean?,
	priority: Enum.AnimationPriority?,
	fadeTime: number?,
	weight: number?,
	speed: number?
): AnimationTrack?
	-- character can arrive nil over a remote if the Instance itself hadn't
	-- replicated to this client yet at the moment the server fired it.
	local animator = getAnimator(character)
	if not animator then
		return nil
	end

	local track = getTrack(animator, animationName)
	if track then
		track.Looped = looped or false
		if priority then
			track.Priority = priority
		end
		track:Play(fadeTime, weight, speed)
	end
	return track
end

local function getCachedTrack(character: Model?, animationName: string): AnimationTrack?
	local animator = getAnimator(character)
	return animator and loadedTracks[animator] and loadedTracks[animator][animationName]
end

function AnimationController.Stop(character: Model?, animationName: string, fadeTime: number?)
	local track = getCachedTrack(character, animationName)
	if track then
		track:Stop(fadeTime)
	end
end

-- Continues an already-loaded track from wherever it left off (AnimationTrack
-- retains TimePosition across Stop/Play) — assumes Play was already called on
-- this (character, animationName) pair at least once; warns otherwise.
function AnimationController.Resume(character: Model?, animationName: string, fadeTime: number?, weight: number?, speed: number?)
	local track = getCachedTrack(character, animationName)
	if not track then
		warn("AnimationController: cannot resume", animationName, "- never loaded for", character and character.Name or "<nil character>")
		return
	end
	track:Play(fadeTime, weight, speed)
end

function AnimationController.Start()
	Net:Connect(RemoteConfig.Animations.PlayAnimation.Name, function(character, animationName, looped, priority)
		AnimationController.Play(character, animationName, looped, priority)
	end)
	Net:Connect(RemoteConfig.Animations.StopAnimation.Name, function(character, animationName, fadeTime)
		AnimationController.Stop(character, animationName, fadeTime)
	end)
	Net:Connect(RemoteConfig.Animations.ResumeAnimation.Name, function(character, animationName, fadeTime, weight, speed)
		AnimationController.Resume(character, animationName, fadeTime, weight, speed)
	end)
end

return AnimationController
