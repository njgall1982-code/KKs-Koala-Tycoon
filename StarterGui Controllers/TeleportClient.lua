local rs = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")
local event = rs:WaitForChild("TeleportNotification")
local gui = script.Parent
local frame = gui:WaitForChild("Overlay")
local text = frame:WaitForChild("Message")

event.OnClientEvent:Connect(function()
	ts:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 0.3}):Play()
	ts:Create(text, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
end)
