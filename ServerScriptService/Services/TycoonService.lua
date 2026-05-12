local TycoonService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local signals = ServerStorage:WaitForChild("Signals")
local updateQuestSignal = signals:WaitForChild("UpdateQuest")
local forcePickupSignal = signals:WaitForChild("ForcePickup")
local showStatusSignal = signals:WaitForChild("ShowStatus")

showStatusSignal.Event:Connect(function(player, message)
	TycoonService.UpdateStatus(player, message)
end)

local playerRepairs = {}

function TycoonService.ClearProgress(player)
	print("[TycoonService] Clearing repair progress for: " .. player.Name)
	for key, _ in pairs(playerRepairs) do
		if key:find("^" .. player.UserId .. "_") then
			playerRepairs[key] = nil
		end
	end
end

function TycoonService.UpdateStatus(player, message)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	local screenGui = playerGui:FindFirstChild("TutorialUI")
	if not screenGui then
		screenGui = Instance.new("ScreenGui", playerGui)
		screenGui.Name = "TutorialUI"
		local label = Instance.new("TextLabel", screenGui)
		label.Name = "Status"
		label.Size = UDim2.new(0, 500, 0, 60)
		label.Position = UDim2.new(0.5, -250, 0.05, 0)
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 0.4
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 22
		label.Font = Enum.Font.GothamBold
		label.TextWrapped = true
		label.Parent = screenGui
	end
	screenGui.Status.Visible = true
	screenGui.Status.Text = message

	task.delay(10, function()
		if screenGui:FindFirstChild("Status") and screenGui.Status.Text == message then
			screenGui.Status.Visible = false
		end
	end)
end

function TycoonService.HandleRepair(player, exhibit, part, toolRequired)
	local char = player.Character
	local tool = char and char:FindFirstChild(toolRequired)

	if not tool then
		TycoonService.UpdateStatus(player, "⚠️ Equip your " .. toolRequired .. " to fix this!")
		return
	end

	local repairKey = player.UserId .. "_" .. exhibit.Name .. "_" .. part.Name
	playerRepairs[repairKey] = (playerRepairs[repairKey] or 0) + 1

	if playerRepairs[repairKey] >= 1 then
		TycoonService.UpdateStatus(player, "✅ Repaired " .. part.Name .. "!")

		-- Visual Repair
		if part.Name == "BrokenFence" then
			part.Transparency = 0
			part.CanCollide = true
			for _, child in pairs(part:GetChildren()) do
				if child.Name:find("Visual") or child.Name:find("Broken") then
					child:Destroy()
				end
			end
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt:Destroy() end
		elseif part.Name == "CollapsedShelter" or part.Name == "Base" then
			exhibit:SetAttribute("ShelterFixed", true)
			local model = part.Parent
			model:SetAttribute("IsFixed", true)

			-- Reposition pieces into a "Fixed" shelter
			local base = model:FindFirstChild("Base")
			local r1 = model:FindFirstChild("RoofPiece1")
			local r2 = model:FindFirstChild("RoofPiece2")

			if base and r1 and r2 then
				local center = base.Position
				base.Color = Color3.fromRGB(101, 67, 33)

				r1.CFrame = CFrame.new(center + Vector3.new(2, 3, 0)) * CFrame.Angles(0, 0, math.rad(-45))
				r2.CFrame = CFrame.new(center + Vector3.new(-2, 3, 0)) * CFrame.Angles(0, 0, math.rad(45))

				r1.Color = Color3.fromRGB(101, 67, 33)
				r2.Color = Color3.fromRGB(101, 67, 33)

				r1.Anchored = true
				r2.Anchored = true
			end

			local prompt = base:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt:Destroy() end

			-- Final Snap Alignment
			base.CFrame = base.CFrame -- Ensure it's where it should be
			base.Anchored = true
		end

		-- Check if exhibit is fully repaired
		TycoonService.CheckExhibitStatus(exhibit)
	else
		TycoonService.UpdateStatus(player, "🔨 Fixing... (" .. playerRepairs[repairKey] .. "/1)")
	end
end

function TycoonService.CheckExhibitStatus(exhibit)
	if exhibit.Name == "TutorialExhibit_Workspace" then
		local fence = exhibit:FindFirstChild("BrokenFence")
		if fence and fence.Transparency == 0 then
			exhibit:SetAttribute("IsRepaired", true)
		end
	elseif exhibit.Name == "SecondExhibit_Workspace" then
		local fence = exhibit:FindFirstChild("BrokenFence")
		local shelter = exhibit:FindFirstChild("CollapsedShelter")
		if (not fence or fence.Transparency == 0) and (not shelter or shelter:GetAttribute("IsFixed")) then
			exhibit:SetAttribute("IsRepaired", true)
		end
	end
end

function TycoonService.InitializePlayer(player)
	-- Restore visuals based on attributes
	local ex1 = workspace:FindFirstChild("TutorialExhibit_Workspace")
	if ex1 and ex1:GetAttribute("IsRepaired") then
		local fence = ex1:FindFirstChild("BrokenFence")
		if fence then
			fence.Transparency = 0
			fence.CanCollide = true
			local p = fence:FindFirstChildOfClass("ProximityPrompt")
			if p then p:Destroy() end
		end
	end

	local ex2 = workspace:FindFirstChild("SecondExhibit_Workspace")
	if ex2 and ex2:GetAttribute("IsRepaired") then
		local fence = ex2:FindFirstChild("BrokenFence")
		if fence then
			fence.Transparency = 0
			fence.CanCollide = true
			local p = fence:FindFirstChildOfClass("ProximityPrompt")
			if p then p:Destroy() end
		end
		local shelter = ex2:FindFirstChild("CollapsedShelter")
		if shelter and shelter:GetAttribute("IsFixed") then
			-- Logic to snap pieces into place
			local base = shelter:FindFirstChild("Base")
			local r1 = shelter:FindFirstChild("RoofPiece1")
			local r2 = shelter:FindFirstChild("RoofPiece2")
			if base and r1 and r2 then
				local center = base.Position
				base.Color = Color3.fromRGB(101, 67, 33)
				r1.CFrame = CFrame.new(center + Vector3.new(2, 3, 0)) * CFrame.Angles(0, 0, math.rad(-45))
				r2.CFrame = CFrame.new(center + Vector3.new(-2, 3, 0)) * CFrame.Angles(0, 0, math.rad(45))
				r1.Color = Color3.fromRGB(101, 67, 33)
				r2.Color = Color3.fromRGB(101, 67, 33)
				r1.Anchored = true
				r2.Anchored = true
			end
		end
	end
end

function TycoonService.HandleVetInteraction(player)
	print("[TycoonService] HandleVetInteraction entered for " .. player.Name)
	local ex1 = workspace:FindFirstChild("TutorialExhibit_Workspace")
	local isRepaired = ex1 and ex1:GetAttribute("IsRepaired")

	if not isRepaired then
		print("[TycoonService] Vet interaction: Exhibit 1 not repaired. Forcing check.")
		TycoonService.CheckExhibitStatus(ex1) -- Double check just in case
		isRepaired = ex1:GetAttribute("IsRepaired")
	end

	if not isRepaired then
		TycoonService.UpdateStatus(player, "👨‍⚕️ Vet: Almost there! Finish fixing those fence boards first.")
		return
	end

	if ex1:FindFirstChild("KK") or player:GetAttribute("Carrying") == "KK" or workspace:FindFirstChild("KK") then
		TycoonService.UpdateStatus(player, "👨‍⚕️ Vet: You already have KK! Go take care of him.")
		-- If Vet is still here for some reason, clean him up
		task.delay(1, function()
			local vet = workspace:FindFirstChild("HeadVet")
			if vet then vet:Destroy() end
		end)
		return
	end

	local folder = ServerStorage:FindFirstChild("Koalas to pick from")
	local kkTemplate = folder and folder:FindFirstChild("Koala")
	if kkTemplate then
		local kk = kkTemplate:Clone()
		kk.Name = "KK"
		kk:SetAttribute("DisplayName", "KK")

		CollectionService:AddTag(kk, "KoalaNPC")
		kk:SetAttribute("HomeExhibit", "TutorialExhibit_Workspace")
		kk.Parent = workspace

		task.wait(0.1)

		-- EVENT BUS: Force Pickup
		forcePickupSignal:Fire(player, kk)

		TycoonService.UpdateStatus(player, "👨‍⚕️ Vet: Carry KK to the exhibit. Click KK and use 'Place' to put him home.")

		-- Reward for completing the repair quest
		local grantCurrency = signals:FindFirstChild("GrantCurrency")
		if grantCurrency then
			grantCurrency:Fire(player, 100, "Cash")
		end

		-- EVENT BUS: Update Quest
		updateQuestSignal:Fire(player, "🏠 Carry KK to his Exhibit. Click him and use the 'Place' button.")

		task.delay(1, function()
			local vet = workspace:FindFirstChild("HeadVet")
			if vet then vet:Destroy() end
		end)
	end
end

function TycoonService.Initialize()
	print("[TycoonService] Initialize() called")
	local ex1 = workspace:FindFirstChild("TutorialExhibit_Workspace")
	if ex1 then
		local fence = ex1:FindFirstChild("BrokenFence")
		if fence then
			for _, oldP in pairs(fence:GetChildren()) do
				if oldP:IsA("ProximityPrompt") then oldP:Destroy() end
			end

			local prompt = Instance.new("ProximityPrompt", fence)
			prompt.ActionText = "Repair Fence 🔨"
			prompt.HoldDuration = 0
			prompt.Triggered:Connect(function(player) TycoonService.HandleRepair(player, ex1, fence, "WoodenHammer") end)
		end
	end

	local ex2 = workspace:FindFirstChild("SecondExhibit_Workspace")
	if ex2 then
		local fence = ex2:FindFirstChild("BrokenFence")
		if fence then
			for _, oldP in pairs(fence:GetChildren()) do
				if oldP:IsA("ProximityPrompt") then oldP:Destroy() end
			end

			local prompt = Instance.new("ProximityPrompt", fence)
			prompt.ActionText = "Repair Fence 🔨"
			prompt.HoldDuration = 1.0
			prompt.Triggered:Connect(function(player) TycoonService.HandleRepair(player, ex2, fence, "WoodenHammer") end)
		end

		local shelter = ex2:FindFirstChild("CollapsedShelter")
		if shelter then
			local base = shelter:FindFirstChild("Base")
			if base then
				for _, oldP in pairs(base:GetChildren()) do
					if oldP:IsA("ProximityPrompt") then oldP:Destroy() end
				end

				local prompt = Instance.new("ProximityPrompt", base)
				prompt.ActionText = "Repair Shelter 🔨"
				prompt.HoldDuration = 1.5
				prompt.Triggered:Connect(function(player) TycoonService.HandleRepair(player, ex2, base, "WoodenHammer") end)
			end
		end

		local veg = ex2:FindFirstChild("OvergrownVegetation")
		if veg then
			for _, bush in pairs(veg:GetChildren()) do
				for _, oldP in pairs(bush:GetChildren()) do
					if oldP:IsA("ProximityPrompt") then oldP:Destroy() end
				end

				local prompt = Instance.new("ProximityPrompt", bush)
				prompt.Name = "ClearPrompt"
				prompt.ActionText = "Clear Weeds 🧹"
				prompt.HoldDuration = 1.0
				prompt.Triggered:Connect(function(player)
					local char = player.Character
					local tool = char and char:FindFirstChild("Shovel")
					if tool then
						prompt.Enabled = false 
						bush.Transparency = 1
						bush.CanCollide = false
						task.delay(0.5, function() bush:Destroy() end)
						TycoonService.UpdateStatus(player, "🧹 Weed cleared!")
					else
						TycoonService.UpdateStatus(player, "⚠️ Equip your Shovel to clear weeds!")
					end
				end)
			end
		end
	end

	local vet = workspace:FindFirstChild("HeadVet") or ServerStorage:FindFirstChild("HeadVet")
	if vet then
		local hrp = vet:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, oldP in pairs(hrp:GetChildren()) do
				if oldP:IsA("ProximityPrompt") then oldP:Destroy() end
			end

			local p = Instance.new("ProximityPrompt")
			p.Name = "VetPrompt"
			p.ActionText = "Talk to Head Vet 👨‍⚕️"
			p.ObjectText = "Head Vet"
			p.HoldDuration = 0.5
			p.MaxActivationDistance = 15
			p.RequiresLineOfSight = false
			p.Parent = hrp

			p.Triggered:Connect(function(player) 
				TycoonService.HandleVetInteraction(player) 
			end)
		end
	end

	print("[TycoonService] Initialize() completed")
end

return TycoonService
