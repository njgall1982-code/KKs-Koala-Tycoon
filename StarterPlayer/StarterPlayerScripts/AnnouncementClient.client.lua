local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remote = ReplicatedStorage:WaitForChild("GlobalAnnounce", 10)
if not remote then
	-- Create on client if it doesn't exist yet (safety)
	remote = Instance.new("RemoteEvent", ReplicatedStorage)
	remote.Name = "GlobalAnnounce"
end

remote.OnClientEvent:Connect(function(message)
	-- Use the default Roblox system chat message for "Global" feel
	StarterGui:SetCore("ChatMakeSystemMessage", {
		Text = message,
		Color = Color3.fromRGB(255, 200, 0), -- Gold color
		Font = Enum.Font.GothamBold,
		FontSize = Enum.FontSize.Size24
	})
end)
