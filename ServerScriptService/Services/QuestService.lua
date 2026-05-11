-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local QuestService = {}
function QuestService.UpdateQuest(player, message)
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("QuestUpdate")
	if remote then remote:FireClient(player, message) end
end
function QuestService.Initialize() end
function QuestService.StartTutorial(player) end
return QuestService
