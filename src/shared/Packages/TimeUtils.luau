--[[
	TimeUtils

	Format(seconds) turns a raw second count into a clock string, e.g. 90 ->
	"1:30". Callers are responsible for rounding their input (e.g. math.ceil on
	a countdown) - Format only floors defensively.
]]

local TimeUtils = {}

export type FormatOptions = {
	PadMinutes: boolean?, -- zero-pad the minutes segment: "01:30" instead of "1:30"
	AlwaysShowHours: boolean?, -- force an "H:MM:SS" segment even under an hour
}

function TimeUtils.Format(totalSeconds: number, options: FormatOptions?): string
	options = options or {}
	totalSeconds = math.max(0, math.floor(totalSeconds))

	local hours = totalSeconds // 3600
	local minutes = (totalSeconds % 3600) // 60
	local seconds = totalSeconds % 60

	if hours > 0 or options.AlwaysShowHours then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	end

	if options.PadMinutes then
		return string.format("%02d:%02d", minutes, seconds)
	end

	return string.format("%d:%02d", minutes, seconds)
end

return TimeUtils
