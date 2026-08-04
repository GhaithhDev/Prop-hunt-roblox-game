local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local UFOEventConfig = require(ReplicatedStorage.Shared.Configs.UFOEventConfig)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local UFOEventController = {}

type Session = { cancelled: boolean, controls: any?, rootPart: BasePart?, wasAnchored: boolean? }

-- The one in-flight abduction sequence for this client, if any - WinAwarded
-- (fired the instant the server grants the reward, which is also what
-- teleports the character back to spawn via WinsTeleportController) cancels
-- it so our own Heartbeat-driven lift/lower loop stops fighting that
-- teleport on the very next frame.
local currentSession: Session? = nil

-- The character's own movement/physics is client-owned (same philosophy as
-- WinsTeleportController), so the whole lift/hold/lower sequence is driven
-- locally here rather than by the server.
local function getControls()
	local playerScripts = LocalPlayer:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:WaitForChild("PlayerModule", 5)
	if not playerModule then return nil end
	return require(playerModule):GetControls()
end

local function endSession(session: Session)
	if session.cancelled then return end
	session.cancelled = true

	if session.controls then
		session.controls:Enable()
	end
	if session.rootPart then
		session.rootPart.Anchored = session.wasAnchored or false
	end
	if currentSession == session then
		currentSession = nil
	end
end

local function tweenPivot(character: Model, session: Session, rotation: CFrame, fromPos: Vector3, toPos: Vector3, duration: number, onDone: () -> ())
	if session.cancelled then return end

	if duration <= 0 then
		character:PivotTo(CFrame.new(toPos) * rotation)
		onDone()
		return
	end

	local startTime = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if session.cancelled or not character.Parent then
			connection:Disconnect()
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		character:PivotTo(CFrame.new(fromPos:Lerp(toPos, alpha)) * rotation)
		if alpha >= 1 then
			connection:Disconnect()
			onDone()
		end
	end)
end

local function liftCharacter(character: Model, targetPosition: Vector3)
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local session: Session = {
		cancelled = false,
		controls = getControls(),
		rootPart = rootPart,
		wasAnchored = rootPart and rootPart.Anchored,
	}
	currentSession = session

	if session.controls then session.controls:Disable() end
	-- Anchored for the whole sequence, not just while a tween is actively
	-- driving it - otherwise gravity takes over during the gap between the
	-- up-tween finishing and the down-tween starting (the "hold" while the
	-- reward VFX plays) and the character free-falls away before either the
	-- hold or the down-tween's start position mean anything.
	if rootPart then rootPart.Anchored = true end

	-- Safety net independent of the tween chain below, in case the character
	-- gets removed (death/respawn) mid-sequence or WinAwarded never arrives
	-- for some reason - endSession is a no-op if already ended.
	task.delay(UFOEventConfig.TotalSequenceDuration + 0.5, function()
		endSession(session)
	end)

	local rotation = character:GetPivot().Rotation
	local startPosition = character:GetPivot().Position
	local topPosition = targetPosition

	tweenPivot(character, session, rotation, startPosition, topPosition, UFOEventConfig.CharacterMovingUpDuration, function()
		if session.cancelled then return end

		SoundUtils.PlayLocalSound(SoundService.SFX.Win)

		task.delay(UFOEventConfig.ApplyingRewardDuration, function()
			if session.cancelled or not character.Parent then return end

			tweenPivot(character, session, rotation, topPosition, startPosition, UFOEventConfig.CharacterMovingDownDuration, function()
				endSession(session)
			end)
		end)
	end)
end

function UFOEventController.Start()
	Net:Connect("AbductionStarted", function(targetPosition: Vector3)
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then return end

		liftCharacter(character, targetPosition)
	end)

	Net:Connect("WinAwarded", function()
		if currentSession then
			endSession(currentSession)
		end
	end)
end

return UFOEventController
