--!nonstrict
-- Pure layout validation. No Instances involved so it runs in Lune tests.
local LayoutValidator = {}

export type Node = { id: number, moduleId: string, sector: string, kind: string, x: number, z: number, role: string, roomCode: string, tags: { string } }
export type Edge = { a: number, b: number, side: string, doorType: string, locked: boolean }
export type Layout = {
	seed: number,
	missionId: string,
	nodes: { Node },
	edges: { Edge },
	startNode: number,
	evacNode: number,
	taskNodes: { [string]: number },
	lockedSectors: { string },
	attempts: number,
	fallback: boolean,
}

local Dirs = { N = { 0, -1 }, S = { 0, 1 }, E = { 1, 0 }, W = { -1, 0 } }
LayoutValidator.Dirs = Dirs

function LayoutValidator.key(x: number, z: number): string
	return x .. "," .. z
end

function LayoutValidator.sideBetween(a: Node, b: Node): string?
	local dx, dz = b.x - a.x, b.z - a.z
	for side, d in Dirs do
		if d[1] == dx and d[2] == dz then
			return side
		end
	end
	return nil
end

local function adjacency(layout: Layout, includeLocked: boolean): { [number]: { number } }
	local adj: { [number]: { number } } = {}
	for _, n in layout.nodes do
		adj[n.id] = {}
	end
	for _, e in layout.edges do
		if includeLocked or not e.locked then
			table.insert(adj[e.a], e.b)
			table.insert(adj[e.b], e.a)
		end
	end
	return adj
end

function LayoutValidator.reachable(layout: Layout, from: number, includeLocked: boolean): { [number]: boolean }
	local adj = adjacency(layout, includeLocked)
	local seen = { [from] = true }
	local queue = { from }
	while #queue > 0 do
		local cur = table.remove(queue, 1) :: number
		for _, nxt in adj[cur] or {} do
			if not seen[nxt] then
				seen[nxt] = true
				table.insert(queue, nxt)
			end
		end
	end
	return seen
end

-- Shortest path length in rooms (used for pacing and tests).
function LayoutValidator.distance(layout: Layout, from: number, to: number, includeLocked: boolean): number?
	local adj = adjacency(layout, includeLocked)
	local dist = { [from] = 0 }
	local queue = { from }
	while #queue > 0 do
		local cur = table.remove(queue, 1) :: number
		if cur == to then
			return dist[cur]
		end
		for _, nxt in adj[cur] or {} do
			if dist[nxt] == nil then
				dist[nxt] = dist[cur] + 1
				table.insert(queue, nxt)
			end
		end
	end
	return nil
end

function LayoutValidator.validate(layout: Layout, requiredTaskKinds: { string }): (boolean, { string })
	local errors: { string } = {}
	local byId: { [number]: Node } = {}
	local cells: { [string]: number } = {}

	if #layout.nodes < 10 then
		table.insert(errors, "too few nodes: " .. #layout.nodes)
	end
	for _, n in layout.nodes do
		if byId[n.id] then
			table.insert(errors, "duplicate node id " .. n.id)
		end
		byId[n.id] = n
		local k = LayoutValidator.key(n.x, n.z)
		if cells[k] then
			table.insert(errors, string.format("cell overlap at %s (%d vs %d)", k, cells[k], n.id))
		end
		cells[k] = n.id
	end

	local edgeKeys: { [string]: boolean } = {}
	local degree: { [number]: number } = {}
	for _, e in layout.edges do
		local a, b = byId[e.a], byId[e.b]
		if not a or not b then
			table.insert(errors, string.format("edge references missing node %d-%d", e.a, e.b))
			continue
		end
		local side = LayoutValidator.sideBetween(a, b)
		if not side then
			table.insert(errors, string.format("edge %d-%d is not between adjacent cells", e.a, e.b))
		elseif side ~= e.side then
			table.insert(errors, string.format("edge %d-%d side mismatch (%s vs %s)", e.a, e.b, side, e.side))
		end
		local ek = math.min(e.a, e.b) .. "-" .. math.max(e.a, e.b)
		if edgeKeys[ek] then
			table.insert(errors, "duplicate edge " .. ek)
		end
		edgeKeys[ek] = true
		degree[e.a] = (degree[e.a] or 0) + 1
		degree[e.b] = (degree[e.b] or 0) + 1
	end
	for id, d in degree do
		if d > 4 then
			table.insert(errors, "node " .. id .. " has more than 4 doors")
		end
	end
	for _, n in layout.nodes do
		if (degree[n.id] or 0) == 0 then
			table.insert(errors, "node " .. n.id .. " (" .. n.moduleId .. ") has no doors")
		end
	end

	if not byId[layout.startNode] then
		table.insert(errors, "start node missing")
	end
	if not byId[layout.evacNode] then
		table.insert(errors, "evac node missing")
	end

	if #errors == 0 then
		local open = LayoutValidator.reachable(layout, layout.startNode, false)
		local all = LayoutValidator.reachable(layout, layout.startNode, true)
		if not open[layout.evacNode] then
			table.insert(errors, "evacuation not reachable without locked doors")
		end
		for _, kind in requiredTaskKinds do
			local id = layout.taskNodes[kind]
			if not id then
				table.insert(errors, "task node missing for " .. kind)
			elseif not open[id] then
				table.insert(errors, "task " .. kind .. " not reachable without locked doors")
			end
		end
		for _, n in layout.nodes do
			if not all[n.id] then
				table.insert(errors, "node " .. n.id .. " unreachable even through locked doors (NPC route broken)")
			end
			local lockedSector = table.find(layout.lockedSectors, n.sector) ~= nil
			if lockedSector and open[n.id] then
				table.insert(errors, "locked sector " .. n.sector .. " node " .. n.id .. " reachable without unlocking")
			end
		end
	end
	return #errors == 0, errors
end

return LayoutValidator
