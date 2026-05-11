local ShopService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")
local connections = {} -- toolShed -> connection
function ShopService.Initialize()
	-- Function to connect a tool shed
	local function connectToolShed(toolShed)
		if not toolShed or toolShed.Name ~= "ToolShed" then return end
		if connections[toolShed] then return end
		
		local prompt = toolShed:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			print("[ShopService] Connected to ToolShed prompt at: " .. toolShed:GetFullName())
			connections[toolShed] = prompt.Triggered:Connect(function(player)
				ShopService.OpenShop(player)
			end)
			
			-- Handle toolShed being destroyed
			toolShed.Destroying:Connect(function()
				if connections[toolShed] then
					connections[toolShed]:Disconnect()
					connections[toolShed] = nil
				end
			end)
		end
	end
	-- Scan existing
	for _, desc in pairs(workspace:GetDescendants()) do
		connectToolShed(desc)
	end
	
	-- Watch for new ones
	workspace.DescendantAdded:Connect(connectToolShed)
	
	print("[ShopService] Initialized with robust ToolShed monitoring.")
end
function ShopService.OpenShop(player)
	openShopEvent:FireClient(player)
	print("[ShopService] Sent OpenShopEvent to " .. player.Name)
end
return ShopService
