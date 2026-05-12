-- TeleportToForest Module
local TeleportToForest = {}

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FOREST_PLACE_ID = 79103142136739
local TRUCK_PATH_NAME = "ForestTransport_Truck"

function TeleportToForest.Initialize()
    local TRUCK_PATH = workspace:WaitForChild(TRUCK_PATH_NAME, 10)
    local signals = ServerStorage:WaitForChild("Signals")
    local showStatus = signals:WaitForChild("ShowStatus")

    if not TRUCK_PATH then
        warn("[TeleportToForest] Truck model not found in Workspace!")
        return
    end

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
                
                local event = ReplicatedStorage:FindFirstChild("TeleportNotification")
                if event then event:FireClient(player) end

                if RunService:IsStudio() then
                    print("[TeleportToForest] ⚠️ Teleportation is disabled in Studio.")
                    showStatus:Fire(player, "🌲 (Studio) Traveling to Forest...", Color3.fromRGB(255, 255, 0))
                    return
                end

                local success, result = pcall(function()
                    local options = Instance.new("TeleportOptions")
                    return TeleportService:TeleportAsync(FOREST_PLACE_ID, {player}, options)
                end)

                if not success then
                    warn("[TeleportToForest] ❌ Teleport failed: " .. tostring(result))
                    showStatus:Fire(player, "❌ Teleport Failed!", Color3.fromRGB(255, 0, 0))
                    
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

    print("[TeleportToForest] Initialized on " .. partsFound .. " parts.")
end

return TeleportToForest
