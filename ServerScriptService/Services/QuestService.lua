local QuestService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

function QuestService.Initialize()
    local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
    local updateQuestSignal = Net.Signal("UpdateQuest")
    local remote = Net.Remote("QuestUpdate")

    updateQuestSignal.Event:Connect(function(player, message)
        remote:FireClient(player, message)
    end)
    
    print("[QuestService] Initialized. Listening to UpdateQuest signal.")
end

function QuestService.StartTutorial(player) 
    -- Existing dummy function
end

return QuestService
