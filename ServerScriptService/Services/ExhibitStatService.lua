local ExhibitStatService = {}

function ExhibitStatService.Initialize()
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit.Name:find("Exhibit_Workspace") then
			ExhibitStatService.CreateSign(exhibit)
			
			-- Listen for changes
			exhibit:GetAttributeChangedSignal("FoodLevel"):Connect(function()
				ExhibitStatService.UpdateSign(exhibit)
			end)
			exhibit:GetAttributeChangedSignal("DisplayName"):Connect(function()
				ExhibitStatService.UpdateSign(exhibit)
			end)
			
			-- Periodic refresh for koala count
			task.spawn(function()
				while true do
					task.wait(5)
					ExhibitStatService.UpdateSign(exhibit)
				end
			end)
		end
	end
	
	-- Handle Rename signal
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local renameExhibit = ReplicatedStorage:FindFirstChild("RenameExhibit")
	if renameExhibit then
		renameExhibit.OnServerEvent:Connect(function(player, target, newName)
			ExhibitStatService.RenameExhibit(player, target, newName)
		end)
	end

	print("[ExhibitStatService] Initialized.")
end

function ExhibitStatService.CreateSign(exhibit)
	local anchor = exhibit:FindFirstChild("SignAnchor") or exhibit:FindFirstChild("Ground")
	if not anchor then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatSign"
	billboard.Size = UDim2.new(6, 0, 4, 0)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = anchor

	local frame = Instance.new("Frame", billboard)
	frame.Name = "Frame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
	frame.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0.1, 0)

	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(150, 255, 150)

	local title = Instance.new("TextLabel", frame)
	title.Name = "ExhibitName"
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.Text = exhibit.Name:gsub("_Workspace", "")
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
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
	
	ExhibitStatService.UpdateSign(exhibit)
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
	local displayName = exhibit:GetAttribute("DisplayName") or exhibit.Name:gsub("_Workspace", "")

	frame.ExhibitName.Text = displayName
	frame.Stats.Text = string.format("🐨 Koalas: %d\n🥗 Food: %d%%", koalaCount, food)

	-- Color change based on food
	if food < 20 then
		frame.Stats.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		frame.Stats.TextColor3 = Color3.fromRGB(150, 255, 150)
	end
end

function ExhibitStatService.RenameExhibit(player, exhibit, newName)
	if not exhibit or not newName then return end
	
	-- Basic filter (Roblox will filter automatically on set, but we handle it clean)
	local TextService = game:GetService("TextService")
	local success, filteredText = pcall(function()
		local result = TextService:FilterStringAsync(newName, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
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
