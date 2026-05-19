        local tool = script.Parent
        tool.Equipped:Connect(function()
            print("[DevWand] Equipped! Attempting to force DevMenu...")
            local player = game.Players.LocalPlayer
            local gui = player.PlayerGui:FindFirstChild("DevMenu")
            if gui then
                gui.Enabled = true
                print("[DevWand] DevMenu enabled.")
            else
                warn("[DevWand] DevMenu GUI not found in PlayerGui!")
            end
        end)
    