--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

--//Configs
local SIZE_MULTI_ATTRIBUTE = "KeycapSizeMulti"
local KEY_CAP_SET_ATTRIBUTE = "KeycapSet"
local KeycapsConfigs = require(ReplicatedStorage.Shared.Configs.KeycapConfigs)
local TAGS = require(ReplicatedStorage.Shared.Configs.Tags)

--//Pacakges
local Vector3Utils = require(ReplicatedStorage.Shared.Packages.Vector3Utils)

local GenerateKeycaps = {}

--//Helpers
local function getRandomLetter(): string
	return string.char(math.random(65, 90)) -- "A" to "Z"
end

function GenerateKeycaps.GenerateKeycapsFromSurface(surface: BasePart)
   print("Generating keycaps for surface: " .. surface:GetFullName())
   local gridSizeX, gridSizeY = surface.Size.X, surface.Size.Z
   local sizeMulti = surface:GetAttribute(SIZE_MULTI_ATTRIBUTE) or 1
   local keycapSize: number = KeycapsConfigs.KeycapBottomBaseSize * sizeMulti

   local padding: number = KeycapsConfigs.OffsetBetweenKeycaps
   local desiredStep = keycapSize + padding
   local columns = math.max(1, math.round(gridSizeX / desiredStep))
   local rows = math.max(1, math.round(gridSizeY / desiredStep))
   local stepX = gridSizeX / columns
   local stepZ = gridSizeY / rows

   local gridTopLeft = surface.Position -  surface.CFrame.RightVector * gridSizeX / 2 + surface.CFrame.LookVector * gridSizeY / 2 
   gridTopLeft += surface.CFrame.UpVector * (keycapSize / 2)
  
   local keycapSet = surface:GetAttribute(KEY_CAP_SET_ATTRIBUTE)
   local keyCapFolder = ReplicatedStorage.Shared.Assets.Keycaps:FindFirstChild(keycapSet)
   if not keyCapFolder then
		warn("Keycap set " .. keycapSet .. " not found!")
		return
   end
   local keyCaps = keyCapFolder:GetChildren()
   for i = 1,rows,1 do
        for j = 1,columns,1 do
            local randomIndex = math.random(1, #keyCaps)
            local keycap = keyCaps[randomIndex]:Clone()
            CollectionService:AddTag(keycap, TAGS.KEYCAP)
            keycap:ScaleTo(sizeMulti)
            local letter = getRandomLetter()
            keycap.PrimaryPart.SurfaceGui.TextLabel.Text = letter
            keycap.Parent = workspace.Functional.Spawns.Keycaps
            local localPosition = gridTopLeft
            localPosition += surface.CFrame.RightVector * (j * (stepX) - (stepX)/2)
            localPosition -= surface.CFrame.LookVector * (i * (stepZ) - (stepZ)/2)
            keycap:PivotTo(CFrame.new(localPosition))
            Vector3Utils.setModelUpVector(keycap,surface.CFrame.UpVector)
        end
   end
end

function GenerateKeycaps.Start()
    for _, surface in pairs(CollectionService:GetTagged(TAGS.GENERATE_KEYCAPS_SURFACE)) do
        GenerateKeycaps.GenerateKeycapsFromSurface(surface)
    end
end

return GenerateKeycaps