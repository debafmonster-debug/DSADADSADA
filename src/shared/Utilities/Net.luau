--!nonstrict
-- Remote registry. Server creates the instances, client waits for them.
-- Every remote is declared here so there are no stray string names in code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- server -> client
	"ShiftListUpdated", "ProfileUpdated", "RoundState", "TaskUpdated", "Notification",
	"Results", "Briefing", "SignalBroadcast", "DownedState", "SpectateTarget", "DebugLayout",
	"CreatureState", "FacilityState", "DocumentFound", "PlayerFlags",
	-- client -> server
	"SignalSend", "FlashlightState", "MovementState", "ClientReady",
}

Net.Functions = {
	"ShiftCreate", "ShiftJoin", "ShiftLeave", "ShiftReady", "ShiftStart", "ShiftList",
	"SelectTool", "GetProfile", "GetArchive", "SaveSettings",
	"TaskInteract", "RescueAction", "ReturnToLobby", "ReadDocument", "TerminalQuery",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			for _, name in Net.Events do
				local e = Instance.new("RemoteEvent")
				e.Name = name
				e.Parent = f
			end
			for _, name in Net.Functions do
				local e = Instance.new("RemoteFunction")
				e.Name = name
				e.Parent = f
			end
			f.Parent = ReplicatedStorage
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

return Net
