local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local KeycapSoundConfig = require(ReplicatedStorage.Shared.Configs.KeycapSoundConfig)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local EQUIPPED_COLOR = Color3.fromRGB(90, 255, 120)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(255, 255, 255)

local KeycapSoundController = {}

local KEYBOARD_SOUNDS = SoundService.SFX.Keyboard
local cachedSound: Sound = KEYBOARD_SOUNDS:FindFirstChild(KeycapSoundConfig.DefaultSoundId)

-- Public: PressKeycaps.luau calls this on every press to get the sound to
-- play. Cached and refreshed off PlayerData.EquippedKeycapSound's
-- Changed signal (see Start()) rather than re-resolved every press.
function KeycapSoundController.GetActiveSound(): Sound
	return cachedSound
end

local function tryShowLivePrice(button: TextButton, productId: number)
	local label = button:FindFirstChildOfClass("TextLabel")
	if not label then return end

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			label.Text = tostring(info.PriceInRobux)
		end
	end)
end

function KeycapSoundController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local soundsFrame = playerGui:WaitForChild("Main"):WaitForChild("Sounds")
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local equippedValue = playerData:WaitForChild("EquippedKeycapSound")
	local darkOverlay = soundsFrame:FindFirstChild("Dark")

	local owned = false
	local cardsById: { [string]: Frame } = {}

	local function refreshActiveSound()
		local soundId = equippedValue.Value
		cachedSound = (soundId ~= "" and KEYBOARD_SOUNDS:FindFirstChild(soundId))
			or KEYBOARD_SOUNDS:FindFirstChild(KeycapSoundConfig.DefaultSoundId)
	end

	local function refreshHighlights()
		local equippedId = equippedValue.Value
		for soundId, card in cardsById do
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = (soundId == equippedId) and EQUIPPED_COLOR or DEFAULT_STROKE_COLOR
			end
		end
	end

	local function refreshStatus()
		local status = Net:Invoke("GetShopStatus")
		local keycapSounds = (status and status.KeycapSounds) or {}
		owned = keycapSounds.Unlock or false
		if darkOverlay then
			darkOverlay.Visible = not owned
		end
		refreshHighlights()
	end

	local buyProductId: number? = nil

	for _, card in soundsFrame:GetChildren() do
		if not card:IsA("Frame") then continue end

		local buyFrame = card:FindFirstChild("Buy")
		if buyFrame then
			local buyButton = buyFrame:FindFirstChildOfClass("TextButton")
			if buyButton then
				buyButton.Activated:Connect(function()
					Net:RemoteEvent("RequestGamePassPurchase"):FireServer("KeycapSounds", "Unlock")
				end)

				local passes = MonetizationConfig.GamePasses.KeycapSounds
				buyProductId = passes and passes.Unlock
				if buyProductId and buyProductId ~= 0 then
					tryShowLivePrice(buyButton, buyProductId)
				end
			end
			continue
		end

		local imageButton = card:FindFirstChildOfClass("ImageButton")
		local textLabel = card:FindFirstChild("TextLabel", true)
		if not (imageButton and textLabel and textLabel:IsA("TextLabel")) then continue end

		local entry: KeycapSoundConfig.SoundEntry? = nil
		for _, candidate in KeycapSoundConfig.Sounds do
			if candidate.DisplayName == textLabel.Text then
				entry = candidate
				break
			end
		end
		if not entry then continue end

		cardsById[entry.Id] = card

		imageButton.Activated:Connect(function()
			if entry.Free or owned then
				Net:Invoke("EquipKeycapSound", entry.Id)
				refreshHighlights()
			else
				Net:RemoteEvent("RequestGamePassPurchase"):FireServer("KeycapSounds", "Unlock")
			end
		end)

		-- Showcase the sound on hover, regardless of ownership - lets a
		-- player preview a locked sound before deciding to buy it.
		imageButton.MouseEnter:Connect(function()
			SoundUtils.PlayLocalSound(KEYBOARD_SOUNDS:FindFirstChild(entry.Id))
		end)
	end

	-- Roblox's own purchase-finished signal, already fired natively (and
	-- already consumed once by PurchaseLoadingController) - reused here
	-- instead of adding a new "purchase completed" remote.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if not isPurchased or userId ~= LocalPlayer.UserId then return end
		if productId == buyProductId then
			refreshStatus()
		end
	end)

	equippedValue:GetPropertyChangedSignal("Value"):Connect(function()
		refreshActiveSound()
		refreshHighlights()
	end)

	refreshActiveSound()
	refreshStatus()
end

return KeycapSoundController
