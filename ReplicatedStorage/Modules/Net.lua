--[[
	Net: single registry of every RemoteEvent / RemoteFunction (client <-> server)
	and every Signal (server <-> server BindableEvent / BindableFunction).

	WHY: names used to be raw strings scattered across ~30 files. A typo failed
	silently (or yielded forever). Now:
	  * Net.Remote("Name") / Net.Signal("Name") ERROR LOUDLY on an unknown name.
	  * The instance is created on demand on the server, so load order and Studio
	    sync stop mattering.
	  * Net.Audit() (run by ValidationService after startup) reports anything
	    missing or of the wrong class.

	ADDING A NEW REMOTE/SIGNAL: add one line to the tables below, then use
	Net.Remote("YourName") / Net.Signal("YourName") everywhere. Never use raw strings.

	USAGE
	  Server: local ev = Net.Remote("QuestUpdate"); ev:FireClient(player, msg)
	  Client: local ev = Net.Remote("QuestUpdate"); ev.OnClientEvent:Connect(fn)
	  Server: Net.Signal("UpdateQuest"):Fire(player, msg)   -- Signals are server-only
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- name = "Event" (RemoteEvent) | "Function" (RemoteFunction). Live in ReplicatedStorage.
Net.Remotes = {
	-- Economy / shops
	PurchaseToolEvent   = "Event",
	OpenShopEvent       = "Event",
	PurchaseOutfitEvent = "Event",
	OpenOutfitShopEvent = "Event",
	EquipOutfitRequest  = "Event",
	-- Quests / announcements
	QuestUpdate         = "Event",
	GlobalAnnounce      = "Event",
	-- Exhibits
	RenameExhibit       = "Event",
	OpenExhibitManage   = "Event",
	UpgradeExhibit      = "Event",
	LeafDropVFX         = "Event",
	-- Koalas
	KoalaAction         = "Event",
	InspectKoala        = "Event",
	InspectRequest      = "Event",
	RenameKoala         = "Event",
	-- Zoo terminal / analytics
	OpenZooAnalytics    = "Event",
	GetZooAnalyticsData = "Function",
	ZooTerminalAction   = "Function",
	-- Staff / workers
	OpenStaffDesk       = "Event",
	StaffAction         = "Function",
	-- Teleport / dev
	TeleportNotification = "Event",
	DevAction           = "Event",
	-- Legacy: exists in Studio but no script uses it. Safe to delete from ReplicatedStorage, then remove this line.
	GiftZooEvent        = "Event",
	-- NOTE: Tool-local remotes (e.g. CrateAction inside the TransferCrate tool) are not global; not listed.
}

-- name = "Event" (BindableEvent) | "Function" (BindableFunction). Live in ServerStorage.Signals.
Net.Signals = {
	AwardTool          = "Event",
	UpdateQuest        = "Event",
	ForcePickup        = "Event",
	GrantCurrency      = "Event",
	ShowStatus         = "Event",
	CuddleRequest      = "Event",
	RespawnRequest     = "Event",
	SleepyEffect       = "Event",
	UnlockOutfit       = "Event",
	EquipOutfit        = "Event",
	InitKoalaAI        = "Event",
	CarryAction        = "Event",
	TransactionRequest = "Function",
	SavePlayerData     = "Function",
}

local REMOTE_CLASS = { Event = "RemoteEvent", Function = "RemoteFunction" }
local SIGNAL_CLASS = { Event = "BindableEvent", Function = "BindableFunction" }

local function getSignalsFolder()
	local folder = ServerStorage:FindFirstChild("Signals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Signals"
		folder.Parent = ServerStorage
	end
	return folder
end

function Net.Remote(name)
	local kind = Net.Remotes[name]
	if not kind then
		error(("[Net] Unknown remote '%s'. Add it to Net.Remotes first."):format(tostring(name)), 2)
	end

	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing end

	if RunService:IsServer() then
		local remote = Instance.new(REMOTE_CLASS[kind])
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	end

	-- Client: the server creates it; wait for replication.
	local remote = ReplicatedStorage:WaitForChild(name, 10)
	if not remote then
		warn(("[Net] Remote '%s' never replicated to the client."):format(name))
	end
	return remote
end

function Net.Signal(name)
	local kind = Net.Signals[name]
	if not kind then
		error(("[Net] Unknown signal '%s'. Add it to Net.Signals first."):format(tostring(name)), 2)
	end
	if not RunService:IsServer() then
		error("[Net] Signals are server-only.", 2)
	end

	local folder = getSignalsFolder()
	local existing = folder:FindFirstChild(name)
	if existing then return existing end

	local signal = Instance.new(SIGNAL_CLASS[kind])
	signal.Name = name
	signal.Parent = folder
	return signal
end

-- Server-side audit. Returns a list of problem strings (empty = healthy).
-- Does not create anything; it reports what scripts will find at runtime.
function Net.Audit()
	local problems = {}
	for name, kind in pairs(Net.Remotes) do
		local inst = ReplicatedStorage:FindFirstChild(name)
		if not inst then
			table.insert(problems, "Remote not created yet: " .. name)
		elseif not inst:IsA(REMOTE_CLASS[kind]) then
			table.insert(problems, ("Remote '%s' is %s, expected %s"):format(name, inst.ClassName, REMOTE_CLASS[kind]))
		end
	end
	local folder = ServerStorage:FindFirstChild("Signals")
	for name, kind in pairs(Net.Signals) do
		local inst = folder and folder:FindFirstChild(name)
		if not inst then
			table.insert(problems, "Signal not created yet: " .. name)
		elseif not inst:IsA(SIGNAL_CLASS[kind]) then
			table.insert(problems, ("Signal '%s' is %s, expected %s"):format(name, inst.ClassName, SIGNAL_CLASS[kind]))
		end
	end
	-- Anything in the folders that the registry doesn't know about = likely typo or dead object.
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and not Net.Remotes[child.Name] then
			table.insert(problems, "Unregistered remote in ReplicatedStorage: " .. child.Name)
		end
	end
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if not Net.Signals[child.Name] then
				table.insert(problems, "Unregistered signal in ServerStorage.Signals: " .. child.Name)
			end
		end
	end
	return problems
end

return Net
