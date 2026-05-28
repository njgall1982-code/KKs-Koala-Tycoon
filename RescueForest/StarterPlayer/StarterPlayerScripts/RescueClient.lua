local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local rescueNotifyEvent = ReplicatedStorage:WaitForChild("RescueNotification", 10)

local function updateVendorPromptText()
	local shop = workspace:FindFirstChild("Shop")
	local vendor = shop and shop:FindFirstChild("Koala Vendor", true)
	local hrp = vendor and vendor:FindFirstChild("HumanoidRootPart")
	local prompt = hrp and hrp:FindFirstChild("VendorPrompt")
	if prompt then
		local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
		local ownedCount = player:GetAttribute("OwnedKoalasCount") or 0
		local price = KoalaConfig.GetMilkBottlePrice(ownedCount)
		prompt.ActionText = "Buy Milk Bottle 🍼 ($" .. price .. ")"
	end
end

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

player:GetAttributeChangedSignal("OwnedKoalasCount"):Connect(updateVendorPromptText)

workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "VendorPrompt" then
		updateVendorPromptText()
	end
end)

-- Initial run
task.spawn(function()
	task.wait(1)
	updateVendorPromptText()
end)
