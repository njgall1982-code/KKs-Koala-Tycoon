local rs = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("Overlay")
local text = frame:WaitForChild("Message")

-- Immediate cleanup on start to prevent blocking clicks
frame.Active = false
pcall(function() frame.Interactable = false end)
frame.Visible = false -- Hide initially in case fade-in isn't run or finishes

-- Spawn Fade-In Transition (from black/opaque to transparent)
local function runSpawnFadeIn()
	-- Make sure it is visible and opaque at start of transition
	frame.BackgroundTransparency = 0
	text.TextTransparency = 0
	frame.Visible = true
	
	-- Wait a moment so player sees the screen loaded
	task.wait(0.5)
	
	-- Tween to transparent
	local frameTween = ts:Create(frame, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
	local textTween = ts:Create(text, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
	
	frameTween:Play()
	textTween:Play()
	
	frameTween.Completed:Connect(function()
		frame.Visible = false
	end)
end

-- Run spawn transition safely in a thread
task.spawn(runSpawnFadeIn)

-- Handle teleport fade-out event from server
local event = rs:WaitForChild("TeleportNotification")
event.OnClientEvent:Connect(function()
	frame.Visible = true
	frame.Active = true
	pcall(function() frame.Interactable = true end)
	
	local frameTween = ts:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0})
	local textTween = ts:Create(text, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 0})
	
	frameTween:Play()
	textTween:Play()
end)
