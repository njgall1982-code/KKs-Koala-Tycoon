-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local ServerScriptService = game:GetService("ServerScriptService")
local CarryService = require(ServerScriptService.Services.CarryService)
local tool = script.Parent
local remote = tool:WaitForChild("CrateAction")

remote.OnServerEvent:Connect(function(player, action, data)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local pos = char.HumanoidRootPart.Position
	if action == "Drop" then
		local d = data
		local dp = type(d) == "table" and d.pos or d
		local en = type(d) == "table" and d.exhibitName or nil
		if player:GetAttribute("Carrying") and (pos - dp).Magnitude < 40 then
			CarryService.Drop(player, CFrame.new(dp + Vector3.new(0, 1, 0)), en)
		end
	end
end)
