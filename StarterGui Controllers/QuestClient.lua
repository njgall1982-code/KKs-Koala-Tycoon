local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")

-- We find the sound, but we don't WAIT for it. If it's missing, the quest still works.
local sound = ReplicatedStorage:FindFirstChild("QuestUpdateSound")

local gui = script.Parent
local frame = gui:WaitForChild("MainFrame")
local objective = frame:WaitForChild("Objective")

-- Hide frame by default on startup to prevent flashing old quest data
frame.Visible = false

local currentQuestId = 0

local function typewrite(text)
	currentQuestId = currentQuestId + 1
	local myId = currentQuestId
	
	objective.Text = ""
	for i = 1, #text do
		if myId ~= currentQuestId then return end
		objective.Text = string.sub(text, 1, i)
		task.wait(0.02)
	end
end

local function updateQuest(message)
	if message == "" then
		local fade = TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		local fadeText = TweenService:Create(objective, TweenInfo.new(0.5), {TextTransparency = 1})
		local fadeTitle = TweenService:Create(frame.Title, TweenInfo.new(0.5), {TextTransparency = 1})
		
		fade:Play()
		fadeText:Play()
		fadeTitle:Play()
		
		fade.Completed:Connect(function()
			frame.Visible = false
			-- Reset transparencies for next quest
			frame.BackgroundTransparency = 0.2
			objective.TextTransparency = 0
			frame.Title.TextTransparency = 0
		end)
		return
	end
	
	frame.Visible = true

	-- Pulse frame
	local pulse = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {
		BackgroundColor3 = Color3.fromRGB(0, 255, 150),
		BackgroundTransparency = 0.4
	})
	pulse:Play()
	
	typewrite(message)
end

remote.OnClientEvent:Connect(updateQuest)
