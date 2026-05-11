local Players = game:GetService("Players")
local RUN_SPEED = 24 -- Default is 16
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = RUN_SPEED
	end)
end)
-- Also update any players already in the game
for _, player in pairs(Players:GetPlayers()) do
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.WalkSpeed = RUN_SPEED
	end
end
print("Player WalkSpeed boosted to " .. RUN_SPEED)
local Players = game:GetService("Players")
local RUN_SPEED = 24 -- Default is 16
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = RUN_SPEED
	end)
end)
-- Also update any players already in the game
for _, player in pairs(Players:GetPlayers()) do
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.WalkSpeed = RUN_SPEED
	end
end
print("Player WalkSpeed boosted to " .. RUN_SPEED)
