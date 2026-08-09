local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local WaitForDataController = {}

while not LocalPlayer:FindFirstChild("PlayerData") do
	task.wait()
end
print("finished waiting for data")

return WaitForDataController
