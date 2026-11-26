local StaffService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local StaffConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StaffConfig"))
local KoalaVFX = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaVFX"))
local KoalaGrowth = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaGrowth"))

local activeNPCs = {} -- [userId] = { [roleId] = Model }

-- ============================================================
-- HELPERS
-- ============================================================

local function getHiredStaffTable(player)
	local attr = player:GetAttribute("HiredStaff")
	if not attr or attr == "" then return {} end
	local decoded = {}
	pcall(function()
		decoded = HttpService:JSONDecode(attr)
	end)
	return (type(decoded) == "table") and decoded or {}
end

local function setHiredStaffTable(player, tbl)
	player:SetAttribute("HiredStaff", HttpService:JSONEncode(tbl))
end

local function findDeskModel(deskName)
	local clinic = workspace:FindFirstChild("VetClinic", true)
	if clinic then
		local desk = clinic:FindFirstChild(deskName, true)
		if desk then return desk end
	end
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Model") and desc.Name == deskName then
			return desc
		end
	end
	return nil
end

local function getTargetPart(model)
	if not model then return nil end
	local pc = model:FindFirstChild("DesktopPC", true)
	if pc then
		if pc:IsA("BasePart") then return pc end
		local part = pc:FindFirstChildWhichIsA("BasePart", true)
		if part then return part end
	end
	if model:IsA("Model") and model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function isSecondExhibitRepaired()
	local second = workspace:FindFirstChild("SecondExhibit_Workspace")
	return second ~= nil and second:GetAttribute("IsRepaired") == true
end

local function getCoveredExhibits(maxExhibits)
	local repaired = {}
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Folder") and child.Name:find("_Workspace") and child:GetAttribute("IsRepaired") == true then
			table.insert(repaired, child)
		end
	end
	-- Deterministic order: TutorialExhibit first, then SecondExhibit, then alphabetical
	table.sort(repaired, function(a, b)
		if a.Name == "TutorialExhibit_Workspace" then return true end
		if b.Name == "TutorialExhibit_Workspace" then return false end
		if a.Name == "SecondExhibit_Workspace" then return true end
		if b.Name == "SecondExhibit_Workspace" then return false end
		return a.Name < b.Name
	end)

	local covered = {}
	for i = 1, math.min(#repaired, maxExhibits) do
		table.insert(covered, repaired[i])
	end
	return covered
end

local function getInstancePosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then return inst:GetPivot().Position end
	return nil
end

local function buildStatePayload(player, roleId)
	roleId = roleId or "Feeder"
	local role = StaffConfig.GetRole(roleId)
	if not role then return nil end

	local staff = getHiredStaffTable(player)
	local entry = staff[roleId]
	local isHired = entry ~= nil and entry.hired == true
	local isPaused = entry ~= nil and entry.paused == true

	local manualRefills = player:GetAttribute("ManualRefills") or 0
	local manualCleanups = player:GetAttribute("ManualCleanups") or 0
	local secondRepaired = isSecondExhibitRepaired()
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = (leaderstats and leaderstats:FindFirstChild("Cash") and leaderstats.Cash.Value) or 0

	local reqs = role.requirements or {}
	local refillsOk = (not reqs.minManualRefills) or (manualRefills >= reqs.minManualRefills)
	local cleanupsOk = (not reqs.minManualCleanups) or (manualCleanups >= reqs.minManualCleanups)
	local secondOk = (not reqs.requireSecondExhibit) or secondRepaired
	local meetsWork = refillsOk and cleanupsOk and secondOk

	local coveredNames = {}
	for _, exh in ipairs(getCoveredExhibits(role.maxExhibits or 2)) do
		table.insert(coveredNames, exh:GetAttribute("DisplayName") or exh.Name:gsub("_Workspace", ""))
	end

	local availableRoles = {}
	for _, id in ipairs(StaffConfig.RoleOrder or {}) do
		local r = StaffConfig.GetRole(id)
		if r then
			local rEntry = staff[id]
			table.insert(availableRoles, {
				id = r.id,
				title = r.title,
				icon = r.icon,
				comingSoon = r.comingSoon == true,
				isHired = rEntry ~= nil and rEntry.hired == true,
				isPaused = rEntry ~= nil and rEntry.paused == true,
			})
		end
	end

	return {
		roleId = role.id,
		title = role.title,
		icon = role.icon,
		description = role.description,
		summaryLine = role.summaryLine,
		comingSoon = role.comingSoon == true,
		hireCost = role.hireCost,
		upkeepCost = role.upkeepCost,
		upkeepInterval = role.upkeepInterval,
		maxExhibits = role.maxExhibits,
		requirements = {
			minManualRefills = reqs.minManualRefills,
			manualRefills = manualRefills,
			minManualCleanups = reqs.minManualCleanups,
			manualCleanups = manualCleanups,
			requireSecondExhibit = reqs.requireSecondExhibit == true,
			secondExhibitRepaired = secondRepaired,
			meetsWork = meetsWork,
		},
		cash = cash,
		isHired = isHired,
		isPaused = isPaused,
		coveredExhibits = coveredNames,
		availableRoles = availableRoles,
	}
end

-- ============================================================
-- VISUAL NPC MANAGEMENT
-- ============================================================

local function despawnWorkerNPC(player, roleId)
	local userTable = activeNPCs[player.UserId]
	if not userTable then return end
	local model = userTable[roleId]
	if model then
		userTable[roleId] = nil
		if model.Parent then
			model:Destroy()
		end
	end
end

local function createWorkerNameplate(npcModel, titleText)
	local head = npcModel:FindFirstChild("Head") or npcModel.PrimaryPart
	if not head then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "StaffNameplate"
	gui.Size = UDim2.new(0, 180, 0, 42)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = head

	local bg = Instance.new("Frame", gui)
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0

	local corner = Instance.new("UICorner", bg)
	corner.CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", bg)
	stroke.Color = Color3.fromRGB(80, 210, 130)
	stroke.Thickness = 1.5

	local label = Instance.new("TextLabel", bg)
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.TextColor3 = Color3.fromRGB(235, 250, 240)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextScaled = false
end

local function moveNPCTo(humanoid, rootPart, targetPos, timeout)
	if not humanoid or not rootPart or humanoid.Health <= 0 then return false end
	local reached = false
	local conn
	conn = humanoid.MoveToFinished:Connect(function(ok)
		reached = ok
	end)
	humanoid:MoveTo(targetPos)

	local elapsed = 0
	local step = 0.25
	while not reached and elapsed < (timeout or 6) do
		if not humanoid.Parent or not rootPart.Parent then break end
		task.wait(step)
		elapsed += step
		if (rootPart.Position - targetPos).Magnitude <= 5 then
			reached = true
			break
		end
	end
	if conn then conn:Disconnect() end
	return reached
end

local SHOW_STAFF_NAMEPLATES = false

local function spawnWorkerNPC(player, roleId)
	local role = StaffConfig.GetRole(roleId)
	if not role then return end

	despawnWorkerNPC(player, roleId)

	local template = (roleId == "CuddleBuddy" and workspace:FindFirstChild("Cuddle Buddy"))
		or workspace:FindFirstChild("Feeder Assistant")
		or workspace:FindFirstChild("HeadVet")
		or workspace:FindFirstChild("Maintenance Tools")
	if not template then
		warn("[StaffService] No NPC template (Cuddle Buddy / Feeder Assistant / HeadVet / Maintenance Tools) found in workspace!")
		return
	end

	local npc = template:Clone()
	npc.Name = "Staff_" .. roleId .. "_" .. player.UserId

	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		npc.PrimaryPart = hrp
	end

	-- Check if the NPC already has joints (Motor6D / Weld / WeldConstraint); if not, weld parts to PrimaryPart so it doesn't collapse
	local hasJoints = false
	for _, desc in ipairs(npc:GetDescendants()) do
		if desc:IsA("Motor6D") or desc:IsA("Weld") or desc:IsA("WeldConstraint") then
			hasJoints = true
			break
		end
	end

	local rootForWeld = npc.PrimaryPart
	for _, desc in ipairs(npc:GetDescendants()) do
		if desc:IsA("ProximityPrompt") or desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("BillboardGui") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CollisionGroup = "Players"
			if not hasJoints and rootForWeld and desc ~= rootForWeld then
				desc.CanCollide = false
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = rootForWeld
				wc.Part1 = desc
				wc.Parent = rootForWeld
			end
		end
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 14
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- Position near the hiring desk
	local desk = findDeskModel(role.deskName)
	local spawnPos = desk and (desk:GetPivot().Position + Vector3.new(-4, 1, 0)) or Vector3.new(116, 8, 90)
	npc:PivotTo(CFrame.new(spawnPos))
	npc.Parent = workspace

	if SHOW_STAFF_NAMEPLATES then
		createWorkerNameplate(npc, role.icon .. " " .. role.title)
	end

	activeNPCs[player.UserId] = activeNPCs[player.UserId] or {}
	activeNPCs[player.UserId][roleId] = npc

	-- Visual patrol loop (purely cosmetic; feeding/cuddling guarantees run independently)
	task.spawn(function()
		local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
		while npc.Parent and activeNPCs[player.UserId] and activeNPCs[player.UserId][roleId] == npc do
			local covered = getCoveredExhibits(role.maxExhibits)
			if #covered > 0 and humanoid and rootPart then
				for _, exhibit in ipairs(covered) do
					if not npc.Parent then break end
					if roleId == "CuddleBuddy" then
						local visitedKoala = false
						for _, koala in ipairs(CollectionService:GetTagged("KoalaNPC")) do
							if not npc.Parent then break end
							if koala:IsDescendantOf(exhibit) and not koala:GetAttribute("IsBeingCarried") then
								local koalaPos = getInstancePosition(koala)
								if koalaPos then
									visitedKoala = true
									moveNPCTo(humanoid, rootPart, koalaPos, 6)
									task.wait(1.0)
								end
							end
						end
						if not visitedKoala and npc.Parent then
							local fallback = exhibit:FindFirstChild("Feeder") or exhibit:FindFirstChild("EucalyptusTree", true)
							local fallbackPos = getInstancePosition(fallback)
							if fallbackPos then
								moveNPCTo(humanoid, rootPart, fallbackPos, 6)
								task.wait(1.0)
							end
						end
					else
						-- Walk toward a leaf or tree in the exhibit
						local leafTarget = nil
						for _, leaf in ipairs(CollectionService:GetTagged("EucalyptusLeaf")) do
							if leaf:IsDescendantOf(exhibit) then
								leafTarget = getInstancePosition(leaf)
								break
							end
						end
						if not leafTarget then
							local tree = exhibit:FindFirstChild("EucalyptusTree", true)
							leafTarget = getInstancePosition(tree)
						end
						if leafTarget then
							moveNPCTo(humanoid, rootPart, leafTarget, 6)
							task.wait(0.8)
						end

						if not npc.Parent then break end
						-- Walk toward the exhibit's Feeder
						local feeder = exhibit:FindFirstChild("Feeder")
						local feederPos = getInstancePosition(feeder)
						if feederPos then
							moveNPCTo(humanoid, rootPart, feederPos, 6)
							task.wait(1.2)
						end
					end
				end
			end
			task.wait(3)
		end
	end)
end

local function syncPlayerWorkers(player)
	local staff = getHiredStaffTable(player)
	for roleId, entry in pairs(staff) do
		if entry and entry.hired and not entry.paused then
			local existing = activeNPCs[player.UserId] and activeNPCs[player.UserId][roleId]
			if not existing or not existing.Parent then
				spawnWorkerNPC(player, roleId)
			end
		else
			despawnWorkerNPC(player, roleId)
		end
	end
end

-- ============================================================
-- GUARANTEED FEEDING, CUDDLING & UPKEEP LOOPS
-- ============================================================

local function applyCuddleToKoala(koala, now)
	koala:SetAttribute("LastCuddleTime", now)

	local stats = koala:FindFirstChild("KoalaStats")
	if stats then
		local cuddleVal = stats:FindFirstChild("LastCuddleTime")
		if not cuddleVal then
			cuddleVal = Instance.new("NumberValue")
			cuddleVal.Name = "LastCuddleTime"
			cuddleVal.Parent = stats
		end
		cuddleVal.Value = now
	end

	KoalaVFX.ShowHeartEffect(koala)
	KoalaGrowth.RefreshGrowth(koala)
end

local function runCuddleTick()
	local role = StaffConfig.GetRole("CuddleBuddy")
	if not role or role.comingSoon then return end

	local refreshThreshold = role.cuddleRefreshThreshold or 150
	local now = workspace:GetServerTimeNow()
	local allKoalas = CollectionService:GetTagged("KoalaNPC")

	for _, player in ipairs(Players:GetPlayers()) do
		local staff = getHiredStaffTable(player)
		local buddyEntry = staff["CuddleBuddy"]
		if not buddyEntry or not buddyEntry.hired or buddyEntry.paused then
			continue
		end

		local covered = getCoveredExhibits(role.maxExhibits)
		for _, exhibit in ipairs(covered) do
			for _, koala in ipairs(allKoalas) do
				if koala:IsDescendantOf(exhibit) and not koala:GetAttribute("IsBeingCarried") then
					local attrCuddle = koala:GetAttribute("LastCuddleTime") or 0
					local stats = koala:FindFirstChild("KoalaStats")
					local statCuddle = (stats and stats:FindFirstChild("LastCuddleTime") and stats.LastCuddleTime.Value) or 0
					local lastCuddle = math.max(attrCuddle, statCuddle)

					if lastCuddle == 0 or (now - lastCuddle) >= refreshThreshold then
						applyCuddleToKoala(koala, now)
					end
				end
			end
		end
	end
end

local function runFeedingTick()
	local role = StaffConfig.GetRole("Feeder")
	if not role then return end

	for _, player in ipairs(Players:GetPlayers()) do
		local staff = getHiredStaffTable(player)
		local feederEntry = staff["Feeder"]
		if not feederEntry or not feederEntry.hired or feederEntry.paused then
			continue
		end

		local covered = getCoveredExhibits(role.maxExhibits)
		for _, exhibit in ipairs(covered) do
			local currentFood = exhibit:GetAttribute("FoodLevel") or 0
			local maxFood = exhibit:GetAttribute("MaxFoodLevel") or 100
			if currentFood < maxFood then
				-- Consume 1 leaf in this exhibit if available (simulating collection)
				for _, leaf in ipairs(CollectionService:GetTagged("EucalyptusLeaf")) do
					if leaf:IsDescendantOf(exhibit) then
						leaf:Destroy()
						break
					end
				end

				local addAmount = math.max(1, math.round(maxFood * role.feedAmountFraction))
				local newFood = math.min(maxFood, currentFood + addAmount)
				exhibit:SetAttribute("FoodLevel", newFood)
			end
		end
	end
end

local function runUpkeepTick()
	local transactionRequest = Net.Signal("TransactionRequest")
	local showStatus = Net.Signal("ShowStatus")

	for _, player in ipairs(Players:GetPlayers()) do
		local staff = getHiredStaffTable(player)
		local changed = false

		for _, roleId in ipairs(StaffConfig.RoleOrder or {}) do
			local role = StaffConfig.GetRole(roleId)
			local entry = staff[roleId]
			if role and not role.comingSoon and entry and entry.hired and not entry.paused then
				local success = transactionRequest:Invoke(player, role.upkeepCost, "StaffUpkeep_" .. roleId)
				if not success then
					entry.paused = true
					staff[roleId] = entry
					changed = true
					despawnWorkerNPC(player, roleId)
					showStatus:Fire(player, string.format("⚠️ %s paused (couldn't afford $%d upkeep)", role.title, role.upkeepCost), Color3.fromRGB(255, 110, 110))
				end
			end
		end

		if changed then
			setHiredStaffTable(player, staff)
		end
	end
end

-- ============================================================
-- PUBLIC INITIALIZE & ACTIONS
-- ============================================================

function StaffService.HandleAction(player, action, roleId)
	roleId = roleId or "Feeder"
	local role = StaffConfig.GetRole(roleId)
	if not role then
		return false, "Unknown staff role"
	end

	if action == "GetState" then
		return true, buildStatePayload(player, roleId)

	elseif action == "Hire" then
		if role.comingSoon then
			return false, "This helper is coming soon!"
		end

		local staff = getHiredStaffTable(player)
		if staff[roleId] and staff[roleId].hired then
			return true, buildStatePayload(player, roleId)
		end

		local state = buildStatePayload(player, roleId)
		if not state.requirements.meetsWork then
			return false, "Complete the work requirements first!"
		end

		local success, err = Net.Signal("TransactionRequest"):Invoke(player, role.hireCost, "HireStaff_" .. roleId)
		if not success then
			return false, err or "Insufficient funds!"
		end

		staff[roleId] = {
			hired = true,
			paused = false,
			hiredAt = os.time(),
		}
		setHiredStaffTable(player, staff)
		syncPlayerWorkers(player)
		if roleId == "CuddleBuddy" then
			task.spawn(runCuddleTick)
		end
		Net.Signal("ShowStatus"):Fire(player, role.hiredToast or string.format("%s Hired %s!", role.icon, role.title), Color3.fromRGB(90, 230, 120))
		return true, buildStatePayload(player, roleId)

	elseif action == "TogglePause" then
		local staff = getHiredStaffTable(player)
		local entry = staff[roleId]
		if not entry or not entry.hired then
			return false, "You haven't hired this worker yet."
		end

		entry.paused = not entry.paused
		staff[roleId] = entry
		setHiredStaffTable(player, staff)
		syncPlayerWorkers(player)
		if roleId == "CuddleBuddy" and not entry.paused then
			task.spawn(runCuddleTick)
		end
		return true, buildStatePayload(player, roleId)
	end

	return false, "Unknown action"
end

function StaffService.Initialize()
	if StaffService._initialized then return end
	StaffService._initialized = true

	local openDeskRemote = Net.Remote("OpenStaffDesk")
	local staffActionRemote = Net.Remote("StaffAction")

	staffActionRemote.OnServerInvoke = function(player, action, roleId)
		return StaffService.HandleAction(player, action, roleId)
	end

	-- Attach ProximityPrompt to Downstairs Desk 3
	task.spawn(function()
		local feederRole = StaffConfig.GetRole("Feeder")
		local deskName = feederRole and feederRole.deskName or "Downstairs Desk 3"

		local desk = findDeskModel(deskName)
		local attempts = 0
		while not desk and attempts < 10 do
			task.wait(1)
			desk = findDeskModel(deskName)
			attempts += 1
		end

		if not desk then
			warn("[StaffService] Could not locate '" .. deskName .. "' in workspace!")
			return
		end

		local targetPart = getTargetPart(desk)
		if not targetPart then
			warn("[StaffService] '" .. deskName .. "' has no BasePart for ProximityPrompt!")
			return
		end

		for _, p in ipairs(desk:GetDescendants()) do
			if p:IsA("ProximityPrompt") then
				p:Destroy()
			end
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StaffDeskPrompt"
		prompt.ActionText = "Open Staff Manager 👷"
		prompt.ObjectText = "Staff Manager"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = targetPart

		prompt.Triggered:Connect(function(player)
			openDeskRemote:FireClient(player, "Feeder")
		end)

		print("[StaffService] 👷 Staff Manager prompt attached to: " .. targetPart:GetFullName())
	end)

	-- Player lifecycle hooks
	local function hookPlayer(player)
		player:GetAttributeChangedSignal("HiredStaff"):Connect(function()
			syncPlayerWorkers(player)
		end)
		task.defer(function()
			syncPlayerWorkers(player)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		local userTable = activeNPCs[player.UserId]
		if userTable then
			for roleId, _ in pairs(userTable) do
				despawnWorkerNPC(player, roleId)
			end
			activeNPCs[player.UserId] = nil
		end
	end)

	-- Background loops
	local feederRole = StaffConfig.GetRole("Feeder")
	local buddyRole = StaffConfig.GetRole("CuddleBuddy")
	local feedInterval = (feederRole and feederRole.feedInterval) or 15
	local cuddleInterval = (buddyRole and buddyRole.cuddleInterval) or 15
	local upkeepInterval = (feederRole and feederRole.upkeepInterval) or 60

	task.spawn(function()
		while true do
			task.wait(feedInterval)
			runFeedingTick()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(cuddleInterval)
			runCuddleTick()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(upkeepInterval)
			runUpkeepTick()
		end
	end)

	print("[StaffService] Initialized (Staff Manager ready: Feeder, Cuddle Buddy).")
end

return StaffService
