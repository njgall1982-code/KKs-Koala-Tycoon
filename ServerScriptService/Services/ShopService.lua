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

    local function connectPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") then return end
        if prompt.Name ~= "OpenShopPrompt" and not (prompt.ObjectText and prompt.ObjectText:lower():find("tool")) then return end
        if connections[prompt] then return end

        print("[ShopService] Connected to Tool Shop prompt at: " .. prompt:GetFullName())
        connections[prompt] = prompt.Triggered:Connect(function(player)
            ShopService.OpenShop(player)
        end)

        prompt.Destroying:Connect(function()
            if connections[prompt] then
                connections[prompt]:Disconnect()
                connections[prompt] = nil
            end
        end)
    end

    for _, desc in pairs(workspace:GetDescendants()) do
        connectPrompt(desc)
    end
    workspace.DescendantAdded:Connect(connectPrompt)

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
    if toolName == "FeedBagUpgrade" then
        local maxLeaves = player:GetAttribute("MaxLeaves") or 5
        local upgradeLevel = (maxLeaves - 5) / 5
        expectedPrice = 250 * (upgradeLevel + 1)
    elseif toolName == "MilkBottle" then
        local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
        local ownedCount = player:GetAttribute("OwnedKoalasCount") or 0
        expectedPrice = KoalaConfig.GetMilkBottlePrice(ownedCount)
    end
    
    if not expectedPrice or price ~= expectedPrice then return end

    -- Check capacity / ownership
    local consumable = isConsumable(toolName)
    if not consumable and toolName ~= "FeedBagUpgrade" then
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
        if toolName == "FeedBagUpgrade" then
            local currentMax = player:GetAttribute("MaxLeaves") or 5
            player:SetAttribute("MaxLeaves", currentMax + 5)
        else
            awardTool:Fire(player, toolName, not consumable)
            if toolName == "MilkBottle" then
                local current = player:GetAttribute("MilkBottles") or 0
                player:SetAttribute("MilkBottles", current + 1)
            end
        end
        purchaseEvent:FireClient(player, true, toolName, "Purchase successful!")
    else
        purchaseEvent:FireClient(player, false, toolName, reason or "Insufficient funds!")
    end
end

return ShopService
