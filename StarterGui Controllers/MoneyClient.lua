local Players = game:GetService("Players")
local player = Players.LocalPlayer
local amountLabel = script.Parent:WaitForChild("MainFrame"):WaitForChild("Amount")

local function updateCash(value)
	amountLabel.Text = "$" .. string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function setup()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local cash = leaderstats:WaitForChild("Cash", 10)
		if cash then
			updateCash(cash.Value)
			cash.Changed:Connect(updateCash)
		end
	end
end

setup()
player.CharacterAdded:Connect(setup)
