-- TeleportToForest Module
-- Handles transporting the player from Tycoon to the Rescue Forest place.
-- Saves player data right before teleporting.

local TeleportToForest = {}

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FOREST_PLACE_ID = 79103142136739

function TeleportToForest.Initialize()
	local TRUCK_PATH = workspace:WaitForChild("ForestTransport_Truck", 5)

	if not TRUCK_PATH then
		warn("[TeleportToForest] ForestTransport_Truck not found in workspace!")
		return
	end

	local prompt = nil
	for _, desc in ipairs(TRUCK_PATH:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			prompt = desc
			break
		end
	end

	if not prompt then
		warn("[TeleportToForest] ProximityPrompt not found in ForestTransport_Truck. Creating one.")
		-- Fallback: find a good part to put it in
		local promptPart = TRUCK_PATH:IsA("BasePart") and TRUCK_PATH or (TRUCK_PATH.PrimaryPart or TRUCK_PATH:FindFirstChild("Part", true))
		if promptPart then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TransportPrompt"
			prompt.ActionText = "Go to Rescue Forest"
			prompt.ObjectText = "Transport Truck"
			prompt.HoldDuration = 2.0
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptPart
		end
	end

	if prompt then
		-- Update properties to match expected standard
		prompt.ActionText = "Go to Rescue Forest"
		prompt.ObjectText = "Transport Truck"
		prompt.HoldDuration = 2.0
		prompt.RequiresLineOfSight = false
		prompt.Enabled = true

		prompt.Triggered:Connect(function(player)
			print("[TeleportToForest] Travel to Rescue Forest requested by: " .. player.Name)
			
			-- Trigger visual fade event on client
			local event = ReplicatedStorage:FindFirstChild("TeleportNotification")
			if not event then
				event = Instance.new("RemoteEvent")
				event.Name = "TeleportNotification"
				event.Parent = ReplicatedStorage
			end
			event:FireClient(player)

			-- Save progress immediately before teleporting
			local DataStoreModule = require(ServerScriptService.Services.DataStoreModule)
			if DataStoreModule then
				DataStoreModule.SaveData(player)
			else
				warn("[TeleportToForest] DataStoreModule not found. Cannot force pre-teleport save!")
			end

			if RunService:IsStudio() then
				print("[TeleportToForest] ⚠️ Teleportation is disabled in Studio.")
				return
			end

			local success, result = pcall(function()
				local options = Instance.new("TeleportOptions")
				return TeleportService:TeleportAsync(FOREST_PLACE_ID, {player}, options)
			end)

			if not success then
				warn("[TeleportToForest] Teleport failed: " .. tostring(result))
			end
		end)
	else
		warn("[TeleportToForest] Failed to find or create ProximityPrompt for teleportation!")
	end
	
	print("[TeleportToForest] Initialized.")
end

return TeleportToForest