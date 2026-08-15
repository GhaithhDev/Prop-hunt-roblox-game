local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local lerp = require(ReplicatedStorage.Shared.Weapon.Utility.lerp)

local camera = Workspace.CurrentCamera

local recoil = Vector2.new()
local zoom = 0

local function onRenderStepped(deltaTime: number)
	camera.CFrame *= CFrame.Angles(recoil.Y * deltaTime, recoil.X * deltaTime, 0)
	camera.FieldOfView = WeaponConstants.RECOIL_DEFAULT_FOV + zoom
	recoil = recoil:Lerp(Vector2.zero, math.min(deltaTime * WeaponConstants.RECOIL_STOP_SPEED, 1))
	zoom = lerp(zoom, 0, math.min(deltaTime * WeaponConstants.RECOIL_ZOOM_RETURN_SPEED, 1))
end

local CameraRecoiler = {}

function CameraRecoiler.recoil(recoilAmount: Vector2)
	zoom = 1
	recoil += recoilAmount
end

-- apply recoil after aim assist
RunService:BindToRenderStep(WeaponConstants.RECOIL_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStepped)

return CameraRecoiler
