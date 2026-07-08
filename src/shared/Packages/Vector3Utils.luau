local Vector3Utils = {}

--Sets the up vector of a model to the given direction. The model will be rotated around its pivot point.
function Vector3Utils.setModelUpVector(model: Model, direction: Vector3)
	direction = direction.Unit

	local pivot = model:GetPivot()
	local delta = CFrame.fromRotationBetweenVectors(pivot.UpVector, direction)

	model:PivotTo(CFrame.new(pivot.Position) * delta * pivot.Rotation)
end

return Vector3Utils