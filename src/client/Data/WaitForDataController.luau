local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local WaitForDataController = {}

-- Required explicitly at the very top of init.client.luau, before any other
-- controller loads. require() blocks the caller until this module's top-level
-- code finishes, so this poll gates the whole client startup on PlayerData
-- existing - no other controller needs its own wait for it. Polling instead
-- of WaitForChild avoids the "Infinite yield possible" warning, since the
-- profile load this is waiting on can legitimately take longer than 5 seconds.
while not LocalPlayer:FindFirstChild("PlayerData") do
	task.wait()
end

return WaitForDataController
