--!nocheck
local CharacterAnimationController = {}
CharacterAnimationController.__index = CharacterAnimationController

function CharacterAnimationController.new(gun: Tool)
	local self = {
		enabled = false,
		loadedAnimations = false,
		gun = gun,
		animationTracks = {},
	}
	setmetatable(self, CharacterAnimationController)

	return self
end

function CharacterAnimationController:playShootAnimation()
	if self.animationTracks.Shoot then
		self.animationTracks.Shoot:Play(0)
	end
end

function CharacterAnimationController:playReloadAnimation(reloadTime: number)
	if not self.animationTracks.Reload then
		return
	end
	local speed = self.animationTracks.Reload.Length / reloadTime
	self.animationTracks.Reload:Play(0.1, 1, speed)
end

function CharacterAnimationController:loadAnimations()
	if self.loadedAnimations then
		return
	end

	self.loadedAnimations = true

	-- Animations are optional - a gun without an Animations folder just won't play
	-- third-person arm animations.
	local animationsFolder = self.gun:FindFirstChild("Animations")
	if not animationsFolder then
		return
	end

	-- This should only be called when the gun has been equipped
	local humanoid = self.gun.Parent:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "Gun is not equipped")
	local animator = humanoid.Animator

	local animationTracks = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animationTracks[animation.Name] = animationTrack

		-- Unlike the ViewModelController, we won't tie any sounds to these animations.
		-- Since we're playing these animations from the client and relying on default replication behavior,
		-- any sounds we played here would overlap the view model sounds and wouldn't replicate.
	end

	self.animationTracks = animationTracks
end

function CharacterAnimationController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

	-- Load animations if they haven't been loaded already
	if not self.loadedAnimations then
		self:loadAnimations()
	end

	if self.animationTracks.Idle then
		self.animationTracks.Idle:Play()
	end
end

function CharacterAnimationController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	for _, animation in self.animationTracks do
		animation:Stop()
	end
end

function CharacterAnimationController:destroy()
	self:disable()
	-- Clear the animationTracks table so we don't keep any references around.
	-- This makes sure the animation tracks get garbage collected correctly and don't cause a memory leak.
	table.clear(self.animationTracks)
end

return CharacterAnimationController
