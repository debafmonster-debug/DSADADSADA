--!nonstrict
-- Seeded layout generator. Produces a graph of catalog modules on a grid,
-- validates it, retries with derived seeds and finally falls back to a
-- hand-authored layout that is known to be valid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local LayoutValidator = require(script.Parent.LayoutValidator)
local Catalog = require(script.Parent.Parent.MapModules.Catalog)

type Node = LayoutValidator.Node
type Edge = LayoutValidator.Edge
type Layout = LayoutValidator.Layout

local LayoutGenerator = {}

local MAX_ATTEMPTS = 24
local Dirs = LayoutValidator.Dirs
local DirOrder = { "N", "E", "S", "W" }
local Opposite = { N = "S", S = "N", E = "W", W = "E" }

local function hasTag(def, tag: string): boolean
	return table.find(def.tags, tag) ~= nil
end

local function modulesFor(sector: string, kind: string?): { any }
	local out = {}
	for _, def in Catalog.List do
		if def.sector == sector and (kind == nil or def.kind == kind) then
			table.insert(out, def)
		end
	end
	return out
end

-- Picks a weighted random module from `pool` not already used if unique.
local function pickModule(rng: SeededRandom.SeededRandom, pool: { any }, used: { [string]: boolean }, exclude: { [string]: boolean }?)
	local candidates = {}
	local total = 0
	for _, def in pool do
		if def.unique and used[def.id] then
			continue
		end
		if exclude and exclude[def.id] then
			continue
		end
		table.insert(candidates, def)
		total += def.weight
	end
	if #candidates == 0 then
		return nil
	end
	local r = rng:nextNumber() * total
	for _, def in candidates do
		r -= def.weight
		if r <= 0 then
			return def
		end
	end
	return candidates[#candidates]
end

local function buildPlan(rng: SeededRandom.SeededRandom, mission: Missions.MissionDef): { { sector: string, modules: { any }, locked: boolean } }
	-- Each sector contributes an ordered list of module defs. The spine is
	-- A -> B -> C -> E, with D as a branch off C.
	local used: { [string]: boolean } = {}
	local function take(def)
		used[def.id] = true
		return def
	end
	local function taskRoom(sector: string): any?
		local wanted = {}
		if mission.mainTask.sector == sector then
			table.insert(wanted, mission.mainTask.kind)
		end
		if mission.optionalTask and mission.optionalTask.sector == sector then
			table.insert(wanted, mission.optionalTask.kind)
		end
		local out = {}
		for _, kind in wanted do
			for _, def in modulesFor(sector, "room") do
				if hasTag(def, kind) then
					table.insert(out, take(def))
					break
				end
			end
		end
		return out
	end
	local function fill(sector: string, roomCount: number, corridorCount: number, mandatory: { any }): { any }
		local list = {}
		local rooms = modulesFor(sector, "room")
		local corridors = modulesFor(sector, "corridor")
		local remainingRooms = roomCount - #mandatory
		local roomsToPlace = table.clone(mandatory)
		for _ = 1, remainingRooms do
			local def = pickModule(rng, rooms, used)
			if def then
				table.insert(roomsToPlace, take(def))
			end
		end
		roomsToPlace = rng:shuffle(roomsToPlace)
		-- Interleave corridors between rooms.
		local ci = 0
		for i, def in roomsToPlace do
			if ci < corridorCount and (i == 1 or rng:chance(0.7)) then
				local c = pickModule(rng, corridors, used)
				if c then
					table.insert(list, c)
					ci += 1
				end
			end
			table.insert(list, def)
		end
		return list
	end

	local plan = {}
	-- Sector A: checkpoint first, always.
	local checkpoint = Catalog.ById.A_Checkpoint
	used[checkpoint.id] = true
	local aList = { checkpoint }
	for _, def in fill("A", rng:nextInteger(2, 3), 1, taskRoom("A")) do
		table.insert(aList, def)
	end
	table.insert(plan, { sector = "A", modules = aList, locked = false })
	table.insert(plan, { sector = "B", modules = fill("B", rng:nextInteger(3, 4), 2, taskRoom("B")), locked = false })
	table.insert(plan, { sector = "C", modules = fill("C", rng:nextInteger(3, 4), 2, taskRoom("C")), locked = false })
	-- E: loading then airlock last.
	local eList = { Catalog.ById.E_Corridor, Catalog.ById.E_Loading, Catalog.ById.E_Airlock }
	table.insert(plan, { sector = "E", modules = eList, locked = false })
	-- D branch
	local dMandatory = taskRoom("D")
	local dList = { Catalog.ById.D_Corridor, Catalog.ById.D_Airlock }
	used.D_Airlock = true
	for _, def in dMandatory do
		if def.id ~= "D_Airlock" then
			table.insert(dList, def)
		end
	end
	local extra = pickModule(rng, modulesFor("D", "room"), used, { D_Airlock = true })
	if extra then
		table.insert(dList, take(extra))
	end
	table.insert(plan, { sector = "D", modules = dList, locked = table.find(mission.lockedSectors, "D") ~= nil, branch = true })
	return plan
end

local function freeNeighbors(grid: { [string]: number }, x: number, z: number): { { side: string, x: number, z: number } }
	local out = {}
	for _, side in DirOrder do
		local d = Dirs[side]
		local nx, nz = x + d[1], z + d[2]
		if not grid[LayoutValidator.key(nx, nz)] then
			table.insert(out, { side = side, x = nx, z = nz })
		end
	end
	return out
end

local function attempt(seed: number, mission: Missions.MissionDef): Layout?
	local rng = SeededRandom.new(seed)
	local plan = buildPlan(rng, mission)
	local nodes: { Node } = {}
	local edges: { Edge } = {}
	local grid: { [string]: number } = {}
	local counters: { [string]: number } = {}
	local nextId = 0

	local function addNode(def, x: number, z: number, role: string): Node
		nextId += 1
		counters[def.sector] = (counters[def.sector] or 0) + 1
		local n: Node = {
			id = nextId,
			moduleId = def.id,
			sector = def.sector,
			kind = def.kind,
			x = x,
			z = z,
			role = role,
			roomCode = string.format("%s-%02d", def.sector, counters[def.sector]),
			tags = def.tags,
		}
		table.insert(nodes, n)
		grid[LayoutValidator.key(x, z)] = n.id
		return n
	end

	local function connect(a: Node, b: Node, doorType: string, locked: boolean)
		local side = LayoutValidator.sideBetween(a, b)
		if not side then
			return
		end
		table.insert(edges, { a = a.id, b = b.id, side = side, doorType = doorType, locked = locked })
	end

	local byId: { [number]: Node } = {}
	local lastDir: string? = nil

	-- Places `def` adjacent to `from` (or any earlier spine node as backtrack).
	local function placeNext(def, from: Node, spine: { Node }, doorType: string, locked: boolean): Node?
		local candidates = freeNeighbors(grid, from.x, from.z)
		local anchor = from
		if #candidates == 0 then
			for i = #spine, 1, -1 do
				local c = freeNeighbors(grid, spine[i].x, spine[i].z)
				if #c > 0 then
					candidates, anchor = c, spine[i]
					break
				end
			end
		end
		if #candidates == 0 then
			return nil
		end
		-- Bias: keep going in the previous direction 55% of the time for long corridors.
		local choice = nil
		if lastDir then
			for _, c in candidates do
				if c.side == lastDir and rng:chance(0.55) then
					choice = c
					break
				end
			end
		end
		if not choice then
			-- Avoid turning straight back toward the start when possible.
			local filtered = {}
			for _, c in candidates do
				if lastDir == nil or c.side ~= Opposite[lastDir] then
					table.insert(filtered, c)
				end
			end
			choice = rng:pick(if #filtered > 0 then filtered else candidates)
		end
		lastDir = choice.side
		local n = addNode(def, choice.x, choice.z, "spine")
		byId[n.id] = n
		connect(anchor, n, doorType, locked)
		return n
	end

	local spine: { Node } = {}
	local branchAnchor: Node? = nil
	local sectorFirst: { [string]: Node } = {}
	local start: Node? = nil

	for _, entry in plan do
		if entry.branch then
			continue
		end
		for _, def in entry.modules do
			local n: Node?
			if #spine == 0 then
				n = addNode(def, 0, 0, "spine")
				byId[n.id] = n
				start = n
			else
				n = placeNext(def, spine[#spine], spine, "standard", false)
			end
			if not n then
				return nil
			end
			table.insert(spine, n)
			if not sectorFirst[entry.sector] then
				sectorFirst[entry.sector] = n
			end
			if entry.sector == "C" and def.kind == "corridor" then
				branchAnchor = n
			end
		end
	end
	if not start then
		return nil
	end
	-- D branch off a C corridor (or any C node).
	for _, entry in plan do
		if not entry.branch then
			continue
		end
		local anchor = branchAnchor or sectorFirst.C
		if not anchor then
			return nil
		end
		local chain = { anchor }
		local prev = anchor
		for i, def in entry.modules do
			local doorType = if i == 1 then "security" else "standard"
			local locked = if i == 1 then entry.locked else false
			local saved = lastDir
			lastDir = nil
			local n = placeNext(def, prev, chain, doorType, locked)
			lastDir = saved
			if not n then
				return nil
			end
			n.role = if entry.locked then "locked" else "branch"
			table.insert(chain, n)
			prev = n
		end
	end

	-- Extra loops: connect adjacent unconnected nodes with some probability,
	-- never into D (single controlled entry) and never into the evac airlock.
	local function connected(a: number, b: number): boolean
		for _, e in edges do
			if (e.a == a and e.b == b) or (e.a == b and e.b == a) then
				return true
			end
		end
		return false
	end
	for _, n in nodes do
		if n.sector == "D" or n.moduleId == "E_Airlock" then
			continue
		end
		for _, side in { "E", "S" } do
			local d = Dirs[side]
			local other = byId[grid[LayoutValidator.key(n.x + d[1], n.z + d[2])] or -1]
			if other and other.sector ~= "D" and other.moduleId ~= "E_Airlock" and not connected(n.id, other.id) and rng:chance(0.35) then
				connect(n, other, "standard", false)
			end
		end
	end

	local taskNodes: { [string]: number } = {}
	for _, n in nodes do
		for _, tag in n.tags do
			if tag == mission.mainTask.kind or (mission.optionalTask and tag == mission.optionalTask.kind) or tag == "evac" then
				taskNodes[tag] = n.id
			end
		end
	end
	local evac = taskNodes.evac
	if not evac then
		return nil
	end
	return {
		seed = seed,
		missionId = mission.id,
		nodes = nodes,
		edges = edges,
		startNode = start.id,
		evacNode = evac,
		taskNodes = taskNodes,
		lockedSectors = mission.lockedSectors,
		attempts = 0,
		fallback = false,
	}
end

-- Hand-authored safe layout: a straight spine with a D branch.
function LayoutGenerator.fallback(mission: Missions.MissionDef): Layout
	local spec = {
		{ "A_Checkpoint", 0, 0 }, { "A_Corridor", 0, -1 }, { "A_Office", 1, -1 }, { "A_DutyRoom", 0, -2 },
		{ "B_Corridor", 0, -3 }, { "B_Switchgear", -1, -3 }, { "B_ServerRoom", 1, -3 }, { "B_Ventilation", 0, -4 }, { "B_Generator", 1, -4 },
		{ "C_Corridor", 0, -5 }, { "C_Lab", -1, -5 }, { "C_Observation", 1, -5 }, { "C_ControlTerminals", 0, -6 },
		{ "D_Corridor", -1, -6 }, { "D_Airlock", -2, -6 }, { "D_Containment", -2, -7 },
		{ "E_Corridor", 0, -7 }, { "E_Loading", 1, -7 }, { "E_Airlock", 1, -8 },
	}
	local links = {
		{ 1, 2 }, { 2, 3 }, { 2, 4 }, { 4, 5 }, { 5, 6 }, { 5, 7 }, { 5, 8 }, { 8, 9 }, { 7, 9 },
		{ 8, 10 }, { 10, 11 }, { 10, 12 }, { 10, 13 }, { 13, 14, "security" }, { 14, 15 }, { 15, 16 },
		{ 13, 17 }, { 17, 18 }, { 18, 19 },
	}
	local nodes: { Node } = {}
	local counters: { [string]: number } = {}
	for i, s in spec do
		local def = Catalog.ById[s[1]]
		counters[def.sector] = (counters[def.sector] or 0) + 1
		nodes[i] = { id = i, moduleId = def.id, sector = def.sector, kind = def.kind, x = s[2], z = s[3], role = if def.sector == "D" then "locked" else "spine", roomCode = string.format("%s-%02d", def.sector, counters[def.sector]), tags = def.tags }
	end
	local edges: { Edge } = {}
	local dLocked = table.find(mission.lockedSectors, "D") ~= nil
	for _, l in links do
		local a, b = nodes[l[1]], nodes[l[2]]
		local side = LayoutValidator.sideBetween(a, b) :: string
		local doorType = l[3] or "standard"
		table.insert(edges, { a = a.id, b = b.id, side = side, doorType = doorType, locked = doorType == "security" and dLocked })
	end
	local taskNodes: { [string]: number } = {}
	for _, n in nodes do
		for _, tag in n.tags do
			taskNodes[tag] = n.id
		end
	end
	return {
		seed = 0,
		missionId = mission.id,
		nodes = nodes,
		edges = edges,
		startNode = 1,
		evacNode = 19,
		taskNodes = taskNodes,
		lockedSectors = mission.lockedSectors,
		attempts = MAX_ATTEMPTS,
		fallback = true,
	}
end

function LayoutGenerator.requiredKinds(mission: Missions.MissionDef): { string }
	local req = { mission.mainTask.kind }
	if mission.optionalTask then
		table.insert(req, mission.optionalTask.kind)
	end
	return req
end

function LayoutGenerator.generate(seed: number, missionId: string): (Layout, { string })
	local mission = Missions.Defs[missionId]
	assert(mission, "unknown mission " .. tostring(missionId))
	local required = LayoutGenerator.requiredKinds(mission)
	local log = {}
	for i = 1, MAX_ATTEMPTS do
		local s = seed + (i - 1) * 7919
		local layout = attempt(s, mission)
		if layout then
			local ok, errors = LayoutValidator.validate(layout, required)
			if ok then
				layout.attempts = i
				return layout, log
			end
			table.insert(log, string.format("seed %d: %s", s, table.concat(errors, "; ")))
		else
			table.insert(log, string.format("seed %d: placement failed", s))
		end
	end
	local fb = LayoutGenerator.fallback(mission)
	local ok, errors = LayoutValidator.validate(fb, required)
	if not ok then
		error("fallback layout invalid: " .. table.concat(errors, "; "))
	end
	table.insert(log, "fallback layout used")
	return fb, log
end

return LayoutGenerator
