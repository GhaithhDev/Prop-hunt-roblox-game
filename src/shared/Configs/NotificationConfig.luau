local NotificationConfig = {}

NotificationConfig.FadeInTime = 0.3
NotificationConfig.HoldTime = 1.5
NotificationConfig.LevelHoldTime = 4
NotificationConfig.FadeOutTime = 0.5

-- Scale units the notification rises during fade-in (small) and fade-out
-- (further, drifting away as it disappears).
NotificationConfig.RiseDuringFadeIn = 0.03
NotificationConfig.RiseDuringFadeOut = 0.08

NotificationConfig.SuccessColor = Color3.fromRGB(89, 255, 0)
NotificationConfig.ErrorColor = Color3.fromRGB(255, 70, 70)

return NotificationConfig
