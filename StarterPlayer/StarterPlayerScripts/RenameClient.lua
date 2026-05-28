local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local renameExhibitRemote = ReplicatedStorage:WaitForChild("RenameExhibit")
local inspectKoalaRemote = ReplicatedStorage:WaitForChild("InspectKoala")
local renameKoalaRemote = ReplicatedStorage:WaitForChild("RenameKoala")

-- Helper to format seconds to M:SS
local function formatTime(seconds)
	if not seconds or seconds >= 999999 then return "Max" end
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%dm %ds", m, s)
end

-- Generic UI Creator Helper
local function createBasePopup(titleText)
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "KoalaPopup"
    
    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 320, 0, 200)
    frame.Position = UDim2.new(0.5, -160, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
    frame.BorderSizePixel = 0
    
    local uiCorner = Instance.new("UICorner", frame)
    uiCorner.CornerRadius = UDim.new(0, 15)
    
    local uiStroke = Instance.new("UIStroke", frame)
    uiStroke.Color = Color3.fromRGB(255, 255, 255)
    uiStroke.Transparency = 0.8
    uiStroke.Thickness = 2
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0.25, 0)
    title.Text = titleText
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.BackgroundTransparency = 1
    
    local close = Instance.new("TextButton", frame)
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -35, 0, 5)
    close.Text = "X"
    close.TextColor3 = Color3.new(1, 0.4, 0.4)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    
    return screenGui, frame
end

-- RENAME EXHIBIT
renameExhibitRemote.OnClientEvent:Connect(function(exhibitPath)
    local gui, frame = createBasePopup("Rename Exhibit")
    
    local textBox = Instance.new("TextBox", frame)
    textBox.Size = UDim2.new(0.8, 0, 0.25, 0)
    textBox.Position = UDim2.new(0.1, 0, 0.35, 0)
    textBox.PlaceholderText = "New Exhibit Name..."
    textBox.Text = ""
    textBox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    textBox.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", textBox)
    
    local confirm = Instance.new("TextButton", frame)
    confirm.Size = UDim2.new(0.6, 0, 0.2, 0)
    confirm.Position = UDim2.new(0.2, 0, 0.7, 0)
    confirm.Text = "Confirm ✅"
    confirm.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
    confirm.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", confirm)
    
    confirm.MouseButton1Click:Connect(function()
        renameExhibitRemote:FireServer(exhibitPath, textBox.Text)
        gui:Destroy()
    end)
end)

-- INSPECT KOALA
local currentInspectedKoala = nil

inspectKoalaRemote.OnClientEvent:Connect(function(koala, isModelSwap)
    if not koala then return end
    
    -- Update reference if model swapped
    if currentInspectedKoala then
        local oldName = currentInspectedKoala:GetAttribute("DisplayName")
        local newName = koala:GetAttribute("DisplayName")
        if oldName == newName then
            currentInspectedKoala = koala
            return
        end
    end

    -- If this is just a model swap event and we were not inspecting this koala, ignore it
    if isModelSwap then
        return
    end

    currentInspectedKoala = koala
    local gui, frame = createBasePopup("") -- No generic title
    frame.Size = UDim2.new(0, 320, 0, 280)
    frame.Position = UDim2.new(0.5, -160, 0.5, -140)
    
    local hasBeenNamed = koala:GetAttribute("HasBeenNamed")
    local displayName = koala:GetAttribute("DisplayName") or "Unnamed Koala"
    
    -- Main Name Title (Replaces Koala Profile)
    local nameLabel = Instance.new("TextLabel", frame)
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.05, 0)
    nameLabel.Text = "🐨 " .. displayName
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 24
    nameLabel.BackgroundTransparency = 1

    -- Growth Stats
    local age = koala:GetAttribute("Age") or 0
    local minAge = koala:GetAttribute("StageMin") or 0
    local maxAge = koala:GetAttribute("StageMax") or 1
    local stageName = koala:GetAttribute("StageName") or "Newborn"
    local isAdult = koala:GetAttribute("IsAdult") or false
    local gStatus = koala:GetAttribute("GrowthStatus") or "🐌 Growing Slow (Needs an adult!)"

    local growthLabel = Instance.new("TextLabel", frame)
    growthLabel.Size = UDim2.new(1, 0, 0.15, 0)
    growthLabel.Position = UDim2.new(0, 0, 0.25, 0)
    growthLabel.Text = string.format("Stage: %s\nAge: %s", stageName, formatTime(age))
    growthLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    growthLabel.Font = Enum.Font.GothamMedium
    growthLabel.TextSize = 14
    growthLabel.BackgroundTransparency = 1
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel", frame)
    statusLabel.Size = UDim2.new(1, 0, 0.1, 0)
    statusLabel.Position = UDim2.new(0, 0, 0.4, 0)
    statusLabel.Text = gStatus
    statusLabel.TextColor3 = gStatus:find("Boosted") and Color3.new(1, 1, 0.4) or Color3.fromRGB(180, 255, 180)
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12
    statusLabel.BackgroundTransparency = 1
    
    -- Progress Bar
    local barBackground = Instance.new("Frame", frame)
    barBackground.Size = UDim2.new(0.8, 0, 0.04, 0)
    barBackground.Position = UDim2.new(0.1, 0, 0.5, 0)
    barBackground.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    Instance.new("UICorner", barBackground)
    
    local range = maxAge - minAge
    local progress = (range > 0) and math.clamp((age - minAge) / range, 0, 1) or 1
    if isAdult then progress = 1 end
    
    local barFill = Instance.new("Frame", barBackground)
    barFill.Size = UDim2.new(progress, 0, 1, 0)
    barFill.BackgroundColor3 = isAdult and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 200, 100)
    Instance.new("UICorner", barFill)
    
    -- Update Loop for Dynamic Stats
    task.spawn(function()
        while gui and gui.Parent do
            local k = currentInspectedKoala
            if not k or not k.Parent then 
                -- Search for the koala again by DisplayName if it was swapped
                task.wait(0.1)
                continue 
            end
            
            local success, err = pcall(function()
                local cAge = k:GetAttribute("Age") or 0
                local cMin = k:GetAttribute("StageMin") or 0
                local cMax = k:GetAttribute("StageMax") or 1
                local cStage = k:GetAttribute("StageName") or "Newborn"
                local cAdult = k:GetAttribute("IsAdult") or false
                local cStatus = k:GetAttribute("GrowthStatus") or "🐌 Growing Slow"
                local cName = k:GetAttribute("DisplayName") or k.Name
                
                nameLabel.Text = "🐨 " .. cName
                growthLabel.Text = string.format("Stage: %s\nAge: %s", cStage, formatTime(cAge))
                statusLabel.Text = cStatus
                
                -- Dynamic coloring for status
                if cStatus:find("Boosted") then
                    statusLabel.TextColor3 = Color3.new(1, 1, 0.4) -- Yellow
                elseif cStatus:find("Protected") then
                    statusLabel.TextColor3 = Color3.fromRGB(180, 255, 180) -- Green
                else
                    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200) -- Gray
                end
                
                local cRange = cMax - cMin
                local cProgress = (cRange > 0) and math.clamp((cAge - cMin) / cRange, 0, 1) or 1
                if cAdult then cProgress = 1 end
                
                barFill.Size = UDim2.new(cProgress, 0, 1, 0)
                barFill.BackgroundColor3 = cAdult and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 200, 100)
            end)
            
            if not success then
                -- Koala likely swapped models, wait for currentInspectedKoala to update from event
                task.wait(0.5)
            else
                task.wait(1)
            end
        end
    end)
    
    -- Needs
    local stats = Instance.new("TextLabel", frame)
    stats.Size = UDim2.new(1, 0, 0.1, 0)
    stats.Position = UDim2.new(0, 0, 0.62, 0)
    
    local exhibitName = koala:GetAttribute("HomeExhibit")
    local exhibit = exhibitName and workspace:FindFirstChild(exhibitName)
    local food = exhibit and exhibit:GetAttribute("FoodLevel") or 100
    
    stats.Text = "🥗 Hunger: " .. food .. "%"
    stats.TextColor3 = (food < 30) and Color3.new(1, 0.4, 0.4) or Color3.new(0.6, 1, 0.6)
    stats.BackgroundTransparency = 1
    
    local renameBtn = Instance.new("TextButton", frame)
    renameBtn.Size = UDim2.new(0.7, 0, 0.15, 0)
    renameBtn.Position = UDim2.new(0.15, 0, 0.78, 0)
    renameBtn.Text = hasBeenNamed and "Change Name (Tag Req.)" or "Register Name (FREE)"
    renameBtn.BackgroundColor3 = hasBeenNamed and Color3.fromRGB(70, 80, 90) or Color3.fromRGB(60, 160, 60)
    renameBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", renameBtn)
    
    renameBtn.MouseButton1Click:Connect(function()
        if hasBeenNamed then
            local tag = player.Backpack:FindFirstChild("RenameTag") or player.Character:FindFirstChild("RenameTag")
            if not tag then
                renameBtn.Text = "❌ Need a Rename Tag!"
                task.wait(2)
                renameBtn.Text = "Change Name (Tag Req.)"
                return
            end
        end

        frame.Visible = false
        local rGui, rFrame = createBasePopup("Name Your Koala")
        local textBox = Instance.new("TextBox", rFrame)
        textBox.Size = UDim2.new(0.8, 0, 0.25, 0)
        textBox.Position = UDim2.new(0.1, 0, 0.35, 0)
        textBox.Text = ""
        textBox.PlaceholderText = "Blinky..."
        textBox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
        textBox.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", textBox)
        
        local confirm = Instance.new("TextButton", rFrame)
        confirm.Size = UDim2.new(0.6, 0, 0.2, 0)
        confirm.Position = UDim2.new(0.2, 0, 0.7, 0)
        confirm.Text = "Confirm"
        confirm.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
        Instance.new("UICorner", confirm)
        
        confirm.MouseButton1Click:Connect(function()
            renameKoalaRemote:FireServer(currentInspectedKoala, textBox.Text)
            rGui:Destroy()
            gui:Destroy()
        end)
    end)
end)