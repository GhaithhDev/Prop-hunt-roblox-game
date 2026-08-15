local Workspace = game:GetService("Workspace")

local EffectTemplates = require(script.Parent.EffectTemplates)

local function impactEffect(position: Vector3, normal: Vector3, isCharacter: boolean)
	local template = if isCharacter then EffectTemplates.getCharacterImpact() else EffectTemplates.getEnvironmentImpact()

	local impact = template:Clone()
	impact.CFrame = CFrame.lookAlong(position, normal)
	impact.Parent = Workspace

	impact.SparkEmitter:Emit(10)
	impact.CircleEmitter:Emit(2)

	task.delay(0.5, function()
		impact:Destroy()
	end)
end

return impactEffect
