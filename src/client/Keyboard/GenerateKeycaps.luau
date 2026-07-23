--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

--//Configs
local SIZE_MULTI_ATTRIBUTE = "KeycapSizeMulti"
local KEY_CAP_SET_ATTRIBUTE = "KeycapSet"
local KeycapsConfigs = require(ReplicatedStorage.Shared.Configs.KeycapConfigs)
local TAGS = require(ReplicatedStorage.Shared.Configs.Tags)

--//Pacakges
local Vector3Utils = require(ReplicatedStorage.Shared.Packages.Vector3Utils)

local LocalPlayer = Players.LocalPlayer

local started = false
local GenerateKeycaps = {}

-- surface -> the keycap instances currently generated for it. All keycaps are
-- parented into one shared workspace.Functional.Spawns.Keycaps folder rather
-- than per-surface, so this is the only way to know exactly what to destroy
-- when a surface falls out of render range.
local generatedKeycaps: { [BasePart]: { Model } } = {}

--//Helpers
local function getRandomLetter(): string
	return string.char(math.random(65, 90)) -- "A" to "Z"
end

local function getPlayerPosition(): Vector3?
	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return rootPart and rootPart.Position
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
   if surface:GetAttribute("AlreadyGenerated") then
       return
   end
   surface:SetAttribute("AlreadyGenerated",true)
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
   local surfaceKeycaps = {}
   for i = 1,rows,1 do
        for j = 1,columns,1 do
            local randomIndex = math.random(1, #keyCaps)
            local keycap = keyCaps[randomIndex]:Clone()
            CollectionService:AddTag(keycap, TAGS.KEYCAP)
            keycap:ScaleTo(sizeMulti)
            keycap:SetAttribute(SIZE_MULTI_ATTRIBUTE, sizeMulti)
            local letter = getRandomLetter()
            keycap.PrimaryPart.SurfaceGui.TextLabel.Text = letter
            keycap.Parent = workspace.Functional.Spawns.Keycaps
            local localPosition = gridTopLeft
            localPosition += surface.CFrame.RightVector * (j * (stepX) - (stepX)/2)
            localPosition -= surface.CFrame.LookVector * (i * (stepZ) - (stepZ)/2)
            keycap:PivotTo(CFrame.new(localPosition))
            Vector3Utils.setModelUpVector(keycap,surface.CFrame.UpVector)
            table.insert(surfaceKeycaps, keycap)
            if onKeycapGenerated then
                onKeycapGenerated()
            end
        end
   end
   generatedKeycaps[surface] = surfaceKeycaps
end

local function DestroyKeycapsForSurface(surface: BasePart)
	local keycaps = generatedKeycaps[surface]
	if not keycaps then return end

	for _, keycap in keycaps do
		if keycap.Parent then
			keycap:Destroy()
		end
	end
	generatedKeycaps[surface] = nil
	surface:SetAttribute("AlreadyGenerated", false)
end

local function updateSurfaceRendering(surface: BasePart, playerPosition: Vector3)
	local distance = (surface.Position - playerPosition).Magnitude
	local isGenerated = generatedKeycaps[surface] ~= nil

	if not isGenerated and distance <= KeycapsConfigs.KeycapRenderDistance then
		GenerateKeycaps.GenerateKeycapsFromSurface(surface)
        return true
	elseif isGenerated and distance > KeycapsConfigs.KeycapUnloadDistance then
		DestroyKeycapsForSurface(surface)
        return true
	end
end

function GenerateKeycaps.Start()
    if started then return end
    started = true

    local renderDistanceEnabled = KeycapsConfigs.RenderDistanceEnabled

    local surfaces = CollectionService:GetTagged(TAGS.GENERATE_KEYCAPS_SURFACE)
    local nearbySurfaces = surfaces

    if renderDistanceEnabled then
        -- Wait for an initial position so the first pass (which the loading
        -- screen below gates on) knows what's actually nearby, instead of
        -- generating every surface in the entire game up front.
        while not getPlayerPosition() do
            task.wait()
        end
        local playerPosition = getPlayerPosition()

        nearbySurfaces = {}
        for _, surface in surfaces do
            if (surface.Position - playerPosition).Magnitude <= KeycapsConfigs.KeycapRenderDistance then
                table.insert(nearbySurfaces, surface)
            end
        end
    end

    local totalKeycaps = 0
    for _, surface in nearbySurfaces do
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

   for _, surface in nearbySurfaces do
        GenerateKeycaps.GenerateKeycapsFromSurface(surface, onKeycapGenerated)
        task.wait(.002)
    end

    workspace:SetAttribute("KeycapsGenerationProgress", 100)
    workspace:SetAttribute("KeycapsGenerated", true)

    if not renderDistanceEnabled then
        -- Feature disabled: generate any surface that streams in later
        -- immediately, same as before render-distance existed.
        CollectionService:GetInstanceAddedSignal(TAGS.GENERATE_KEYCAPS_SURFACE):Connect(function(surface: BasePart)
            GenerateKeycaps.GenerateKeycapsFromSurface(surface)
        end)
        return
    end

    -- Ongoing distance-based load/unload: keycaps only exist for surfaces
    -- within KeycapRenderDistance of the player, freeing memory/physics load
    -- for whichever of the (up to 15) stages the player isn't near. Re-fetches
    -- CollectionService fresh every tick, so surfaces that stream in later
    -- (StreamingEnabled is on) are picked up automatically too.
    task.spawn(function()
        while true do
            task.wait(KeycapsConfigs.RenderRate)
            local position = getPlayerPosition()
            if position then
                for _, surface in CollectionService:GetTagged(TAGS.GENERATE_KEYCAPS_SURFACE) do
                    local updated = updateSurfaceRendering(surface, position)
                    if updated then
                        task.wait()
                    end
                end
            end
        end
    end)
end


return GenerateKeycaps