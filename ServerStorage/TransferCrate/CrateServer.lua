-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local CarryService = require(ServerScriptService.Services.CarryService)
local tool = script.Parent
local remote = tool:WaitForChild("CrateAction")
local handle = tool:WaitForChild("Handle")
remote.OnServerEvent:Connect(function(player, action, data)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local pos = char.HumanoidRootPart.Position
	if action == "PickUp" then
		local closest = nil
		local dist = 15
		for _, k in pairs(CollectionService:GetTagged("KoalaNPC")) do
			if k:IsDescendantOf(workspace) and not k:GetAttribute("IsBeingCarried") then
				local d = (k:GetPivot().Position - pos).Magnitude
				if d < dist then dist = d closest = k end
			end
		end
		if closest then CarryService.PickUp(player, closest, handle) end
	elseif action == "Drop" then
		local d = data
		local dp = type(d) == "table" and d.pos or d
		local en = type(d) == "table" and d.exhibitName or nil
		if player:GetAttribute("Carrying") and (pos - dp).Magnitude < 40 then
			CarryService.Drop(player, CFrame.new(dp + Vector3.new(0, 1, 0)), en)
		end
	end
end)
