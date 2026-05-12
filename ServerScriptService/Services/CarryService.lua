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

	-- Handle CuddleRequest
	local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
	local cuddleRequest = signals and signals:FindFirstChild("CuddleRequest")
	if cuddleRequest then
		cuddleRequest.Event:Connect(function(player, koala)
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
	print("[CarryService] 🟢 STARTING PICKUP for " .. player.Name)
	print("[CarryService] PickUp called for " .. player.Name .. " target: " .. (targetModel and targetModel.Name or "nil"))
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	
	-- Force unequip other tools
	humanoid:UnequipTools()
	
	-- Rotate Arms
	pcall(function() setArms(player, true) end)
	
	-- Disable target AI/Physics
	targetModel:SetAttribute("AI_Disabled", true)
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChildOfClass("Part")
	if not targetRoot then return end
	
	-- Position target
	if weldTarget then
		if weldTarget:IsA("Attachment") then
			targetModel:PivotTo(weldTarget.WorldCFrame)
		else
			targetModel:PivotTo(weldTarget.CFrame)
		end
	elseif isCuddle then
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0, -0.2, -0.7) * CFrame.Angles(0, math.rad(180), 0))
	else
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0.7, -0.4, -0.6) * CFrame.Angles(0, math.rad(90), 0))
	end
	
	-- Make parts ghost-like and weightless
	for _, p in pairs(targetModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Massless = true
			p.Anchored = false
			p.Transparency = 0
			if p.Name == "HumanoidRootPart" then p.Transparency = 1 end
		end
	end
	
	-- Create Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	local part0 = weldTarget
	if weldTarget and weldTarget:IsA("Attachment") then
		part0 = weldTarget.Parent
	end
	weld.Part0 = part0 or rootPart
	weld.Part1 = targetRoot
	weld.Parent = targetRoot
	
	-- Parent to container
	if part0 then
		targetModel.Parent = part0.Parent
	end
	
	-- Disable target physics
	local targetHum = targetModel:FindFirstChild("Humanoid")
	if targetHum then
		targetHum.PlatformStand = true
	end
	
	player:SetAttribute("Carrying", targetModel.Name)
	targetModel:SetAttribute("IsBeingCarried", true)
	targetModel:SetAttribute("FollowingPlayer", nil)
	if weldTarget then
		targetModel:SetAttribute("Crated", true)
	end
end

function CarryService.PerformCuddle(player, koala)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not hum then return end
	
	local oldSpeed = hum.WalkSpeed
	local oldJump = hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	
	CarryService.PickUp(player, koala, nil, true)
	task.wait(2)
	
	local dropPos = char.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, -1.5)
	CarryService.Drop(player, dropPos)
	
	hum.WalkSpeed = oldSpeed
	hum.JumpPower = oldJump
end

function CarryService.Drop(player, dropCFrame, explicitExhibitName)
	print("[CarryService] 🟢 STARTING DROP for " .. player.Name)
	local currentlyCarrying = player:GetAttribute("Carrying") or "NOTHING"
	print('[CarryService] Attribute "Carrying" is: ' .. currentlyCarrying)

	local character = player.Character
	if not character then return end
	
	local carryingName = player:GetAttribute("Carrying")
	if not carryingName then return end
	
	-- Find the carried model
	local searchContainers = {character, player.Backpack, workspace}
	local targetModel = nil
	
	for _, container in ipairs(searchContainers) do
		for _, m in pairs(container:GetDescendants()) do
			if m:IsA("Model") and m.Name == carryingName and m:GetAttribute("IsBeingCarried") then
				targetModel = m
				print("[CarryService] 🟢 FOUND " .. m.Name .. " inside " .. container.Name)
				break
			end
		end
		if targetModel then break end
	end
	
	if targetModel then
		local exhibitName = explicitExhibitName
		local dropParent = nil
		
		-- 1. Identify Exhibit (Optimized)
		if not exhibitName then
			for _, folder in ipairs(workspace:GetChildren()) do
				if folder:IsA("Folder") and folder.Name:find("_Workspace") then
					local ground = folder:FindFirstChild("Ground")
					if ground and (ground.Position - dropCFrame.Position).Magnitude < 35 then
						exhibitName = folder.Name
						dropParent = folder
						break
					end
				end
			end
		else
			dropParent = workspace:FindFirstChild(exhibitName)
		end

		-- 2. Validate Exhibit State
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
				return
			end

			-- Capacity Check
			local maxKoalas = dropParent:GetAttribute("MaxKoalas") or 10
			local currentKoalas = 0
			local CollectionService = game:GetService("CollectionService")
			for _, child in ipairs(dropParent:GetChildren()) do
				if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
					currentKoalas += 1
				end
			end

			if currentKoalas >= maxKoalas then
				local playerGui = player:FindFirstChild("PlayerGui")
				local tutorialUI = playerGui and playerGui:FindFirstChild("TutorialUI")
				local statusLabel = tutorialUI and tutorialUI:FindFirstChild("Status")
				if statusLabel then
					statusLabel.Text = "⚠️ Exhibit Full!"
					statusLabel.Visible = true
					task.delay(5, function() statusLabel.Visible = false end)
				end
				return
			end
		end

		-- Clean Arms
		pcall(function() setArms(player, false) end)
		player:SetAttribute("Carrying", nil)
		
		-- Respawn
		local spawnPos = dropCFrame.Position
		if dropParent and dropParent:FindFirstChild("Ground") then
			local g = dropParent.Ground
			local rayOrigin = Vector3.new(spawnPos.X, spawnPos.Y + 50, spawnPos.Z)
			local rayDirection = Vector3.new(0, -100, 0)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {player.Character, targetModel}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
			if result then spawnPos = result.Position end
		end

		local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
		local respawnRequest = signals and signals:FindFirstChild("RespawnRequest")
		if respawnRequest then
			respawnRequest:Fire(targetModel, spawnPos, dropParent)
		end
		
		-- Tutorial Reward Logic
		if exhibitName == "TutorialExhibit_Workspace" and carryingName == "KK" then
			local hasExhibit = player:FindFirstChild("HasExhibit")
			if hasExhibit and not hasExhibit.Value then
				local grantCurrency = signals and signals:FindFirstChild("GrantCurrency")
				if grantCurrency then grantCurrency:Fire(player, 500, "Cash") end
				hasExhibit.Value = true
			end
			local updateQuest = signals and signals:FindFirstChild("UpdateQuest")
			if updateQuest then
				updateQuest:Fire(player, "🎉 KK is Home!")
				task.delay(5, function() updateQuest:Fire(player, "") end)
			end
		end
	end
end

return CarryService
