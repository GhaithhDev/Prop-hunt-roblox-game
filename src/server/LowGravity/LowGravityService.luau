--[[
	LowGravityService

	Workspace.Functional.Areas.LowGravity is a single Part players can walk
	onto. While a player is inside it, their own gravity is lowered (client-
	side workspace.Gravity write - player characters are client-network-owned
	by default, so this only affects that one client's physics simulation,
	not the server or other clients) and a server-authoritative wing is
	welded to their back so everyone sees it. Both leaving the zone and
	respawning restore/clear this.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

local WingAsset = ReplicatedStorage.Shared.Assets.Wings.Wing

local ZONE_CHECK_INTERVAL = 0.05

local LowGravityService = {}

local zonePart: BasePart
local DEFAULT_GRAVITY: number

local playersInZone: { [Player]: boolean } = {}
local equippedWings: { [Player]: Model } = {}

local function isInsideBox(position: Vector3, box: BasePart): boolean
	local halfSize = box.Size / 2
	local localPosition = box.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function unequipWing(player: Player)
	local wing = equippedWings[player]
	if wing then
		wing:Destroy()
	end
	equippedWings[player] = nil
end

local function equipWing(player: Player)
	local character = player.Character
	if not character then return end
	unequipWing(player) -- guard against double-equip

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local backPart = humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
		and character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
	if not backPart then return end

	local backAttachment = backPart:FindFirstChild("BodyBackAttachment") or Instance.new("Attachment",backPart)
	if not backAttachment then return end

	local clone = WingAsset:Clone()
	local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	clone.Parent = character

	if root then
		local wingAttachment = root:FindFirstChild("WingAttachment") or Instance.new("Attachment", root)
		wingAttachment.Name = "WingAttachment"
		wingAttachment.CFrame = CFrame.new(-1, -1.5, 0) * CFrame.Angles(0, math.rad(90), 0)

		local weld = Instance.new("RigidConstraint")
		weld.Attachment0 = backAttachment
		weld.Attachment1 = wingAttachment
		weld.Parent = root
	end

	local animController = clone:FindFirstChildOfClass("AnimationController")
	local flyAnim = clone:FindFirstChild("WingFlyAnim", true)
	if animController and flyAnim then
		local animator = animController:FindFirstChildOfClass("Animator") or Instance.new("Animator", animController)
		local track = animator:LoadAnimation(flyAnim)
		track.Looped = true
		track:Play()
	end

	equippedWings[player] = clone
end

local function updateZoneMembership()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local inZone = root and isInsideBox(root.Position, zonePart)

		if inZone and not playersInZone[player] then
			playersInZone[player] = true
			equipWing(player)
			Net:RemoteEvent("SetGravity"):FireClient(player, zonePart:GetAttribute("Gravity"),true)
		elseif not inZone and playersInZone[player] then
			playersInZone[player] = nil
			unequipWing(player)
			Net:RemoteEvent("SetGravity"):FireClient(player, DEFAULT_GRAVITY)
		end
	end
end

function LowGravityService.Start()
	zonePart = workspace.Functional.Areas.LowGravity
	DEFAULT_GRAVITY = workspace.Gravity

	local function onCharacterAdded(player: Player)
		-- Fresh character has no wing welded to it and isn't known to be in
		-- the zone yet - let the next poll tick re-detect cleanly instead of
		-- trusting state left over from the previous body.
		playersInZone[player] = nil
		equippedWings[player] = nil
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		playersInZone[player] = nil
		equippedWings[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(ZONE_CHECK_INTERVAL)
			updateZoneMembership()
		end
	end)
end

return LowGravityService
