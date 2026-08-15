--[[
	EffectTemplates

	Builds and caches the Part templates used by impactEffect/laserBeamEffect. The
	original FPS template ships these as hand-tuned binary instances; since this repo
	has no such assets, they're constructed procedurally in code instead so they stay
	fully version-controlled. The visuals here are simple placeholders - restyle the
	properties below (or swap in your own Parts) to match your game's look without
	touching impactEffect.luau/laserBeamEffect.luau.
]]

local EffectTemplates = {}

local cache: { [string]: Part } = {}

local function newParticleEmitter(color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparks_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.1, 0.3)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Size = NumberSequence.new(0.2)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Enabled = false
	return emitter
end

local function buildImpactTemplate(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false

	local sparkEmitter = newParticleEmitter(color)
	sparkEmitter.Name = "SparkEmitter"
	sparkEmitter.Parent = part

	local circleEmitter = newParticleEmitter(color)
	circleEmitter.Name = "CircleEmitter"
	circleEmitter.Speed = NumberRange.new(0)
	circleEmitter.Size = NumberSequence.new(0.6)
	circleEmitter.Parent = part

	return part
end

local function buildLaserBeamTemplate(): Part
	local part = Instance.new("Part")
	part.Name = "LaserBeam"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false

	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "StartAttachment"
	startAttachment.Parent = part

	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "EndAttachment"
	endAttachment.Parent = part

	local coreBeam = Instance.new("Beam")
	coreBeam.Name = "CoreBeam"
	coreBeam.Attachment0 = startAttachment
	coreBeam.Attachment1 = endAttachment
	coreBeam.Width0 = 0.03
	coreBeam.Width1 = 0.03
	coreBeam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	coreBeam.LightEmission = 1
	coreBeam.FaceCamera = true
	coreBeam.Parent = part

	local otherBeam = Instance.new("Beam")
	otherBeam.Name = "OtherBeam"
	otherBeam.Attachment0 = startAttachment
	otherBeam.Attachment1 = endAttachment
	otherBeam.Width0 = 0.12
	otherBeam.Width1 = 0.12
	otherBeam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
	otherBeam.Transparency = NumberSequence.new(0.6)
	otherBeam.LightEmission = 1
	otherBeam.FaceCamera = true
	otherBeam.Parent = part

	return part
end

local function getOrBuild(name: string, build: () -> Part): Part
	local template = cache[name]
	if not template then
		template = build()
		cache[name] = template
	end
	return template
end

function EffectTemplates.getCharacterImpact(): Part
	return getOrBuild("CharacterImpact", function()
		return buildImpactTemplate("CharacterImpact", Color3.fromRGB(255, 60, 60))
	end)
end

function EffectTemplates.getEnvironmentImpact(): Part
	return getOrBuild("EnvironmentImpact", function()
		return buildImpactTemplate("EnvironmentImpact", Color3.fromRGB(255, 220, 150))
	end)
end

function EffectTemplates.getLaserBeam(): Part
	return getOrBuild("LaserBeam", buildLaserBeamTemplate)
end

return EffectTemplates
