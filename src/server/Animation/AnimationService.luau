--[[
	AnimationService

	Thin server-side entry point other Services call instead of touching
	Net/RemoteConfig themselves. Animations always actually play on the
	client (see AnimationController) — this just relays the request there.

	Also tracks which animation is currently active per character, so a
	player who joins mid-game gets it replayed to them — otherwise
	FireAllClients-only events are invisible to anyone not yet connected when
	they fired, leaving already-animated NPCs stuck in a default pose for
	late joiners.
]]

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local AnimationService = {}

local animationMeta = {} -- [character][animationName] = { looped, priority } -- captured from Play calls
local activeAnimations = {} -- [character] = animationName currently visible (or nil)
local hookedCharacters = {} -- [character] = true, so Destroying is only connected once

local function ensureHooked(character: Model)
	if hookedCharacters[character] then
		return
	end
	hookedCharacters[character] = true
	character.Destroying:Connect(function()
		activeAnimations[character] = nil
		animationMeta[character] = nil
		hookedCharacters[character] = nil
	end)
end

-- Fires to all clients, not just one player, since NPC/other-entity animations
-- need to be visible to everyone watching (same treatment as every other
-- visual effect in this codebase: server-authored, client-rendered).
function AnimationService.Play(character: Model, animationName: string, looped: boolean?, priority: Enum.AnimationPriority?)
	ensureHooked(character)
	animationMeta[character] = animationMeta[character] or {}
	animationMeta[character][animationName] = { looped = looped, priority = priority }
	activeAnimations[character] = animationName

	Net:RemoteEvent(RemoteConfig.Animations.PlayAnimation.Name):FireAllClients(character, animationName, looped, priority)
end

function AnimationService.Stop(character: Model, animationName: string, fadeTime: number?)
	if activeAnimations[character] == animationName then
		activeAnimations[character] = nil
	end

	Net:RemoteEvent(RemoteConfig.Animations.StopAnimation.Name):FireAllClients(character, animationName, fadeTime)
end

-- Resumes an animation that was already Play'd at least once (e.g. the
-- spawn-time warm-up) — reuses the looped/priority captured back then for
-- late-joiner replay purposes; doesn't need to resend them to already-
-- connected clients since AnimationController.Resume just continues the
-- already-loaded track from wherever it left off.
function AnimationService.Resume(character: Model, animationName: string, fadeTime: number?, weight: number?, speed: number?)
	ensureHooked(character)
	activeAnimations[character] = animationName

	Net:RemoteEvent(RemoteConfig.Animations.ResumeAnimation.Name):FireAllClients(character, animationName, fadeTime, weight, speed)
end

function AnimationService.Init()
	Players.PlayerAdded:Connect(function(player)
		for character, animationName in activeAnimations do
			local meta = animationMeta[character] and animationMeta[character][animationName]
			if meta then
				Net:RemoteEvent(RemoteConfig.Animations.PlayAnimation.Name):FireClient(
					player, character, animationName, meta.looped, meta.priority)
			end
		end
	end)
end

return AnimationService
