local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)

local MonetizationUtils = {}

-- Searches every GamePass category plus DevProducts for a matching ProductId
-- and returns its key name, or nil if not found. Display-purposes only
-- (toasts, warnings) - NOT used for Pass-vs-DevProduct grant dispatch, since
-- it doesn't distinguish which side a match came from.
function MonetizationUtils.GetNameFromId(id: number): string?
	for _, category in MonetizationConfig.GamePasses do
		for name, productId in category do
			if productId == id then
				return name
			end
		end
	end

	-- DevProducts entries can be a bare ProductId (e.g. RebirthSkip) or a nested
	-- table of ProductIds (e.g. SkipToStage, keyed per stage) - walk both shapes.
	for name, value in MonetizationConfig.DevProducts do
		if type(value) == "table" then
			for subKey, productId in value do
				if productId == id then
					return `{name} {subKey}`
				end
			end
		elseif value == id then
			return name
		end
	end

	return nil
end

return MonetizationUtils
