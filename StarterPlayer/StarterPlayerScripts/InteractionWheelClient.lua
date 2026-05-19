-- InteractionWheelClient.lua (StarterPlayerScripts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")

local INTERACT_DIST = 15
local currentKoala = nil
local wheelGui = nil

-- Create UI
local function createWheelUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "InteractionWheel"
	sg.Enabled = false
	sg.Parent = player:WaitForChild("PlayerGui")

	local center = Instance.new("Frame", sg)
	center.Name = "Center"
	center.Size = UDim2.new(0, 5, 0, 5)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.BackgroundTransparency = 1

	local function createOption(name, angle, icon, action)
		local btn = Instance.new("TextButton", center)
		btn.Name = name
		btn.Size = UDim2.new(0, 60, 0, 60)
		btn.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
		btn.Text = icon
		btn.TextSize = 24
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)

		-- Radial position
		local rad = math.rad(angle)
		local dist = 80
		btn.Position = UDim2.new(0, math.cos(rad) * dist, 0, math.sin(rad) * dist)

		Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
		local stroke = Instance.new("UIStroke", btn)
		stroke.Thickness = 2
		stroke.Color = Color3.new(1, 1, 1)

		local label = Instance.new("TextLabel", btn)
		label.Name = "Label"
		label.Size = UDim2.new(1.2, 0, 0.4, 0)
		label.Position = UDim2.new(-0.1, 0, 1.1, 0)
		label.Text = name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.ZIndex = 2

		btn.MouseButton1Click:Connect(function()
			sg.Enabled = false
			if currentKoala then
				if action == "Stats" then
					local inspectRequest = ReplicatedStorage:FindFirstChild("InspectRequest")
					if inspectRequest then
						inspectRequest:FireServer(currentKoala)
					end
				elseif action == "Rename" then
					local inspectRequest = ReplicatedStorage:FindFirstChild("InspectRequest")
					if inspectRequest then inspectRequest:FireServer(currentKoala) end
				else
					local actionToFire = btn:GetAttribute("CurrentAction") or action
					koalaAction:FireServer(actionToFire, currentKoala)
				end
			end
		end)

		-- Hover effect
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
		end)
	end

	createOption("Cuddle", -90, "🤗", "Cuddle")
	createOption("Carry", 0, "📦", "Carry")
	createOption("Stats", 90, "ℹ️", "Stats")
	createOption("Rename", 180, "🏷️", "Rename")
	createOption("Follow", 135, "👣", "Follow")

	-- Initialize attributes
	for _, child in pairs(center:GetChildren()) do
		child:SetAttribute("CurrentAction", child.Name)
	end

	return sg
end

wheelGui = createWheelUI()

-- Highlight handling
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.OutlineTransparency = 0.5
highlight.Enabled = false
highlight.Parent = player:WaitForChild("PlayerGui")

local modifiedGlow = nil
local originalGlowData = {}

local function restoreGlow()
	if modifiedGlow then
		modifiedGlow.OutlineColor = originalGlowData.color
		modifiedGlow.OutlineTransparency = originalGlowData.transparency
		modifiedGlow = nil
	end
end

local function applyHoverHighlight(koala)
	if not koala then
		highlight.Enabled = false
		restoreGlow()
		return
	end

	local glow = koala:FindFirstChild("GlowHighlight", true)
	if glow then
		if modifiedGlow ~= glow then
			restoreGlow()
			modifiedGlow = glow
			originalGlowData = {
				color = glow.OutlineColor,
				transparency = glow.OutlineTransparency
			}
		end
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.OutlineTransparency = 0
		highlight.Enabled = false
	else
		restoreGlow()
		highlight.Adornee = koala
		highlight.Enabled = true
	end
end

-- Raycast for koalas
local function getKoalaUnderMouse()
	local mousePos = UserInputService:GetMouseLocation()
	local ray = mouse.UnitRay

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = game:GetService("CollectionService"):GetTagged("KoalaNPC")

	local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params)
	if not result or not result.Instance then return nil end

	local target = result.Instance
	local model = target:FindFirstAncestorOfClass("Model")
	if model and game:GetService("CollectionService"):HasTag(model, "KoalaNPC") then
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			-- For carried koalas, distance is always small
			if model:GetAttribute("IsBeingCarried") then return model end

			local dist = (char.HumanoidRootPart.Position - target.Position).Magnitude
			if dist <= INTERACT_DIST then
				return model
			end
		end
	end
	return nil
end

-- Update Loop
RunService.RenderStepped:Connect(function()
	if wheelGui and wheelGui.Enabled then 
		applyHoverHighlight(currentKoala)
		return 
	end

	local koala = getKoalaUnderMouse()
	if koala then
		applyHoverHighlight(koala)
		currentKoala = koala
	else
		applyHoverHighlight(nil)
	end
end)

local function updateWheelState()
	local carrying = player:GetAttribute("Carrying")
	local carryBtn = wheelGui.Center:FindFirstChild("Carry")
	if carryBtn then
		carryBtn.Text = carrying and "📍" or "📦"
		carryBtn:SetAttribute("CurrentAction", carrying and "Drop" or "Carry")

		local label = carryBtn:FindFirstChild("Label")
		if label then
			label.Text = carrying and "Place" or "Carry"
		end
	end

	local followBtn = wheelGui.Center:FindFirstChild("Follow")
	if followBtn and currentKoala then
		local followingPlayer = currentKoala:GetAttribute("FollowingPlayer")
		local isFollowingMe = followingPlayer == player.Name

		followBtn.Text = isFollowingMe and "🛑" or "👣"
		followBtn:SetAttribute("CurrentAction", isFollowingMe and "Stay" or "Follow")

		local label = followBtn:FindFirstChild("Label")
		if label then
			label.Text = isFollowingMe and "Stay" or "Follow"
		end
	end
end

-- Click handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Don't open wheel if holding a tool (UNLESS it's a crate)
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if tool and tool.Name ~= "TransferCrate" then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		print("[WheelClient] Click/Touch detected")
		if wheelGui.Enabled then
			wheelGui.Enabled = false
		else
			local koala = getKoalaUnderMouse()
			if koala then
				print("[WheelClient] Opening wheel for " .. koala.Name)
				currentKoala = koala
				updateWheelState()
				wheelGui.Enabled = true
				wheelGui.Center.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
			else
				print("[WheelClient] No koala found under mouse")
			end
		end
	end
end)
