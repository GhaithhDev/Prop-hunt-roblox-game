local NumberFormat = {}

local SUFFIXES = {
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

function NumberFormat.Format(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	end

	for _, entry in SUFFIXES do
		local threshold, suffix = entry[1], entry[2]
		if value >= threshold then
			local scaled = value / threshold
			if scaled >= 1000 then
				return string.format("%.3e", value)
			end
			if scaled < 10 then
				local truncated = math.floor(scaled * 10) / 10
				return (string.format("%.1f", truncated):gsub("%.0$", "")) .. suffix
			end
			return tostring(math.floor(scaled)) .. suffix
		end
	end

	return tostring(math.floor(value))
end

-- Formats a small decimal value (e.g. a multiplier like 1.2, 1.8, 20) with up
-- to 2 decimal places, trimming trailing zeros - unlike Format, this doesn't
-- floor/abbreviate, so 1.2 stays "1.2" instead of being truncated to "1".
function NumberFormat.FormatDecimal(value: number): string
	local rounded = math.floor(value * 100 + 0.5) / 100
	return (string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", ""))
end

return NumberFormat
