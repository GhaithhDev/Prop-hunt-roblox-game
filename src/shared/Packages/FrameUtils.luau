--[[
	FrameUtils

	ShakeFrame nudges a GuiObject around its resting Position for a short burst
	of small random tweens, then eases it back - a generic "hit feedback" shake,
	fire-and-forget (runs in its own task, doesn't yield the caller). Re-calling
	it on a frame that's already mid-shake is a no-op until that shake finishes,
	so rapid repeated calls (e.g. several hits in quick succession) don't stack
	conflicting tweens against different resting positions.
]]

local TweenService = game:GetService("TweenService")

local FrameUtils = {}

local DEFAULT_INTENSITY = 6 -- pixels
local DEFAULT_DURATION = 0.3
local DEFAULT_SHAKE_COUNT = 6

local activeShakes: { [GuiObject]: boolean } = {}

function FrameUtils.ShakeFrame(frame: GuiObject, intensity: number?, duration: number?, shakeCount: number?)
	if activeShakes[frame] then
		return
	end
	activeShakes[frame] = true

	intensity = intensity or DEFAULT_INTENSITY
	duration = duration or DEFAULT_DURATION
	shakeCount = shakeCount or DEFAULT_SHAKE_COUNT

	local restingPosition = frame.Position
	local stepTime = duration / shakeCount

	task.spawn(function()
		for _ = 1, shakeCount do
			local offset = UDim2.fromOffset(
				(math.random() * 2 - 1) * intensity,
				(math.random() * 2 - 1) * intensity
			)
			local tween = TweenService:Create(
				frame,
				TweenInfo.new(stepTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Position = restingPosition + offset }
			)
			tween:Play()
			tween.Completed:Wait()
		end

		local resetTween = TweenService:Create(
			frame,
			TweenInfo.new(stepTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Position = restingPosition }
		)
		resetTween:Play()
		resetTween.Completed:Wait()

		activeShakes[frame] = nil
	end)
end

return FrameUtils
