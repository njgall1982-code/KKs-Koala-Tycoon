local ZooTerminalService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local openAnalyticsRemote = ReplicatedStorage:FindFirstChild("OpenZooAnalytics")
if not openAnalyticsRemote then
	openAnalyticsRemote = Instance.new("RemoteEvent")
	openAnalyticsRemote.Name = "OpenZooAnalytics"
	openAnalyticsRemote.Parent = ReplicatedStorage
end

local function findComputerModel()
	local clinic = workspace:FindFirstChild("VetClinic", true)
	if clinic then
		local comp = clinic:FindFirstChild("Zookeeper Computer", true)
		if comp then return comp end
	end
	-- Fallback: check workspace descendants
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Model") and (desc.Name == "Zookeeper Computer" or desc.Name == "Zookeep Computer") then
			return desc
		end
	end
	return nil
end

function ZooTerminalService.Initialize()
	task.spawn(function()
		local comp = findComputerModel()
		local attempts = 0
		while not comp and attempts < 10 do
			task.wait(1)
			comp = findComputerModel()
			attempts += 1
		end

		if not comp then
			warn("[ZooTerminalService] Could not locate 'Zookeeper Computer' model in workspace!")
			return
		end

		-- Find a guaranteed BasePart for ProximityPrompt
		local targetPart = nil
		local screen = comp:FindFirstChild("Screen", true)
		if screen and screen:IsA("BasePart") then
			targetPart = screen
		elseif comp.PrimaryPart and comp.PrimaryPart:IsA("BasePart") then
			targetPart = comp.PrimaryPart
		else
			for _, desc in ipairs(comp:GetDescendants()) do
				if desc:IsA("BasePart") then
					targetPart = desc
					break
				end
			end
		end

		if not targetPart then
			warn("[ZooTerminalService] 'Zookeeper Computer' has no BasePart to attach ProximityPrompt!")
			return
		end

		-- Ensure model has primary part set
		if not comp.PrimaryPart then
			comp.PrimaryPart = targetPart
		end

		-- Clean up existing prompts if any
		for _, p in ipairs(comp:GetDescendants()) do
			if p:IsA("ProximityPrompt") then
				p:Destroy()
			end
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ComputerPrompt"
		prompt.ActionText = "Zoo Analytics 💻"
		prompt.ObjectText = "Zookeeper Computer"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = targetPart

		prompt.Triggered:Connect(function(player)
			openAnalyticsRemote:FireClient(player)
		end)

		print("[ZooTerminalService] 💻 ProximityPrompt attached to BasePart: " .. targetPart:GetFullName())
	end)
end

return ZooTerminalService
