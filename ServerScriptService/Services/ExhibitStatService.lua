local ExhibitStatService = {}

local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

function ExhibitStatService.Initialize()
	-- Look for all exhibits and create signs
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			ExhibitStatService.CreateSign(exhibit)
		end
	end

	-- Periodically update all signs
	task.spawn(function()
		while true do
			task.wait(2) -- Update every 2 seconds
			for _, exhibit in ipairs(workspace:GetChildren()) do
				if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
					ExhibitStatService.UpdateSign(exhibit)
				end
			end
		end
	end)

	print("[ExhibitStatService] Initialized.")
	
	-- Listen for Rename requests from clients
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remote = ReplicatedStorage:WaitForChild("RenameExhibit")
	remote.OnServerEvent:Connect(function(player, exhibitPath, newName)
		-- Security: The client sends a path string, we find the actual folder
		local pathParts = string.split(exhibitPath, ".")
		local target = game
		for _, part in ipairs(pathParts) do
			target = target:FindFirstChild(part)
			if not target then break end
		end
		
		if target and target:IsA("Folder") and target.Name:find("_Workspace") then
			ExhibitStatService.RenameExhibit(player, target, newName)
		end
	end)
end

function ExhibitStatService.CreateSign(exhibit)
	-- Look for the board we just placed
	local anchor = exhibit:FindFirstChild("SignAnchor")
	if not anchor then return end
	
	-- Add a ProximityPrompt to the board for Management
	local prompt = anchor:FindFirstChild("ManagePrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "ManagePrompt"
	prompt.ActionText = "Manage Exhibit ⚙️"
	prompt.ObjectText = exhibit:GetAttribute("DisplayName") or exhibit.Name:gsub("_Workspace", "")
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = anchor
	
	prompt.Triggered:Connect(function(player)
		-- Fire a local event or signal to open the Management UI
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remote = ReplicatedStorage:FindFirstChild("OpenExhibitManage")
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = "OpenExhibitManage"
			remote.Parent = ReplicatedStorage
		end
		remote:FireClient(player, exhibit:GetFullName())
	end)
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatSign"
	billboard.Size = UDim2.new(8, 0, 4, 0) -- Measured in STUDS now
	billboard.Adornee = anchor
	billboard.ExtentsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 50
	billboard.Parent = anchor

	-- Premium Background (Glassmorphism)
	local frame = Instance.new("Frame", billboard)
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0

	local uiCorner = Instance.new("UICorner", frame)
	uiCorner.CornerRadius = UDim.new(0, 12)

	-- Add a subtle border
	local uiStroke = Instance.new("UIStroke", frame)
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.Transparency = 0.8
	uiStroke.Thickness = 2

	local title = Instance.new("TextLabel", frame)
	title.Name = "ExhibitName"
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Position = UDim2.new(0, 0, 0.05, 0)
	title.Text = exhibit:GetAttribute("DisplayName") or exhibit.Name:gsub("_Workspace", "")
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.BackgroundTransparency = 1

	local stats = Instance.new("TextLabel", frame)
	stats.Name = "Stats"
	stats.Size = UDim2.new(1, 0, 0.5, 0)
	stats.Position = UDim2.new(0, 0, 0.45, 0)
	stats.Text = "Loading..."
	stats.TextColor3 = Color3.fromRGB(150, 255, 150)
	stats.Font = Enum.Font.GothamMedium
	stats.TextSize = 16
	stats.BackgroundTransparency = 1
	stats.TextYAlignment = Enum.TextYAlignment.Top
end

function ExhibitStatService.UpdateSign(exhibit)
	local anchor = exhibit:FindFirstChild("SignAnchor") or exhibit:FindFirstChild("Ground")
	if not anchor then return end

	local billboard = anchor:FindFirstChild("StatSign")
	if not billboard then return end

	local frame = billboard:FindFirstChild("Frame")
	if not frame then return end

	-- Calculate stats
	local koalaCount = 0
	local CollectionService = game:GetService("CollectionService")
	
	for _, child in ipairs(exhibit:GetChildren()) do
		if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
			koalaCount += 1
		end
	end

	local food = exhibit:GetAttribute("FoodLevel") or 0
	local maxFood = exhibit:GetAttribute("MaxFoodLevel") or 100
	local maxKoalas = exhibit:GetAttribute("MaxKoalas") or 10
	local displayName = exhibit:GetAttribute("DisplayName") or exhibit.Name:gsub("_Workspace", "")

	frame.ExhibitName.Text = displayName
	
	local foodText = string.format("%d%%", food)
	if maxFood > 100 then
		foodText = string.format("%d/%d", food, maxFood)
	end
	
	frame.Stats.Text = string.format("🐨 Koalas: %d/%d\n🥗 Food: %s", koalaCount, maxKoalas, foodText)

	-- Color change based on food
	if food < 20 then
		frame.Stats.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red alert
	elseif food < 50 then
		frame.Stats.TextColor3 = Color3.fromRGB(255, 200, 100) -- Yellow warning
	else
		frame.Stats.TextColor3 = Color3.fromRGB(200, 255, 200) -- Green good
	end
end

-- Server-side naming (safely filtered)
function ExhibitStatService.RenameExhibit(player, exhibit, newName)
	if not exhibit or not newName then return end

	-- SAFETY FIRST: Filter the text for Roblox
	local success, filteredText = pcall(function()
		local filterResult = TextService:FilterStringAsync(newName, player.UserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if success then
		exhibit:SetAttribute("DisplayName", filteredText)
		ExhibitStatService.UpdateSign(exhibit)
		print("[ExhibitStatService] " .. player.Name .. " renamed exhibit to: " .. filteredText)
	else
		warn("[ExhibitStatService] Failed to filter text!")
	end
end

return ExhibitStatService
