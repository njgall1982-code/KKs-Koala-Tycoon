local PoopBotService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local POOP_BOT_COST = 800
local WASTE_INTERVAL_MULTIPLIER = 2.0 -- Poop spawns 2x less often when an exhibit has a Poop Bot

local exhibitDocks = {}    -- [exhibit] = { dockModel, statusLight, prompt, botModel, homePos, exitPos }
local activeDispatch = {}  -- [exhibit] = boolean

local function getWasteService()
	local ok, mod = pcall(function()
		return require(ServerScriptService:WaitForChild("Services"):WaitForChild("WasteService"))
	end)
	return ok and mod or nil
end

local function getInstancePosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then return inst:GetPivot().Position end
	return nil
end

local function getFloorY(pos, exhibit, excludeModel)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if excludeModel then
		table.insert(exclude, excludeModel)
	end
	local wasteFolder = exhibit and exhibit:FindFirstChild("Waste")
	if wasteFolder then
		table.insert(exclude, wasteFolder)
	end
	rayParams.FilterDescendantsInstances = exclude

	local result = workspace:Raycast(Vector3.new(pos.X, pos.Y + 6, pos.Z), Vector3.new(0, -20, 0), rayParams)
	if result then
		return result.Position.Y + 0.24
	end
	local ground = exhibit and exhibit:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground.Position.Y + (ground.Size.Y * 0.5) + 0.24
	end
	return pos.Y
end

local function setBotVisible(botModel, visible)
	if not botModel then return end
	for _, part in ipairs(botModel:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = visible and 0 or 1
		end
	end
end

local function createRoombaBot(homeCFrame)
	local model = Instance.new("Model")
	model.Name = "PoopBot"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(1.6, 0.4, 1.6)
	hrp.Transparency = 1
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.CanTouch = false
	hrp.CanQuery = false
	hrp.CFrame = homeCFrame
	hrp.Parent = model
	model.PrimaryPart = hrp

	local function addPart(name, shape, size, color, material, offsetCFrame)
		local part = Instance.new("Part")
		part.Name = name
		if shape then part.Shape = shape end
		part.Material = material or Enum.Material.SmoothPlastic
		part.Color = color
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = hrp.CFrame * offsetCFrame
		part.Parent = model
		return part
	end

	-- Sleek Roomba disc
	addPart("Body", Enum.PartType.Cylinder, Vector3.new(0.38, 2.2, 2.2), Color3.fromRGB(42, 48, 58), Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, math.rad(90)))
	addPart("Lid", Enum.PartType.Cylinder, Vector3.new(0.09, 1.65, 1.65), Color3.fromRGB(70, 80, 95), Enum.Material.SmoothPlastic, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	addPart("StatusLight", Enum.PartType.Cylinder, Vector3.new(0.08, 0.5, 0.5), Color3.fromRGB(85, 235, 160), Enum.Material.Neon, CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)))
	addPart("Bumper", Enum.PartType.Block, Vector3.new(1.1, 0.14, 0.18), Color3.fromRGB(95, 200, 220), Enum.Material.SmoothPlastic, CFrame.new(0, -0.04, -1.08))

	setBotVisible(model, false)
	return model
end

local function glideBotTo(bot, exhibit, targetPos, speed, hugFloor)
	local startPos = bot:GetPivot().Position
	local flatTarget = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	local dist = (flatTarget - startPos).Magnitude
	if dist < 0.25 then return true end

	local stepRate = 0.03
	local stepDist = (speed or 14) * stepRate
	local steps = math.max(1, math.ceil(dist / stepDist))

	for i = 1, steps do
		if not bot.Parent then return false end
		local alpha = i / steps
		local nextXZ = startPos:Lerp(flatTarget, alpha)
		local y = hugFloor and getFloorY(nextXZ, exhibit, bot) or startPos.Y
		local nextPos = Vector3.new(nextXZ.X, y, nextXZ.Z)
		local lookTarget = Vector3.new(flatTarget.X, y, flatTarget.Z)
		if (lookTarget - nextPos).Magnitude > 0.05 then
			bot:PivotTo(CFrame.lookAt(nextPos, lookTarget))
		else
			bot:PivotTo(CFrame.new(nextPos))
		end
		task.wait(stepRate)
	end
	return true
end

local function updateDockVisualState(exhibit)
	local info = exhibitDocks[exhibit]
	if not info then return end

	local hasBot = exhibit:GetAttribute("HasPoopBot") == true
	if info.statusLight and info.statusLight.Parent then
		info.statusLight.Color = hasBot and Color3.fromRGB(85, 235, 160) or Color3.fromRGB(245, 175, 65)
	end
	if info.prompt and info.prompt.Parent then
		info.prompt.Enabled = not hasBot
	end
end

local function createDockForExhibit(exhibit)
	if exhibitDocks[exhibit] then return end
	local ground = exhibit:FindFirstChild("Ground")
	if not (ground and ground:IsA("BasePart")) then return end

	-- Clean up any pre-existing dock
	local existing = exhibit:FindFirstChild("PoopBotDock")
	if existing then existing:Destroy() end

	-- Place dock neatly along the edge of the exhibit Ground, facing inward toward the center
	local edgeOffset = Vector3.new(
		(ground.Size.X * 0.5) - 2.2,
		0,
		-(ground.Size.Z * 0.5) + 3.0
	)
	local rawPos = ground.Position + edgeOffset
	local floorY = ground.Position.Y + (ground.Size.Y * 0.5)
	local dockPos = Vector3.new(rawPos.X, floorY + 0.9, rawPos.Z)
	local centerPos = Vector3.new(ground.Position.X, dockPos.Y, ground.Position.Z)
	local dockCFrame = CFrame.lookAt(dockPos, centerPos)

	local dockModel = Instance.new("Model")
	dockModel.Name = "PoopBotDock"

	local shell = Instance.new("Part")
	shell.Name = "DockBox"
	shell.Size = Vector3.new(3.0, 1.8, 3.0)
	shell.Material = Enum.Material.SmoothPlastic
	shell.Color = Color3.fromRGB(52, 60, 74)
	shell.Anchored = true
	shell.CanCollide = true
	shell.CFrame = dockCFrame
	shell.Parent = dockModel
	dockModel.PrimaryPart = shell

	-- Dark garage opening on the front face
	local door = Instance.new("Part")
	door.Name = "GarageSlot"
	door.Size = Vector3.new(2.4, 0.75, 0.12)
	door.Material = Enum.Material.SmoothPlastic
	door.Color = Color3.fromRGB(20, 24, 30)
	door.Anchored = true
	door.CanCollide = false
	door.CFrame = dockCFrame * CFrame.new(0, -0.45, -1.51)
	door.Parent = dockModel

	-- Top trim & status light
	local cap = Instance.new("Part")
	cap.Name = "TopTrim"
	cap.Size = Vector3.new(3.2, 0.22, 3.2)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Color = Color3.fromRGB(75, 86, 104)
	cap.Anchored = true
	cap.CanCollide = false
	cap.CFrame = dockCFrame * CFrame.new(0, 0.95, 0)
	cap.Parent = dockModel

	local statusLight = Instance.new("Part")
	statusLight.Name = "StatusLight"
	statusLight.Shape = Enum.PartType.Cylinder
	statusLight.Size = Vector3.new(0.14, 0.65, 0.65)
	statusLight.Material = Enum.Material.Neon
	statusLight.Color = Color3.fromRGB(245, 175, 65)
	statusLight.Anchored = true
	statusLight.CanCollide = false
	statusLight.CFrame = dockCFrame * CFrame.new(0, 1.08, 0) * CFrame.Angles(0, 0, math.rad(90))
	statusLight.Parent = dockModel

	-- Purchase ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPoopBotPrompt"
	prompt.ActionText = string.format("Buy Poop Bot ($%d)", POOP_BOT_COST)
	prompt.ObjectText = "Poop Bot Dock 🤖"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell

	prompt.Triggered:Connect(function(player)
		if exhibit:GetAttribute("HasPoopBot") == true then return end

		local transactionRequest = Net.Signal("TransactionRequest")
		local success, err = transactionRequest:Invoke(player, POOP_BOT_COST, "BuyPoopBot_" .. exhibit.Name)
		if success then
			exhibit:SetAttribute("HasPoopBot", true)
			updateDockVisualState(exhibit)
			Net.Signal("ShowStatus"):Fire(player, "🤖 Poop Bot installed! It will keep this exhibit spotless.", Color3.fromRGB(90, 230, 120))
			PoopBotService.DispatchForExhibit(exhibit)
		else
			Net.Signal("ShowStatus"):Fire(player, string.format("⚠️ Need $%d for Poop Bot! (%s)", POOP_BOT_COST, tostring(err or "Insufficient funds")), Color3.fromRGB(255, 120, 120))
		end
	end)

	-- Hidden Roomba bot resting inside the dock
	local homePos = (dockCFrame * CFrame.new(0, -0.62, 0)).Position
	local exitPos = (dockCFrame * CFrame.new(0, -0.62, -2.6)).Position
	local homeCFrame = CFrame.lookAt(homePos, exitPos)
	local botModel = createRoombaBot(homeCFrame)
	botModel.Parent = dockModel

	dockModel.Parent = exhibit

	exhibitDocks[exhibit] = {
		dockModel = dockModel,
		statusLight = statusLight,
		prompt = prompt,
		botModel = botModel,
		homeCFrame = homeCFrame,
		homePos = homePos,
		exitPos = exitPos,
	}

	updateDockVisualState(exhibit)
	exhibit:GetAttributeChangedSignal("HasPoopBot"):Connect(function()
		updateDockVisualState(exhibit)
		if exhibit:GetAttribute("HasPoopBot") == true then
			PoopBotService.DispatchForExhibit(exhibit)
		end
	end)
end

function PoopBotService.GetWasteIntervalMultiplier(exhibit)
	if exhibit and exhibit:GetAttribute("HasPoopBot") == true then
		return WASTE_INTERVAL_MULTIPLIER
	end
	return 1.0
end

function PoopBotService.DispatchForExhibit(exhibit)
	if not exhibit or exhibit:GetAttribute("HasPoopBot") ~= true then return end
	if activeDispatch[exhibit] then return end

	local info = exhibitDocks[exhibit]
	if not info or not info.botModel or not info.botModel.Parent then return end

	local wasteService = getWasteService()
	if not wasteService then return end

	if wasteService.GetWasteCount(exhibit) == 0 then return end

	activeDispatch[exhibit] = true

	task.spawn(function()
		-- Short beat so the player sees the waste appear before the bot emerges
		task.wait(0.8)

		local bot = info.botModel
		if not bot or not bot.Parent then
			activeDispatch[exhibit] = nil
			return
		end

		-- Emerge from the dock box
		bot:PivotTo(info.homeCFrame)
		setBotVisible(bot, true)
		glideBotTo(bot, exhibit, info.exitPos, 10, false)

		-- Clean all waste currently in this exhibit
		while exhibit.Parent and exhibit:GetAttribute("HasPoopBot") == true do
			local wasteList = wasteService.GetWasteInExhibit(exhibit)
			if #wasteList == 0 then break end

			local targetWaste = wasteList[1]
			local pos = getInstancePosition(targetWaste)
			if pos then
				glideBotTo(bot, exhibit, pos, 15, true)
				if targetWaste and targetWaste.Parent then
					wasteService.CleanWaste(targetWaste, nil)
				end
				task.wait(0.3)
			else
				break
			end
		end

		-- Return to the dock box and hide back inside
		if bot.Parent then
			glideBotTo(bot, exhibit, info.exitPos, 14, true)
			glideBotTo(bot, exhibit, info.homePos, 10, false)
			bot:PivotTo(info.homeCFrame)
			setBotVisible(bot, false)
		end

		activeDispatch[exhibit] = nil
	end)
end

function PoopBotService.Initialize()
	if PoopBotService._initialized then return end
	PoopBotService._initialized = true

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			createDockForExhibit(exhibit)
		end
	end

	print("[PoopBotService] Initialized (Per-exhibit Poop Bot docks ready).")
end

return PoopBotService
