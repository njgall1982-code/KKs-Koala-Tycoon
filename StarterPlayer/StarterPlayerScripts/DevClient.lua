print('[DevClient] Script Running')
-- DevClient.lua (LocalScript in StarterPlayerScripts)
-- Handles the DevWand UI and firing RemoteEvents

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local devAction = ReplicatedStorage:WaitForChild("DevAction")
local toggleKey = Enum.KeyCode.P -- Hotkey to toggle if holding wand

-- UI Creation
local function createDevUI()
    if playerGui:FindFirstChild("DevMenu") then return end
    
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "DevMenu"
    screenGui.Enabled = false
    
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 250, 0, 350)
    mainFrame.Position = UDim2.new(1, -260, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", mainFrame).Thickness = 2
    
    local title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "🛠️ DEV MENU"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.BackgroundTransparency = 1
    
    local container = Instance.new("ScrollingFrame", mainFrame)
    container.Size = UDim2.new(1, -20, 1, -50)
    container.Position = UDim2.new(0, 10, 0, 45)
    container.BackgroundTransparency = 1
    container.CanvasSize = UDim2.new(0, 0, 0, 400)
    container.ScrollBarThickness = 4
    
    local layout = Instance.new("UIListLayout", container)
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local function createBtn(text, color, action, data)
        local btn = Instance.new("TextButton", container)
        btn.Size = UDim2.new(0.9, 0, 0, 35)
        btn.Text = text
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        Instance.new("UICorner", btn)
        
        btn.MouseButton1Click:Connect(function()
            devAction:FireServer(action, data)
        end)
    end
    
    -- Populate buttons
    createBtn("Spawn Newborn (Cute)", Color3.fromRGB(70, 70, 70), "SpawnKoala", {stage = 1, rarity = "Cute"})
    createBtn("Spawn Newborn (Extra)", Color3.fromRGB(180, 150, 0), "SpawnKoala", {stage = 1, rarity = "Extra Cute"})
    createBtn("Spawn Newborn (Ultra)", Color3.fromRGB(130, 0, 180), "SpawnKoala", {stage = 1, rarity = "Ultra Cute"})
    
    createBtn("Grow All Nearby 🧪", Color3.fromRGB(0, 120, 200), "GrowNearby")
    createBtn("Grant $5,000 💰", Color3.fromRGB(0, 150, 0), "AddCash", 5000)
    createBtn("Skip Tutorial ⚡", Color3.fromRGB(200, 100, 0), "Skip")
    createBtn("HARD RESET 🔄", Color3.fromRGB(180, 0, 0), "Reset")
    
    return screenGui
end

local gui = createDevUI()

-- Character/Tool handling
local function onCharacterAdded(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "DevWand" then
            gui.Enabled = true
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child.Name == "DevWand" then
            gui.Enabled = false
        end
    end)
    
    -- Check if wand already equipped
    if char:FindFirstChild("DevWand") then
        gui.Enabled = true
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Hotkey handling
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == toggleKey then
        -- Only allow toggle if holding the wand OR if they are the creator (for convenience)
        local isHoldingWand = player.Character and player.Character:FindFirstChild("DevWand")
        if isHoldingWand then
            gui.Enabled = not gui.Enabled
        end
    end
end)
