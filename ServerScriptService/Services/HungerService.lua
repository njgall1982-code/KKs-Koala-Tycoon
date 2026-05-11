local HungerService = {}
local RunService = game:GetService("RunService")
-- Config
local HUNGER_TICK_INTERVAL = 60 -- Every 60 seconds
local FOOD_LOSS_PER_TICK = 5   -- Lose 5% food per minute
function HungerService.Initialize()
	task.spawn(function()
		while true do
			task.wait(HUNGER_TICK_INTERVAL)
			HungerService.DepleteAllExhibits()
		end
	end)
	print("[HungerService] Initialized.")
end
function HungerService.DepleteAllExhibits()
	-- Find all folders ending in _Workspace in the workspace
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			local currentFood = exhibit:GetAttribute("FoodLevel") or 0
			if currentFood > 0 then
				local newFood = math.max(0, currentFood - FOOD_LOSS_PER_TICK)
				exhibit:SetAttribute("FoodLevel", newFood)
				if newFood == 0 then
					print("[HungerService] Exhibit " .. exhibit.Name .. " is now EMPTY! Revenue will stop.")
				end
			end
		end
	end
end
return HungerService
