local CarryService = {}
-- local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager) -- Removed for Decoupling
function CarryService.Initialize()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")
	
	koalaAction.OnServerEvent:Connect(function(player, action, targetKoala)
		if action == "Carry" then
			CarryService.PickUp(player, targetKoala)
		elseif action == "Drop" then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				-- Drop in front of player, slightly down
				local dropPos = char.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, -3)
				CarryService.Drop(player, dropPos)
			end
		end
	end)

	-- Handle RequestCuddle
	local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
	local requestCuddle = signals and signals:FindFirstChild("RequestCuddle")
	if requestCuddle then
		requestCuddle.Event:Connect(function(player, koala)
			CarryService.PerformCuddle(player, koala)
		end)
	end
	print("[CarryService] Initialized.")
end
local function setArms(player, hold)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end
	
	local function updateMotor(motor, targetC0)
		if motor and motor:IsA("Motor6D") then
			pcall(function()
				motor.C0 = targetC0
			end)
		end
	end
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	if isR15 then
		local rArm = char:FindFirstChild("RightUpperArm")
		local lArm = char:FindFirstChild("LeftUpperArm")
		if rArm and lArm then
			updateMotor(rArm:FindFirstChild("RightShoulder"), hold and CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(60), 0, math.rad(-20)) or CFrame.new(1, 0.5, 0))
			updateMotor(lArm:FindFirstChild("LeftShoulder"), hold and CFrame.new(-1, 0.5, 0) * CFrame.Angles(math.rad(60), 0, math.rad(20)) or CFrame.new(-1, 0.5, 0))
		end
	else
		-- R6
		local tor = char:FindFirstChild("Torso")
		if tor then
			updateMotor(tor:FindFirstChild("Right Shoulder"), hold and CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), math.rad(70)) or CFrame.new(1, 0.5, 0))
			updateMotor(tor:FindFirstChild("Left Shoulder"), hold and CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-70)) or CFrame.new(-1, 0.5, 0))
		end
	end
end
function CarryService.PickUp(player, targetModel, weldTarget, isCuddle)
	print("[CarryService] PickUp called for " .. player.Name .. " target: " .. (targetModel and targetModel.Name or "nil"))
	local character = player.Character
	if not character then 
		print("[CarryService] ❌ No character found for " .. player.Name)
		return 
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then 
		print("[CarryService] ❌ Missing rootPart or humanoid")
		return 
	end
	
	-- Force unequip other tools
	humanoid:UnequipTools()
	
	-- Rotate Arms
	pcall(function() setArms(player, true) end)
	
	-- Disable target AI/Physics
	targetModel:SetAttribute("AI_Disabled", true)
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChildOfClass("Part")
	if not targetRoot then 
		print("[CarryService] ❌ No root part found for target model")
		return 
	end
	
	-- Position target
	if weldTarget then
		targetModel:PivotTo(weldTarget.CFrame)
	elseif isCuddle then
		-- Centered "Hug" Position
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0, -0.2, -0.7) * CFrame.Angles(0, math.rad(180), 0))
	else
		-- Side-Carry Position: Lower, to the right, and rotated 90 degrees
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0.7, -0.4, -0.6) * CFrame.Angles(0, math.rad(90), 0))
	end
	
	print("[CarryService] Parts setup starting...")
	-- Make parts ghost-like and weightless
	for _, p in pairs(targetModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Massless = true
			p.Anchored = false
			-- Ensure visible
			p.Transparency = 0
			if p.Name == "HumanoidRootPart" then p.Transparency = 1 end
			
			-- If in a crate, maybe hide or shrink (optional visual flavor)
			if weldTarget then
				-- p.Transparency = 1
				if p.Name == "SelectionBox" then p:Destroy() end
			end
		elseif p:IsA("Decal") or p:IsA("Texture") then
			-- if weldTarget then p.Transparency = 1 end
		end
	end
	
	print("--- " .. player.Name .. " PICKED UP " .. targetModel.Name .. " ---")
	
	-- Create Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = weldTarget or rootPart
	weld.Part1 = targetRoot
	weld.Parent = targetRoot
	
	-- Disable target physics
	local targetHum = targetModel:FindFirstChild("Humanoid")
	if targetHum then
		targetHum.PlatformStand = true
	end
	
	player:SetAttribute("Carrying", targetModel.Name)
	targetModel:SetAttribute("IsBeingCarried", true)
	targetModel:SetAttribute("FollowingPlayer", nil) -- Clear follower status when picked up
	if weldTarget then
		targetModel:SetAttribute("Crated", true)
	end
end
function CarryService.PerformCuddle(player, koala)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not hum then return end
	
	-- Root player
	local oldSpeed = hum.WalkSpeed
	local oldJump = hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	
	-- Pick up in "Cuddle" position
	CarryService.PickUp(player, koala, nil, true)
	
	task.wait(2)
	
	-- Drop
	local dropPos = char.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, -1.5)
	CarryService.Drop(player, dropPos)
	
	-- Restore player
	hum.WalkSpeed = oldSpeed
	hum.JumpPower = oldJump
end
function CarryService.Drop(player, dropCFrame, explicitExhibitName)
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local carryingName = player:GetAttribute("Carrying")
	if not carryingName then return end
	
	-- Find the carried model in the workspace by checking attribute
	local targetModel = nil
	for _, m in pairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m.Name == carryingName and m:GetAttribute("IsBeingCarried") then
			targetModel = m
			break
		end
	end
	
	if targetModel then
		-- 1. Identify Exhibit First
		local exhibitName = explicitExhibitName
		local dropParent = nil
		
		-- If client didn't send explicit name, fallback to spatial search
		if not exhibitName then
			for _, obj in pairs(workspace:GetDescendants()) do
				if obj.Name == "Ground" and (obj.Position - dropCFrame.Position).Magnitude < 25 then
					exhibitName = obj.Parent.Name
					dropParent = obj.Parent
					break
				end
			end
		else
			dropParent = workspace:FindFirstChild(exhibitName)
		end
		
		-- 2. Validate Exhibit State (Safety Check)
		if exhibitName and dropParent then
			if not dropParent:GetAttribute("IsRepaired") then
				local playerGui = player:FindFirstChild("PlayerGui")
				local tutorialUI = playerGui and playerGui:FindFirstChild("TutorialUI")
				local statusLabel = tutorialUI and tutorialUI:FindFirstChild("Status")
				if statusLabel then
					statusLabel.Text = "⚠️ You must repair the exhibit before placing koalas!"
					statusLabel.Visible = true
					task.delay(5, function() statusLabel.Visible = false end)
				end
				return -- EXIT: Keep koala in inventory/crate
			end
		end
		-- Clean Arms
		pcall(function() setArms(player, false) end)
		player:SetAttribute("Carrying", nil)
		-- Clean Respawn!
		-- Find a nice spawn point (center of exhibit if possible)
		local spawnPos = dropCFrame.Position
		if dropParent and dropParent:FindFirstChild("Ground") then
			local g = dropParent.Ground
			
			-- Raycast to find the true terrain/surface height
			local rayOrigin = Vector3.new(g.Position.X, g.Position.Y + 50, g.Position.Z)
			local rayDirection = Vector3.new(0, -100, 0)
			
			local rayParams = RaycastParams.new()
			-- Exclude the dropping player and the carried model
			rayParams.FilterDescendantsInstances = {player.Character, targetModel}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			
			local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
			if result then
				spawnPos = result.Position
			else
				-- Fallback if raycast fails
				spawnPos = Vector3.new(g.Position.X, g.Position.Y + (g.Size.Y / 2), g.Position.Z)
			end
		end
		local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
		local requestRespawn = signals and signals:FindFirstChild("RequestRespawn")
		if requestRespawn then
			print("[CarryService] Firing RequestRespawn for " .. targetModel.Name)
			requestRespawn:Fire(targetModel, spawnPos, dropParent)
		else
			warn("[CarryService] RequestRespawn signal not found!")
		end
		
		-- Tutorial Reward Logic
		if exhibitName == "TutorialExhibit_Workspace" and carryingName == "KK" then
			local hasExhibit = player:FindFirstChild("HasExhibit")
			
			-- Always fire quest update and clear it, to prevent stuck UI
			local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
			if signals and signals:FindFirstChild("UpdateQuest") then
				signals.UpdateQuest:Fire(player, "🎉 KK is Home! You completed the first rescue!")
				
				-- Clear quest after 8 seconds (longer for first one)
				task.delay(8, function()
					signals.UpdateQuest:Fire(player, "")
				end)
			end
			
			-- Reward only if first time
			if hasExhibit and not hasExhibit.Value then
				local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
				local grantCurrency = signals and signals:FindFirstChild("GrantCurrency")
				if grantCurrency then
					grantCurrency:Fire(player, 500, "Cash")
				else
					leaderstats.Cash.Value += 500
				end
				hasExhibit.Value = true
				print("Reward given and Exhibit Owned by " .. player.Name)
			end
		end
	end
end
return CarryService
