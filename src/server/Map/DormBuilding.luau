--!nonstrict
-- Корпус №2 (спальный) + переход + скрытый бункер под спальным сектором.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Common = require(script.Parent.Common)
local P = Builder.Palette
local R = Station.RoomById
local FY = Station.FloorY
local H = Station.WallHeight

local DormBuilding = {}

local function roomModel(ctx, r)
	local m = Builder.model(ctx.root, "Room_" .. r.id)
	m:SetAttribute("RoomId", r.id)
	m:SetAttribute("RoomName", r.name)
	return m
end

local function passage(ctx, handle)
	local r = R.Passage
	local b = Station.Buildings.Passage
	local m = roomModel(ctx, r)
	local shell = Builder.model(ctx.root, "Shell_Passage")
	-- Walls with window strips on both sides; floor and roof are lighter.
	local wins = {}
	for x = 66, 88, 6 do
		table.insert(wins, { at = x, width = 4, height = 3.2, sill = 3.6 })
	end
	Common.shell(ctx, shell, b, { N = wins, S = wins, W = { { at = 0, width = Station.DoorWidth, height = Station.DoorHeight } }, E = { { at = 0, width = Station.DoorWidth, height = Station.DoorHeight } } }, { piles = true, ribs = true })
	for x = 66, 88, 6 do
		Builder.window(shell, ctx.CF(x, FY + 3.6 + 1.6, b.z1), 4, 3.2)
		Builder.window(shell, ctx.CF(x, FY + 3.6 + 1.6, b.z2), 4, 3.2)
	end
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	Builder.pipeRun(m, { ctx.W(62.5, FY + H - 1.8, 4.3), ctx.W(91.5, FY + H - 1.8, 4.3) }, 0.4, P.Galvanized)
	Builder.cableTray(m, ctx.W(62.5, FY + H - 1.3, -4.2), ctx.W(91.5, FY + H - 1.3, -4.2), 1.2)
	Builder.emergencyLampFor(m, ctx.CF(77, FY + H - 0.9, -4.4), "LightsDorm")
	Common.wallSign(ctx, m, 77, FY + 9.4, -4.4, 0, 6, 0.8, "ПЕРЕХОД К-1 ↔ К-2 · ДЕРЖИТЕ ДВЕРИ ЗАКРЫТЫМИ", P.Paper, P.WarningBlack, 14)
	-- Bench and a lost glove: people waited here for the storm to pass.
	Props.bench(m, ctx.CF(80, FY, 3.8), 5)
	Builder.part({ name = "Glove", size = Vector3.new(0.5, 0.2, 0.9), cframe = ctx.CF(83, FY + 1.75, 3.8, 0.4), material = Enum.Material.Fabric, color = P.StationOrangeFaded, parent = m, canCollide = false })
	-- Door into the dorm vestibule (east end).
	local d = Builder.door(ctx.doors, ctx.CF(92, FY, 0, -math.pi / 2), Station.DoorWidth, Station.DoorHeight, { heavy = true, name = "Door_PassageDorm", label = "К-2" })
	d:SetAttribute("Room", "Passage")
	handle.doors.passageDorm = d
	Builder.fxAnchor(m, "PassageSnow", ctx.CF(77, FY + 8, 0), "SnowIn", Vector3.new(28, 4, 6), { Rate = 0.4 })
end

local function vestibule(ctx, handle)
	local r = R.DormVestibule
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.DiamondPlate, P.Graphite, "grate")
	Common.roomLights(ctx, m, r)
	Props.coatRack(m, ctx.CF(98, FY, -5.3), 3)
	Props.boots(m, ctx.CF(94, FY, -4.5))
	Props.bench(m, ctx.CF(98, FY, 5.2), 5)
	Builder.emergencyLampFor(m, ctx.CF(98, FY + H - 1, 5.4), "LightsDorm")
	local d = Common.roomDoor(ctx, r, "E", 0, { window = true, name = "Door_Dorm" })
	handle.doors.dorm = d
	handle.roomDoors.Dorm = d
	Common.wallSign(ctx, m, 103.4, FY + 9.2, -3, -math.pi / 2, 4, 0.8, "СПАЛЬНЫЙ СЕКТОР", P.DirtyWhiteDark, P.WarningBlack, 16)
	Common.wallSign(ctx, m, 103.4, FY + 8.3, -3, -math.pi / 2, 4, 0.7, "ПОСЛЕ 22:00 НЕ ВЫХОДИТЬ", P.Red, P.Paper, 14)
end

local function dormStore(ctx, handle)
	local r = R.DormStore
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Concrete, P.ConcreteFloor, "concrete")
	Common.roomLights(ctx, m, r, "cage")
	Props.shelf(m, ctx.CF(93, FY, -14, math.pi / 2), 8, 4)
	for i = 0, 3 do
		Builder.part({ name = "Linen", size = Vector3.new(1.3, 0.5, 1.8), cframe = ctx.CF(93, FY + 1.3 + i * 1.7, -16 + (i % 2) * 3), material = Enum.Material.Fabric, color = P.DirtyWhite, parent = m, canCollide = false })
	end
	Props.crate(m, ctx.CF(101, FY, -18), Vector3.new(3, 2.2, 2.4), P.Wood, "ОДЕЯЛА")
	Props.crate(m, ctx.CF(101, FY, -10, 0.3), Vector3.new(2.4, 1.6, 2), P.Wood)
	Common.marker(ctx, "ItemSpot", Vector3.new(93, FY + 4.7, -11), { ItemId = "Battery" })
	handle.roomDoors.DormStore = Common.roomDoor(ctx, r, "S", nil, { name = "Door_DormStore" })
end

local function drying(ctx, handle)
	local r = R.Drying
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.DiamondPlate, P.Graphite, "grate")
	Common.roomLights(ctx, m, r, "cage")
	Builder.heater(m, ctx.CF(94, FY, 14, math.pi / 2), "Heating", GameConfig.Temperature.HeaterRange)
	Props.coatRack(m, ctx.CF(98, FY, 21.2), 4)
	Props.coatRack(m, ctx.CF(102.3, FY, 14, -math.pi / 2), 3)
	Props.boots(m, ctx.CF(96, FY, 19.5))
	Props.boots(m, ctx.CF(100, FY, 19.8, 0.5))
	Props.bench(m, ctx.CF(98, FY, 9), 5)
	Builder.pipeRun(m, { ctx.W(92.6, FY + 1, 8), ctx.W(92.6, FY + 9.5, 8), ctx.W(103.5, FY + 9.5, 8) }, 0.25, P.Galvanized)
	handle.roomDoors.Drying = Common.roomDoor(ctx, r, "N", nil, { name = "Door_Drying" })
	-- Exterior exit (south wall) — heavy door, stairs outside.
	local exitDoor = Builder.door(ctx.doors, ctx.CF(98, FY, 22, math.pi), Station.DoorWidth, Station.DoorHeight, { heavy = true, name = "Door_DormExit", label = "ВЫХОД · К-2" })
	exitDoor:SetAttribute("Room", "Drying")
	exitDoor:SetAttribute("Exterior", true)
	handle.doors.dormExit = exitDoor
	Builder.fxAnchor(m, "ExitSnow", ctx.CF(98, FY + 4, 20), "SnowIn", Vector3.new(6, 6, 2))
	local puddle = Builder.part({ name = "Puddle", size = Vector3.new(2.6, 0.04, 2.0), cframe = ctx.CF(98, FY + 0.14, 18), material = Enum.Material.Glass, color = Color3.fromRGB(60, 66, 74), parent = m, canCollide = false, reflectance = 0.3 })
	puddle.CastShadow = false
end

local function dorm(ctx, handle)
	local r = R.Dorm
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.WoodPlanks, P.WoodDark, "wood")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	-- Beds along the north wall + one along the east wall.
	local bedX = { 109, 117, 125, 133, 141 }
	for i, x in bedX do
		local bed = Props.bed(m, ctx.CF(x, FY, -18.2), if i % 2 == 0 then P.Blanket else P.FabricWarm, "Bed" .. i)
		bed:SetAttribute("BedIndex", i)
		Props.boots(m, ctx.CF(x - 1.1, FY, -14.2, 0.2 * i))
		Props.locker(m, ctx.CF(x + 2.5, FY, -20.6), P.OldGreen, if i == 1 then "КАЛИНИН" elseif i == 2 then "ЖАРОВА" elseif i == 3 then "МИЩЕНКО" elseif i == 4 then "ТОЙВО" else "—")
	end
	local bed6 = Props.bed(m, ctx.CF(147.8, FY, -6, -math.pi / 2), P.Blanket, "Bed6")
	bed6:SetAttribute("BedIndex", 6)
	-- Table with chairs, mugs, the small radio, books.
	Props.table(m, ctx.CF(127, FY, -8), 8, 3.4)
	for i = 0, 2 do
		Props.chair(m, ctx.CF(124 + i * 3, FY, -5.2, math.pi), if i == 1 then P.FabricWarm else P.Fabric)
		Props.chair(m, ctx.CF(124 + i * 3, FY, -10.8), P.Fabric)
	end
	Props.mug(m, ctx.CF(125, FY + 2.75, -8.6), false)
	Props.mug(m, ctx.CF(129.5, FY + 2.75, -7.2), false, Color3.fromRGB(180, 70, 60))
	Props.book(m, ctx.CF(127.5, FY + 2.75, -8.9), P.Red)
	local radio = Props.radioSmall(m, ctx.CF(123.6, FY + 2.75, -7.0, 0.3), "DormRadio")
	handle.dormRadio = radio
	Common.marker(ctx, "EventSpot", Vector3.new(130.8, FY + 2.75, -8.4), { Spot = "DormTable", Event = "ExtraRadio" })
	Props.papers(m, ctx.CF(128, FY + 2.75, -6.8), 2)
	-- Duty board (headcount prompt lives here) and the clock on the south wall.
	local board = Props.noticeBoard(ctx.interactive, ctx.CF(127, FY + 6.2, 7.4, math.pi), 6, 3.6, { "ЖУРНАЛ СМЕНЫ · К-2", "Состав: —", "В секторе: —", "Пересчёт: —" })
	board.Name = "DormBoard"
	handle.dormBoard = board
	Props.wallClock(m, ctx.CF(146, FY + 8.6, 7.4, math.pi), "DormClock")
	Builder.heater(m, ctx.CF(127, FY, -21.2), "Heating", GameConfig.Temperature.HeaterRange)
	-- Hatch to the bunker: steel plate with a ring, under a rug.
	local hatch = Builder.model(ctx.interactive, "Hatch")
	local S = Station.Bunker.Shaft
	local plate = Builder.part({ name = "Plate", size = Vector3.new(S.size - 0.4, 0.25, S.size - 0.4), cframe = ctx.CF(S.x, FY + 0.18, S.z), material = Enum.Material.DiamondPlate, color = P.Graphite, parent = hatch })
	Builder.part({ name = "Ring", size = Vector3.new(0.8, 0.1, 0.8), cframe = ctx.CF(S.x + 1, FY + 0.35, S.z), material = Enum.Material.Metal, color = P.Stainless, parent = hatch, canCollide = false })
	local rug = Builder.part({ name = "Rug", size = Vector3.new(S.size + 1.5, 0.06, S.size + 1.5), cframe = ctx.CF(S.x + 0.6, FY + 0.34, S.z + 0.4, 0.08), material = Enum.Material.Fabric, color = Color3.fromRGB(104, 70, 60), parent = hatch, canCollide = false })
	rug.CastShadow = false
	hatch.PrimaryPart = plate
	hatch:SetAttribute("Open", false)
	handle.hatch = hatch
	-- Floor marks in the two diagonal corners (worn diamond plates).
	local a, b = Station.Points.DormCornerA, Station.Points.DormCornerB
	for i, c in { a, b } do
		local mark = Builder.part({ name = "CornerMark" .. i, size = Vector3.new(2.2, 0.08, 2.2), cframe = ctx.CF(c.X, FY + 0.16, c.Z, math.pi / 4), material = Enum.Material.DiamondPlate, color = P.GraphiteLight, parent = m, canCollide = false })
		mark.CastShadow = false
		Common.marker(ctx, "Corner", Vector3.new(c.X, FY, c.Z), { Index = i })
	end
	-- Personal items, photos, blankets, a pinned note.
	Props.photoFrame(m, ctx.CF(105.3, FY + 7, -12, math.pi / 2), "Нас четверо")
	Props.photoFrame(m, ctx.CF(105.3, FY + 7, -9, math.pi / 2), nil)
	Props.noticeBoard(m, ctx.CF(105.3, FY + 6.4, -3, math.pi / 2), 3.4, 2.6, { "ПРАВИЛА К-2", "22:00 — отбой", "считать людей", "люк — только вдвоём" })
	Builder.part({ name = "Blankets", size = Vector3.new(2.2, 1.2, 1.6), cframe = ctx.CF(146, FY + 0.6, 4), material = Enum.Material.Fabric, color = P.Blanket, parent = m, canCollide = false })
	for _, x in { 112, 140 } do
		Builder.emergencyLampFor(m, ctx.CF(x, FY + H - 0.9, 7.4), "LightsDorm")
	end
	Common.wallSign(ctx, m, 110, FY + 9.4, 7.4, math.pi, 8, 0.8, "ПЕРЕД СНОМ: ГЕНЕРАТОР · КРЫШКА · ДВЕРИ · ЛЮДИ", P.Paper, P.WarningBlack, 16)
	local tick = Builder.sound(m, Sounds.ClockTick, "ClockTick")
	tick:SetAttribute("AutoPlay", true)
	tick.Looped = true
	tick.Parent = (m:FindFirstChild("DormClock") :: Model).PrimaryPart
	Common.marker(ctx, "EventSpot", Vector3.new(127, FY + H + 1, -6), { Event = "FootstepsRoof" })
end

local function dormWash(ctx, handle)
	local r = R.DormWash
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.SmoothPlastic, P.PanelWhite, "concrete")
	Common.roomLights(ctx, m, r)
	for i = 0, 2 do
		Builder.part({ name = "Sink", size = Vector3.new(1.6, 0.8, 1.2), cframe = ctx.CF(110 + i * 2.6, FY + 2.6, 20.8), material = Enum.Material.Metal, color = P.Stainless, parent = m })
		Builder.part({ name = "SinkStand", size = Vector3.new(1.4, 2.2, 1.0), cframe = ctx.CF(110 + i * 2.6, FY + 1.1, 20.8), material = Enum.Material.Metal, color = P.DirtyWhiteDark, parent = m })
	end
	local mirror = Builder.part({ name = "Mirror", size = Vector3.new(7.6, 2.4, 0.08), cframe = ctx.CF(112.6, FY + 5.6, 21.4), material = Enum.Material.Glass, color = Color3.fromRGB(190, 200, 210), parent = m, reflectance = 0.7, canCollide = false })
	mirror:SetAttribute("Mirror", true)
	handle.roomDoors.DormWash = Common.roomDoor(ctx, r, "N", nil, { name = "Door_DormWash" })
	Common.marker(ctx, "EventSpot", Vector3.new(112.6, FY + 5.6, 21.4), { Event = "Reflection" })
end

local function dormBoiler(ctx, handle)
	local r = R.DormBoiler
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Concrete, P.ConcreteFloor, "concrete")
	Common.roomLights(ctx, m, r, "cage")
	Builder.part({ name = "Tank", size = Vector3.new(3.4, 5.5, 3.4), cframe = ctx.CF(144, FY + 2.75, 17), material = Enum.Material.Metal, color = P.OldGreenDark, parent = m })
	Builder.pipeRun(m, { ctx.W(144, FY + 6, 17), ctx.W(144, FY + 9.5, 17), ctx.W(128, FY + 9.5, 17), ctx.W(128, FY + 9.5, 8.6) }, 0.35, P.Galvanized)
	Builder.heater(m, ctx.CF(138, FY, 21.2), "Heating", GameConfig.Temperature.HeaterRange)
	Props.gauge(m, ctx.CF(142.2, FY + 5, 17.0, 0), "бар", 0.55)
	Props.jerrycan(m, ctx.CF(131, FY, 19.5))
	Props.jerrycan(m, ctx.CF(132.5, FY, 19.9, 0.3))
	handle.roomDoors.DormBoiler = Common.roomDoor(ctx, r, "N", nil, { name = "Door_DormBoiler" })
	local hum = Builder.sound(m, Sounds.HeaterHum, "Hum")
	hum:SetAttribute("AutoPlay", true)
end

-- ===== Bunker ===========================================================

local function bunker(ctx, handle)
	local B = Station.Bunker
	local m = Builder.model(ctx.root, "Bunker")
	m:SetAttribute("RoomId", "Bunker")
	local fy = B.FloorY
	local h = B.Height
	local S = B.Shaft
	-- Shaft: concrete tube from the dorm floor down to the bunker floor.
	local shaftTop = FY
	local shaftH = shaftTop - fy
	for _, side in { { S.x - S.size / 2, 0 }, { S.x + S.size / 2, 0 } } do
		Builder.part({ name = "ShaftWall", size = Vector3.new(0.6, shaftH, S.size + 0.6), cframe = ctx.CF(side[1], fy + shaftH / 2, S.z), material = Enum.Material.Concrete, color = P.ConcreteDark, parent = m })
	end
	Builder.part({ name = "ShaftWall", size = Vector3.new(S.size + 0.6, shaftH, 0.6), cframe = ctx.CF(S.x, fy + shaftH / 2, S.z - S.size / 2), material = Enum.Material.Concrete, color = P.ConcreteDark, parent = m })
	-- South side is open at the bottom into the antechamber (opening 7 high).
	Builder.part({ name = "ShaftWall", size = Vector3.new(S.size + 0.6, shaftH - 7, 0.6), cframe = ctx.CF(S.x, fy + 7 + (shaftH - 7) / 2, S.z + S.size / 2), material = Enum.Material.Concrete, color = P.ConcreteDark, parent = m })
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, shaftH, 2)
	ladder.CFrame = ctx.CF(S.x - S.size / 2 + 1.2, fy + shaftH / 2, S.z - S.size / 2 + 1.0)
	ladder.Anchored = true
	ladder.Material = Enum.Material.Metal
	ladder.Color = P.Galvanized
	ladder.Parent = m
	-- Antechamber + room: concrete box, floor, ceiling.
	local function concreteRoom(rect, name)
		local w, d = rect.x2 - rect.x1, rect.z2 - rect.z1
		local cx, cz = (rect.x1 + rect.x2) / 2, (rect.z1 + rect.z2) / 2
		local floor = Builder.part({ name = name .. "Floor", size = Vector3.new(w + 1, 1, d + 1), cframe = ctx.CF(cx, fy - 0.5, cz), material = Enum.Material.Concrete, color = P.ConcreteFloor, parent = m })
		floor:SetAttribute("Floor", "concrete")
		Builder.part({ name = name .. "Ceiling", size = Vector3.new(w + 1, 1, d + 1), cframe = ctx.CF(cx, fy + h + 0.5, cz), material = Enum.Material.Concrete, color = P.ConcreteDark, parent = m })
	end
	concreteRoom(B.Antechamber, "Ante")
	concreteRoom(B.Room, "Room")
	local A, Rm = B.Antechamber, B.Room
	-- Antechamber walls (north has the shaft opening, west has the heavy door).
	Common.wall(ctx, m, "x", A.z1, A.x1, A.x2, fy, h, { { at = S.x, width = S.size, height = 7 } }, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "x", A.z2, A.x1, A.x2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "z", A.x2, A.z1, A.z2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "z", A.x1, A.z1, A.z2, fy, h, { { at = B.DoorAt.z, width = 5, height = 7.5 } }, Enum.Material.Concrete, P.ConcreteDark)
	-- Room walls.
	Common.wall(ctx, m, "x", Rm.z1, Rm.x1, Rm.x2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "x", Rm.z2, Rm.x1, Rm.x2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "z", Rm.x1, Rm.z1, Rm.z2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "z", Rm.x2, Rm.z1, A.z1, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	Common.wall(ctx, m, "z", Rm.x2, A.z2, Rm.z2, fy, h, nil, Enum.Material.Concrete, P.ConcreteDark)
	-- Heavy bunker door (hinged, opens into the room), lever inside.
	local door = Builder.door(ctx.doors, ctx.CF(B.DoorAt.x, fy, B.DoorAt.z, math.pi / 2), 5, 7.5, { heavy = true, name = "Door_Bunker", label = "УБЕЖИЩЕ" })
	door:SetAttribute("Room", "Bunker")
	door:SetAttribute("LeverOnly", true)
	handle.doors.bunker = door
	local lever = Builder.model(ctx.interactive, "BunkerLever")
	Builder.part({ name = "Box", size = Vector3.new(0.5, 2.2, 1.2), cframe = ctx.CF(B.LeverAt.x + 1.6, fy + 4.3, B.LeverAt.z), material = Enum.Material.Metal, color = P.Graphite, parent = lever })
	local arm = Builder.part({ name = "Arm", size = Vector3.new(0.4, 1.4, 0.4), cframe = ctx.CF(B.LeverAt.x + 1.3, fy + 4.5, B.LeverAt.z) * CFrame.Angles(0.5, 0, 0), material = Enum.Material.Metal, color = P.Red, parent = lever })
	lever.PrimaryPart = arm
	Common.wallSign(ctx, lever, B.LeverAt.x + 1.33, fy + 5.9, B.LeverAt.z, -math.pi / 2, 1.4, 0.5, "ДВЕРЬ", P.Yellow, P.WarningBlack, 10)
	handle.bunkerLever = lever
	-- Contents: cots, emergency crate, old radio, shelves, scratches on the door.
	Props.bed(m, ctx.CF(106, fy, -5), P.Blanket, "Cot1")
	Props.bed(m, ctx.CF(106, fy, 4), P.Blanket, "Cot2")
	Props.crate(m, ctx.CF(118, fy, -6, 0.2), Vector3.new(3, 2.2, 2.4), P.OldGreenDark, "НЗ · ВОДА")
	Props.crate(m, ctx.CF(118, fy, 5), Vector3.new(2.4, 1.6, 2), P.OldGreenDark, "АКБ")
	Props.shelf(m, ctx.CF(112, fy, 7.2, math.pi), 6, 3)
	Props.radioSmall(m, ctx.CF(112, fy + 3.0, 7.2), "BunkerRadio")
	Props.table(m, ctx.CF(113, fy, 0), 4, 2.4, P.WoodDark)
	Props.papers(m, ctx.CF(113, fy + 2.75, 0), 3)
	Common.marker(ctx, "DocumentSpot", Vector3.new(113.8, fy + 2.75, 0.4), { Spot = "BunkerDesk" })
	Props.scratches(m, ctx.CF(123.3, fy + 4, 2, 0) * CFrame.Angles(math.pi / 2, 0, 0), 3)
	Builder.cageLamp(m, ctx.CF(113, fy + h - 0.8, 0), "LightsDorm", P.LightWarmOld, 0.7, 14)
	Builder.cageLamp(m, ctx.CF(127, fy + h - 0.8, 2), "LightsDorm", P.LightWarmOld, 0.6, 10)
	local e1 = Builder.emergencyLampFor(m, ctx.CF(104, fy + h - 1, 0), "LightsDorm")
	e1:SetAttribute("AlwaysOn", true)
	local e2 = Builder.emergencyLampFor(m, ctx.CF(130, fy + h - 1, 4), "LightsDorm")
	e2:SetAttribute("AlwaysOn", true)
	Builder.ventGrille(m, ctx.CF(104, fy + 7, -6, math.pi / 2), 2, 1)
	Builder.pipeRun(m, { ctx.W(103.6, fy + 8, -7), ctx.W(122, fy + 8, -7) }, 0.3, P.Galvanized)
	Common.wallSign(ctx, m, 113, fy + 7.8, 7.4, math.pi, 8, 0.8, "УБЕЖИЩЕ · ВМЕСТИМОСТЬ 4 · ДВЕРЬ ЗАКРЫВАТЬ РЫЧАГОМ", P.Paper, P.WarningBlack, 14)
	Common.marker(ctx, "EventSpot", Vector3.new(124.5, fy + 3, 2), { Event = "Knock" })
end

-- ===== Build =============================================================

function DormBuilding.build(ctx, handle)
	local b = Station.Buildings.Dorm
	local shellModel = Builder.model(ctx.root, "Shell_Dorm")
	local function w(at)
		return { at = at, width = 4, height = 3, sill = 4 }
	end
	Common.shell(ctx, shellModel, b, {
		W = { { at = 0, width = Station.DoorWidth, height = Station.DoorHeight } },
		S = { { at = 98, width = Station.DoorWidth, height = Station.DoorHeight }, w(115), w(138) },
		N = { w(113), w(129), w(145) },
		E = { w(-6) },
	})
	for _, x in { 113, 129, 145 } do
		Builder.window(shellModel, ctx.CF(x, FY + 5.5, b.z1), 4, 3)
	end
	for _, x in { 115, 138 } do
		Builder.window(shellModel, ctx.CF(x, FY + 5.5, b.z2), 4, 3)
	end
	Builder.window(shellModel, ctx.CF(b.x2, FY + 5.5, -6, math.pi / 2), 4, 3)
	Common.partitions(ctx, shellModel, "Dorm", Station.Rooms, b)
	Common.wallSign(ctx, shellModel, 120, FY + 8.5, b.z2 + 0.7, math.pi, 16, 2.4, "КОРПУС 2 · ЖИЛОЙ", P.StationOrangeDark, P.Paper, 40)
	for _, x in { 100, 130 } do
		Builder.part({ name = "RoofVent", size = Vector3.new(2, 2.4, 2), cframe = ctx.CF(x, FY + b.height + 2.2, 12), material = Enum.Material.Metal, color = P.Graphite, parent = shellModel })
	end
	passage(ctx, handle)
	vestibule(ctx, handle)
	dormStore(ctx, handle)
	drying(ctx, handle)
	dorm(ctx, handle)
	dormWash(ctx, handle)
	dormBoiler(ctx, handle)
	bunker(ctx, handle)
end

return DormBuilding
