-- Shovel Tool Script
local tool = script.Parent
local player = nil
local character = nil

tool.Equipped:Connect(function()
    player = game.Players:GetPlayerFromCharacter(tool.Parent)
    character = tool.Parent
end)

tool.Unequipped:Connect(function()
    player = nil
    character = nil
end)

-- The actual clearing logic is handled by SecondExhibitManager
-- This script just tracks when the shovel is equipped
