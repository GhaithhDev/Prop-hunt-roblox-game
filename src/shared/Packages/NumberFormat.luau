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
			return string.format("%.2f%s", scaled, suffix)
		end
	end

	return tostring(math.floor(value))
end

return NumberFormat
