--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

--//Configs
local SIZE_MULTI_ATTRIBUTE = "KeycapSizeMulti"
local KEY_CAP_SET_ATTRIBUTE = "KeycapSet"
local KeycapsConfigs = require(ReplicatedStorage.Shared.Configs.KeycapConfigs)
local TAGS = require(ReplicatedStorage.Shared.Configs.Tags)
local decalTemplates = ReplicatedStorage.Shared.Assets.Decals.Keycaps

--//Pacakges
local Vector3Utils = require(ReplicatedStorage.Shared.Packages.Vector3Utils)

local GenerateKeycaps = {}

--//Helpers
local function getRandomLetter(): string
	return string.char(math.random(65, 90)) -- "A" to "Z"
end

-- Pure arithmetic (no instance creation) - safe to call cheaply for a
-- total-count pre-pass ahead of the real generation loop, see Start().
local function computeGridDimensions(surface: BasePart): (number, number)
   local gridSizeX, gridSizeY = surface.Size.X, surface.Size.Z
   local sizeMulti = surface:GetAttribute(SIZE_MULTI_ATTRIBUTE) or 1
   local keycapSize: number = KeycapsConfigs.KeycapBottomBaseSize * sizeMulti

   local padding: number = KeycapsConfigs.OffsetBetweenKeycaps
   local desiredStep = keycapSize + padding
   local columns = math.max(1, math.round(gridSizeX / desiredStep))
   local rows = math.max(1, math.round(gridSizeY / desiredStep))
   return rows, columns
end

function GenerateKeycaps.GenerateKeycapsFromSurface(surface: BasePart, onKeycapGenerated: (() -> ())?)
   local gridSizeX, gridSizeY = surface.Size.X, surface.Size.Z
   local sizeMulti = surface:GetAttribute(SIZE_MULTI_ATTRIBUTE) or 1
   local keycapSize: number = KeycapsConfigs.KeycapBottomBaseSize * sizeMulti
   local rows, columns = computeGridDimensions(surface)
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
            keycap:SetAttribute(SIZE_MULTI_ATTRIBUTE, sizeMulti)
            local newDecal =  decalTemplates:FindFirstChild(getRandomLetter()):Clone()
            newDecal.Parent = keycap.PrimaryPart
            --surfaceGuiTemplate:Clone().Parent = keycap.PrimaryPart
            --[[local letter = getRandomLetter()
            keycap.PrimaryPart.SurfaceGui.TextLabel.Text = letter]]

            keycap.Parent = workspace.Functional.Spawns.Keycaps
            local localPosition = gridTopLeft
            localPosition += surface.CFrame.RightVector * (j * (stepX) - (stepX)/2)
            localPosition -= surface.CFrame.LookVector * (i * (stepZ) - (stepZ)/2)
            keycap:PivotTo(CFrame.new(localPosition))
            Vector3Utils.setModelUpVector(keycap,surface.CFrame.UpVector)
            if onKeycapGenerated then
                onKeycapGenerated()
            end
        end
   end
end

function GenerateKeycaps.Start()
    local surfaces = CollectionService:GetTagged(TAGS.GENERATE_KEYCAPS_SURFACE)

    local totalKeycaps = 0
    for _, surface in surfaces do
        local rows, columns = computeGridDimensions(surface)
        totalKeycaps += rows * columns
    end

    local generatedCount = 0
    local lastPercent = -1
    local function onKeycapGenerated()
        generatedCount += 1
        local percent = totalKeycaps > 0 and math.floor((generatedCount / totalKeycaps) * 100) or 100
        if percent ~= lastPercent then
            lastPercent = percent
            workspace:SetAttribute("KeycapsGenerationProgress", percent)
        end
    end

    for _, surface in surfaces do
        GenerateKeycaps.GenerateKeycapsFromSurface(surface, onKeycapGenerated)
        task.wait(.002)
    end

    workspace:SetAttribute("KeycapsGenerationProgress", 100)
    workspace:SetAttribute("KeycapsGenerated", true)
end

return GenerateKeycaps