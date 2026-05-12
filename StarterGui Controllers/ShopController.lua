-- Tool Shop GUI Controller
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for GUI
local screenGui = script.Parent
local shopFrame = screenGui:FindFirstChild("ShopFrame")
local closeBtn = shopFrame and shopFrame:FindFirstChild("CloseButton")
local toolContainer = shopFrame and shopFrame:FindFirstChild("ToolContainer")

-- Get RemoteEvent
local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseToolEvent")
local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")

-- Track owned tools locally
local ownedTools = {}

-- Function to close shop
local function closeShop()
    screenGui.Enabled = false
end

-- Function to open shop
local function openShop()
    screenGui.Enabled = true
end

-- Function to update button state
local function updateBuyButton(toolName, owned)
    if not toolContainer then return end
    
    for _, card in pairs(toolContainer:GetChildren()) do
        if card:IsA("Frame") then
            local buyBtn = card:FindFirstChild("BuyButton")
            if buyBtn and buyBtn:GetAttribute("ToolName") == toolName then
                if owned then
                    buyBtn.Text = "OWNED"
                    buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    buyBtn.Active = false
                end
            end
        end
    end
end

-- Handle buy button clicks
if toolContainer then
    for _, card in pairs(toolContainer:GetChildren()) do
        if card:IsA("Frame") then
            local buyBtn = card:FindFirstChild("BuyButton")
            if buyBtn then
                buyBtn.MouseButton1Click:Connect(function()
                    local toolName = buyBtn:GetAttribute("ToolName")
                    local price = buyBtn:GetAttribute("Price")
                    
                    if toolName and price then
                        -- Fire purchase request to server
                        purchaseEvent:FireServer(toolName, price)
                    end
                end)
            end
        end
    end
end

-- Handle close button
if closeBtn then
    closeBtn.MouseButton1Click:Connect(closeShop)
end

-- Listen for purchase responses
purchaseEvent.OnClientEvent:Connect(function(success, toolName, message)
    -- Handle status message if provided
    local statusLabel = shopFrame and shopFrame:FindFirstChild("StatusLabel")
    if statusLabel and message then
        statusLabel.Text = message
        statusLabel.Visible = true
        statusLabel.TextColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
        task.delay(3, function()
            if statusLabel.Text == message then
                statusLabel.Visible = false
            end
        end)
    end

    if success then
        -- Update button to show owned (skip for consumables)
        if toolName ~= "RenameTag" and toolName ~= "MilkBottle" then
            updateBuyButton(toolName, true)
            ownedTools[toolName] = true
        end
    end
end)

-- Listen for open shop requests from server
openShopEvent.OnClientEvent:Connect(openShop)
