--!nonstrict
-- Shared helpers for the authored station map: coordinate conversion, wall
-- bookkeeping (so adjacent rooms never double up a partition), building
-- shells with openings, per-room lighting. Everything is deterministic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local P = Builder.Palette

local Common = {}

export type Ctx = {
	root: Model,
	origin: Vector3,
	markers: Folder,
	doors: Folder,
	interactive: Folder,
	W: (number, number, number) -> Vector3, -- local xyz -> world position
	CF: (number, number, number, number?) -> CFrame, -- local xyz (+yaw) -> world CFrame
	coverage: { [string]: { { number } } },
	rng: any,
}

function Common.newCtx(root: Model, origin: Vector3, rng: any): Ctx
	local ctx: Ctx = {
		root = root,
		origin = origin,
		markers = Builder.folder(root, "Markers"),
		doors = Builder.folder(root, "Doors"),
		interactive = Builder.folder(root, "Interactive"),
		W = function(x, y, z)
			return origin + Vector3.new(x, y, z)
		end,
		CF = function(x, y, z, yaw)
			return CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw or 0, 0)
		end,
		coverage = {},
		rng = rng,
	}
	return ctx
end

function Common.marker(ctx: Ctx, name: string, localPos: Vector3, attrs: { [string]: any }?): Part
	local p = Builder.invisible(ctx.markers, name, CFrame.new(ctx.origin + localPos), Vector3.new(1, 1, 1))
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	return p
end

-- ===== Walls with coverage clipping ======================================

local function subtract(intervals: { { number } }, a: number, b: number): { { number } }
	local out = { { a, b } }
	for _, iv in intervals do
		local next = {}
		for _, seg in out do
			local s, e = seg[1], seg[2]
			if iv[2] <= s or iv[1] >= e then
				table.insert(next, seg)
			else
				if iv[1] > s then
					table.insert(next, { s, iv[1] })
				end
				if iv[2] < e then
					table.insert(next, { iv[2], e })
				end
			end
		end
		out = next
	end
	return out
end

-- Builds a wall along x (axis="x": varies x at fixed z) or z (axis="z": varies
-- z at fixed x) between `a` and `b`, clipped by what already exists on that
-- line. `openings` are {center, width, height, sill?} along the axis.
export type Opening = { at: number, width: number, height: number, sill: number? }

function Common.wall(ctx: Ctx, parent: Instance, axis: string, fixed: number, a: number, b: number, y0: number, height: number, openings: { Opening }?, material: Enum.Material?, color: Color3?, thickness: number?): { Part }
	if a > b then
		a, b = b, a
	end
	local key = axis .. ":" .. tostring(fixed) .. ":" .. tostring(y0)
	ctx.coverage[key] = ctx.coverage[key] or {}
	local free = subtract(ctx.coverage[key], a, b)
	table.insert(ctx.coverage[key], { a, b })
	local parts = {}
	local t = thickness or Station.WallThickness
	local mat = material or Enum.Material.SmoothPlastic
	local col = color or P.DirtyWhite
	local function seg(s: number, e: number, yBase: number, h: number, name: string)
		if e - s < 0.05 or h < 0.05 then
			return
		end
		local mid = (s + e) / 2
		local cf, size
		if axis == "x" then
			cf = CFrame.new(ctx.origin + Vector3.new(mid, yBase + h / 2, fixed))
			size = Vector3.new(e - s, h, t)
		else
			cf = CFrame.new(ctx.origin + Vector3.new(fixed, yBase + h / 2, mid))
			size = Vector3.new(t, h, e - s)
		end
		local p = Builder.part({ name = name, size = size, cframe = cf, material = mat, color = col, parent = parent })
		p:SetAttribute("Wall", true)
		table.insert(parts, p)
	end
	for _, iv in free do
		local s, e = iv[1], iv[2]
		-- carve openings that intersect this free interval
		local cursor = s
		local ops = {}
		for _, o in openings or {} do
			local os_, oe = o.at - o.width / 2, o.at + o.width / 2
			if oe > s and os_ < e then
				table.insert(ops, { math.max(s, os_), math.min(e, oe), o })
			end
		end
		table.sort(ops, function(x, y)
			return x[1] < y[1]
		end)
		for _, op in ops do
			seg(cursor, op[1], y0, height, "Wall")
			local o = op[3]
			local sill = o.sill or 0
			if sill > 0 then
				seg(op[1], op[2], y0, sill, "WallSill")
			end
			seg(op[1], op[2], y0 + sill + o.height, height - sill - o.height, "WallLintel")
			cursor = op[2]
		end
		seg(cursor, e, y0, height, "Wall")
	end
	return parts
end

-- ===== Building shell ====================================================

export type ShellOpenings = { N: { Opening }?, S: { Opening }?, E: { Opening }?, W: { Opening }? }

-- Orange insulated hull: slab, roof, outer walls with horizontal ribs, piles.
function Common.shell(ctx: Ctx, parent: Instance, b: { x1: number, z1: number, x2: number, z2: number, height: number }, openings: ShellOpenings, opts: { piles: boolean?, roofSnow: boolean?, ribs: boolean?, floorColor: Color3?, interiorColor: Color3? }?)
	local o = opts or {}
	local y0 = Station.FloorY
	local w, d = b.x2 - b.x1, b.z2 - b.z1
	local cx, cz = (b.x1 + b.x2) / 2, (b.z1 + b.z2) / 2
	local slab = Builder.part({ name = "Floor", size = Vector3.new(w + 1, 1, d + 1), cframe = CFrame.new(ctx.origin + Vector3.new(cx, y0 - 0.5, cz)), material = Enum.Material.Metal, color = P.RubberFloor, parent = parent })
	slab:SetAttribute("Floor", "metal")
	Builder.part({ name = "SlabEdge", size = Vector3.new(w + 1.6, 1.4, d + 1.6), cframe = CFrame.new(ctx.origin + Vector3.new(cx, y0 - 1.2, cz)), material = Enum.Material.Metal, color = P.Graphite, parent = parent })
	Builder.part({ name = "Roof", size = Vector3.new(w + 1.6, 1, d + 1.6), cframe = CFrame.new(ctx.origin + Vector3.new(cx, y0 + b.height + 0.5, cz)), material = Enum.Material.Metal, color = P.RoofGrey, parent = parent })
	if o.roofSnow ~= false then
		Builder.part({ name = "RoofSnow", size = Vector3.new(w + 1.2, 0.7, d + 1.2), cframe = CFrame.new(ctx.origin + Vector3.new(cx, y0 + b.height + 1.35, cz)), material = Enum.Material.Snow, color = P.Snow, parent = parent, canCollide = false })
	end
	-- Outer walls: hull colour outside; the inner face gets a dirty-white liner.
	local hull = Enum.Material.Metal
	local hc = P.StationOrange
	Common.wall(ctx, parent, "x", b.z1, b.x1, b.x2, y0, b.height, openings.N, hull, hc)
	Common.wall(ctx, parent, "x", b.z2, b.x1, b.x2, y0, b.height, openings.S, hull, hc)
	Common.wall(ctx, parent, "z", b.x1, b.z1, b.z2, y0, b.height, openings.W, hull, hc)
	Common.wall(ctx, parent, "z", b.x2, b.z1, b.z2, y0, b.height, openings.E, hull, hc)
	if o.ribs ~= false then
		for _, yy in { 2.5, 5.5, 8.5 } do
			if yy < b.height then
				for _, side in { { "x", b.z1 - 0.55 }, { "x", b.z2 + 0.55 } } do
					Builder.part({ name = "Rib", size = Vector3.new(w + 1.2, 0.35, 0.12), cframe = CFrame.new(ctx.origin + Vector3.new(cx, y0 + yy, side[2])), material = Enum.Material.Metal, color = P.StationOrangeDark, parent = parent, canCollide = false, castShadow = false })
				end
				for _, side in { b.x1 - 0.55, b.x2 + 0.55 } do
					Builder.part({ name = "Rib", size = Vector3.new(0.12, 0.35, d + 1.2), cframe = CFrame.new(ctx.origin + Vector3.new(side, y0 + yy, cz)), material = Enum.Material.Metal, color = P.StationOrangeDark, parent = parent, canCollide = false, castShadow = false })
				end
			end
		end
	end
	if o.piles ~= false then
		local nx, nz = math.max(2, math.floor(w / 12)), math.max(2, math.floor(d / 12))
		for i = 0, nx do
			for j = 0, nz do
				if i == 0 or i == nx or j == 0 or j == nz or (i + j) % 2 == 0 then
					local px = b.x1 + 1 + (w - 2) * i / nx
					local pz = b.z1 + 1 + (d - 2) * j / nz
					Builder.part({ name = "Pile", size = Vector3.new(1.2, y0 - 1.5, 1.2), cframe = CFrame.new(ctx.origin + Vector3.new(px, (y0 - 1.5) / 2, pz)), material = Enum.Material.Metal, color = P.Graphite, parent = parent })
				end
			end
		end
	end
end

-- Interior partition walls for every room in a building, clipped against the
-- shell and each other. Doors are cut where the room definition says.
function Common.partitions(ctx: Ctx, parent: Instance, building: string, rooms: { any }, bounds: { x1: number, z1: number, x2: number, z2: number }, extraDoors: { [string]: { { side: string, at: number?, width: number? } } }?)
	local y0 = Station.FloorY
	local h = Station.WallHeight
	-- Pass 1: every door becomes an opening on its wall line, so a partition
	-- shared by two rooms gets the opening no matter which room builds it.
	local lineOpenings: { [string]: { Opening } } = {}
	local function register(r, d)
		local axis, fixed, at
		if d.side == "N" then
			axis, fixed, at = "x", r.z1, d.at or (r.x1 + r.x2) / 2
		elseif d.side == "S" then
			axis, fixed, at = "x", r.z2, d.at or (r.x1 + r.x2) / 2
		elseif d.side == "W" then
			axis, fixed, at = "z", r.x1, d.at or (r.z1 + r.z2) / 2
		else
			axis, fixed, at = "z", r.x2, d.at or (r.z1 + r.z2) / 2
		end
		local key = axis .. ":" .. tostring(fixed)
		lineOpenings[key] = lineOpenings[key] or {}
		table.insert(lineOpenings[key], { at = at, width = d.width or Station.DoorWidth, height = Station.DoorHeight })
	end
	for _, r in rooms do
		if r.building ~= building then
			continue
		end
		if r.door then
			register(r, r.door)
		end
		if extraDoors and extraDoors[r.id] then
			for _, d in extraDoors[r.id] do
				register(r, d)
			end
		end
	end
	-- Pass 2: build each interior side once (coverage clipping handles overlaps).
	for _, r in rooms do
		if r.building ~= building or r.id == "Corridor" or r.id == "Passage" then
			continue
		end
		if r.z1 > bounds.z1 then
			Common.wall(ctx, parent, "x", r.z1, r.x1, r.x2, y0, h, lineOpenings["x:" .. tostring(r.z1)])
		end
		if r.z2 < bounds.z2 then
			Common.wall(ctx, parent, "x", r.z2, r.x1, r.x2, y0, h, lineOpenings["x:" .. tostring(r.z2)])
		end
		if r.x1 > bounds.x1 then
			Common.wall(ctx, parent, "z", r.x1, r.z1, r.z2, y0, h, lineOpenings["z:" .. tostring(r.x1)])
		end
		if r.x2 < bounds.x2 then
			Common.wall(ctx, parent, "z", r.x2, r.z1, r.z2, y0, h, lineOpenings["z:" .. tostring(r.x2)])
		end
	end
end

-- Hinged door at a room opening. `side` is the wall the opening is in; the
-- leaf's hinge sits on the "left" looking from outside the room.
function Common.roomDoor(ctx: Ctx, r: any, side: string, at: number?, opts: Builder.DoorOpts?): Model
	local x, z, yaw
	if side == "N" then
		x, z, yaw = at or (r.x1 + r.x2) / 2, r.z1, 0
	elseif side == "S" then
		x, z, yaw = at or (r.x1 + r.x2) / 2, r.z2, math.pi
	elseif side == "W" then
		x, z, yaw = r.x1, at or (r.z1 + r.z2) / 2, math.pi / 2
	else
		x, z, yaw = r.x2, at or (r.z1 + r.z2) / 2, -math.pi / 2
	end
	local o = opts or {}
	o.name = o.name or ("Door_" .. r.id .. "_" .. side)
	local m = Builder.door(ctx.doors, ctx.CF(x, Station.FloorY, z, yaw), Station.DoorWidth, Station.DoorHeight, o)
	m:SetAttribute("Room", r.id)
	return m
end

-- Ceiling fixtures along the room's long axis + inner wall liner color.
function Common.roomLights(ctx: Ctx, parent: Instance, r: any, kind: string?)
	local n = r.lamps or 1
	local color = P[r.lightColor or "LightFluor"] or P.LightFluor
	local circuit = r.circuit or "LightsMain"
	local w, d = r.x2 - r.x1, r.z2 - r.z1
	local along = if w >= d then "x" else "z"
	local y = Station.FloorY + Station.WallHeight - 0.35
	for i = 1, n do
		local t = (i - 0.5) / n
		local x = if along == "x" then r.x1 + w * t else (r.x1 + r.x2) / 2
		local z = if along == "z" then r.z1 + d * t else (r.z1 + r.z2) / 2
		local cf = ctx.CF(x, y, z, if along == "z" then math.pi / 2 else 0)
		if kind == "cage" or r.lightColor == "LightWarmOld" and (r.id == "Storage" or r.id == "Boiler" or r.id == "DormBoiler" or r.id == "Drying") then
			Builder.cageLamp(parent, cf * CFrame.new(0, -0.5, 0), circuit, color, 0.8, 16)
		elseif r.lightColor == "LightWarmOld" then
			-- Old incandescent ceiling fixture: flat round shade, warm & dim.
			local shade = Builder.part({ name = "Shade", size = Vector3.new(2.2, 0.35, 2.2), cframe = cf, material = Enum.Material.Metal, color = P.DirtyWhiteDark, parent = parent, canCollide = false })
			local lamp = Builder.part({ name = "Lamp", size = Vector3.new(1.6, 0.2, 1.6), cframe = cf * CFrame.new(0, -0.25, 0), material = Enum.Material.Neon, color = color, parent = shade, canCollide = false, castShadow = false })
			Builder.pointLight(lamp, color, 20, 0.85, false).Name = "Light"
			Builder.registerLamp(lamp, circuit, color, 0.85)
		else
			Builder.fluorLamp(parent, cf, math.min(6, math.max(3, (if along == "x" then w else d) / n * 0.5)), circuit, color, if r.lightColor == "LightLab" then 1.0 else 1.1, i == 1 and n <= 3)
		end
	end
end

-- Thin metal skirting + cable conduit along a room's walls (cheap grounding).
function Common.roomTrim(ctx: Ctx, parent: Instance, r: any)
	local y0 = Station.FloorY
	local w, d = r.x2 - r.x1, r.z2 - r.z1
	local cx, cz = (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2
	for _, z in { r.z1 + 0.6, r.z2 - 0.6 } do
		Builder.part({ name = "Skirting", size = Vector3.new(w - 1, 0.5, 0.2), cframe = ctx.CF(cx, y0 + 0.25, z), material = Enum.Material.Metal, color = P.Graphite, parent = parent, canCollide = false, castShadow = false })
	end
	for _, x in { r.x1 + 0.6, r.x2 - 0.6 } do
		Builder.part({ name = "Skirting", size = Vector3.new(0.2, 0.5, d - 1), cframe = ctx.CF(x, y0 + 0.25, cz), material = Enum.Material.Metal, color = P.Graphite, parent = parent, canCollide = false, castShadow = false })
	end
end

-- Floor surface override for a room (concrete in utility rooms, planks in cabins).
function Common.roomFloor(ctx: Ctx, parent: Instance, r: any, material: Enum.Material, color: Color3, kind: string)
	local w, d = r.x2 - r.x1, r.z2 - r.z1
	local f = Builder.part({ name = "RoomFloor", size = Vector3.new(w - 0.2, 0.12, d - 0.2), cframe = ctx.CF((r.x1 + r.x2) / 2, Station.FloorY + 0.06, (r.z1 + r.z2) / 2), material = material, color = color, parent = parent, canCollide = false })
	f:SetAttribute("Floor", kind)
	return f
end

function Common.wallSign(ctx: Ctx, parent: Instance, x: number, y: number, z: number, yaw: number, w: number, h: number, text: string, bg: Color3?, fg: Color3?, size: number?)
	return Builder.signPlate(parent, ctx.CF(x, y, z, yaw), w, h, text, bg or P.Graphite, fg or P.Paper, size or 28)
end

function Common.extinguisher(ctx: Ctx, parent: Instance, x: number, z: number, yaw: number?)
	local m = Builder.model(parent, "Extinguisher")
	local cf = ctx.CF(x, Station.FloorY, z, yaw)
	Builder.part({ name = "Body", size = Vector3.new(0.8, 2.2, 0.8), cframe = cf * CFrame.new(0, 1.5, 0), material = Enum.Material.Metal, color = P.Red, parent = m, canCollide = false })
	Builder.part({ name = "Bracket", size = Vector3.new(1, 0.3, 0.4), cframe = cf * CFrame.new(0, 2.4, -0.4), material = Enum.Material.Metal, color = P.Graphite, parent = m, canCollide = false })
	return m
end

return Common
