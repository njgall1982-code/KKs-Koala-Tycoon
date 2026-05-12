local HungerService = {}
local RunService = game:GetService("RunService")
-- Config
local HUNGER_TICK_INTERVAL = 60 -- Every 60 seconds
local FOOD_LOSS_PER_TICK = 5   -- Lose 5% food per minute
function HungerService.Initialize()
	-- Initialize exhibits with default attributes if missing
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			if exhibit:GetAttribute("MaxKoalas") == nil then
				exhibit:SetAttribute("MaxKoalas", 10)
			end
			if exhibit:GetAttribute("MaxFoodLevel") == nil then
				exhibit:SetAttribute("MaxFoodLevel", 100)
			end
			if exhibit:GetAttribute("ExhibitLevel") == nil then
				exhibit:SetAttribute("ExhibitLevel", 1)
			end
			if exhibit:GetAttribute("FeederLevel") == nil then
				exhibit:SetAttribute("FeederLevel", 1)
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(HUNGER_TICK_INTERVAL)
			HungerService.DepleteAllExhibits()
		end
	end)
	print("[HungerService] Initialized with dynamic scaling.")
end
function HungerService.DepleteAllExhibits()
	local CollectionService = game:GetService("CollectionService")

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			local currentFood = exhibit:GetAttribute("FoodLevel") or 0
			
			if currentFood > 0 then
				-- Count koalas in this exhibit
				local koalaCount = 0
				for _, child in ipairs(exhibit:GetChildren()) do
					if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
						koalaCount += 1
					end
				end

				-- Calculate loss: 1% base + 2% per koala
				local loss = 1 + (koalaCount * 2)
				local newFood = math.max(0, currentFood - loss)
				
				exhibit:SetAttribute("FoodLevel", newFood)

				if newFood == 0 then
					print("[HungerService] Exhibit " .. exhibit.Name .. " is now EMPTY! Revenue will stop.")
				end
			end
		end
	end
end
return HungerService
