-- Koala System - Animation and Wandering
local RunService = game:GetService("RunService")

print("[KoalaSystem] ===== SCRIPT STARTING =====")

-- Config
local WALK_SPEED = 3 -- Slow, lazy koala
local WADDLE_SWING = 20
local WADDLE_SPEED = 6 -- Slower wiggle
local T_POSE_TILT = math.rad(90) -- Adjust body from T-pose to all-fours
local WANDER_RADIUS = 15
local IDLE_TIME_MIN = 1
local IDLE_TIME_MAX = 3
local CLIMB_CHANCE = 0.4
local EAT_CHANCE = 0.3 -- 30% chance to go eat when idle
local CLIMB_DURATION = 10 -- Stay for 10 seconds
local CLIMB_HEIGHT = 5 -- Lowered more so he stays visible on the trunk
local CLIMB_VERTICAL_SPEED = 4
local FOLLOW_DIST_MIN = 6
local FOLLOW_DIST_TELEPORT = 35
local FOLLOW_SPEED_CATCHUP = 18
local FOLLOW_SPEED_WALK = 6

local CollectionService = game:GetService("CollectionService")
local KOALA_TAG = "KoalaNPC"

-- Store state for each koala
local koalaStates = {}

local function initKoala(koala)
	print("[KoalaSystem] Found new Koala: " .. koala:GetFullName())
	if not CollectionService:HasTag(koala, KOALA_TAG) then
		CollectionService:AddTag(koala, KOALA_TAG)
	end

	local humanoid = koala:FindFirstChild("Humanoid")
	local hrp = koala:FindFirstChild("HumanoidRootPart")

	-- Detect Rig Type (char1 for old rig, Mesh_0 for new rig, or fallback to first MeshPart)
	local rigRoot = koala:FindFirstChild("char1") or koala:FindFirstChild("Mesh_0")
	if not rigRoot then
		for _, child in ipairs(koala:GetChildren()) do
			if child:IsA("MeshPart") and child.Name ~= "HumanoidRootPart" then
				rigRoot = child
				break
			end
		end
	end

	if not rigRoot or not humanoid or not hrp then
		print("[KoalaSystem] Missing core components for " .. koala.Name)
		koalaStates[koala] = "failed"
		return false
	end

	-- Helper to find bones recursively (handles both simple and CC_Base naming)
	local function findBone(name)
		-- Exact match first
		local found = rigRoot:FindFirstChild(name, true)
		if found and found:IsA("Bone") then return found end

		-- Partial/mapped match
		local mapping = {
			["Hips"] = "CC_Base_Hip",
			["chest"] = "CC_Base_Spine02",
			["head"] = "CC_Base_Head",
			["tail"] = "CC_Base_Pelvis",
			["frontleg"] = "CC_Base_L_Upperarm",
			["R_frontleg"] = "CC_Base_R_Upperarm",
			["backleg"] = "CC_Base_L_Thigh",
			["R_backleg"] = "CC_Base_R_Thigh"
		}

		local mappedName = mapping[name]
		if mappedName then
			found = rigRoot:FindFirstChild(mappedName, true)
			if found and found:IsA("Bone") then return found end
		end

		return nil
	end

	local bones = {
		hips = findBone("Hips"),
		chest = findBone("chest"),
		head = findBone("head"),
		tail = findBone("tail"),
		frontleg = findBone("frontleg"),
		R_frontleg = findBone("R_frontleg"),
		backleg = findBone("backleg"),
		R_backleg = findBone("R_backleg"),
	}

	-- Ensure HumanoidRootPart ALWAYS has collision to prevent falling through floor
	if hrp then hrp.CanCollide = true end

	-- Disable collisions on all visual parts to prevent sticking
	for _, part in ipairs(koala:GetDescendants()) do
		if part:IsA("BasePart") and part ~= hrp then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = true -- Still allow mouse detection for tools
		end
	end

	humanoid.WalkSpeed = WALK_SPEED
	humanoid.AutoRotate = true

	-- Ensure everything is unanchored (Unless AI is disabled, e.g. for KK in crate)
	if not koala:GetAttribute("AI_Disabled") then
		for _, p in ipairs(koala:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
			end
		end
	end

	local state = {
		koala = koala,
		humanoid = humanoid,
		hrp = hrp,
		bones = bones,
		spawnPoint = hrp.Position,
		targetPoint = nil,
		idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX),
		state = "idle",
		animTime = 0,
		currentSpeed = 0,
		isClimbing = false,
		climbTarget = nil,
		climbTimer = 0,
		originalY = hrp.Position.Y,
		climbPhase = nil, -- nil, "approaching", "climbing", "descending"
		treePos = nil,
		lastPos = hrp.Position,
		stuckTimer = 0,
		-- Capture Initial Pose
		baseRotations = {
			hips = bones.hips and bones.hips.CFrame or CFrame.new(),
			chest = bones.chest and bones.chest.CFrame or CFrame.new(),
			head = bones.head and bones.head.CFrame or CFrame.new(),
			frontleg = bones.frontleg and bones.frontleg.CFrame or CFrame.new(),
			R_frontleg = bones.R_frontleg and bones.R_frontleg.CFrame or CFrame.new(),
			backleg = bones.backleg and bones.backleg.CFrame or CFrame.new(),
			R_backleg = bones.R_backleg and bones.R_backleg.CFrame or CFrame.new(),
		}
	}

	-- Check for missing critical bones
	if not state.bones.hips then
		print("[KoalaSystem] Warning: No Hip bone found for " .. koala.Name)
	end

	koalaStates[koala] = state
	print("[KoalaSystem] Initialized " .. koala.Name .. " successfully!")
	return true
end

local function getRandomWanderPoint(koala, spawnPoint)
	local hrp = koala:FindFirstChild("HumanoidRootPart")
	if not hrp then return spawnPoint end

	local homePath = koala:GetAttribute("HomeExhibit")
	local ground = nil

	if homePath then
		local exhibit = workspace:FindFirstChild(homePath)
		ground = exhibit and exhibit:FindFirstChild("Ground")
	end

	if ground then
		-- Pick a spot strictly within the ground boundaries
		local size = ground.Size
		local pos = ground.Position
		local margin = 3 -- Stay 3 studs away from the walls

		local randomX = (math.random() - 0.5) * (size.X - (margin * 2))
		local randomZ = (math.random() - 0.5) * (size.Z - (margin * 2))

		return Vector3.new(pos.X + randomX, pos.Y, pos.Z + randomZ)
	else
		-- Fallback to the old random circle if no home is found
		local angle = math.random() * math.pi * 2
		local distance = math.random() * WANDER_RADIUS
		return Vector3.new(
			spawnPoint.X + math.cos(angle) * distance,
			spawnPoint.Y,
			spawnPoint.Z + math.sin(angle) * distance
		)
	end
end

local function findNearestTree(hrp)
	local nearestTree = nil
	local nearestDist = 20 -- Max distance to detect trees

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and string.find(obj.Name, "Tree") then
			local treePos = obj:GetPivot().Position
			local dist = (hrp.Position - treePos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestTree = obj
			end
		end
	end

	return nearestTree
end

local function animateKoala(state, dt)
	if state.koala:GetAttribute("IsBeingCarried") then
		local bones = state.bones
		local base = state.baseRotations
		-- Clinging pose: Rotate legs inward relative to base pose
		local clingAngle = math.rad(45)
		if bones.frontleg then bones.frontleg.CFrame = base.frontleg * CFrame.Angles(clingAngle, 0, 0) end
		if bones.R_frontleg then bones.R_frontleg.CFrame = base.R_frontleg * CFrame.Angles(clingAngle, 0, 0) end
		if bones.backleg then bones.backleg.CFrame = base.backleg * CFrame.Angles(-clingAngle, 0, 0) end
		if bones.R_backleg then bones.R_backleg.CFrame = base.R_backleg * CFrame.Angles(-clingAngle, 0, 0) end

		-- Reset hips to base
		if bones.hips then bones.hips.CFrame = base.hips end
		return
	end

	local velocity = state.hrp.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	-- Fallback to MoveDirection if physics is sleeping
	if speed < 0.1 then
		speed = state.humanoid.MoveDirection.Magnitude * WALK_SPEED
	end

	local isMoving = speed > 0.5 or state.climbPhase == "climbing_up" or state.climbPhase == "climbing_down"

	-- Stop wiggle if stationary on tree
	if state.climbPhase == "climbing_stay" then
		isMoving = false
	end

	local targetSpeed = isMoving and 1 or 0
	state.currentSpeed = state.currentSpeed + (targetSpeed - state.currentSpeed) * 0.2 -- Faster response
	state.animTime = state.animTime + dt * WALK_SPEED * state.currentSpeed

	if isMoving and state.currentSpeed > 0.01 then
		-- Force a minimal speed for animation to ensure it fires
		if state.currentSpeed < 0.1 then state.currentSpeed = 0.5 end
	end

	local waddleRad = math.rad(WADDLE_SWING) * state.currentSpeed
	local bones = state.bones
	local base = state.baseRotations

	-- Waddle: side-to-side roll and bounce
	if bones.hips then
		local waddleAngle = math.sin(state.animTime * WADDLE_SPEED / WALK_SPEED) * waddleRad
		local bounce = math.abs(math.sin(state.animTime * WADDLE_SPEED / WALK_SPEED * 2)) * 0.1 * state.currentSpeed

		-- Apply waddle and bounce ON TOP of base rotation
		bones.hips.CFrame = base.hips * CFrame.new(0, bounce, 0) * CFrame.Angles(0, 0, waddleAngle)
	end

	-- Leg Movement (Pig-like crawl)
	local legAngle = math.sin(state.animTime * WADDLE_SPEED / WALK_SPEED) * math.rad(20) * state.currentSpeed

	if bones.frontleg then bones.frontleg.CFrame = base.frontleg * CFrame.Angles(legAngle, 0, 0) end
	if bones.R_frontleg then bones.R_frontleg.CFrame = base.R_frontleg * CFrame.Angles(-legAngle, 0, 0) end
	if bones.backleg then bones.backleg.CFrame = base.backleg * CFrame.Angles(-legAngle, 0, 0) end
	if bones.R_backleg then bones.R_backleg.CFrame = base.R_backleg * CFrame.Angles(legAngle, 0, 0) end

	if bones.head then bones.head.CFrame = base.head * CFrame.Angles(math.rad(speed * 2), 0, 0) end
end

local function updateWander(state, dt)
	-- Stuck Detection
	if state.state == "walking" then
		local distMoved = (state.hrp.Position - state.lastPos).Magnitude
		if distMoved < 0.1 then
			state.stuckTimer = state.stuckTimer + dt
			if state.stuckTimer > 3 then
				print("[KoalaSystem] " .. state.koala.Name .. " stuck! Recalculating...")
				state.state = "idle"
				state.idleTimer = 1
				state.stuckTimer = 0
			end
		else
			state.stuckTimer = 0
		end
		state.lastPos = state.hrp.Position
	end

	-- Handle climbing phases
	if state.climbPhase == "approaching" then
		if state.treePos then
			local flatHrp = Vector3.new(state.hrp.Position.X, 0, state.hrp.Position.Z)
			local flatTree = Vector3.new(state.treePos.X, 0, state.treePos.Z)
			local dist = (flatTree - flatHrp).Magnitude

			-- If we've been approaching too long, just start the climb
			state.approachTimer = (state.approachTimer or 0) + dt

			if dist < 3.2 then
				print("[KoalaSystem] Reached tree, starting climb: " .. state.koala.Name)
				state.approachTimer = 0
				state.climbPhase = "climbing_up"
				state.climbProgress = 0
				state.humanoid.PlatformStand = true 
				state.hrp.Anchored = true 

				local dir = (flatHrp - flatTree).Unit
				state.climbOffset = dir * 1.4 
			elseif state.approachTimer > 8 then
				print("[KoalaSystem] Approach timeout, cancelling climb: " .. state.koala.Name)
				state.climbPhase = nil
				state.isClimbing = false
				state.state = "idle"
				state.idleTimer = 2
				state.approachTimer = 0
			else
				state.humanoid:MoveTo(Vector3.new(state.treePos.X, state.hrp.Position.Y, state.treePos.Z))
			end
		end
		return
	elseif state.climbPhase == "climbing_up" then
		state.climbProgress = math.min(1, state.climbProgress + dt * CLIMB_VERTICAL_SPEED / CLIMB_HEIGHT)
		local yPos = state.originalY + (state.climbProgress * CLIMB_HEIGHT)

		-- Position on tree side
		local targetPos = Vector3.new(state.treePos.X, yPos, state.treePos.Z) + state.climbOffset
		local lookAt = Vector3.new(state.treePos.X, yPos, state.treePos.Z)

		-- Face the tree AND TILT VERTICAL (Face up, belly to tree)
		local baseRotation = CFrame.lookAt(targetPos, lookAt)
		state.hrp.CFrame = baseRotation * CFrame.Angles(math.rad(90), 0, 0)

		if state.climbProgress >= 1 then
			state.climbPhase = "climbing_stay"
			state.climbTimer = CLIMB_DURATION
		end
		return
	elseif state.climbPhase == "climbing_stay" then
		state.climbTimer = state.climbTimer - dt
		if state.climbTimer <= 0 then
			state.climbPhase = "climbing_down"
		end
		return
	elseif state.climbPhase == "climbing_down" then
		state.climbProgress = math.max(0, state.climbProgress - dt * CLIMB_VERTICAL_SPEED / CLIMB_HEIGHT)
		local yPos = state.originalY + (state.climbProgress * CLIMB_HEIGHT)

		local targetPos = Vector3.new(state.treePos.X, yPos, state.treePos.Z) + state.climbOffset
		local lookAt = Vector3.new(state.treePos.X, yPos, state.treePos.Z)

		-- Face the tree AND TILT VERTICAL (Face up, belly to tree)
		local baseRotation = CFrame.lookAt(targetPos, lookAt)
		state.hrp.CFrame = baseRotation * CFrame.Angles(math.rad(90), 0, 0)

		if state.climbProgress <= 0 then
			-- Back on ground
			state.climbPhase = nil
			state.isClimbing = false
			state.humanoid.PlatformStand = false

			-- FORCE UPRIGHT AND SOLID: Reset collision and rotation
			state.hrp.Anchored = false
			state.hrp.CanCollide = true
			state.humanoid.AutoRotate = true
			local flatPos = state.hrp.Position
			state.koala:PivotTo(CFrame.new(flatPos.X, state.originalY, flatPos.Z))
			state.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

			state.state = "idle"
			state.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
		end
		return
	end

	if state.state == "idle" or state.state == "eating" then
		state.humanoid:MoveTo(state.hrp.Position)
		state.idleTimer = state.idleTimer - dt

		if state.idleTimer <= 0 then
			if state.state == "eating" then
				state.state = "idle"
				state.idleTimer = 1 -- Short pause after eating
				return
			end

			-- Check for nearby tree to climb
			local tree = findNearestTree(state.hrp)
			if tree and math.random() < CLIMB_CHANCE then
				print("[KoalaSystem] Decided to climb tree: " .. tree.Name)
				state.isClimbing = true
				state.climbTarget = tree
				state.climbPhase = "approaching"

				-- Set originalY to ground level if available
				local homePath = state.koala:GetAttribute("HomeExhibit")
				local exhibit = homePath and workspace:FindFirstChild(homePath)
				local ground = exhibit and exhibit:FindFirstChild("Ground")
				if ground then
					state.originalY = ground.Position.Y + (ground.Size.Y / 2)
				else
					state.originalY = state.hrp.Position.Y
				end

				-- Target the trunk part if it exists
				local trunk = tree:FindFirstChild("Trunk") or tree
				state.treePos = trunk:GetPivot().Position
			elseif math.random() < EAT_CHANCE then
				-- Go to feeder
				local homePath = state.koala:GetAttribute("HomeExhibit")
				local exhibit = homePath and workspace:FindFirstChild(homePath)
				local feeder = exhibit and exhibit:FindFirstChild("Feeder")

				if feeder then
					print("[KoalaSystem] " .. state.koala.Name .. " is hungry, going to feeder")
					state.targetPoint = feeder.Position
					state.state = "wandering"
					state.isEatingNext = true -- Flag to start eating when we arrive
				end
			else
				print("[KoalaSystem] " .. state.koala.Name .. " state: " .. state.state)
				state.targetPoint = getRandomWanderPoint(state.koala, state.spawnPoint)
				state.state = "wandering"
				print("[KoalaSystem] " .. state.koala.Name .. " target: " .. tostring(state.targetPoint))
			end
		end

		-- RANDOM SLEEPY BUBBLES
		if state.state == "idle" and math.random() < 0.005 then
			local Core = require(game:GetService("ServerScriptService").Services.KoalaCoreManager)
			Core.ShowSleepyEffect(state.koala)
		end
	elseif state.state == "wandering" then
		if state.targetPoint then
			state.humanoid:MoveTo(state.targetPoint)
			local distance = (state.hrp.Position - state.targetPoint).Magnitude

			-- Wander timeout
			state.wanderTimer = (state.wanderTimer or 0) + dt

			local maxWanderTime = state.isEatingNext and 25 or 12
			if distance < 2.5 or state.wanderTimer > maxWanderTime then
				if state.wanderTimer > maxWanderTime then
					print("[KoalaSystem] " .. state.koala.Name .. " wander timeout (Target: " .. (state.isEatingNext and "Feeder" or "Wander") .. ")")
				end
				state.wanderTimer = 0
				state.targetPoint = nil

				if state.isEatingNext then
					state.state = "eating"
					state.idleTimer = 10 -- Eat for 10 seconds
					state.isEatingNext = false

					-- Visual only: HungerService now handles the actual depletion
					print("[KoalaSystem] " .. state.koala.Name .. " is eating for show.")
				else
					state.state = "idle"
					state.idleTimer = math.random(IDLE_TIME_MIN, IDLE_TIME_MAX)
				end
			end
		else
			state.state = "idle"
		end
	end
end

local function findKoalas()
	local tagged = CollectionService:GetTagged(KOALA_TAG)
	local inWorkspace = {}
	for _, k in ipairs(tagged) do
		if k:IsDescendantOf(workspace) then
			table.insert(inWorkspace, k)
		end
	end
	return inWorkspace
end

local scanTimer = 0
RunService.Heartbeat:Connect(function(dt)
	script:SetAttribute("IsRunning", true)
	script:SetAttribute("LastHeartbeat", os.time())

	scanTimer = scanTimer + dt
	if scanTimer >= 2 then
		scanTimer = 0
		for _, koala in ipairs(findKoalas()) do
			if not koalaStates[koala] then
				initKoala(koala)
			end
		end
	end

	for koala, state in pairs(koalaStates) do
		if koala.Parent then
			if state == "failed" then continue end
			
			if not koala:GetAttribute("AI_Disabled") then
				animateKoala(state, dt)
				updateWander(state, dt)

				-- Safety Grounding: If not climbing and significantly above ground, drop down
				if not state.isClimbing and not koala:GetAttribute("IsBeingCarried") then
					local rayOrigin = state.hrp.Position
					local rayDirection = Vector3.new(0, -20, 0)
					local raycastParams = RaycastParams.new()
					raycastParams.FilterDescendantsInstances = {koala}
					raycastParams.FilterType = Enum.RaycastFilterType.Exclude

					local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
					if result and result.Distance > 3 then -- Floating too high
						state.humanoid.PlatformStand = false
						state.hrp.Anchored = false
						state.humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
					end
				end
			elseif koala:GetAttribute("IsBeingCarried") then
				animateKoala(state, dt)
			end
		else
			koalaStates[koala] = nil
		end
	end
end)

print("[KoalaSystem] ===== SCRIPT LOADED =====")