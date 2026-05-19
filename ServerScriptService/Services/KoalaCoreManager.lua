local KoalaCoreManager = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local KoalaConfig    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
local KoalaVFX       = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaVFX"))
local KoalaLifecycle = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaLifecycle"))
local KoalaGrowth    = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaGrowth"))

-- ============================================================
-- INITIALIZE
-- ============================================================

function KoalaCoreManager.Initialize()
	-- Start background growth loop
	KoalaGrowth.Initialize()

	-- Handle incoming KoalaActions
	local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")

	koalaAction.OnServerEvent:Connect(function(player, action, targetKoala)
		if not targetKoala or not targetKoala:IsDescendantOf(workspace) then return end

		if action == "Cuddle" then
			targetKoala:SetAttribute("LastCuddleTime", workspace:GetServerTimeNow())
			print("[KoalaCoreManager] " .. player.Name .. " cuddled " .. targetKoala.Name)

			-- Show Heart Emoji Effect
			KoalaVFX.ShowHeartEffect(targetKoala)

			-- Force immediate UI/status update AND check for growth
			KoalaGrowth.RefreshGrowth(targetKoala)

			-- Start physical cuddle interaction via signal
			local signals = ServerStorage:FindFirstChild("Signals")
			local cuddleRequest = signals and signals:FindFirstChild("CuddleRequest")
			if cuddleRequest then
				cuddleRequest:Fire(player, targetKoala)
			else
				warn("[KoalaCoreManager] CuddleRequest signal not found!")
			end
		elseif action == "Follow" then
			-- Clear any existing follower for this player
			for _, k in ipairs(CollectionService:GetTagged("KoalaNPC")) do
				if k:GetAttribute("FollowingPlayer") == player.Name then
					k:SetAttribute("FollowingPlayer", nil)
				end
			end
			targetKoala:SetAttribute("FollowingPlayer", player.Name)
			print("[KoalaCoreManager] " .. targetKoala.Name .. " is now following " .. player.Name)
		elseif action == "Stay" then
			targetKoala:SetAttribute("FollowingPlayer", nil)
			print("[KoalaCoreManager] " .. targetKoala.Name .. " is staying.")
		end
	end)

	-- Auto-init any koala that gets the KoalaNPC tag
	CollectionService:GetInstanceAddedSignal("KoalaNPC"):Connect(function(koala)
		task.wait(1)
		if not koala:IsDescendantOf(workspace) then return end
		if koala:FindFirstChild("KoalaStats") then return end
		KoalaLifecycle.InitKoala(koala, "Cute", 3600)
	end)

	-- Handle RespawnRequest (Signals)
	local signalsFolder = ServerStorage:WaitForChild("Signals")
	local respawnRequest = signalsFolder:FindFirstChild("RespawnRequest")
	if respawnRequest then
		respawnRequest.Event:Connect(function(oldKoala, pos, parent)
			KoalaLifecycle.RespawnAt(oldKoala, pos, parent)
		end)
	end

	-- Listen for SleepyEffect requests
	local sleepySignal = signalsFolder:FindFirstChild("SleepyEffect")
	if sleepySignal then
		sleepySignal.Event:Connect(function(koala)
			KoalaVFX.ShowSleepyEffect(koala)
		end)
	end

	-- Handle global shoutouts for rarity (can stay here or move to Lifecycle)
	-- For now, let's keep it in Lifecycle where InitKoala is, which it already is.

	print("[KoalaCoreManager] Fully Refactored & Initialized.")
end

return KoalaCoreManager


