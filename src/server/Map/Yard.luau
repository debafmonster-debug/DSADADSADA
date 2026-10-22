--!nonstrict
-- Outdoor infrastructure: snow field, stairs, generator block, warehouse
-- container, antenna & met station, floodlights, guide ropes, the sealed
-- drilling-complex gate on the horizon and the evacuation apron.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Common = require(script.Parent.Common)
local P = Builder.Palette
local FY = Station.FloorY
local Y = Station.Yard

local Yard = {}

local function ground(ctx, m)
	local size = Y.SnowSize
	local c = Y.SnowCenter
	local snow = Builder.part({ name = "Snow", size = Vector3.new(size, 10, size), cframe = ctx.CF(c[1], -5, c[2]), material = Enum.Material.Snow, color = P.Snow, parent = m })
	snow:SetAttribute("Floor", "snow")
	snow:SetAttribute("Snow", true)
	-- Drifts against buildings and random hummocks; ice patches on the paths.
	local rng = ctx.rng
	local drifts = {
		{ -64, -26, 10, 3, 9 }, { 30, -25, 16, 2.6, 7 }, { 100, 25, 14, 2.4, 8 }, { 152, 0, 8, 3, 12 },
		{ -34, 56, 9, 2.2, 7 }, { 86, 51, 8, 2, 6 }, { -120, -80, 30, 5, 24 }, { 140, -140, 40, 6, 30 },
		{ -150, 120, 34, 5, 28 }, { 220, 60, 36, 6, 30 }, { -40, -120, 26, 4, 20 }, { 60, 150, 30, 5, 26 },
	}
	for _, d in drifts do
		Props.snowDrift(m, ctx.W(d[1], 0, d[2]), Vector3.new(d[3], d[4], d[5]))
	end
	for _ = 1, 14 do
		local x, z = rng:nextNumber(-260, 300), rng:nextNumber(-260, 260)
		if math.abs(x - 40) > 120 or math.abs(z) > 90 then
			Props.snowDrift(m, ctx.W(x, 0, z), Vector3.new(rng:nextNumber(10, 40), rng:nextNumber(2, 6), rng:nextNumber(10, 34)))
		end
	end
	for _, ip in { { -80, 20, 10, 6 }, { 60, 40, 8, 5 }, { 20, -40, 12, 7 }, { 110, 36, 6, 5 } } do
		local ice = Builder.part({ name = "Ice", size = Vector3.new(ip[3], 0.1, ip[4]), cframe = ctx.CF(ip[1], 0.05, ip[2]), material = Enum.Material.Ice, color = P.Ice, parent = m, canCollide = false, reflectance = 0.2 })
		ice:SetAttribute("Floor", "ice")
	end
	-- Wind-driven snow volume anchor for clients.
	Builder.fxAnchor(m, "SnowField", ctx.CF(40, 20, 0), "SnowField", Vector3.new(400, 40, 400))
	local wind = Builder.sound(m, Sounds.Wind, "Wind")
	wind:SetAttribute("AutoPlay", true)
	wind.Parent = snow
end

local function stairsAndRails(ctx, m)
	-- Airlock stairs (west end of K-1): landing + stairs down to the snow.
	Builder.part({ name = "Landing", size = Vector3.new(8, 0.6, 10), cframe = ctx.CF(-66.5, FY - 0.3, 0), material = Enum.Material.DiamondPlate, color = P.Graphite, parent = m })
	Props.stairs(m, ctx.CF(-70.5, 0, -5, 0) * CFrame.Angles(0, math.pi, 0), 6, FY, 10)
	Props.railing(m, ctx.W(-62.5, FY, -5), ctx.W(-70.5, FY, -5))
	Props.railing(m, ctx.W(-62.5, FY, 5), ctx.W(-70.5, FY, 5))
	Props.railing(m, ctx.W(-70.5, FY, -5), ctx.W(-70.5, FY, 5))
	Common.marker(ctx, "SnowPath", Vector3.new(-72, 0, -8))
	-- Dorm exit stairs (south of K-2).
	Builder.part({ name = "Landing", size = Vector3.new(8, 0.6, 6), cframe = ctx.CF(98, FY - 0.3, 25), material = Enum.Material.DiamondPlate, color = P.Graphite, parent = m })
	Props.stairs(m, ctx.CF(98, 0, 38, 0) * CFrame.Angles(0, 0, 0), 6, FY, 10)
	Props.railing(m, ctx.W(94, FY, 22.5), ctx.W(94, FY, 28))
	Props.railing(m, ctx.W(102, FY, 22.5), ctx.W(102, FY, 28))
	-- Service walkway under K-1 along the south side (cable route to the generator).
	Builder.cableTray(m, ctx.W(-20, 2.5, 23), ctx.W(-20, 2.5, 39), 1.2)
	for z = 26, 38, 6 do
		Builder.part({ name = "CablePost", size = Vector3.new(0.4, 2.6, 0.4), cframe = ctx.CF(-20, 1.3, z), material = Enum.Material.Metal, color = P.Graphite, parent = m })
	end
end

local function generatorBlock(ctx, _m, handle)
	local G = Y.GeneratorShed
	local shed = Builder.model(ctx.root, "GeneratorShed")
	local w, d = G.x2 - G.x1, G.z2 - G.z1
	local cx, cz = (G.x1 + G.x2) / 2, (G.z1 + G.z2) / 2
	local slab = Builder.part({ name = "Slab", size = Vector3.new(w + 1, 0.6, d + 1), cframe = ctx.CF(cx, 0.2, cz), material = Enum.Material.Concrete, color = P.ConcreteFloor, parent = shed })
	slab:SetAttribute("Floor", "concrete")
	Builder.part({ name = "Roof", size = Vector3.new(w + 1.4, 0.6, d + 1.4), cframe = ctx.CF(cx, 0.5 + G.height + 0.3, cz), material = Enum.Material.Metal, color = P.RoofGrey, parent = shed })
	Builder.part({ name = "RoofSnow", size = Vector3.new(w + 1.2, 0.6, d + 1.2), cframe = ctx.CF(cx, 0.5 + G.height + 0.9, cz), material = Enum.Material.Snow, color = P.Snow, parent = shed, canCollide = false })
	local hull, hc = Enum.Material.Metal, P.StationOrangeFaded
	Common.wall(ctx, shed, "x", G.z1, G.x1, G.x2, 0.5, G.height, { { at = cx, width = 6, height = 8 } }, hull, hc)
	Common.wall(ctx, shed, "x", G.z2, G.x1, G.x2, 0.5, G.height, { { at = cx + 4, width = 2, height = 2, sill = 5 } }, hull, hc)
	Common.wall(ctx, shed, "z", G.x1, G.z1, G.z2, 0.5, G.height, nil, hull, hc)
	Common.wall(ctx, shed, "z", G.x2, G.z1, G.z2, 0.5, G.height, nil, hull, hc)
	Builder.ventGrille(shed, ctx.CF(cx + 4, 0.5 + 6, G.z2 + 0.05), 2, 2)
	Builder.fxAnchor(shed, "ExhaustSteam", ctx.CF(cx + 4, 8, G.z2 + 1), "Steam", nil, { Rate = 6 })
	local door = Builder.door(ctx.doors, ctx.CF(cx, 0.5, G.z1, 0), 6, 8, { heavy = true, name = "Door_GeneratorShed", label = "ГЕНЕРАТОРНАЯ" })
	door:SetAttribute("Room", "GeneratorShed")
	door:SetAttribute("Exterior", true)
	handle.doors.generatorShed = door
	Builder.cageLamp(shed, ctx.CF(cx, 0.5 + G.height - 0.8, cz), "LightsMain", P.LightWarmOld, 0.9, 18)
	Builder.emergencyLampFor(shed, ctx.CF(G.x1 + 1, 0.5 + G.height - 1, cz), "LightsMain")
	Builder.fluorLamp(shed, ctx.CF(cx, 0.5 + G.height - 0.4, G.z1 - 1.2), 4, "Floodlights", P.LightFlood, 1.0, false)
	-- The generator unit itself.
	local gen = Builder.model(ctx.interactive, "Generator")
	local gp = Station.Points.Generator
	local base = Builder.part({ name = "Base", size = Vector3.new(9, 0.6, 5), cframe = ctx.CF(gp.X, 0.8, gp.Z), material = Enum.Material.Metal, color = P.Graphite, parent = gen })
	Builder.part({ name = "Engine", size = Vector3.new(5, 3.2, 3.2), cframe = ctx.CF(gp.X - 1.5, 2.7, gp.Z), material = Enum.Material.Metal, color = P.OldGreenDark, parent = gen })
	Builder.part({ name = "Alternator", size = Vector3.new(2.6, 2.6, 2.6), cframe = ctx.CF(gp.X + 2.6, 2.4, gp.Z), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.OldGreen, parent = gen })
	Builder.part({ name = "Exhaust", size = Vector3.new(0.6, 5, 0.6), cframe = ctx.CF(gp.X - 3.2, 5.5, gp.Z - 1.2), material = Enum.Material.Metal, color = P.Graphite, parent = gen })
	Builder.pipeRun(gen, { ctx.W(gp.X - 3.2, 8, gp.Z - 1.2), ctx.W(gp.X - 3.2, 8.4, gp.Z + 4), ctx.W(cx + 4, 8.4, G.z2 - 0.4) }, 0.3, P.Graphite)
	for i = 0, 3 do
		Builder.part({ name = "Fin", size = Vector3.new(0.15, 2.4, 2.6), cframe = ctx.CF(gp.X - 3.2 + i * 0.5, 2.7, gp.Z), material = Enum.Material.Metal, color = P.Graphite, parent = gen, canCollide = false })
	end
	-- Protective cover: hinged plate over the engine bay (night rule object).
	local cover = Builder.part({ name = "Cover", size = Vector3.new(5.2, 0.25, 3.4), cframe = ctx.CF(gp.X - 1.5, 4.45, gp.Z), material = Enum.Material.Metal, color = P.StationOrangeDark, parent = gen })
	cover:SetAttribute("ClosedCFrame", cover.CFrame)
	cover:SetAttribute("OpenCFrame", ctx.CF(gp.X - 1.5, 5.6, gp.Z - 1.4) * CFrame.Angles(-1.25, 0, 0))
	Builder.label(cover, Enum.NormalId.Top, "ЗАКРЫТЬ ПЕРЕД НОЧЬЮ", { textSize = 20, bold = true, textColor = P.Paper, pixelsPerStud = 30 })
	-- Control panel on the east end with gauges and a service hatch.
	local panel = Builder.part({ name = "Panel", size = Vector3.new(1.2, 3.4, 3.0), cframe = ctx.CF(gp.X + 6, 2.5, gp.Z), material = Enum.Material.Metal, color = P.OldGreen, parent = gen })
	Builder.label(panel, Enum.NormalId.Right, "ДГ-100\nДИЗЕЛЬ-ГЕНЕРАТОР", { textSize = 14, bold = true, textColor = P.Paper, alignY = Enum.TextYAlignment.Top, padding = 6, pixelsPerStud = 40 })
	for i, g in { "кВт", "об/мин", "V", "°C" } do
		local gf = Props.gauge(gen, ctx.CF(gp.X + 6.62, 3.2 - (i - 1) * 0.0, gp.Z - 1.1 + (i - 1) * 0.75, -math.pi / 2), g, 0.6)
		gf.Name = "Gauge_" .. i
	end
	local serviceDoor = Builder.part({ name = "ServicePanel", size = Vector3.new(0.15, 1.4, 2.4), cframe = ctx.CF(gp.X + 6.62, 1.3, gp.Z), material = Enum.Material.Metal, color = P.OldGreenDark, parent = gen })
	serviceDoor:SetAttribute("ClosedCFrame", serviceDoor.CFrame)
	serviceDoor:SetAttribute("OpenCFrame", ctx.CF(gp.X + 6.7, 1.3, gp.Z + 2.3, 1.3))
	-- Components inside the service bay (revealed when the panel opens).
	for i, comp in GameConfig.Power.Components do
		local c = Builder.part({ name = "Component_" .. comp.id, size = Vector3.new(0.5, 0.5, 0.5), cframe = ctx.CF(gp.X + 6.1, 1.3, gp.Z - 0.8 + (i - 1) * 0.8), material = Enum.Material.Metal, color = P.Bakelite, parent = gen, canCollide = false })
		local led = Builder.part({ name = "Led", size = Vector3.new(0.1, 0.15, 0.15), cframe = ctx.CF(gp.X + 6.4, 1.6, gp.Z - 0.8 + (i - 1) * 0.8), material = Enum.Material.Neon, color = P.Green, parent = c, canCollide = false, castShadow = false })
		led:SetAttribute("ComponentId", comp.id)
	end
	local runLamp = Builder.part({ name = "RunLamp", size = Vector3.new(0.1, 0.3, 0.3), cframe = ctx.CF(gp.X + 6.62, 4.0, gp.Z + 1.2), material = Enum.Material.Neon, color = P.Green, parent = gen, canCollide = false, castShadow = false })
	Builder.pointLight(runLamp, P.Green, 4, 0.4).Name = "Light"
	-- Fuel tank (barrel-shaped) west of the unit.
	local fp = Station.Points.GeneratorFuel
	local tank = Builder.part({ name = "FuelTank", size = Vector3.new(3.6, 2.6, 2.6), cframe = ctx.CF(fp.X, 1.9, fp.Z) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.StationOrangeDark, parent = gen })
	Builder.label(tank, Enum.NormalId.Top, "ДТ · ОГНЕОПАСНО", { textSize = 18, bold = true, textColor = P.Paper })
	Builder.pipeRun(gen, { ctx.W(fp.X + 1.6, 1.9, fp.Z), ctx.W(gp.X - 4, 1.9, gp.Z) }, 0.15, P.Graphite, Enum.Material.Rubber)
	Props.gauge(gen, ctx.CF(fp.X, 3.3, fp.Z + 0.3, 0), "л", 0.7).Name = "FuelGauge"
	Props.jerrycan(shed, ctx.CF(G.x1 + 1.5, 0.5, G.z2 - 1.5))
	Props.jerrycan(shed, ctx.CF(G.x1 + 3.0, 0.5, G.z2 - 1.3, 0.4))
	Props.crate(shed, ctx.CF(G.x2 - 2, 0.5, G.z2 - 2), Vector3.new(2.6, 1.6, 2), P.Wood, "ЗИП ДГ")
	Props.cableDrum(shed, ctx.CF(G.x2 - 2.5, 0.5, G.z1 + 2.6, 0.5))
	Builder.cableTray(shed, ctx.W(gp.X + 6, 0.5 + G.height - 1, gp.Z), ctx.W(gp.X + 6, 0.5 + G.height - 1, G.z1 + 0.5), 1.0)
	Builder.hazardStripes(shed, ctx.CF(gp.X, 0.52, gp.Z + 3.6), 9, 0.6)
	Common.wallSign(ctx, shed, cx - 4, 7.5, G.z1 - 0.6, 0, 5, 1, "ДИЗЕЛЬ-ГЕНЕРАТОРНАЯ · 100 кВт", P.Yellow, P.WarningBlack, 18)
	gen.PrimaryPart = base
	handle.generator = gen
	handle.generatorSoundParent = base
end

local function warehouse(ctx, m, handle)
	local W = Y.Warehouse
	local box = Builder.model(ctx.root, "Warehouse")
	local w, d, h = W.x2 - W.x1, W.z2 - W.z1, W.height
	local cx, cz = (W.x1 + W.x2) / 2, (W.z1 + W.z2) / 2
	Builder.part({ name = "Sleeper", size = Vector3.new(w + 1, 1, 1.2), cframe = ctx.CF(cx, 0.5, W.z1 + 1), material = Enum.Material.Wood, color = P.WoodDark, parent = box })
	Builder.part({ name = "Sleeper", size = Vector3.new(w + 1, 1, 1.2), cframe = ctx.CF(cx, 0.5, W.z2 - 1), material = Enum.Material.Wood, color = P.WoodDark, parent = box })
	local floor = Builder.part({ name = "Floor", size = Vector3.new(w, 0.5, d), cframe = ctx.CF(cx, 1.25, cz), material = Enum.Material.WoodPlanks, color = P.WoodDark, parent = box })
	floor:SetAttribute("Floor", "wood")
	Builder.part({ name = "Roof", size = Vector3.new(w + 0.4, 0.4, d + 0.4), cframe = ctx.CF(cx, 1.5 + h + 0.2, cz), material = Enum.Material.CorrodedMetal, color = P.StationOrangeDark, parent = box })
	Builder.part({ name = "RoofSnow", size = Vector3.new(w, 0.5, d), cframe = ctx.CF(cx, 1.5 + h + 0.65, cz), material = Enum.Material.Snow, color = P.Snow, parent = box, canCollide = false })
	local hull, hc = Enum.Material.CorrodedMetal, P.StationOrange
	Common.wall(ctx, box, "x", W.z1, W.x1, W.x2, 1.5, h, nil, hull, hc, 0.4)
	Common.wall(ctx, box, "x", W.z2, W.x1, W.x2, 1.5, h, nil, hull, hc, 0.4)
	Common.wall(ctx, box, "z", W.x2, W.z1, W.z2, 1.5, h, nil, hull, hc, 0.4)
	Common.wall(ctx, box, "z", W.x1, W.z1, W.z2, 1.5, h, { { at = cz, width = 7, height = 8.5 } }, hull, hc, 0.4)
	-- Corrugation ribs on long sides.
	for x = W.x1 + 1, W.x2 - 1, 2 do
		for _, z in { W.z1 - 0.25, W.z2 + 0.25 } do
			Builder.part({ name = "Corrugation", size = Vector3.new(0.5, h - 0.6, 0.12), cframe = ctx.CF(x, 1.5 + h / 2, z), material = Enum.Material.Metal, color = P.StationOrangeDark, parent = box, canCollide = false, castShadow = false })
		end
	end
	-- Double doors on the west end (two leaves, hinged outward) + keypad box.
	local leafL = Builder.door(ctx.doors, ctx.CF(W.x1, 1.5, cz - 1.75, math.pi / 2), 3.5, 8.5, { heavy = true, name = "Door_WarehouseL", locked = true })
	local leafR = Builder.door(ctx.doors, ctx.CF(W.x1, 1.5, cz + 1.75, -math.pi / 2), 3.5, 8.5, { heavy = true, name = "Door_WarehouseR", locked = true })
	for _, leaf in { leafL, leafR } do
		leaf:SetAttribute("Room", "Warehouse")
		leaf:SetAttribute("Exterior", true)
		leaf:SetAttribute("KeypadLocked", true)
	end
	handle.doors.warehouseL = leafL
	handle.doors.warehouseR = leafR
	local keypad = Builder.model(ctx.interactive, "Keypad")
	local kb = Builder.part({ name = "Body", size = Vector3.new(0.4, 1.4, 1.0), cframe = ctx.CF(W.x1 - 0.4, 5.3, cz + 4.5), material = Enum.Material.Metal, color = P.Graphite, parent = keypad })
	local screen = Builder.part({ name = "Screen", size = Vector3.new(0.06, 0.4, 0.8), cframe = ctx.CF(W.x1 - 0.63, 5.7, cz + 4.5), material = Enum.Material.Neon, color = P.LightCold, parent = keypad, canCollide = false, castShadow = false })
	Builder.label(screen, Enum.NormalId.Left, "- - - -", { textSize = 14, font = Enum.Font.Code, textColor = P.WarningBlack, pixelsPerStud = 60 }).Name = "Text"
	Builder.pointLight(screen, P.LightCold, 4, 0.3).Name = "Light"
	for i = 0, 8 do
		Builder.part({ name = "Key", size = Vector3.new(0.06, 0.18, 0.18), cframe = ctx.CF(W.x1 - 0.63, 5.25 - math.floor(i / 3) * 0.25, cz + 4.25 + (i % 3) * 0.25), material = Enum.Material.SmoothPlastic, color = P.Bakelite, parent = keypad, canCollide = false })
	end
	keypad.PrimaryPart = kb
	handle.keypad = keypad
	Common.wallSign(ctx, box, W.x1 - 0.3, 9.0, cz, math.pi / 2, 6, 1.2, "СКЛАД №2 · КОДОВЫЙ ЗАМОК", P.Graphite, P.Paper, 22)
	Common.wallSign(ctx, box, W.x1 - 0.3, 7.8, cz, math.pi / 2, 6, 0.7, "3 ОШИБКИ — БЛОКИРОВКА НА СУТКИ", P.Red, P.Paper, 14)
	-- Interior: shelves with spares, crates, batteries, a hanging cage lamp.
	Builder.cageLamp(box, ctx.CF(cx - 4, 1.5 + h - 0.8, cz), "Floodlights", P.LightWarmOld, 0.8, 16)
	Builder.cageLamp(box, ctx.CF(cx + 6, 1.5 + h - 0.8, cz), "Floodlights", P.LightWarmOld, 0.8, 16)
	local shelfN = Props.shelf(box, ctx.CF(cx + 2, 1.5, W.z1 + 0.9), 14, 4)
	shelfN.Name = "WarehouseShelfN"
	local shelfS = Props.shelf(box, ctx.CF(cx + 2, 1.5, W.z2 - 0.9, math.pi), 14, 4)
	shelfS.Name = "WarehouseShelfS"
	local spots = {
		{ "SpareRelay", cx - 3, 1.5 + 1.3, W.z1 + 0.9 }, { "SpareInjector", cx + 0, 1.5 + 1.3, W.z1 + 0.9 },
		{ "Fuse", cx + 3, 1.5 + 3.0, W.z1 + 0.9 }, { "Fuse", cx + 5, 1.5 + 3.0, W.z1 + 0.9 },
		{ "Battery", cx - 3, 1.5 + 3.0, W.z2 - 0.9 }, { "Battery", cx + 0, 1.5 + 3.0, W.z2 - 0.9 },
		{ "Medkit", cx + 4, 1.5 + 1.3, W.z2 - 0.9 }, { "FuelCanister", W.x2 - 2, 1.5, cz },
	}
	for _, s in spots do
		Common.marker(ctx, "ItemSpot", Vector3.new(s[2], s[3], s[4]), { ItemId = s[1] })
	end
	Props.crate(box, ctx.CF(W.x2 - 3, 1.5, W.z1 + 2.2), Vector3.new(3, 2.2, 2.4), P.Wood, "ПРОДУКТЫ")
	Props.crate(box, ctx.CF(W.x2 - 3, 1.5 + 2.2, W.z1 + 2.2, 0.1), Vector3.new(2.6, 1.8, 2.0), P.Wood, "ПРОДУКТЫ")
	Props.crate(box, ctx.CF(W.x2 - 6, 1.5, W.z2 - 2.2, 0.2), Vector3.new(2.6, 1.6, 2), P.OldGreenDark, "ЗАПЧАСТИ")
	Props.barrel(box, ctx.CF(W.x1 + 4, 1.5, W.z2 - 1.8), P.StationOrangeDark, "ДТ")
	Builder.part({ name = "Frost", size = Vector3.new(w - 1, 0.04, d - 1), cframe = ctx.CF(cx, 1.52, cz), material = Enum.Material.Ice, color = P.Ice, parent = box, canCollide = false, transparency = 0.7, castShadow = false })
	Builder.floodlight(m, ctx.W(W.x1 - 6, 0, cz - 8), 12, ctx.W(W.x1, 3, cz), "Floodlights")
	-- Story prop: a flashlight nobody issued, on the floor by the door.
	Builder.part({ name = "LostFlashlight", size = Vector3.new(0.4, 0.4, 1.4), cframe = ctx.CF(W.x1 + 2, 1.7, cz - 2.5, 0.7), material = Enum.Material.Metal, color = P.Graphite, parent = box, canCollide = false })
end

local function antennaField(ctx, m, handle)
	local A = Y.Antenna
	local mast = Props.antennaMast(m, ctx.W(A.x, 0, A.z), A.height)
	handle.antenna = mast
	-- Equipment box at the base: the alignment panel (task target).
	local panel = Builder.model(ctx.interactive, "AntennaPanel")
	local pp = Station.Points.AntennaPanel
	local body = Builder.part({ name = "Body", size = Vector3.new(2.2, 3.2, 1.2), cframe = ctx.CF(pp.X, 1.6, pp.Z), material = Enum.Material.Metal, color = P.OldGreen, parent = panel })
	Builder.label(body, Enum.NormalId.Back, "ПРИВОД АНТЕННЫ\nАЗИМУТ", { textSize = 14, bold = true, textColor = P.Paper, alignY = Enum.TextYAlignment.Top, padding = 6, pixelsPerStud = 40 })
	local az = Props.gauge(panel, ctx.CF(pp.X, 1.8, pp.Z + 0.62, 0), "АЗ", 0.2)
	az.Name = "Azimuth"
	Builder.part({ name = "Wheel", size = Vector3.new(1.2, 1.2, 0.2), cframe = ctx.CF(pp.X + 0.7, 0.9, pp.Z + 0.7), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Stainless, parent = panel, canCollide = false }).CFrame = ctx.CF(pp.X + 0.7, 0.9, pp.Z + 0.7) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0)
	Builder.part({ name = "Clamp", size = Vector3.new(0.4, 0.8, 0.3), cframe = ctx.CF(pp.X - 0.7, 0.9, pp.Z + 0.7), material = Enum.Material.Metal, color = P.Red, parent = panel, canCollide = false })
	panel.PrimaryPart = body
	handle.antennaPanel = panel
	Builder.cableTray(m, ctx.W(A.x, 0.4, A.z + 2), ctx.W(-33, 0.4, -24), 0.8)
	Props.metStation(m, ctx.W(Y.MetStation.x, 0, Y.MetStation.z), "Radio")
	Props.crate(m, ctx.CF(A.x + 5, 0, A.z + 4, 0.4), Vector3.new(2.4, 1.6, 2), P.OldGreenDark, "Р-1")
	-- Story: fresh prints walking from the met station straight into the K-1 north wall.
	Props.footprintTrail(m, ctx.W(-8, 0, -58), ctx.W(-20, 0, -23.6), 22, false)
	Common.marker(ctx, "EventSpot", Vector3.new(-20, 0, -24), { Event = "TracksEnd" })
	local creak = Builder.sound(mast, Sounds.MetalCreak, "Creak")
	creak.Looped = false
	creak:SetAttribute("WindCreak", true)
end

local function floodlightsAndRopes(ctx, m)
	for _, fl in Y.Floodlights do
		local aim = Station.StationCenter + Vector3.new(0, 1, 0)
		if fl[1] < -70 then
			aim = Vector3.new(-66, 3, 0)
		elseif fl[1] > 110 then
			aim = Vector3.new(98, 3, 30)
		end
		Builder.floodlight(m, ctx.W(fl[1], 0, fl[2]), 14, ctx.W(aim.X, aim.Y, aim.Z), "Floodlights")
	end
	for _, rope in Y.GuideRopes do
		Props.guideRope(m, ctx.W(rope.from[1], 0, rope.from[2]), ctx.W(rope.to[1], 0, rope.to[2]))
	end
end

local function drillGate(ctx, m)
	local D = Y.DrillGate
	local g = Builder.model(m, "DrillGate")
	for i = -2, 2 do
		Builder.part({ name = "FencePost", size = Vector3.new(0.3, 5, 0.3), cframe = ctx.CF(D.x + i * 6, 2.5, D.z), material = Enum.Material.Metal, color = P.Graphite, parent = g })
	end
	Builder.part({ name = "FenceMesh", size = Vector3.new(24, 4.4, 0.1), cframe = ctx.CF(D.x, 2.6, D.z), material = Enum.Material.Metal, color = P.Graphite, parent = g, transparency = 0.35 })
	Builder.signPlate(g, ctx.CF(D.x, 3.5, D.z - 0.2), 8, 2, "БУРОВОЙ КОМПЛЕКС · ДОСТУП ЗАКРЫТ · ГЛАВА IV", P.Red, P.Paper, 22)
	-- Derrick silhouette far behind the fence (truss tower, no interior).
	local top = Vector3.new(D.x, 0, D.z - 60)
	for i = 0, 3 do
		local ang = i * math.pi / 2
		local off = Vector3.new(math.cos(ang) * 4, 0, math.sin(ang) * 4)
		Builder.part({ name = "DerrickLeg", size = Vector3.new(0.6, 44, 0.6), cframe = ctx.CF(top.X + off.X, 22, top.Z + off.Z), material = Enum.Material.Metal, color = P.Graphite, parent = g })
	end
	for y = 8, 40, 8 do
		Builder.part({ name = "DerrickRing", size = Vector3.new(9, 0.4, 9), cframe = ctx.CF(top.X, y, top.Z), material = Enum.Material.Metal, color = P.Graphite, parent = g, canCollide = false })
	end
	local beacon = Builder.part({ name = "DerrickBeacon", size = Vector3.new(0.6, 0.6, 0.6), cframe = ctx.CF(top.X, 45, top.Z), material = Enum.Material.Neon, color = P.Red, parent = g, canCollide = false, castShadow = false })
	Builder.pointLight(beacon, P.Red, 24, 1.5).Name = "Light"
	beacon:SetAttribute("Blink", 2.0)
	Builder.part({ name = "DrillShed", size = Vector3.new(16, 8, 12), cframe = ctx.CF(top.X + 14, 4, top.Z + 6), material = Enum.Material.Metal, color = P.StationOrangeDark, parent = g })
end

local function evacApron(ctx, m, handle)
	local E = Y.EvacApron
	local apron = Builder.model(m, "EvacApron")
	for i = 0, 11 do
		local ang = i * math.pi * 2 / 12
		local pos = ctx.W(E.x + math.cos(ang) * E.radius, 0.4, E.z + math.sin(ang) * E.radius)
		local lamp = Builder.part({ name = "ApronLight", size = Vector3.new(0.6, 0.6, 0.6), cframe = CFrame.new(pos), material = Enum.Material.Neon, color = if i % 3 == 0 then P.Red else P.Orange, parent = apron, canCollide = false, castShadow = false })
		Builder.pointLight(lamp, lamp.Color, 10, 0.8).Name = "Light"
		lamp:SetAttribute("Blink", 1.5 + (i % 3) * 0.3)
	end
	Builder.signPlate(apron, ctx.CF(E.x, 2.5, E.z - E.radius - 3), 6, 1.4, "ПЛОЩАДКА · ВЕТРОУКАЗАТЕЛЬ", P.Graphite, P.Paper, 18)
	Builder.part({ name = "WindsockPole", size = Vector3.new(0.3, 9, 0.3), cframe = ctx.CF(E.x + E.radius + 4, 4.5, E.z), material = Enum.Material.Metal, color = P.Galvanized, parent = apron })
	local sock = Builder.part({ name = "Windsock", size = Vector3.new(3, 0.9, 0.9), cframe = ctx.CF(E.x + E.radius + 5.8, 9, E.z), material = Enum.Material.Fabric, color = P.Orange, parent = apron, canCollide = false })
	sock:SetAttribute("Windsock", true)
	Common.marker(ctx, "EvacZone", Station.Points.EvacZone)
	handle.evacApron = apron
end

function Yard.build(ctx, handle)
	local m = Builder.model(ctx.root, "Yard")
	ground(ctx, m)
	stairsAndRails(ctx, m)
	generatorBlock(ctx, m, handle)
	warehouse(ctx, m, handle)
	antennaField(ctx, m, handle)
	floodlightsAndRopes(ctx, m)
	drillGate(ctx, m)
	evacApron(ctx, m, handle)
	-- Markers consumed by services.
	for i, p in Station.Points.ArrivalSpawn do
		Common.marker(ctx, "Spawn", p, { Index = i })
	end
	for _, p in Station.Patrol.Outdoor do
		Common.marker(ctx, "Patrol", p, { Zone = "Outdoor" })
	end
	for _, p in Station.Patrol.Indoor do
		Common.marker(ctx, "Patrol", p, { Zone = "Indoor" })
	end
	for _, p in Station.Patrol.Observe do
		Common.marker(ctx, "Observe", p)
	end
	for _, p in Station.Points.GuestSpawns do
		Common.marker(ctx, "GuestSpawn", p)
	end
	for _, p in Station.Points.LostPoints do
		Common.marker(ctx, "LostPoint", p)
	end
end

return Yard
