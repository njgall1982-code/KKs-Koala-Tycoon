-- TeleportBackToTycoon Module
-- NOTE: This script is typically used in the Rescue Forest place.
-- It is included in Services for consistency and optional multi-place synchronization.

local TeleportBackToTycoon = {}

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TYCOON_PLACE_ID = 101119931747763 

function TeleportBackToTycoon.Initialize()
    local TRUCK_PATH = workspace:WaitForChild("TycoonTransport_Truck", 5)
    if not TRUCK_PATH then
        TRUCK_PATH = workspace:FindFirstChild("ReturnPart", true)
    end

    if not TRUCK_PATH then 
        warn("[TeleportBack] No transport part found.")
        return 
    end

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
    
    print("[TeleportBackToTycoon] Initialized.")
end

return TeleportBackToTycoon
