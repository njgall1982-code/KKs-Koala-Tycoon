-- Tool Purchase Handler
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseToolEvent")
local TOOL_PRICES = {
    Shovel = 150,
    RenameTag = 150,
    MilkBottle = 50,
}
purchaseEvent.OnServerEvent:Connect(function(player, toolName, price)
    if not toolName or not price then return end
    local expectedPrice = TOOL_PRICES[toolName]
    if not expectedPrice or price ~= expectedPrice then return end
    -- Check if it's a permanent tool already owned
    local isConsumable = (toolName == "RenameTag" or toolName == "MilkBottle")
    local ownedTools = player:FindFirstChild("OwnedTools")
    if not isConsumable and ownedTools and ownedTools:FindFirstChild(toolName) then return end
    -- Cap Milk Bottles at 5
    if toolName == "MilkBottle" then
        local count = 0
        local backpack = player:FindFirstChild("Backpack")
        local character = player.Character
        
        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                if item.Name == "MilkBottle" then count += 1 end
            end
        end
        if character then
            for _, item in pairs(character:GetChildren()) do
                if item.Name == "MilkBottle" then count += 1 end
            end
        end
        
        if count >= 5 then
            purchaseEvent:FireClient(player, false, toolName, "You can only hold 5 Milk Bottles at a time!")
            return
        end
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end
    local cash = leaderstats:FindFirstChild("Cash")
    if not cash or cash.Value < price then return end
    cash.Value = cash.Value - price
    
    -- Only add to OwnedTools if not consumable
    if not isConsumable then
        if not ownedTools then
            ownedTools = Instance.new("Folder", player)
            ownedTools.Name = "OwnedTools"
        end
        local toolValue = Instance.new("StringValue", ownedTools)
        toolValue.Name = toolName
        toolValue.Value = toolName
    end
    local toolTemplate = ServerStorage:FindFirstChild(toolName)
    if toolTemplate then
        toolTemplate:Clone().Parent = player.Backpack
    end
    purchaseEvent:FireClient(player, true, toolName, "Purchase successful!")
end)
local function giveOwnedTools(player)
    local ownedTools = player:FindFirstChild("OwnedTools")
    if not ownedTools then return end
    for _, toolValue in pairs(ownedTools:GetChildren()) do
        local toolTemplate = ServerStorage:FindFirstChild(toolValue.Value)
        if toolTemplate and not player.Backpack:FindFirstChild(toolValue.Value) then
            toolTemplate:Clone().Parent = player.Backpack
        end
    end
end
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function() giveOwnedTools(player) end)
end)
