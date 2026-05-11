local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local renameEvent = ReplicatedStorage:WaitForChild("RenameExhibit")
local renameKoalaEvent = ReplicatedStorage:WaitForChild("RenameKoala")

-- Function to create the Prompt UI
local function createRenameUI(isKoala, targetName, targetPath, targetInstance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RenamePromptGui"
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 150)
	frame.Position = UDim2.new(0.5, -150, 0.4, -75)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = isKoala and ("Rename " .. targetName) or "Rename Exhibit"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.BackgroundTransparency = 1
	title.Parent = frame

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0.8, 0, 0, 35)
	textBox.Position = UDim2.new(0.1, 0, 0.35, 0)
	textBox.PlaceholderText = "Enter new name..."
	textBox.Text = ""
	textBox.TextColor3 = Color3.new(0, 0, 0)
	textBox.BackgroundColor3 = Color3.new(1, 1, 1)
	textBox.Font = Enum.Font.Gotham
	textBox.TextSize = 16
	textBox.Parent = frame

	local confirm = Instance.new("TextButton")
	confirm.Size = UDim2.new(0.35, 0, 0, 35)
	confirm.Position = UDim2.new(0.1, 0, 0.7, 0)
	confirm.Text = "Confirm"
	confirm.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	confirm.TextColor3 = Color3.new(1, 1, 1)
	confirm.Font = Enum.Font.GothamBold
	confirm.Parent = frame

	local cancel = Instance.new("TextButton")
	cancel.Size = UDim2.new(0.35, 0, 0, 35)
	cancel.Position = UDim2.new(0.55, 0, 0.7, 0)
	cancel.Text = "Cancel"
	cancel.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	cancel.TextColor3 = Color3.new(1, 1, 1)
	cancel.Font = Enum.Font.GothamBold
	cancel.Parent = frame

	confirm.MouseButton1Click:Connect(function()
		local newName = textBox.Text
		if newName ~= "" then
			if isKoala then
				renameKoalaEvent:FireServer(targetInstance, newName)
			else
				renameEvent:FireServer(targetPath, newName)
			end
		end
		screenGui:Destroy()
	end)

	cancel.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)
end

-- Listen for Exhibit Rename
renameEvent.OnClientEvent:Connect(function(exhibitPath)
	createRenameUI(false, nil, exhibitPath)
end)

-- Listen for Koala Rename (from tools/interaction)
renameKoalaEvent.OnClientEvent:Connect(function(koalaInstance)
	createRenameUI(true, koalaInstance.Name, nil, koalaInstance)
end)
