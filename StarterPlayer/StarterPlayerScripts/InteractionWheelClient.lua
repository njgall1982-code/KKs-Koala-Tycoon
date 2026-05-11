local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local actionRemote = ReplicatedStorage:WaitForChild("KoalaAction")
local renameRemote = ReplicatedStorage:WaitForChild("RenameKoala")
local wheelGui = nil
local activeKoala = nil
local isVisible = false
local function createWheel()
	wheelGui = Instance.new("ScreenGui")
	wheelGui.Name = "InteractionWheel"
	wheelGui.ResetOnSpawn = false
	wheelGui.Parent = player:WaitForChild("PlayerGui")
	
	local center = Instance.new("Frame", wheelGui)
	center.Name = "Center"
	center.Size = UDim2.new(0, 260, 0, 260)
	center.Position = UDim2.new(0.5, -130, 0.5, -130)
	center.BackgroundTransparency = 1
	center.Visible = false
	
	-- Premium Background Blur/Glow
	local blur = Instance.new("ImageLabel", center)
	blur.Size = UDim2.new(1.4, 0, 1.4, 0)
	blur.Position = UDim2.new(-0.2, 0, -0.2, 0)
	blur.Image = "rbxassetid://1316045217" -- Soft radial glow
	blur.ImageColor3 = Color3.fromRGB(0, 150, 255)
	blur.ImageTransparency = 0.7
	blur.BackgroundTransparency = 1
	
	local function createOption(name, angle, icon, action)
		local btn = Instance.new("TextButton", center)
		btn.Name = name
		btn.Size = UDim2.new(0, 80, 0, 80)
		btn.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
		btn.BorderSizePixel = 0
		btn.Text = ""
		
		local uiCorner = Instance.new("UICorner", btn)
		uiCorner.CornerRadius = UDim.new(0.5, 0)
		
		local uiStroke = Instance.new("UIStroke", btn)
		uiStroke.Color = Color3.new(1, 1, 1)
		uiStroke.Thickness = 2
		uiStroke.Transparency = 0.8
		
		local iconLabel = Instance.new("TextLabel", btn)
		iconLabel.Size = UDim2.new(0.8, 0, 0.8, 0)
		iconLabel.Position = UDim2.new(0.1, 0, 0.1, 0)
		iconLabel.Text = icon
		iconLabel.TextScaled = true
		iconLabel.BackgroundTransparency = 1
		iconLabel.TextColor3 = Color3.new(1, 1, 1)
		
		local label = Instance.new("TextLabel", btn)
		label.Size = UDim2.new(1.2, 0, 0.3, 0)
		label.Position = UDim2.new(-0.1, 0, 1, 5)
		label.Text = name
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
		
		-- Position on circle
		local radius = 100
		local rad = math.rad(angle)
		btn.Position = UDim2.new(0.5, math.cos(rad) * radius - 40, 0.5, math.sin(rad) * radius - 40)
		
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
			uiStroke.Transparency = 0
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
			uiStroke.Transparency = 0.8
		end)
		
		btn.MouseButton1Click:Connect(function()
			if action == "Rename" then
				renameRemote:FireClient(player, activeKoala)
			else
				actionRemote:FireServer(action, activeKoala)
			end
			center.Visible = false
			isVisible = false
		end)
	end
	
	createOption("Cuddle", -90, "❤️", "Cuddle")
	createOption("Carry", 30, "🤲", "Carry")
	createOption("Rename", 150, "🏷️", "Rename")
	
	return center
end
local function showWheel(koala)
	if not wheelGui then wheelGui = createWheel() end
	activeKoala = koala
	wheelGui.Visible = true
	isVisible = true
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = mouse.Target
		if target then
			local koala = target:FindFirstAncestorOfClass("Model")
			if koala and (koala.Name:find("Koala") or koala.Name:find("KK") or game:GetService("CollectionService"):HasTag(koala, "KoalaNPC")) then
				-- Check distance
				local dist = (player.Character.HumanoidRootPart.Position - target.Position).Magnitude
				if dist < 15 then
					showWheel(koala)
				end
			elseif isVisible then
				wheelGui.Visible = false
				isVisible = false
			end
		elseif isVisible then
			wheelGui.Visible = false
			isVisible = false
		end
	end
end)
