local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local leafDropRemote = Net.Remote("LeafDropVFX")
local leafTemplate = ReplicatedStorage:WaitForChild("LeafDropTemplate", 15)

if not leafDropRemote or not leafTemplate then
	return
end

local MAX_RENDER_DISTANCE = 180

local vfxFolder = workspace:FindFirstChild("LeafDropVFX")
if not vfxFolder then
	vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "LeafDropVFX"
	vfxFolder.Parent = workspace
end

local activeDrops = {}
local renderConn = nil

local function setVisualCFrame(instance, cf)
	if instance:IsA("Model") then
		instance:PivotTo(cf)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cf
	end
end

local function stepDrops()
	local now = os.clock()

	for i = #activeDrops, 1, -1 do
		local drop = activeDrops[i]
		local elapsed = now - drop.startTime
		local alpha = math.clamp(elapsed / drop.duration, 0, 1)

		if alpha >= 1 or not drop.visual.Parent then
			if drop.visual and drop.visual.Parent then
				drop.visual:Destroy()
			end
			table.remove(activeDrops, i)
		else
			local pos = drop.startPos:Lerp(drop.endPos, alpha)
			local envelope = math.sin(alpha * math.pi)
			local swayX = math.sin(elapsed * 5.5 + drop.phase) * 1.1 * envelope
			local swayZ = math.cos(elapsed * 4.2 + drop.phase) * 1.1 * envelope

			local rotX = math.sin(elapsed * 4.0 + drop.phase) * 0.45 * (1 - alpha)
			local rotZ = math.cos(elapsed * 3.5 + drop.phase) * 0.45 * (1 - alpha)
			local rotY = drop.yaw + elapsed * 1.8 * (1 - alpha)

			local cf = CFrame.new(pos + Vector3.new(swayX, 0, swayZ)) * CFrame.Angles(rotX, rotY, rotZ)
			setVisualCFrame(drop.visual, cf)
		end
	end

	if #activeDrops == 0 and renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

leafDropRemote.OnClientEvent:Connect(function(startPos, endPos, duration)
	if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
		return
	end

	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - endPos).Magnitude > MAX_RENDER_DISTANCE then
		return
	end

	local visual = leafTemplate:Clone()
	local yaw = math.random() * math.pi * 2
	setVisualCFrame(visual, CFrame.new(startPos) * CFrame.Angles(0, yaw, 0))
	visual.Parent = vfxFolder

	table.insert(activeDrops, {
		visual = visual,
		startPos = startPos,
		endPos = endPos,
		duration = math.max(tonumber(duration) or 1.25, 0.2),
		startTime = os.clock(),
		phase = math.random() * math.pi * 2,
		yaw = yaw,
	})

	if not renderConn then
		renderConn = RunService.RenderStepped:Connect(stepDrops)
	end
end)
