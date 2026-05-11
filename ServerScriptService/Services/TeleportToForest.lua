local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local FOREST_ID = 71358226133788

-- Find the ProximityPrompt on the truck
local truck = workspace:FindFirstChild("ForestTransport_Truck")
if not truck then
	warn("Truck not found in Workspace")
	return
end

local prompt = truck:FindFirstChild("Model", true)
if prompt then
	prompt = prompt:FindFirstChild("Delivery Truck", true)
end
if prompt then
	prompt = prompt:FindFirstChild("Model", true)
end
if prompt then
	prompt = prompt:FindFirstChild("Vehicle Seat", true)
end
if prompt then
	prompt = prompt:FindFirstChild("ProximityPrompt")
end

if not prompt then
	warn("ProximityPrompt not found on truck")
	return
end

prompt.Triggered:Connect(function(player)
	print("Teleporting " .. player.Name .. " to Rescue Forest...")
	TeleportService:Teleport(FOREST_ID, player)
end)

print("Teleport script loaded successfully")