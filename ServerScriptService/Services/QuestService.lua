local QuestService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

function QuestService.Initialize()
    local signals = ServerStorage:WaitForChild("Signals")
    local updateQuestSignal = signals:WaitForChild("UpdateQuest")

    updateQuestSignal.Event:Connect(function(player, message)
        local remote = ReplicatedStorage:FindFirstChild("QuestUpdate")
        if remote then 
            remote:FireClient(player, message) 
        end
    end)
    
    print("[QuestService] Initialized. Listening to UpdateQuest signal.")
end

function QuestService.StartTutorial(player) 
    -- Existing dummy function
end

return QuestService
