local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local frame = gui:WaitForChild("Main")
local openEvent = ReplicatedStorage:WaitForChild("OpenExhibitManage")
local renameEvent = ReplicatedStorage:WaitForChild("RenameExhibit")
local upgradeEvent = ReplicatedStorage:WaitForChild("UpgradeExhibit")

local currentExhibitPath = ""

openEvent.OnClientEvent:Connect(function(exhibitPath)
	currentExhibitPath = exhibitPath
	gui.Enabled = true
	frame.RenameBox.Text = ""
end)

frame.Close.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

frame.RenameBtn.MouseButton1Click:Connect(function()
	local newName = frame.RenameBox.Text
	if newName ~= "" then
		renameEvent:FireServer(currentExhibitPath, newName)
		gui.Enabled = false
	end
end)

frame.UpgradeFeeder.MouseButton1Click:Connect(function()
	upgradeEvent:FireServer(currentExhibitPath, "Feeder")
	gui.Enabled = false
end)

frame.UpgradeSpace.MouseButton1Click:Connect(function()
	upgradeEvent:FireServer(currentExhibitPath, "Exhibit")
	gui.Enabled = false
end)
