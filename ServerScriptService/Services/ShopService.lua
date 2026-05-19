local ShopService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")
local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseToolEvent")

local signals = ServerStorage:WaitForChild("Signals")
local transactionRequest = signals:WaitForChild("TransactionRequest")
local awardTool = signals:WaitForChild("AwardTool")

local connections = {} -- toolShed -> connection

local TOOL_PRICES = {
    ["Garden Shovel"] = 150,
    RenameTag = 150,
    MilkBottle = 50,
}

local function isConsumable(toolName)
    return toolName == "RenameTag" or toolName == "MilkBottle"
end

local function countMilkBottles(player)
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
    return count
end

function ShopService.Initialize()
    -- Guard Clause
    if ShopService._initialized then return end
    ShopService._initialized = true

    local function connectToolShed(toolShed)
        if not toolShed or toolShed.Name ~= "ToolShed" then return end
        if connections[toolShed] then return end
        
        local prompt = toolShed:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[ShopService] Connected to ToolShed at: " .. toolShed:GetFullName())
            connections[toolShed] = prompt.Triggered:Connect(function(player)
                ShopService.OpenShop(player)
            end)
            
            toolShed.Destroying:Connect(function()
                if connections[toolShed] then
                    connections[toolShed]:Disconnect()
                    connections[toolShed] = nil
                end
            end)
        end
    end

    for _, desc in pairs(workspace:GetDescendants()) do
        connectToolShed(desc)
    end
    workspace.DescendantAdded:Connect(connectToolShed)
    
    -- Purchase Handler
    purchaseEvent.OnServerEvent:Connect(function(player, toolName, price)
        ShopService.HandlePurchaseRequest(player, toolName, price)
    end)

    print("[ShopService] Initialized (Event-Driven Mode).")
end

function ShopService.OpenShop(player)
    if not player then return end
    openShopEvent:FireClient(player)
end

function ShopService.HandlePurchaseRequest(player, toolName, price)
    -- Guard Clauses
    if not player or not toolName or not price then return end
    local expectedPrice = TOOL_PRICES[toolName]
    if not expectedPrice or price ~= expectedPrice then return end

    -- Check capacity / ownership
    local consumable = isConsumable(toolName)
    if not consumable then
        local ownedTools = player:FindFirstChild("OwnedTools")
        if ownedTools and ownedTools:FindFirstChild(toolName) then
            purchaseEvent:FireClient(player, false, toolName, "You already own this tool!")
            return
        end
    end

    if toolName == "MilkBottle" and countMilkBottles(player) >= 5 then
        purchaseEvent:FireClient(player, false, toolName, "You can only hold 5 Milk Bottles at a time!")
        return
    end

    -- Decoupled Transaction Request
    local success, reason = transactionRequest:Invoke(player, expectedPrice, "Purchase_" .. toolName)
	
    if success then
        awardTool:Fire(player, toolName, not consumable)
        purchaseEvent:FireClient(player, true, toolName, "Purchase successful!")
    else
        purchaseEvent:FireClient(player, false, toolName, reason or "Insufficient funds!")
    end
end

return ShopService
