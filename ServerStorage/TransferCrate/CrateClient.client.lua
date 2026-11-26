local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	
	-- Verify tool is currently held in character
	if not player.Character or tool.Parent ~= player.Character then return end
	
	local rootPart = player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart")
	local playerPos = rootPart and rootPart.Position
	local hitPos = mouse and mouse.Hit and mouse.Hit.Position

	-- Use mouse hit position first, then fall back to player position
	local exhibit = (hitPos and getExhibitAtPosition(hitPos)) or (playerPos and getExhibitAtPosition(playerPos))
	
	if exhibit then
		lastAction = tick()
		local targetPos = (hitPos and getExhibitAtPosition(hitPos) and hitPos) or playerPos
		remote:FireServer("Drop", {pos = targetPos, exhibitName = exhibit.Name})
	else
		-- Provide helpful on-screen feedback
		local playerGui = player:FindFirstChild("PlayerGui")
		local tutorialUI = playerGui and playerGui:FindFirstChild("TutorialUI")
		local statusLabel = tutorialUI and tutorialUI:FindFirstChild("Status")
		if statusLabel then
			statusLabel.Text = "⚠️ Stand inside or click an Exhibit to release the koala!"
			statusLabel.Visible = true
			task.delay(4, function() statusLabel.Visible = false end)
		else
			print("Must be inside or clicking an Exhibit to release the koala!")
		end
	end
end)
