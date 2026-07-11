local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local GroupRewardsConfig = require(ReplicatedStorage.Shared.Configs.GroupRewardsConfig)

local LocalPlayer = Players.LocalPlayer

local GroupRewardsController = {}

function GroupRewardsController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")

	local icon = mainGui:WaitForChild("LeftIcons"):WaitForChild("LeftIconsContainer"):WaitForChild("GroupReward"):WaitForChild("Button")
	local frame = mainGui:WaitForChild("GroupReward")
	local claim = frame:WaitForChild("Claim")
	local claimButton = claim:WaitForChild("ClaimButton")
	local claimLabel = claim:WaitForChild("TextLabel")

	local lastStatus = { InGroup = false, Claimed = false }

	local function RefreshStatus()
		lastStatus = Net:Invoke("GetStatus")
		claimLabel.Text = lastStatus.Claimed and "Claimed!" or "CLAIM!"
	end

	icon.Activated:Connect(RefreshStatus)

	claimButton.Activated:Connect(function()
		if lastStatus.Claimed then return end

		if not lastStatus.InGroup then
			pcall(function()
				GuiService:OpenBrowserWindow(`https://www.roblox.com/groups/{GroupRewardsConfig.GroupId}`)
			end)
		end

		Net:Invoke("ClaimReward")
		RefreshStatus()
	end)
end

return GroupRewardsController
