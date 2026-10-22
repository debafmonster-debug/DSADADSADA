--!nonstrict
-- Shared room construction helpers for all sector modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Props = require(script.Parent.Props)
local P = Builder.Palette

export type Ctx = {
	model: Model,
	cframe: CFrame, -- floor-level center of the cell, +X east, -Z north
	size: number,
	height: number,
	doors: { [string]: boolean }, -- N E S W
	rng: SeededRandom.SeededRandom,
	sector: string,
	roomCode: string,
	markers: Folder,
	damage: number, -- 0..1 wear level for variation
}

local Common = {}

Common.DoorOpening = { width = 8, height = 9 }
Common.CorridorWidth = 10

Common.SectorStyle = {
	A = { light = P.LightWarm:Lerp(P.LightCold, 0.5), wall = Color3.fromRGB(150, 148, 140), floor = Color3.fromRGB(110, 108, 104), accent = P.Blue, floorMat = Enum.Material.Concrete, name = "АДМИНИСТРАТИВНЫЙ" },
	B = { light = P.LightCold, wall = P.Concrete, floor = P.ConcreteFloor, accent = P.Yellow, floorMat = Enum.Material.Concrete, name = "ТЕХНИЧЕСКИЙ" },
	C = { light = P.LightLab, wall = Color3.fromRGB(196, 200, 202), floor = Color3.fromRGB(150, 154, 156), accent = P.Green, floorMat = Enum.Material.SmoothPlastic, name = "ИССЛЕДОВАТЕЛЬСКИЙ" },
	D = { light = Color3.fromRGB(190, 170, 170), wall = Color3.fromRGB(80, 78, 80), floor = Color3.fromRGB(60, 58, 60), accent = P.Red, floorMat = Enum.Material.Concrete, name = "ИЗОЛЯЦИОННЫЙ" },
	E = { light = P.LightCold, wall = P.ConcreteDark, floor = P.RubberFloor, accent = P.Orange, floorMat = Enum.Material.DiamondPlate, name = "ЭВАКУАЦИОННЫЙ" },
}

function Common.style(sector: string)
	return Common.SectorStyle[sector] or Common.SectorStyle.B
end

function Common.doorOpenings(ctx: Ctx): { [string]: Builder.Opening? }
	local d = {}
	for side, open in ctx.doors do
		if open then
			d[side] = Common.DoorOpening
		end
	end
	return d
end

-- Standard room shell with sector styling; returns the shell folder.
function Common.roomShell(ctx: Ctx, opts: { floorColor: Color3?, wallColor: Color3?, floorMat: Enum.Material? }?): Folder
	local st = Common.style(ctx.sector)
	local o = opts or {}
	return Builder.shell(ctx.model, ctx.cframe, ctx.size, ctx.size, ctx.height, {
		doors = Common.doorOpenings(ctx),
		floorColor = o.floorColor or st.floor,
		floorMaterial = o.floorMat or st.floorMat,
		wallColor = o.wallColor or st.wall,
		thickness = GameConfig.Grid.WallThickness,
	})
end

-- Grid of ceiling lamps. `cols x rows`, with the sector light color.
function Common.lights(ctx: Ctx, cols: number, rows: number, brightness: number?, color: Color3?): { Part }
	local st = Common.style(ctx.sector)
	local lamps = {}
	local f = Builder.folder(ctx.model, "Lights")
	local sx = ctx.size / cols
	local sz = ctx.size / rows
	for i = 1, cols do
		for j = 1, rows do
			local x = -ctx.size / 2 + sx * (i - 0.5)
			local z = -ctx.size / 2 + sz * (j - 0.5)
			local lamp = Builder.ceilingLamp(f, ctx.cframe * CFrame.new(x, ctx.height - 0.3, z), Vector3.new(4, 0.2, 1.2), color or st.light, 22, brightness or 0.9)
			table.insert(lamps, lamp)
		end
	end
	return lamps
end

function Common.emergencyLights(ctx: Ctx)
	local f = Builder.folder(ctx.model, "EmergencyLights")
	for _, side in { "N", "S" } do
		local z = if side == "N" then -ctx.size / 2 + 1.3 else ctx.size / 2 - 1.3
		Builder.emergencyLamp(f, ctx.cframe * CFrame.new(0, ctx.height - 1.2, z))
	end
end

-- Ceiling clutter: beams, cable trays, ducts. Random count for variation.
function Common.ceilingDetail(ctx: Ctx, density: number)
	local f = Builder.folder(ctx.model, "CeilingDetail")
	local h = ctx.height
	local s = ctx.size / 2 - 1
	local n = ctx.rng:nextInteger(1, 2 + math.floor(density * 2))
	for i = 1, n do
		local z = -s + (2 * s) * (i / (n + 1))
		Builder.beam(f, ctx.cframe:PointToWorldSpace(Vector3.new(-s, h - 0.8, z)), ctx.cframe:PointToWorldSpace(Vector3.new(s, h - 0.8, z)), 1.2, 1.4)
	end
	if ctx.rng:chance(0.8) then
		local x = ctx.rng:nextNumber(-s + 4, s - 4)
		Builder.cableTray(f, ctx.cframe:PointToWorldSpace(Vector3.new(x, h - 1.9, -s)), ctx.cframe:PointToWorldSpace(Vector3.new(x, h - 1.9, s)), 1.6)
	end
	if ctx.rng:chance(0.6) then
		local z = ctx.rng:nextNumber(-s + 4, s - 4)
		Builder.ventDuct(f, ctx.cframe:PointToWorldSpace(Vector3.new(-s, h - 2.2, z)), ctx.cframe:PointToWorldSpace(Vector3.new(s, h - 2.2, z)), 2.2)
	end
	-- Corner columns
	for _, cx in { -s + 0.9, s - 0.9 } do
		for _, cz in { -s + 0.9, s - 0.9 } do
			Builder.column(f, ctx.cframe:PointToWorldSpace(Vector3.new(cx, 0, cz)), 1.8, h, Common.style(ctx.sector).wall:Lerp(Color3.new(0, 0, 0), 0.25))
		end
	end
end

-- Room code sign beside every open door (inside the room).
function Common.doorSigns(ctx: Ctx, text: string)
	local st = Common.style(ctx.sector)
	local f = Builder.folder(ctx.model, "Signs")
	local half = ctx.size / 2
	local offs = Common.DoorOpening.width / 2 + 2.2
	local placements = {
		N = CFrame.new(offs, 7.2, -half + 0.6),
		S = CFrame.new(-offs, 7.2, half - 0.6) * CFrame.Angles(0, math.pi, 0),
		E = CFrame.new(half - 0.6, 7.2, offs) * CFrame.Angles(0, -math.pi / 2, 0),
		W = CFrame.new(-half + 0.6, 7.2, -offs) * CFrame.Angles(0, math.pi / 2, 0),
	}
	for side, open in ctx.doors do
		if open and placements[side] then
			Props.roomNumber(f, ctx.cframe * placements[side], text)
			local stripe = Builder.part({
				name = "SectorStripe",
				size = Vector3.new(Common.DoorOpening.width + 6, 0.35, 0.15),
				cframe = ctx.cframe * placements[side] * CFrame.new(-offs, 2.4, 0),
				material = Enum.Material.SmoothPlastic,
				color = st.accent,
				parent = f,
				canCollide = false,
			})
			stripe.CastShadow = false
		end
	end
end

-- Wear: scuffs and stains on the floor; cheap decals made of flat parts.
function Common.wear(ctx: Ctx)
	if ctx.damage <= 0.05 then
		return
	end
	local f = Builder.folder(ctx.model, "Wear")
	local n = math.floor(ctx.damage * 6)
	local s = ctx.size / 2 - 3
	for _ = 1, n do
		local x, z = ctx.rng:nextNumber(-s, s), ctx.rng:nextNumber(-s, s)
		Builder.part({
			name = "Stain",
			size = Vector3.new(ctx.rng:nextNumber(2, 5), 0.04, ctx.rng:nextNumber(2, 5)),
			cframe = ctx.cframe * CFrame.new(x, 0.02, z) * CFrame.Angles(0, ctx.rng:nextNumber(0, math.pi), 0),
			material = Enum.Material.Slate,
			color = Color3.fromRGB(40, 38, 36),
			transparency = 0.6,
			canCollide = false,
			castShadow = false,
			parent = f,
		})
	end
end

function Common.marker(ctx: Ctx, name: string, cf: CFrame, attrs: { [string]: any }?): Part
	local m = Builder.invisible(ctx.markers, name, cf, Vector3.new(2, 2, 2))
	if attrs then
		for k, v in attrs do
			m:SetAttribute(k, v)
		end
	end
	return m
end

-- Plus-shaped corridor: central hub, arms only toward open doors, solid fill elsewhere.
function Common.corridor(ctx: Ctx, title: string)
	local st = Common.style(ctx.sector)
	local size, h = ctx.size, ctx.height
	local half = size / 2
	local cw = Common.CorridorWidth
	local arm = half - cw / 2 -- length of a filler block along a side
	local f = Builder.folder(ctx.model, "Shell")
	Builder.part({ name = "Floor", size = Vector3.new(size, 1, size), cframe = ctx.cframe * CFrame.new(0, -0.5, 0), material = st.floorMat, color = st.floor, parent = f })
	Builder.part({ name = "Ceiling", size = Vector3.new(size, 1, size), cframe = ctx.cframe * CFrame.new(0, h + 0.5, 0), material = Enum.Material.Concrete, color = P.ConcreteDark, parent = f })
	local wallColor = st.wall
	-- Corner fillers
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.part({
				name = "Fill",
				size = Vector3.new(arm, h, arm),
				cframe = ctx.cframe * CFrame.new(sx * (half - arm / 2), h / 2, sz * (half - arm / 2)),
				material = Enum.Material.Concrete,
				color = wallColor,
				parent = f,
			})
		end
	end
	-- Closed arms become wall slabs; open arms get a door lintel at the edge.
	-- Each arm frame is rotated so local -Z points out of the cell.
	local sides = {
		N = CFrame.new(0, 0, -(half - arm / 2)),
		S = CFrame.new(0, 0, half - arm / 2) * CFrame.Angles(0, math.pi, 0),
		E = CFrame.new(half - arm / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		W = CFrame.new(-(half - arm / 2), 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	}
	for side, local_cf in sides do
		if ctx.doors[side] then
			-- Door lintel at outer edge
			local edge = CFrame.new(0, 0, -arm / 2 + 0.5)
			Builder.part({
				name = "Lintel",
				size = Vector3.new(cw, h - Common.DoorOpening.height, 1),
				cframe = ctx.cframe * local_cf * edge * CFrame.new(0, Common.DoorOpening.height + (h - Common.DoorOpening.height) / 2, 0),
				material = Enum.Material.Concrete,
				color = wallColor,
				parent = f,
			})
			for _, sx in { -1, 1 } do
				Builder.part({
					name = "Jamb",
					size = Vector3.new((cw - Common.DoorOpening.width) / 2, Common.DoorOpening.height, 1),
					cframe = ctx.cframe * local_cf * edge * CFrame.new(sx * (cw / 2 - (cw - Common.DoorOpening.width) / 4), Common.DoorOpening.height / 2, 0),
					material = Enum.Material.Concrete,
					color = wallColor,
					parent = f,
				})
			end
			-- Arm lights
			local lf = ctx.model:FindFirstChild("Lights") or Builder.folder(ctx.model, "Lights")
			Builder.ceilingLamp(lf, ctx.cframe * local_cf * CFrame.new(0, h - 0.3, 0), Vector3.new(1, 0.2, 5), st.light, 18, 0.7)
			-- Wall markings along the arm
			local sf = ctx.model:FindFirstChild("Signs") or Builder.folder(ctx.model, "Signs")
			Builder.part({
				name = "Stripe",
				size = Vector3.new(0.1, 0.4, arm - 1),
				cframe = ctx.cframe * local_cf * CFrame.new(cw / 2 - 0.05, 3.2, 0),
				material = Enum.Material.SmoothPlastic,
				color = st.accent,
				parent = sf,
				canCollide = false,
			})
			Builder.part({
				name = "Stripe",
				size = Vector3.new(0.1, 0.4, arm - 1),
				cframe = ctx.cframe * local_cf * CFrame.new(-cw / 2 + 0.05, 3.2, 0),
				material = Enum.Material.SmoothPlastic,
				color = st.accent,
				parent = sf,
				canCollide = false,
			})
			-- Cable tray along one wall
			Builder.cableTray(f, (ctx.cframe * local_cf * CFrame.new(cw / 2 - 1, h - 1.5, -arm / 2)).Position, (ctx.cframe * local_cf * CFrame.new(cw / 2 - 1, h - 1.5, arm / 2)).Position, 1.2)
		else
			Builder.part({
				name = "Fill",
				size = Vector3.new(cw, h, arm),
				cframe = ctx.cframe * local_cf * CFrame.new(0, h / 2, 0),
				material = Enum.Material.Concrete,
				color = wallColor,
				parent = f,
			})
		end
	end
	-- Hub light + sign
	local lf = ctx.model:FindFirstChild("Lights") or Builder.folder(ctx.model, "Lights")
	Builder.ceilingLamp(lf, ctx.cframe * CFrame.new(0, h - 0.3, 0), Vector3.new(4, 0.2, 4), st.light, 20, 0.8)
	Common.emergencyHub(ctx)
	local sf = ctx.model:FindFirstChild("Signs") or Builder.folder(ctx.model, "Signs")
	-- Direction sign on an interior corner facing the hub
	Builder.signPlate(sf, ctx.cframe * CFrame.new(cw / 2 - 0.2, 8, -(cw / 2) + 0.1) * CFrame.Angles(0, -math.pi / 2, 0), 5, 1.4, title, st.accent, P.WarningBlack, 30)
	Common.marker(ctx, "Patrol", ctx.cframe * CFrame.new(0, 3, 0))
	Common.pipesAlongArm(ctx)
end

function Common.emergencyHub(ctx: Ctx)
	local f = ctx.model:FindFirstChild("EmergencyLights") or Builder.folder(ctx.model, "EmergencyLights")
	Builder.emergencyLamp(f, ctx.cframe * CFrame.new(Common.CorridorWidth / 2 - 0.4, ctx.height - 1.5, Common.CorridorWidth / 2 - 0.4))
end

function Common.pipesAlongArm(ctx: Ctx)
	local half = ctx.size / 2
	local cw = Common.CorridorWidth
	local pts = {}
	for _, side in { "N", "S" } do
		if ctx.doors[side] then
			local sz = if side == "N" then -1 else 1
			table.insert(pts, ctx.cframe:PointToWorldSpace(Vector3.new(-cw / 2 + 0.6, ctx.height - 2.8, sz * half)))
		end
	end
	if #pts == 2 then
		Builder.pipeRun(ctx.model, pts, 0.35, P.Galvanized)
		Builder.pipeRun(ctx.model, { pts[1] + Vector3.new(0, -0.9, 0), pts[2] + Vector3.new(0, -0.9, 0) }, 0.25, P.Red:Lerp(P.Galvanized, 0.6))
	end
end

-- Spread N patrol markers around a room so the Warden wanders inside rooms, not only corridors.
function Common.roomPatrol(ctx: Ctx, n: number)
	local s = ctx.size / 2 - 6
	Common.marker(ctx, "Patrol", ctx.cframe * CFrame.new(0, 3, 0))
	for _ = 1, n do
		Common.marker(ctx, "Patrol", ctx.cframe * CFrame.new(ctx.rng:nextNumber(-s, s), 3, ctx.rng:nextNumber(-s, s)))
	end
end

-- `cf` is the surface the paper lies on (desk top, floor); marker sits 1 stud above it.
function Common.docSpot(ctx: Ctx, cf: CFrame)
	Common.marker(ctx, "DocumentSpot", cf * CFrame.new(0, 1, 0), { Sector = ctx.sector })
end

-- Door-safe placement of props: keeps the 10-stud corridor lanes in front of
-- open doors free so navigation and NPC paths never get blocked.
function Common.laneBlocked(ctx: Ctx, x: number, z: number): boolean
	local lane = Common.CorridorWidth / 2 + 1
	if ctx.doors.N and math.abs(x) < lane and z < 0 then
		return true
	end
	if ctx.doors.S and math.abs(x) < lane and z > 0 then
		return true
	end
	if ctx.doors.E and math.abs(z) < lane and x > 0 then
		return true
	end
	if ctx.doors.W and math.abs(z) < lane and x < 0 then
		return true
	end
	return false
end

-- Picks a position along the walls that does not block any door lane.
function Common.wallSpot(ctx: Ctx, inset: number): (CFrame, string)
	local half = ctx.size / 2 - inset
	for _ = 1, 12 do
		local side = ctx.rng:pick({ "N", "S", "E", "W" })
		local t = ctx.rng:nextNumber(-half + 5, half - 5)
		local x, z, rot
		-- Props face -Z locally; rotate so they face into the room.
		if side == "N" then
			x, z, rot = t, -half, math.pi
		elseif side == "S" then
			x, z, rot = t, half, 0
		elseif side == "E" then
			x, z, rot = half, t, math.pi / 2
		else
			x, z, rot = -half, t, -math.pi / 2
		end
		if not Common.laneBlocked(ctx, x, z) then
			return ctx.cframe * CFrame.new(x, 0, z) * CFrame.Angles(0, rot, 0), side
		end
	end
	return ctx.cframe * CFrame.new(half - 4, 0, half - 4), "S"
end

return Common
