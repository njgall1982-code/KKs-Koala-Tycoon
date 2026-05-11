local FeederVisualService = {}

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
	local leaf1 = feeder:FindFirstChild("Leaf1")
	local leaf2 = feeder:FindFirstChild("Leaf2")
	local leaf3 = feeder:FindFirstChild("Leaf3")
	
	print(string.format("[FeederVisual] Updating %s | Food: %d | Found: L1:%s, L2:%s, L3:%s", 
		exhibit.Name, food, tostring(leaf1 ~= nil), tostring(leaf2 ~= nil), tostring(leaf3 ~= nil)))
	
	-- Helper to move leaf piles to the feeder tray
	local function snapToFeeder(leafPart)
		if not leafPart then return end
		
		-- Calculate where the top of the tray is
		local feederTopY = feeder.Position.Y + (feeder.Size.Y / 2)
		local leafHeight = leafPart.Size.Y / 2
		
		-- Move leaf to center of feeder, on top of it
		leafPart.Position = Vector3.new(feeder.Position.X, feederTopY + leafHeight, feeder.Position.Z)
	end

	-- Snap them to the tray every time we update (in case the feeder moved)
	snapToFeeder(leaf1)
	snapToFeeder(leaf2)
	snapToFeeder(leaf3)
	
	-- 1. Hide everything first
	if leaf1 then setTransparencyAndCollision(leaf1, 1) end
	if leaf2 then setTransparencyAndCollision(leaf2, 1) end
	if leaf3 then setTransparencyAndCollision(leaf3, 1) end
	
	-- 2. Show the correct stage based on food level
	if food > 80 then
		if leaf3 then setTransparencyAndCollision(leaf3, 0) end
	elseif food > 40 then
		if leaf2 then setTransparencyAndCollision(leaf2, 0) end
	elseif food > 0 then
		if leaf1 then setTransparencyAndCollision(leaf1, 0) end
	end
end

function FeederVisualService.Initialize()
	-- Find all exhibits in the workspace
	task.spawn(function()
		-- Give the game a moment to fully load all parts/meshes
		task.wait(2) 
		
		for _, child in pairs(workspace:GetChildren()) do
			if child.Name:match("_Workspace$") then
				
				-- Make sure it has a FoodLevel attribute before attaching listener
				if child:GetAttribute("FoodLevel") == nil then
					child:SetAttribute("FoodLevel", 0)
				end
				
				-- 1. Initial visual update
				updateFeederVisuals(child)
				
				-- 2. Listen for any future changes (refilling or eating)
				child:GetAttributeChangedSignal("FoodLevel"):Connect(function()
					updateFeederVisuals(child)
				end)
				
				print("[FeederVisualService] Attached to " .. child.Name)
			end
		end
	end)
end

return FeederVisualService
