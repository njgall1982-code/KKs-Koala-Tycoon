local KoalaStatService = {}

local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Ensure remotes exist at load time
local inspectRemote = ReplicatedStorage:FindFirstChild("InspectKoala") or Instance.new("RemoteEvent", ReplicatedStorage)
inspectRemote.Name = "InspectKoala"

local renameRemote = ReplicatedStorage:FindFirstChild("RenameKoala") or Instance.new("RemoteEvent", ReplicatedStorage)
renameRemote.Name = "RenameKoala"

local inspectRequest = ReplicatedStorage:FindFirstChild("InspectRequest") or Instance.new("RemoteEvent", ReplicatedStorage)
inspectRequest.Name = "InspectRequest"

function KoalaStatService.Initialize()

	-- Listen for inspect requests from tools
	inspectRequest.OnServerEvent:Connect(function(player, koala)
		if koala and (koala.Name:find("Koala") or koala.Name:find("KK") or CollectionService:HasTag(koala, "KoalaNPC")) then
			inspectRemote:FireClient(player, koala)
		end
	end)

	-- Listen for rename requests
	renameRemote.OnServerEvent:Connect(function(player, koala, newName)
		if not koala or not newName then return end

		-- Safety Check: Is it a Koala?
		if koala:IsA("Model") and (koala.Name:find("Koala") or koala.Name:find("KK") or game:GetService("CollectionService"):HasTag(koala, "KoalaNPC")) then
			KoalaStatService.RenameKoala(player, koala, newName)
		end
	end)

	-- Listen for Rename from Interaction Wheel
	local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")
	koalaAction.OnServerEvent:Connect(function(player, action, koala, data)
		if action == "Rename" and koala and data then
			-- data is the new name
			if koala:IsA("Model") and (koala.Name:find("Koala") or koala.Name:find("KK") or game:GetService("CollectionService"):HasTag(koala, "KoalaNPC")) then
				KoalaStatService.RenameKoala(player, koala, data)
			end
		end
	end)

	-- Initial scan for existing koalas
	local function onKoalaAdded(koala)
		task.wait(1) -- Wait for model to fully load/HRP to exist
		KoalaStatService.CreateNameTag(koala)
	end

	CollectionService:GetInstanceAddedSignal("KoalaNPC"):Connect(onKoalaAdded)
	for _, koala in ipairs(CollectionService:GetTagged("KoalaNPC")) do
		onKoalaAdded(koala)
	end

	print("[KoalaStatService] Initialized.")
end

function KoalaStatService.RenameKoala(player, koala, newName)
	-- Check if we need to consume a tag
	local hasBeenNamed = koala:GetAttribute("HasBeenNamed")
	if hasBeenNamed then
		local tag = player.Backpack:FindFirstChild("RenameTag") or player.Character:FindFirstChild("RenameTag")
		if tag then
			tag:Destroy() -- Consume the tag
		else
			return -- No tag, no rename!
		end
	end

	-- SAFETY FIRST: Filter the text
	local success, filteredText = pcall(function()
		local filterResult = TextService:FilterStringAsync(newName, player.UserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if success then
		-- Update the model name
		koala.Name = filteredText

		-- Store as attribute for persistence
		koala:SetAttribute("DisplayName", filteredText)
		koala:SetAttribute("HasBeenNamed", true)

		-- Update the floating nametag if it exists
		local tag = koala:FindFirstChild("NameTag", true)
		if tag then
			local label = tag:FindFirstChild("Label", true)
			if label then
				label.Text = filteredText
			end
		else
			-- Create it if it somehow doesn't exist
			KoalaStatService.CreateNameTag(koala)
		end

		print("[KoalaStatService] " .. player.Name .. " named koala: " .. filteredText)
	else
		warn("[KoalaStatService] Failed to filter name!")
	end
end

function KoalaStatService.CreateNameTag(koala)
	if koala:FindFirstChild("NameTag") then return end

	local hrp = koala:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(3, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0) -- Hover above head
	billboard.MaxDistance = 20
	billboard.Adornee = hrp
	billboard.Parent = koala

	local frame = Instance.new("Frame", billboard)
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
	frame.BackgroundTransparency = 0.3

	local uiCorner = Instance.new("UICorner", frame)
	uiCorner.CornerRadius = UDim.new(0.5, 0) -- Rounded pill shape

	local uiStroke = Instance.new("UIStroke", frame)
	uiStroke.Color = Color3.new(1, 1, 1)
	uiStroke.Transparency = 0.6
	uiStroke.Thickness = 1

	local label = Instance.new("TextLabel", frame)
	label.Name = "Label"
	label.Size = UDim2.new(0.9, 0, 0.8, 0)
	label.Position = UDim2.new(0.05, 0, 0.1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold

	-- Set initial text
	local displayName = koala:GetAttribute("DisplayName")
	label.Text = (displayName and displayName ~= "") and displayName or "Unnamed Koala"

	return billboard
end

return KoalaStatService
