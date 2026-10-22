--!nonstrict
-- Remote registry. Server creates the instances, client waits for them.
-- Every remote is declared here so there are no stray string names in code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- server -> client
	"RoomListUpdated", "ProfileUpdated", "RoundState", "TaskUpdated", "Notification",
	"Results", "Briefing", "SignalBroadcast", "DownedState", "SpectateTarget", "DebugLayout",
	"CreatureState", "PowerState", "WeatherState", "ClockState", "PlayerFlags", "DocumentFound",
	"Subtitle", "Cinematic", "RadioState", "InventoryUpdated", "HeadcountResult", "ScannerEvent",
	"Hallucination", "GeneratorState", "StoryEvent",
	-- client -> server
	"SignalSend", "FlashlightState", "ClientReady", "CinematicDone",
}

Net.Functions = {
	"RoomCreate", "RoomJoin", "RoomLeave", "RoomReady", "RoomStart", "RoomList",
	"SelectTool", "GetProfile", "GetArchive", "SaveSettings", "TerminalQuery",
	"RescueAction", "ReturnToLobby", "ReadDocument", "IntroChoice",
	"RadioTune", "RadioSend", "RadioQuery", "KeypadSubmit", "InventoryUse",
	"BreakerToggle", "BreakerReset", "Headcount", "GeneratorAction",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder :: Folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			for _, name in Net.Events do
				local e = Instance.new("RemoteEvent")
				e.Name = name
				e.Parent = nf
			end
			for _, name in Net.Functions do
				local e = Instance.new("RemoteFunction")
				e.Name = name
				e.Parent = nf
			end
			nf.Parent = ReplicatedStorage
			f = nf
		end
		folder = f
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

function Net.event(name: string): RemoteEvent
	local f = getFolder()
	local r = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(r and r:IsA("RemoteEvent"), "Unknown RemoteEvent " .. name)
	return r
end

function Net.func(name: string): RemoteFunction
	local f = getFolder()
	local r = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(r and r:IsA("RemoteFunction"), "Unknown RemoteFunction " .. name)
	return r
end

-- Validation helpers used by every server handler.
function Net.isString(v: any, maxLen: number?): boolean
	return typeof(v) == "string" and #v <= (maxLen or 64)
end

function Net.isInt(v: any, min: number?, max: number?): boolean
	if typeof(v) ~= "number" or v ~= v or v % 1 ~= 0 then
		return false
	end
	if min and v < min then
		return false
	end
	if max and v > max then
		return false
	end
	return true
end

function Net.isNumber(v: any, min: number?, max: number?): boolean
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return false
	end
	if min and v < min then
		return false
	end
	if max and v > max then
		return false
	end
	return true
end

function Net.isBool(v: any): boolean
	return typeof(v) == "boolean"
end

function Net.ok(data: any?): { ok: boolean, data: any? }
	return { ok = true, data = data }
end

function Net.fail(reason: string): { ok: boolean, reason: string }
	return { ok = false, reason = reason }
end

-- Distance guard shared by interaction handlers: the player's root must be
-- within `maxDist` studs of `position`.
function Net.near(player: Player, position: Vector3, maxDist: number): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return (hrp.Position - position).Magnitude <= maxDist
end

return Net
