local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local actionEvent = ReplicatedStorage:WaitForChild("DevAction")
local tool = script.Parent
local screenGui = nil
local frame = nil
local function createUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DevMenu"
	screenGui.Parent = player:WaitForChild("PlayerGui")
	frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 200, 0, 300)
	frame.Position = UDim2.new(1, -220, 0.5, -150)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 2
	frame.Visible = false
	frame.Parent = screenGui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Text = "DEV MENU"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	title.Parent = frame
	local function createButton(name, text, yPos, color, action, data)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0.9, 0, 0, 35)
		btn.Position = UDim2.new(0.05, 0, 0, yPos)
		btn.Text = text
		btn.BackgroundColor3 = color or Color3.fromRGB(80, 80, 80)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = frame
		btn.MouseButton1Click:Connect(function()
			-- If "GrowKoala", we need to find the target
			local finalData = data
			if action == "GrowKoala" then
				local target = mouse.Target
				local koala = target and target:FindFirstAncestorOfClass("Model")
				if koala and (koala.Name:find("Koala") or koala.Name:find("KK")) then
					finalData = koala
				else
					print("Click on a Koala first!")
					return
				end
			end
			actionEvent:FireServer(action, finalData)
		end)
		return btn
	end
	createButton("SpawnCute", "Spawn Cute 🐨", 40, Color3.fromRGB(100, 100, 100), "SpawnKoala", "Cute")
	createButton("SpawnExtra", "Spawn Extra 🌟", 80, Color3.fromRGB(200, 160, 0), "SpawnKoala", "Extra Cute")
	createButton("SpawnUltra", "Spawn Ultra ✨", 120, Color3.fromRGB(160, 0, 200), "SpawnKoala", "Ultra Cute")
	createButton("Grow", "Grow Clicked 📈", 165, Color3.fromRGB(0, 150, 200), "GrowKoala")
	createButton("Clear", "Clear All 🧹", 210, Color3.fromRGB(150, 50, 50), "ClearAll")
	createButton("Cash", "Give $1000 💵", 255, Color3.fromRGB(50, 150, 50), "GiveCash")
end
tool.Equipped:Connect(function()
	if not screenGui then createUI() end
	frame.Visible = true
end)
tool.Unequipped:Connect(function()
	if frame then frame.Visible = false end
end)
