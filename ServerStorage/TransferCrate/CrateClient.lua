local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent
local remote = tool:WaitForChild("CrateAction")

local COOLDOWN = 1.0 -- Increased cooldown to prevent double clicks
local lastAction = 0

local function getExhibitAtPosition(pos)
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit.Name:find("_Workspace") then
			local ground = exhibit:FindFirstChild("Ground")
			if ground then
				local diff = pos - ground.Position
				-- Check if position is within X/Z bounds of the ground part
				if math.abs(diff.X) <= (ground.Size.X / 2) + 2 and math.abs(diff.Z) <= (ground.Size.Z / 2) + 2 then
					return exhibit
				end
			end
		end
	end
	return nil
end

tool.Activated:Connect(function()
	if tick() - lastAction < COOLDOWN then return end
	
	local isCarrying = player:GetAttribute("Carrying") ~= nil
	
	if isCarrying then
		-- Use the player's position or the mouse hit position to find the exhibit
		-- Checking mouse hit first, then falling back to player position
		local exhibit = getExhibitAtPosition(mouse.Hit.Position) or getExhibitAtPosition(player.Character.PrimaryPart.Position)
		
		if exhibit then
			lastAction = tick()
			remote:FireServer("Drop", {pos = mouse.Hit.Position, exhibitName = exhibit.Name})
		else
			-- Provide some client-side feedback
			print("Must be inside or clicking an Exhibit to release the koala!")
		end
	else
		lastAction = tick()
		remote:FireServer("PickUp")
	end
end)
