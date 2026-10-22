--!nonstrict
-- Noise Director: the only channel through which the creature learns about
-- players. Every loud action becomes a noise event with loudness, radius and
-- a position; hearing is computed per listener through walls and doors, and
-- the director remembers where the team has been noisy (sector heat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)

local N = GameConfig.Noise

export type NoiseEvent = { pos: Vector3, loud: number, radius: number, source: string, player: Player?, at: number, zone: string? }

local NoiseDirector = {}
NoiseDirector.Reported = Signal.new() :: Signal.Signal<NoiseEvent>

local events: { NoiseEvent } = {}
local sectorHeat: { [string]: number } = {}
local lastWalkReport: { [Player]: number } = {}
local zoneOf: (Vector3) -> string? = function(_)
	return nil
end
local occluderFilter: { Instance } = {}
local enabled = false

function NoiseDirector.Configure(zoneResolver: (Vector3) -> string?, filter: { Instance }?)
	zoneOf = zoneResolver
	occluderFilter = filter or {}
end

function NoiseDirector.SetEnabled(on: boolean)
	enabled = on
	if not on then
		table.clear(events)
		table.clear(sectorHeat)
	end
end

function NoiseDirector.Report(pos: Vector3, source: string, player: Player?, loudOverride: number?, radiusOverride: number?): NoiseEvent?
	if not enabled then
		return nil
	end
	local def = N.Sources[source]
	if not def and not loudOverride then
		return nil
	end
	local ev: NoiseEvent = {
		pos = pos,
		loud = loudOverride or def.loud,
		radius = radiusOverride or def.radius,
		source = source,
		player = player,
		at = os.clock(),
		zone = zoneOf(pos) or "Outdoor",
	}
	table.insert(events, ev)
	if #events > 64 then
		table.remove(events, 1)
	end
	sectorHeat[ev.zone] = math.min(1, (sectorHeat[ev.zone] or 0) + N.SectorHeatPerEvent * ev.loud)
	NoiseDirector.Reported:Fire(ev)
	return ev
end

-- Count solid hits between two points. Doors count less than walls. The
-- creature never gets a free position: it only hears what gets through.
local function occlusion(from: Vector3, to: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = occluderFilter
	local attenuation = 1
	local origin = from
	local remaining = to - from
	for _ = 1, 5 do
		if remaining.Magnitude < 0.5 then
			break
		end
		local ok, hit = pcall(function()
			return workspace:Raycast(origin, remaining, params)
		end)
		if not ok or not hit then
			break
		end
		local inst = hit.Instance
		if inst and inst.Transparency < 0.5 and inst.CanCollide then
			local door = inst.Name == "Leaf"
			attenuation *= if door then N.DoorAttenuation else N.WallAttenuation
		end
		origin = hit.Position + remaining.Unit * 0.6
		remaining = to - origin
	end
	return attenuation
end

-- How strongly `listener` would hear `ev` right now (0 = inaudible).
function NoiseDirector.Audibility(ev: NoiseEvent, listener: Vector3, hearMult: number?): number
	local age = os.clock() - ev.at
	if age > N.MemorySeconds then
		return 0
	end
	local dist = (ev.pos - listener).Magnitude
	local radius = ev.radius * (hearMult or 1)
	if dist > radius then
		return 0
	end
	local base = ev.loud * (1 - dist / radius)
	local decay = 1 - age / N.MemorySeconds
	return base * decay * occlusion(ev.pos, listener)
end

-- Best audible event for a listener; nil when nothing gets through.
function NoiseDirector.Loudest(listener: Vector3, hearMult: number?, minStrength: number?): (NoiseEvent?, number)
	local best, bestV = nil, minStrength or 0.05
	for _, ev in events do
		local v = NoiseDirector.Audibility(ev, listener, hearMult)
		if v > bestV then
			best, bestV = ev, v
		end
	end
	return best, if best then bestV else 0
end

-- Where the team has been loud lately; patrol weighting reads this.
function NoiseDirector.HottestZone(): (string?, number)
	local best, bestV = nil, 0
	for z, v in sectorHeat do
		if v > bestV then
			best, bestV = z, v
		end
	end
	return best, bestV
end

function NoiseDirector.Heat(zone: string): number
	return sectorHeat[zone] or 0
end

function NoiseDirector.Recent(seconds: number): { NoiseEvent }
	local out = {}
	local now = os.clock()
	for _, ev in events do
		if now - ev.at <= seconds then
			table.insert(out, ev)
		end
	end
	return out
end

-- Pure decay step used by the loop and tests.
function NoiseDirector.Tick(dt: number)
	for z, v in sectorHeat do
		sectorHeat[z] = math.max(0, v - N.SectorHeatDecayPerSecond * dt)
	end
	local now = os.clock()
	for i = #events, 1, -1 do
		if now - events[i].at > N.MemorySeconds then
			table.remove(events, i)
		end
	end
end

-- Movement noise is measured on the server from actual velocity, never trusted
-- from the client.
local function sampleMovement()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			continue
		end
		local speed = hrp.AssemblyLinearVelocity.Magnitude
		local now = os.clock()
		if speed > GameConfig.Character.SprintNoiseSpeed then
			if now - (lastWalkReport[p] or 0) > 0.6 then
				lastWalkReport[p] = now
				NoiseDirector.Report(hrp.CFrame.Position, "Sprint", p)
			end
		elseif speed > 4 then
			if now - (lastWalkReport[p] or 0) > 1.5 then
				lastWalkReport[p] = now
				NoiseDirector.Report(hrp.CFrame.Position, "Walk", p)
			end
		end
	end
end

function NoiseDirector.Init() end

function NoiseDirector.Start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.5)
			local now = os.clock()
			NoiseDirector.Tick(now - last)
			last = now
			if enabled then
				sampleMovement()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastWalkReport[p] = nil
	end)
end

-- Expose zone list for tests / debug.
NoiseDirector.Zones = Station.Zones

return NoiseDirector
