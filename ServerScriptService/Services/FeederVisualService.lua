local FeederVisualService = {}

-- Safely gets CFrame and Size of a Part or Model
local function getPartOrModelCFrameAndSize(instance)
	if not instance then return nil, nil end
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	elseif instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		if instance.PrimaryPart then
			cframe = instance.PrimaryPart.CFrame
		end
		return cframe, size
	end
	return nil, nil
end

-- Safely and recursively hide/show parts and models
local function setTransparencyAndCollision(instance, transparencyValue)
	if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = transparencyValue
		if instance:IsA("BasePart") then
			instance.CanCollide = false -- Always false so players don't get stuck on invisible leaves
		end
	end
	for _, child in pairs(instance:GetChildren()) do
		setTransparencyAndCollision(child, transparencyValue)
	end
end

local function updateFeederVisuals(exhibit)
	local feeder = exhibit:FindFirstChild("Feeder")
	if not feeder then return end
	
	local food = exhibit:GetAttribute("FoodLevel") or 0
	local maxFood = exhibit:GetAttribute("MaxFoodLevel") or 100
	local ratio = food / maxFood
	
	local leaf1 = feeder:FindFirstChild("Leaf1")
	local leaf2 = feeder:FindFirstChild("Leaf2")
	local leaf3 = feeder:FindFirstChild("Leaf3")
	
	print(string.format("[FeederVisual] Updating %s | Food: %d/%d | Ratio: %.2f | Found: L1:%s, L2:%s, L3:%s", 
		exhibit.Name, food, maxFood, ratio, tostring(leaf1 ~= nil), tostring(leaf2 ~= nil), tostring(leaf3 ~= nil)))
	
	-- Helper to move leaf piles to the feeder tray
	local function snapToFeeder(leafPart)
		if not leafPart then return end
		
		local feederCFrame, feederSize = getPartOrModelCFrameAndSize(feeder)
		local leafCFrame, leafSize = getPartOrModelCFrameAndSize(leafPart)
		
		if not feederCFrame or not leafCFrame then return end
		
		local feederTopY = feederCFrame.Position.Y + (feederSize.Y / 2)
		local leafHeight = leafSize.Y / 2
		local targetY = feederTopY + leafHeight
		
		local targetCFrame = CFrame.new(feederCFrame.Position.X, targetY, feederCFrame.Position.Z)
		
		if leafPart:IsA("BasePart") then
			leafPart.CFrame = targetCFrame
		elseif leafPart:IsA("Model") then
			leafPart:PivotTo(targetCFrame)
		end
	end

	-- Snap them to the tray every time we update (in case the feeder moved)
	snapToFeeder(leaf1)
	snapToFeeder(leaf2)
	snapToFeeder(leaf3)
	
	-- 1. Hide everything first
	if leaf1 then setTransparencyAndCollision(leaf1, 1) end
	if leaf2 then setTransparencyAndCollision(leaf2, 1) end
	if leaf3 then setTransparencyAndCollision(leaf3, 1) end
	
	-- 2. Show the correct stage based on food percentage
	if ratio > 0.8 then
		if leaf3 then setTransparencyAndCollision(leaf3, 0) end
	elseif ratio > 0.4 then
		if leaf2 then setTransparencyAndCollision(leaf2, 0) end
	elseif ratio > 0.0 then
		if leaf1 then setTransparencyAndCollision(leaf1, 0) end
	end

	-- 3. Set up the Refill Prompt
	-- Destroy any pre-existing ProximityPrompts to ensure absolute consistency
	for _, oldPrompt in ipairs(feeder:GetChildren()) do
		if oldPrompt:IsA("ProximityPrompt") then
			oldPrompt:Destroy()
		end
	end
	
	local foodText = string.format("%d%%", food)
	if maxFood > 100 then
		foodText = string.format("%d/%d", food, maxFood)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RefillPrompt"
	prompt.ActionText = "Refill Feeder 🌿"
	prompt.ObjectText = string.format("Feeder (Food: %s)", foodText)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = feeder
	
	prompt.Triggered:Connect(function(player)
		-- Check if player has the FeedBag equipped
		local char = player.Character
		local hasBag = char and char:FindFirstChild("FeedBag")
		if not hasBag then
			local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
			TycoonService.UpdateStatus(player, "⚠️ Equip your Feed Bag to refill this!")
			return
		end

		local leafCount = player:GetAttribute("LeafCount") or 0
		if leafCount <= 0 then
			local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
			TycoonService.UpdateStatus(player, "⚠️ Your Feed Bag is empty! Gather some leaves first.")
			return
		end
		
		local currentFood = exhibit:GetAttribute("FoodLevel") or 0
		local currentMaxFood = exhibit:GetAttribute("MaxFoodLevel") or 100
		
		if currentFood >= currentMaxFood then
			local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
			TycoonService.UpdateStatus(player, "✅ Feeder is already full!")
			return
		end
		
		-- Deduct 1 leaf, add exactly 20% of max capacity
		local foodPerLeaf = math.max(1, math.round(currentMaxFood * 0.2))
		player:SetAttribute("LeafCount", leafCount - 1)
		local newFood = math.min(currentMaxFood, currentFood + foodPerLeaf)
		exhibit:SetAttribute("FoodLevel", newFood)
		
		local maxLeaves = player:GetAttribute("MaxLeaves") or 5
		local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
		TycoonService.UpdateStatus(player, string.format("🌿 Refilled! Food: %d/%d (Bag: %d/%d)", newFood, currentMaxFood, leafCount - 1, maxLeaves))
	end)
end

local function setupExhibit(child)
	if child.Name:match("_Workspace$") then
		-- Make sure it has a FoodLevel attribute before attaching listener
		-- Default to MaxFoodLevel (or 100) so exhibits start with food on load/initialization.
		if child:GetAttribute("FoodLevel") == nil then
			local maxFood = child:GetAttribute("MaxFoodLevel") or 100
			child:SetAttribute("FoodLevel", maxFood)
		end
		
		-- 1. Initial visual update
		updateFeederVisuals(child)
		
		-- 2. Listen for any future changes (refilling or eating)
		child:GetAttributeChangedSignal("FoodLevel"):Connect(function()
			updateFeederVisuals(child)
		end)
		
		-- Listen for feeder child added dynamically
		child.ChildAdded:Connect(function(newChild)
			if newChild.Name == "Feeder" then
				updateFeederVisuals(child)
			end
		end)
		
		print("[FeederVisualService] Attached to " .. child.Name)
	end
end

function FeederVisualService.Initialize()
	-- Find all exhibits in the workspace
	task.spawn(function()
		-- Give the game a moment to fully load all parts/meshes
		task.wait(2) 
		
		for _, child in pairs(workspace:GetChildren()) do
			setupExhibit(child)
		end
		
		-- Handle dynamic additions (e.g. built/cloned exhibits)
		workspace.ChildAdded:Connect(function(child)
			if child:IsA("Folder") then
				task.wait() -- Wait one frame for name to settle
				setupExhibit(child)
			end
		end)
	end)
end

return FeederVisualService
