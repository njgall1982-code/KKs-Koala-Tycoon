-- RescueClient (LocalScript)
-- Listens for RescueNotification events from the server and displays native pop-up notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local rescueNotifyEvent = ReplicatedStorage:WaitForChild("RescueNotification", 10)

if rescueNotifyEvent then
	rescueNotifyEvent.OnClientEvent:Connect(function(success, message, rarity)
		local title = success and "Rescue Successful! 🐨" or "Rescue Failed ⚠️"
		
		-- Use Roblox SendNotification to display a native slide-in pop-up
		local successCall, err = pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title,
				Text = message,
				Duration = 6
			})
		end)
		
		if not successCall then
			warn("[RescueClient] SendNotification failed: " .. tostring(err))
		end
	end)
	print("[RescueClient] Listening for rescue notifications.")
else
	warn("[RescueClient] RescueNotification RemoteEvent not found in ReplicatedStorage.")
end
