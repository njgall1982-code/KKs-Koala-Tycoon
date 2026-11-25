-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local ServerScriptService = game:GetService("ServerScriptService")
local CarryService = require(ServerScriptService.Services.CarryService)
local tool = script.Parent
local remote = tool:WaitForChild("CrateAction")

tool.Equipped:Connect(function()
	local char = tool.Parent
	local player = game:GetService("Players"):GetPlayerFromCharacter(char)
	if not player then return end

	local koala = tool:FindFirstChildOfClass("Model")
	local koalaName = koala and koala.Name or "Koala"
	player:SetAttribute("Carrying", koalaName)
	CarryService.SetArms(player, true)
end)

tool.Unequipped:Connect(function()
	local backpack = tool.Parent
	local player = backpack and backpack.Parent:IsA("Player") and backpack.Parent
	if not player then
		local char = tool:FindFirstAncestorOfClass("Model")
		if char then
			player = game:GetService("Players"):GetPlayerFromCharacter(char)
		end
	end
	if player then
		local koala = tool:FindFirstChildOfClass("Model")
		local currentCarrying = player:GetAttribute("Carrying")
		if not koala or currentCarrying == koala.Name or currentCarrying == "Koala" then
			player:SetAttribute("Carrying", nil)
		end
		CarryService.SetArms(player, false)
	end
end)

remote.OnServerEvent:Connect(function(player, action, data)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	if tool.Parent ~= char then return end -- Tool must be equipped

	local pos = char.HumanoidRootPart.Position
	if action == "Drop" then
		local d = data
		local dp = type(d) == "table" and d.pos or d
		local en = type(d) == "table" and d.exhibitName or nil
		if (pos - dp).Magnitude < 50 then
			local koala = tool:FindFirstChildOfClass("Model")
			CarryService.Drop(player, CFrame.new(dp + Vector3.new(0, 1, 0)), en, koala, tool)
		end
	end
end)
