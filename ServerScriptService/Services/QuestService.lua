local QuestService = {}

function QuestService.UpdateQuest(player, message)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remote = ReplicatedStorage:FindFirstChild("QuestUpdate")
	if remote then
		remote:FireClient(player, message)
	end
end

function QuestService.Initialize()
	-- Legacy init removed
end

function QuestService.StartTutorial(player)
	-- Legacy tutorial removed
end

return QuestService
