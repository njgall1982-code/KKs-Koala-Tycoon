-- TeleportBackToTycoon.lua (Server Script)
-- FOR USE IN THE RESCUE FOREST PLACE
-- Handles transporting the player back to the Main Tycoon place.

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local TYCOON_PLACE_ID = 101119931747763 
local TRUCK_PATH = workspace:WaitForChild("TycoonTransport_Truck", 10)

if not TRUCK_PATH then
    warn("[TeleportBack] Truck model not found in Workspace!")
    -- If no truck, try finding any part named 'ReturnPart'
    TRUCK_PATH = workspace:FindFirstChild("ReturnPart", true)
end

if not TRUCK_PATH then return end

-- Find a suitable part for the prompt
local promptPart = TRUCK_PATH:IsA("BasePart") and TRUCK_PATH or (TRUCK_PATH.PrimaryPart or TRUCK_PATH:FindFirstChildOfClass("Part", true))

if promptPart then
    local prompt = promptPart:FindFirstChild("TransportPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = "TransportPrompt"
        prompt.ActionText = "Return to Koala Tycoon 🐨"
        prompt.ObjectText = "Rescue Truck"
        prompt.HoldDuration = 2.0
        prompt.Parent = promptPart
    end

    prompt.Triggered:Connect(function(player)
        print("[TeleportBack] Teleport requested by: " .. player.Name)
        
        -- Fire UI notification if it exists in this place
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local event = ReplicatedStorage:FindFirstChild("TeleportNotification")
        if event then event:FireClient(player) end

        if RunService:IsStudio() then
            print("[TeleportBack] ⚠️ Teleportation is disabled in Studio.")
            return
        end

        local success, result = pcall(function()
            local options = Instance.new("TeleportOptions")
            return TeleportService:TeleportAsync(TYCOON_PLACE_ID, {player}, options)
        end)

        if not success then
            warn("[TeleportBack] Teleport failed: " .. tostring(result))
        end
    end)
end
