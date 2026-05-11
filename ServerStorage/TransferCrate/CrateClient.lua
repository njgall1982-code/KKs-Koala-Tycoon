local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent
local remote = tool:WaitForChild("CrateAction")

local COOLDOWN = 1.0 -- Increased cooldown to prevent double clicks
local lastAction = 0

tool.Activated:Connect(function()
	if tick() - lastAction < COOLDOWN then return end
	
	local isCarrying = player:GetAttribute("Carrying") ~= nil
	
	if isCarrying then
		-- Only allow dropping if clicking on an exhibit ground
		local target = mouse.Target
		if target and target.Name == "Ground" and target.Parent and target.Parent.Name:match("Exhibit") then
			lastAction = tick()
			remote:FireServer("Drop", {pos = mouse.Hit.Position, exhibitName = target.Parent.Name})
		else
			-- Provide some client-side feedback or just ignore
			print("Must click on an Exhibit Ground to release the koala!")
		end
	else
		lastAction = tick()
		remote:FireServer("PickUp")
	end
end)
