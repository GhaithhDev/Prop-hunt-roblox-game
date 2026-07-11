local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local CATEGORY_SELECTED_COLOR = Color3.fromRGB(80, 200, 60)
local CATEGORY_UNSELECTED_COLOR = Color3.fromRGB(150, 150, 150)
local OWNED_COLOR = Color3.fromRGB(90, 255, 120)
local EQUIPPED_COLOR = Color3.fromRGB(255, 220, 80)
local BUY_COLOR = Color3.fromRGB(80, 200, 60)

local InventoryController = {}

function InventoryController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")
	local frame = mainGui:WaitForChild("Inventory")

	local trailsButton = frame:WaitForChild("CategoryButtons"):WaitForChild("TrailsButton")
	local aurasButton = frame.CategoryButtons:WaitForChild("AurasButton")
	local scrollingFrame = frame:WaitForChild("ScrollingFrame")
	local itemTemplate = scrollingFrame:WaitForChild("ItemTemplate")

	local currentCategory = "Trails"
	local lastStatus = nil
	local refreshStatus -- forward-declared: populate()'s row click handlers close over this

	local function updateCategoryButtons()
		trailsButton.BackgroundColor3 = currentCategory == "Trails" and CATEGORY_SELECTED_COLOR or CATEGORY_UNSELECTED_COLOR
		aurasButton.BackgroundColor3 = currentCategory == "Auras" and CATEGORY_SELECTED_COLOR or CATEGORY_UNSELECTED_COLOR
	end

	local function clearRows()
		for _, child in scrollingFrame:GetChildren() do
			if child:IsA("Frame") and child ~= itemTemplate then
				child:Destroy()
			end
		end
	end

	local function populate()
		if not lastStatus then return end

		clearRows()

		local items = currentCategory == "Trails" and lastStatus.Trails or lastStatus.Auras
		local equippedId = currentCategory == "Trails" and lastStatus.EquippedTrail or lastStatus.EquippedAura
		local categorySingular = currentCategory == "Trails" and "Trail" or "Aura"

		for _, item in items do
			local row = itemTemplate:Clone()
			row.Name = item.Id
			row.Visible = true

			row.NameLabel.Text = item.Name
			row.WinsCostLabel.Text = `{NumberFormat.Format(item.WinsCost)} Wins`
			row.MultiplierLabel.Text = `{item.Multiplier}x XP`

			if item.Owned then
				row.BuyWinsButton.Visible = false
				row.BuyRobuxButton.Visible = false
				row.EquipButton.Visible = true

				if item.Id == equippedId then
					row.EquipButton.Text = "Equipped!"
					row.EquipButton.BackgroundColor3 = EQUIPPED_COLOR
				else
					row.EquipButton.Text = "Equip"
					row.EquipButton.BackgroundColor3 = OWNED_COLOR
				end

				row.EquipButton.Activated:Connect(function()
					Net:Invoke("EquipItem", categorySingular, item.Id)
					refreshStatus()
				end)
			else
				row.BuyWinsButton.Visible = true
				row.BuyRobuxButton.Visible = true
				row.EquipButton.Visible = false
				row.BuyWinsButton.BackgroundColor3 = BUY_COLOR

				row.BuyWinsButton.Activated:Connect(function()
					Net:Invoke("BuyWithWins", categorySingular, item.Id)
					refreshStatus()
				end)
				row.BuyRobuxButton.Activated:Connect(function()
					Net:RemoteEvent("RequestRobuxPurchase"):FireServer(categorySingular, item.Id)
				end)
			end

			row.Parent = scrollingFrame
		end
	end

	refreshStatus = function()
		lastStatus = Net:Invoke("GetInventoryStatus")
		populate()
	end

	trailsButton.Activated:Connect(function()
		currentCategory = "Trails"
		updateCategoryButtons()
		populate()
	end)

	aurasButton.Activated:Connect(function()
		currentCategory = "Auras"
		updateCategoryButtons()
		populate()
	end)

	local icon = mainGui:WaitForChild("LeftIcons"):WaitForChild("LeftIconsContainer"):WaitForChild("Inventory"):WaitForChild("Button")
	icon.Activated:Connect(refreshStatus)

	updateCategoryButtons()
end

return InventoryController
