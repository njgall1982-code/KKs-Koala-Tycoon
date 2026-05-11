local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")
local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseToolEvent")
local gui = script.Parent
local mainFrame = gui:WaitForChild("MainFrame")
local container = mainFrame:WaitForChild("Container")
local closeBtn = mainFrame:WaitForChild("Close")
local TOOL_LIST = {
	{ name = "Shovel", icon = "⛏️", price = 150, desc = "Clears large rocks and debris." },
	{ name = "RenameTag", icon = "🏷️", price = 150, desc = "Rename a koala! (Consumable)" },
	{ name = "MilkBottle", icon = "🍼", price = 50, desc = "Boosts baby growth. (Consumable)" },
}
local function updateUI()
	for _, child in pairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	for _, toolInfo in ipairs(TOOL_LIST) do
		local itemFrame = Instance.new("Frame", container)
		itemFrame.Name = toolInfo.name
		itemFrame.Size = UDim2.new(1, -10, 0, 80)
		itemFrame.BackgroundColor3 = Color3.fromRGB(45, 50, 55)
		itemFrame.BorderSizePixel = 0
		
		local corner = Instance.new("UICorner", itemFrame)
		
		local icon = Instance.new("TextLabel", itemFrame)
		icon.Size = UDim2.new(0, 60, 0, 60)
		icon.Position = UDim2.new(0, 10, 0.5, -30)
		icon.Text = toolInfo.icon
		icon.TextSize = 40
		icon.BackgroundTransparency = 1
		
		local nameLabel = Instance.new("TextLabel", itemFrame)
		nameLabel.Size = UDim2.new(0.5, 0, 0, 30)
		nameLabel.Position = UDim2.new(0, 80, 0, 10)
		nameLabel.Text = toolInfo.name .. " ($" .. toolInfo.price .. ")"
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.BackgroundTransparency = 1
		
		local buyBtn = Instance.new("TextButton", itemFrame)
		buyBtn.Size = UDim2.new(0, 80, 0, 40)
		buyBtn.Position = UDim2.new(1, -90, 0.5, -20)
		buyBtn.Text = "BUY"
		buyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 100)
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Font = Enum.Font.GothamBold
		Instance.new("UICorner", buyBtn)
		
		buyBtn.MouseButton1Click:Connect(function()
			purchaseEvent:FireServer(toolInfo.name, toolInfo.price)
		end)
	end
end
openShopEvent.OnClientEvent:Connect(function()
	updateUI()
	mainFrame.Visible = true
end)
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)
purchaseEvent.OnClientEvent:Connect(function(success, toolName, message)
	print("[Shop] " .. message)
end)
