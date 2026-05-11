-- TeleportToForest.lua (Server Script)
-- Handles transporting the player to the Rescue Forest place.

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local FOREST_PLACE_ID = 79103142136739
local TRUCK_PATH = workspace:WaitForChild("ForestTransport_Truck", 10)

if not TRUCK_PATH then
    warn("[TeleportToForest] Truck model not found in Workspace!")
    return
end

-- Find all visible parts on the truck to ensure prompt is accessible
local partsFound = 0
for _, p in pairs(TRUCK_PATH:GetDescendants()) do
    if p:IsA("BasePart") and p.Transparency < 1 then
        local prompt = p:FindFirstChild("TransportPrompt")
        if not prompt then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "TransportPrompt"
            prompt.ActionText = "Travel to Rescue Forest 🌲"
            prompt.ObjectText = "Rescue Truck"
            prompt.HoldDuration = 2.0
            prompt.Parent = p
        end

        prompt.Triggered:Connect(function(player)
            print("[TeleportToForest] Teleport requested by: " .. player.Name)
            
            -- Fire UI notification
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local event = ReplicatedStorage:FindFirstChild("TeleportNotification")
            if event then event:FireClient(player) end

            if RunService:IsStudio() then
                print("[TeleportToForest] ⚠️ Teleportation is disabled in Studio.")
                local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
                TycoonService.UpdateStatus(player, "🌲 (Studio) Traveling to Forest... (Simulated)")
                return
            end

            local success, result = pcall(function()
                print("[TeleportToForest] Attempting TeleportAsync to PlaceId: " .. tostring(FOREST_PLACE_ID))
                local options = Instance.new("TeleportOptions")
                return TeleportService:TeleportAsync(FOREST_PLACE_ID, {player}, options)
            end)

            if not success then
                warn("[TeleportToForest] ❌ Teleport failed: " .. tostring(result))
                local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
                TycoonService.UpdateStatus(player, "❌ Teleport Failed! Reason: " .. tostring(result))
                
                -- Fallback to old Teleport method
                task.delay(1, function()
                    pcall(function()
                        TeleportService:Teleport(FOREST_PLACE_ID, player)
                    end)
                end)
            end
        end)
        partsFound += 1
    end
end

if partsFound > 0 then
    print("[TeleportToForest] Transport prompts initialized on " .. partsFound .. " parts.")
else
    warn("[TeleportToForest] Could not find any visible parts on the truck for the ProximityPrompt!")
end
