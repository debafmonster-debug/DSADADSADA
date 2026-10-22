--!nonstrict
-- Event Director: the small, deniable wrongnesses. Every event has explicit
-- conditions, a cooldown and a budget; nothing fires in the first quiet
-- minutes so players learn the station's normal state first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local FacilityService = require(script.Parent.FacilityService)
local CreatureService = require(script.Parent.CreatureService)
local CommunicationService = require(script.Parent.CommunicationService)
local IdentityService = require(script.Parent.IdentityService)

local EventDirector = {}
EventDirector.Fired = Signal.new() :: Signal.Signal<string>

local map = nil
local rng = SeededRandom.new(9)
local enabled: { [string]: boolean } = {}
local fired: { [string]: number } = {}
local startedAt = 0
local lastAny = 0
local deps = {
	stationHour = function()
		return 0
	end,
	isNight = function()
		return false
	end,
	escalated = function()
		return false
	end,
	roomOccupied = function(_roomId: string)
		return false
	end,
	anyPlayerNear = function(_pos: Vector3, _r: number)
		return false
	end,
	teamPlayers = function()
		return {}
	end,
}

function EventDirector.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

local function playAt(pos: Vector3, key: string, parent: Instance?)
	local def = Sounds[key]
	if not def or not def.id then
		return
	end
	local p = Builder.invisible(parent or map.root, "EventSound", CFrame.new(pos), Vector3.new(1, 1, 1))
	local s = Builder.sound(p, def, key)
	s:Play()
	task.delay(6, function()
		p:Destroy()
	end)
end

local function story(text: string)
	Net.event("StoryEvent"):FireAllClients({ text = text })
end

-- ===== Event definitions =================================================
-- Each: minMinutes (real since shift start), cooldown, maxTimes, when(), run().

local defs = {}

defs.ExtraMug = {
	minMinutes = 3,
	cooldown = 600,
	maxTimes = 1,
	when = function()
		return not deps.roomOccupied("Kitchen") and not deps.roomOccupied("RestRoom")
	end,
	run = function()
		local spots = map.eventSpots.ExtraMug
		if not spots or #spots == 0 then
			return false
		end
		local cf = spots[rng:nextInteger(1, #spots)]
		local mug = Props.mug(map.root:FindFirstChild("Room_Kitchen") or map.root, cf, true)
		mug.Name = "ExtraMug"
		return true
	end,
}

defs.ChairMoved = {
	minMinutes = 4,
	cooldown = 400,
	maxTimes = 2,
	when = function()
		return not deps.roomOccupied("RestRoom")
	end,
	run = function()
		local room = map.root:FindFirstChild("Room_RestRoom")
		local chair = room and room:FindFirstChild("Chair")
		if not chair or not chair.PrimaryPart then
			return false
		end
		-- Move to a spot that cannot trap anyone: into the open middle, turned to face the door.
		chair:PivotTo(chair:GetPivot() * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi * 0.8, 0))
		return true
	end,
}

defs.RadioCallsign = {
	minMinutes = 6,
	cooldown = 900,
	maxTimes = 1,
	when = function()
		return deps.isNight() or deps.stationHour() >= 21
	end,
	run = function()
		local players = deps.teamPlayers()
		if #players == 0 then
			return false
		end
		local victim = players[rng:nextInteger(1, #players)]
		CommunicationService.Incoming("Эфир", string.upper(victim.DisplayName) .. ", приём. " .. string.upper(victim.DisplayName) .. ", ответьте.", "echo")
		-- The dorm radio and the corridor speaker click on as well.
		if map.dormRadio and map.dormRadio.PrimaryPart then
			playAt(map.dormRadio.PrimaryPart.CFrame.Position, "RadioClick")
		end
		return true
	end,
}

defs.DoorHandle = {
	minMinutes = 5,
	cooldown = 300,
	maxTimes = 3,
	when = function()
		return deps.roomOccupied("Dorm") or deps.roomOccupied("Control") or deps.roomOccupied("RestRoom")
	end,
	run = function()
		local candidates = {}
		for id, door in map.roomDoors do
			if deps.roomOccupied(id) then
				table.insert(candidates, door)
			end
		end
		if #candidates == 0 then
			return false
		end
		local door = candidates[rng:nextInteger(1, #candidates)]
		local leaf = door:FindFirstChild("Leaf")
		if not leaf then
			return false
		end
		for i = 1, 3 do
			task.delay(i * 0.9, function()
				local s = Builder.sound(leaf, Sounds.DoorHandle, "Handle")
				s.PlaybackSpeed = 0.6 + rng:nextNumber() * 0.1
				s:Play()
				task.delay(2, function()
					s:Destroy()
				end)
			end)
		end
		return true
	end,
}

defs.FootstepsRoof = {
	minMinutes = 7,
	cooldown = 420,
	maxTimes = 2,
	when = function()
		return deps.roomOccupied("Dorm") and (deps.isNight() or deps.stationHour() >= 21)
	end,
	run = function()
		local spots = map.eventSpots.FootstepsRoof
		if not spots then
			return false
		end
		local base = spots[1].Position
		for i = 1, 6 do
			task.delay(i * 1.1 + rng:nextNumber() * 0.3, function()
				playAt(base + Vector3.new((i - 3) * 2.5, 0, 0), "Knock")
			end)
		end
		return true
	end,
}

defs.Knock = {
	minMinutes = 8,
	cooldown = 240,
	maxTimes = 3,
	when = function()
		return deps.isNight() and CreatureService.IsActive() and (deps.roomOccupied("Dorm") or deps.roomOccupied("Bunker"))
	end,
	run = function()
		local door = if deps.roomOccupied("Bunker") then map.doors.bunker else map.doors.dorm
		if not door then
			return false
		end
		if deps.roomOccupied("Bunker") then
			-- Inside the bunker the Guest cannot path; play the knocks from outside the door.
			local leaf = door:FindFirstChild("Leaf")
			for i = 1, 3 do
				task.delay(i * 1.4 + rng:nextNumber(), function()
					playAt(leaf.CFrame.Position + leaf.CFrame.LookVector * 2, "Knock")
				end)
			end
			return true
		end
		return CreatureService.PlayScripted("Knock", { door = door, outsideSign = -1 })
	end,
}

defs.Silence = {
	minMinutes = 9,
	cooldown = 500,
	maxTimes = 1,
	when = function()
		return deps.isNight()
	end,
	run = function()
		-- The corridor vent hum stops for a while; nothing else changes.
		local vent = map.root:FindFirstChild("Vent", true)
		if not vent or not vent:IsA("Sound") then
			return false
		end
		vent:Stop()
		task.delay(40 + rng:nextInteger(0, 30), function()
			if vent.Parent then
				vent:Play()
			end
		end)
		return true
	end,
}

defs.WindowSilhouette = {
	minMinutes = 6,
	cooldown = 360,
	maxTimes = 2,
	when = function()
		return CreatureService.IsActive() and (deps.roomOccupied("Control") or deps.roomOccupied("Dorm"))
	end,
	run = function()
		local pos = if deps.roomOccupied("Dorm") then map.point("DormBoard") + Vector3.new(2, -6, 20) else map.point("ControlBoard") + Vector3.new(-7, -6, -8)
		return CreatureService.PlayScripted("Window", { pos = Vector3.new(pos.X, 0, pos.Z), seconds = 9 + rng:nextInteger(0, 6) })
	end,
}

defs.Sabotage = {
	minMinutes = 8,
	cooldown = 400,
	maxTimes = 2,
	when = function()
		local PowerGridService = require(script.Parent.PowerGridService)
		return deps.isNight() and CreatureService.IsActive() and PowerGridService.Generator().coverOpen and PowerGridService.Generator().running and not deps.anyPlayerNear(map.point("Generator"), 30)
	end,
	run = function()
		return CreatureService.PlayScripted("Sabotage", { pos = map.point("Generator") + Vector3.new(0, 0, -6) })
	end,
}

defs.Reflection = {
	minMinutes = 5,
	cooldown = 300,
	maxTimes = 2,
	when = function()
		return deps.roomOccupied("DormWash") or deps.roomOccupied("Washroom")
	end,
	run = function()
		-- Local-only hallucination: the client draws a figure in the mirror for whoever is there.
		for _, p in deps.teamPlayers() do
			local room = FacilityService.RoomAt(FacilityService.PlayerPosition(p) or Vector3.zero)
			if room and (room.id == "DormWash" or room.id == "Washroom") then
				Net.event("Hallucination"):FireClient(p, { kind = "Reflection" })
			end
		end
		return true
	end,
}

-- ===== Scheduler ===========================================================

function EventDirector.BeginShift(mapHandle, shiftDef, seed: number)
	map = mapHandle
	rng = SeededRandom.new(seed + 77)
	table.clear(enabled)
	table.clear(fired)
	for _, id in shiftDef.events do
		enabled[id] = true
	end
	enabled.Knock = true
	enabled.Silence = true
	enabled.WindowSilhouette = true
	enabled.Sabotage = true
	startedAt = os.clock()
	lastAny = os.clock()
end

function EventDirector.EndShift()
	map = nil
	table.clear(enabled)
end

function EventDirector.Force(id: string): boolean
	local d = defs[id]
	if not d or not map then
		return false
	end
	local ok = d.run()
	if ok then
		EventDirector.Fired:Fire(id)
	end
	return ok
end

local lastFired: { [string]: number } = {}

function EventDirector.Tick()
	if not map then
		return
	end
	local now = os.clock()
	if now - lastAny < 45 then
		return -- global spacing: never two wrongnesses back to back
	end
	local elapsedMin = (now - startedAt) / 60
	local candidates = {}
	for id, d in defs do
		if not enabled[id] then
			continue
		end
		if (fired[id] or 0) >= d.maxTimes then
			continue
		end
		if elapsedMin < d.minMinutes then
			continue
		end
		if now - (lastFired[id] or 0) < d.cooldown then
			continue
		end
		local ok, cond = pcall(d.when)
		if ok and cond then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		return
	end
	if rng:nextNumber() > 0.35 then
		return -- most ticks do nothing; the quiet is the point
	end
	local id = candidates[rng:nextInteger(1, #candidates)]
	local ok, result = pcall(defs[id].run)
	if ok and result then
		fired[id] = (fired[id] or 0) + 1
		lastFired[id] = now
		lastAny = now
		EventDirector.Fired:Fire(id)
	end
end

function EventDirector.Init() end

function EventDirector.Start()
	task.spawn(function()
		while true do
			task.wait(15)
			local ok, err = pcall(EventDirector.Tick)
			if not ok then
				warn("[Events] " .. tostring(err))
			end
		end
	end)
end

-- For completeness: the identity service double-exposure also counts as a story beat.
IdentityService.DoubleExposed:Connect(function()
	story("Двойник разоблачён.")
end)

EventDirector.Defs = defs
EventDirector._players = Players

return EventDirector
