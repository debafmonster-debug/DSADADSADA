--!nonstrict
-- Корпус №1: airlock, corridor, control room, radio room, electrical room,
-- archive/lab, kitchen, medical, rest room, storage, cabins, washroom, boiler.
-- Every room tells its own story through props; interactive parts are named
-- and registered on the handle for services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Common = require(script.Parent.Common)
local P = Builder.Palette
local R = Station.RoomById
local FY = Station.FloorY
local H = Station.WallHeight

local MainBuilding = {}

local function roomModel(ctx, r)
	local m = Builder.model(ctx.root, "Room_" .. r.id)
	m:SetAttribute("RoomId", r.id)
	m:SetAttribute("RoomName", r.name)
	return m
end

-- ===== Rooms ============================================================

local function airlock(ctx, handle)
	local r = R.Airlock
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.DiamondPlate, P.Graphite, "grate")
	Common.roomLights(ctx, m, r, "cage")
	Builder.emergencyLampFor(m, ctx.CF(-56, FY + H - 1, -7.4), "LightsMain")
	-- Outer heavy door (west wall, opens outward) and inner door to corridor.
	local outer = Builder.door(ctx.doors, ctx.CF(-62, FY, 0, math.pi / 2), Station.DoorWidth + 1, Station.DoorHeight, { heavy = true, name = "Door_AirlockOuter", label = "ШЛЮЗ К-1" })
	outer:SetAttribute("Room", "Airlock")
	outer:SetAttribute("Exterior", true)
	handle.doors.airlockOuter = outer
	local inner = Common.roomDoor(ctx, r, "E", 0, { window = true, name = "Door_AirlockInner" })
	handle.doors.airlockInner = inner
	-- Coat rack, boots, snow tracked in.
	Props.coatRack(m, ctx.CF(-56, FY, -7.3), 4)
	Props.boots(m, ctx.CF(-59, FY, -6.5))
	Props.boots(m, ctx.CF(-53, FY, -6.8, 0.4))
	Props.bench(m, ctx.CF(-56, FY, 7.0), 6)
	for i = 1, 4 do
		local s = Builder.part({ name = "SnowPatch", size = Vector3.new(1.6 + i * 0.3, 0.08, 1.2), cframe = ctx.CF(-60.5 + i * 1.3, FY + 0.1, (i % 2 - 0.5) * 1.5), material = Enum.Material.Snow, color = P.Snow, parent = m, canCollide = false, castShadow = false })
		s:SetAttribute("SnowPatch", true)
	end
	Builder.fxAnchor(m, "SnowIn", ctx.CF(-60, FY + 4, 0), "SnowIn", Vector3.new(2, 6, 6))
	-- Identity scanner on the inner door frame.
	local scanner = Builder.model(ctx.interactive, "Scanner")
	local body = Builder.part({ name = "Body", size = Vector3.new(0.5, 2.0, 1.4), cframe = ctx.CF(-50.6, FY + 5, 4.2), material = Enum.Material.Metal, color = P.OldGreen, parent = scanner })
	local screen = Builder.part({ name = "Screen", size = Vector3.new(0.06, 0.9, 1.1), cframe = ctx.CF(-50.86, FY + 5.3, 4.2), material = Enum.Material.Neon, color = P.LightCold, parent = scanner, canCollide = false, castShadow = false })
	Builder.label(screen, Enum.NormalId.Left, "КОНТРОЛЬ ВХОДА\nОЖИДАНИЕ", { textSize = 10, font = Enum.Font.Code, textColor = P.WarningBlack, pixelsPerStud = 60 }).Name = "Text"
	Builder.registerLamp(screen, "Scanner", P.LightCold, 0.3)
	Builder.pointLight(screen, P.LightCold, 5, 0.3).Name = "Light"
	local lamp = Builder.part({ name = "StatusLamp", size = Vector3.new(0.1, 0.3, 0.3), cframe = ctx.CF(-50.86, FY + 4.3, 4.2), material = Enum.Material.Neon, color = P.Green, parent = scanner, canCollide = false, castShadow = false })
	Builder.pointLight(lamp, P.Green, 4, 0.4).Name = "Light"
	scanner.PrimaryPart = body
	handle.scanner = scanner
	Common.wallSign(ctx, m, -55, FY + 8.5, -7.4, 0, 8, 2.2, "ПРАВИЛА ВХОДА: 1. ОТМЕТИТЬСЯ НА СКАНЕРЕ. 2. ЗАКРЫТЬ ШЛЮЗ. 3. СЧИТАТЬ ЛЮДЕЙ.", P.Paper, P.WarningBlack, 16)
	-- Manual override lever (inside, next to the inner door).
	local lever = Builder.part({ name = "ScannerOverride", size = Vector3.new(0.4, 1.4, 0.4), cframe = ctx.CF(-50.7, FY + 4.5, -4.2), material = Enum.Material.Metal, color = P.Red, parent = ctx.interactive })
	Builder.part({ name = "Box", size = Vector3.new(0.5, 2.2, 1.2), cframe = ctx.CF(-50.6, FY + 4.3, -4.2), material = Enum.Material.Metal, color = P.Graphite, parent = lever })
	Common.wallSign(ctx, lever, -50.86, FY + 5.9, -4.2, math.pi / 2, 1.4, 0.5, "РУЧНАЯ РАЗБЛОКИРОВКА", P.Yellow, P.WarningBlack, 10)
	handle.scannerOverride = lever
	Common.wallSign(ctx, m, -62.6, FY + 9.6, 5, math.pi / 2, 6, 1.2, "ВОСТОК-9 · К-1", P.StationOrangeDark, P.Paper, 30)
end

local function corridor(ctx, handle)
	local r = R.Corridor
	local m = roomModel(ctx, r)
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	-- Cable trays and pipes under the ceiling run the full length.
	Builder.cableTray(m, ctx.W(-49, FY + H - 1.2, -3.6), ctx.W(61, FY + H - 1.2, -3.6), 1.4)
	Builder.pipeRun(m, { ctx.W(-49, FY + H - 1.4, 3.4), ctx.W(61, FY + H - 1.4, 3.4) }, 0.35, P.Galvanized)
	Builder.pipeRun(m, { ctx.W(-49, FY + H - 2.2, 3.6), ctx.W(61, FY + H - 2.2, 3.6) }, 0.22, P.StationOrangeFaded)
	for _, x in { -40, -5, 30, 58 } do
		Builder.emergencyLampFor(m, ctx.CF(x, FY + H - 0.9, -3.9), "LightsMain")
	end
	Common.extinguisher(ctx, m, -47, 3.9)
	Common.extinguisher(ctx, m, 20, -3.9)
	Common.wallSign(ctx, m, -46, FY + 9.2, -4.0, 0, 7, 0.9, "← ШЛЮЗ      УПРАВЛЕНИЕ · РАДИО · ЩИТОВАЯ →", P.Graphite, P.Paper, 14)
	Common.wallSign(ctx, m, 40, FY + 9.2, 4.0, math.pi, 7, 0.9, "← МЕДИЦИНСКАЯ · ОТДЫХ      ПЕРЕХОД В К-2 →", P.Graphite, P.Paper, 14)
	Common.wallSign(ctx, m, 61.4, FY + 9.4, 3.8, -math.pi / 2, 4, 0.8, "К-2 →", P.Yellow, P.WarningBlack, 20)
	-- Door signs for every room on the corridor.
	for _, id in { "Control", "RadioRoom", "Electrical", "Archive", "Kitchen" } do
		local rr = R[id]
		Common.wallSign(ctx, m, (rr.x1 + rr.x2) / 2 + 4.2, FY + 8.6, -4.0, 0, 3.2, 0.7, string.upper(rr.name), P.DirtyWhiteDark, P.WarningBlack, 14)
	end
	for _, id in { "Medical", "RestRoom", "Storage", "CabinA", "CabinB", "Washroom", "Boiler" } do
		local rr = R[id]
		Common.wallSign(ctx, m, (rr.x1 + rr.x2) / 2 - 4.2, FY + 8.6, 4.0, math.pi, 3.2, 0.7, string.upper(rr.name), P.DirtyWhiteDark, P.WarningBlack, 14)
	end
	-- Story prop: long scratches on the floor that stop at the north wall.
	Props.scratches(m, ctx.CF(24, FY + 0.12, -1.5, 0.9), 7)
	-- Door to the passage (east end).
	local pd = Builder.door(ctx.doors, ctx.CF(62, FY, 0, -math.pi / 2), Station.DoorWidth, Station.DoorHeight, { heavy = true, name = "Door_PassageMain", label = "ПЕРЕХОД" })
	pd:SetAttribute("Room", "Corridor")
	handle.doors.passageMain = pd
	-- Doors for every corridor room.
	for _, rr in Station.Rooms do
		if rr.building == "Main" and rr.door then
			local d = Common.roomDoor(ctx, rr, rr.door.side, rr.door.at, { window = rr.id == "Control" or rr.id == "Medical" })
			handle.roomDoors[rr.id] = d
		end
	end
end

local function control(ctx, handle)
	local r = R.Control
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Fabric, Color3.fromRGB(70, 74, 80), "concrete")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	-- Big map table with documents.
	local tbl = Props.table(m, ctx.CF(-33, FY, -12), 10, 5, P.WoodDark)
	tbl.Name = "MapTable"
	local mapPlate = Builder.part({ name = "MapSheet", size = Vector3.new(7, 0.04, 3.4), cframe = ctx.CF(-33, FY + 2.75, -12), material = Enum.Material.SmoothPlastic, color = P.Paper, parent = m, canCollide = false })
	Builder.label(mapPlate, Enum.NormalId.Top, "СХЕМА СТАНЦИИ «ВОСТОК-9»\nК-1 · ПЕРЕХОД · К-2 · ГЕНЕРАТОР · СКЛАД №2 · АНТЕННА · БУРОВАЯ (СЕВ.-ВОСТ.)", { textSize = 14, textColor = P.WarningBlack, pixelsPerStud = 40 })
	Props.papers(m, ctx.CF(-29, FY + 2.75, -10.5), 4)
	Props.mug(m, ctx.CF(-36.5, FY + 2.75, -10), false)
	Common.marker(ctx, "DocumentSpot", Vector3.new(-30, FY + 2.75, -13.2), { Spot = "ControlDesk" })
	for i = 1, 4 do
		Props.chair(m, ctx.CF(-39 + i * 3, FY, -8.5, math.pi))
	end
	-- Console wall (north): generator monitor + two monitors + status board.
	local console = Props.console(m, ctx.CF(-40, FY, -19.5), 10, "ГЕНЕРАТОР · ОТОПЛЕНИЕ · СВЯЗЬ", { "кВт", "ТОПЛ", "°C", "СИГН" })
	console.Name = "PowerConsole"
	handle.powerConsole = console
	Props.monitor(m, ctx.CF(-27, FY + 2.75, -19.4), "СТАНЦИЯ ВОСТОК-9\nТЕЛЕМЕТРИЯ\n> генератор ...\n> связь ...", P.ScreenBlue)
	Props.monitor(m, ctx.CF(-23.5, FY + 2.75, -19.4), "КАМЕРЫ\n[К-1] [К-2]\n[ГЕН] [СКЛ]\nсигнал: нет", Color3.fromRGB(60, 80, 70))
	Props.table(m, ctx.CF(-25, FY, -19.4), 9, 2.6, P.WoodDark)
	local board = Props.noticeBoard(m, ctx.CF(-18.5, FY + 6.5, -21.4), 5, 4, { "СОСТОЯНИЕ СИСТЕМ", "генератор: --", "отопление: --", "связь: --", "контроль входа: --" })
	board.Name = "StatusBoard"
	handle.statusBoard = board
	-- Shelf with the supply journal (warehouse code lives here).
	local shelf = Props.shelf(m, ctx.CF(-48.9, FY, -14, math.pi / 2), 6, 4)
	shelf.Name = "ControlShelf"
	Props.book(m, ctx.CF(-48.9, FY + 1.3, -15.5), P.OldGreenDark)
	Props.book(m, ctx.CF(-48.9, FY + 1.3, -12.5), P.Red)
	Common.marker(ctx, "DocumentSpot", Vector3.new(-48.9, FY + 3.0, -14), { Spot = "ControlShelf" })
	Props.cabinet(m, ctx.CF(-20, FY, -6, math.pi), P.OldGreen, "ИНСТРУКЦИИ")
	Props.wallClock(m, ctx.CF(-33, FY + 9, -21.4), "ControlClock")
	Builder.heater(m, ctx.CF(-44, FY, -21.2), "Heating", GameConfig.Temperature.HeaterRange)
	-- Windows on the north wall (view onto the antenna field).
	Common.wallSign(ctx, m, -33, FY + 9.8, -5.0, math.pi, 6, 0.8, "ДЕЖУРНЫЙ ОБЯЗАН ВЕСТИ ЖУРНАЛ", P.Paper, P.WarningBlack, 14)
	Props.radioSmall(m, ctx.CF(-45, FY + 2.75, -19.4), "ControlRadio")
	Common.extinguisher(ctx, m, -17, -20.5)
end

local function radioRoom(ctx, handle)
	local r = R.RadioRoom
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.WoodPlanks, P.WoodDark, "wood")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	local radio = Props.radioStation(ctx.interactive, ctx.CF(-7, FY, -20.2), "Radio")
	radio.Name = "RadioStation"
	handle.radio = radio
	Props.chair(m, ctx.CF(-7, FY, -16.5))
	Props.lampDesk(m, ctx.CF(-11.5, FY + 2.75, -19.5), P.LightWarmOld)
	Props.table(m, ctx.CF(-12, FY, -19.5), 4, 2.6, P.WoodDark)
	local shelf = Props.shelf(m, ctx.CF(0.9, FY, -14, -math.pi / 2), 5, 4)
	shelf.Name = "RadioShelf"
	Props.book(m, ctx.CF(0.9, FY + 1.3, -15), P.OldGreenDark)
	Common.marker(ctx, "DocumentSpot", Vector3.new(0.9, FY + 3.0, -13), { Spot = "RadioShelf" })
	Props.noticeBoard(m, ctx.CF(-7, FY + 6.5, -21.4), 5, 3.2, { "КАРТА РЕТРАНСЛЯТОРОВ", "Р-1 антенна К-1 — осн.", "Р-2 метеоплощадка — рез.", "Р-3 буровая — ОТКЛ." })
	Props.crate(m, ctx.CF(-13.5, FY, -7, 0.3), Vector3.new(2.6, 1.8, 2), P.OldGreenDark, "АКБ РЕЗЕРВ")
	Builder.cableTray(m, ctx.W(-7, FY + H - 1.3, -21.2), ctx.W(-7, FY + H - 1.3, -5.5), 1.0)
	Builder.pipeRun(m, { ctx.W(-15.5, FY + 2, -21.3), ctx.W(-15.5, FY + 9.5, -21.3), ctx.W(-2, FY + 9.5, -21.3) }, 0.18, P.Cable, Enum.Material.Rubber)
	Builder.emergencyLampFor(m, ctx.CF(-14, FY + H - 1, -5.4), "LightsMain")
	Common.wallSign(ctx, m, -7, FY + 9.6, -21.3, 0, 5, 0.7, "РАДИОРУБКА · ТИШИНА ВО ВРЕМЯ СЕАНСА", P.Paper, P.WarningBlack, 14)
end

local function electrical(ctx, handle)
	local r = R.Electrical
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Concrete, P.ConcreteFloor, "concrete")
	Common.roomLights(ctx, m, r)
	Builder.cageLamp(m, ctx.CF(14, FY + H - 0.8, -18), "LightsMain", P.LightWarmOld, 0.7, 12)
	local circuits = {}
	for _, c in GameConfig.Power.Circuits do
		table.insert(circuits, { id = c.id, label = c.label })
	end
	local panel = Props.breakerPanel(ctx.interactive, ctx.CF(10, FY, -21.3), circuits)
	handle.breakerPanel = panel
	local fuses = Props.fuseBox(ctx.interactive, ctx.CF(16.5, FY, -14, -math.pi / 2), 4)
	handle.fuseBox = fuses
	Builder.cableTray(m, ctx.W(3, FY + H - 1.2, -20), ctx.W(17, FY + H - 1.2, -20), 1.6)
	Builder.cableTray(m, ctx.W(10, FY + H - 1.2, -20), ctx.W(10, FY + H - 1.2, -5.5), 1.2)
	Builder.pipeRun(m, { ctx.W(10, FY + H - 1.2, -20.5), ctx.W(10, FY + 8, -20.5) }, 0.3, P.Graphite, Enum.Material.Rubber)
	Props.noticeBoard(m, ctx.CF(4.5, FY + 6.5, -12, math.pi / 2), 4, 3.6, { "СХЕМА СЕТИ 380 В", "ГЕН → АВТОМАТ → ЛИНИИ", "ЛАБОРАТОРИЯ: включать", "только при нагрузке < 81 кВт" })
	local shelf = Props.shelf(m, ctx.CF(14, FY, -6.2, math.pi), 5, 3)
	shelf.Name = "ElectricalShelf"
	Common.marker(ctx, "ItemSpot", Vector3.new(13, FY + 1.3, -6.2), { ItemId = "Fuse" })
	Props.crate(m, ctx.CF(5, FY, -7.5), Vector3.new(2.4, 1.6, 2), P.Wood, "КАБЕЛЬ")
	Builder.emergencyLampFor(m, ctx.CF(10, FY + H - 1, -5.4), "LightsMain")
	Common.wallSign(ctx, m, 10, FY + 9.8, -21.3, 0, 5, 0.8, "ВЫСОКОЕ НАПРЯЖЕНИЕ", P.Yellow, P.WarningBlack, 24)
	Builder.hazardStripes(m, ctx.CF(10, FY + 0.15, -17.5), 8, 0.6)
end

local function archive(ctx, _handle)
	local r = R.Archive
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.SmoothPlastic, P.LabWhite, "concrete")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	-- Archive half (west): shelves with folders, photo wall.
	for i = 0, 2 do
		local shelf = Props.shelf(m, ctx.CF(21 + i * 5, FY, -20.2), 4.4, 4)
		for lvl = 1, 3 do
			for k = 0, 2 do
				Props.book(shelf, ctx.CF(19.5 + i * 5 + k * 1.3, FY + lvl * 1.7 - 0.35, -20.2), if (i + k + lvl) % 3 == 0 then P.Red else P.OldGreenDark)
			end
		end
	end
	for i = 0, 3 do
		Props.photoFrame(m, ctx.CF(19.2, FY + 7.5 - i * 1.6, -13 + i * 1.2, math.pi / 2), if i == 0 then "1998" elseif i == 1 then "2005" elseif i == 2 then "2014" else "2021")
	end
	Common.marker(ctx, "DocumentSpot", Vector3.new(20.5, FY + 2.75, -9), { Spot = "ArchivePhoto" })
	Props.table(m, ctx.CF(21.5, FY, -9), 3, 3, P.WoodDark)
	-- Lab half (east): lab table, analyzer, samples.
	local lab = Props.table(m, ctx.CF(40, FY, -16), 10, 3.6, P.Stainless)
	lab.Name = "LabTable"
	Props.analyzer(m, ctx.CF(43, FY + 2.75, -16.4), "Lab")
	for i = 0, 3 do
		Props.sampleJar(m, ctx.CF(36 + i * 1.0, FY + 2.75, -17), if i == 2 then Color3.fromRGB(80, 90, 110) else P.Ice)
	end
	Props.papers(m, ctx.CF(38.5, FY + 2.75, -14.8), 3)
	Common.marker(ctx, "DocumentSpot", Vector3.new(36, FY + 2.75, -14.6), { Spot = "ArchiveTable" })
	Props.desk(m, ctx.CF(44, FY, -8, math.pi))
	Props.chair(m, ctx.CF(44, FY, -10.8))
	Props.cabinet(m, ctx.CF(30, FY, -20.2), P.DirtyWhiteDark, "ОБРАЗЦЫ")
	Props.monitor(m, ctx.CF(28, FY + 2.75, -8), "СЕЙСМО/АКУСТ\n7 имп. / 40 с\n7 имп. / 40 с\n7 имп. / 40 с", P.LightLab, "Lab")
	Props.table(m, ctx.CF(28, FY, -8), 4, 2.6, P.WoodDark)
	Builder.emergencyLampFor(m, ctx.CF(33, FY + H - 1, -5.4), "LightsMain")
	Common.wallSign(ctx, m, 33, FY + 9.8, -21.3, 0, 8, 0.8, "АРХИВ ЭКСПЕДИЦИЙ · ЛАБОРАТОРИЯ КЕРНА", P.Paper, P.WarningBlack, 16)
	Builder.pipeRun(m, { ctx.W(47.5, FY + 1, -21), ctx.W(47.5, FY + 9, -21), ctx.W(47.5, FY + 9, -6) }, 0.22, P.Galvanized)
end

local function kitchen(ctx, _handle)
	local r = R.Kitchen
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.WoodPlanks, P.Wood, "wood")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	Props.table(m, ctx.CF(55, FY, -13), 6, 3.2)
	for i = 1, 3 do
		Props.chair(m, ctx.CF(52 + (i - 1) * 2.6, FY, -10.4, math.pi), if i == 2 then P.FabricWarm else P.Fabric)
	end
	Props.chair(m, ctx.CF(55, FY, -15.6), P.Fabric)
	Props.mug(m, ctx.CF(53, FY + 2.75, -13.4), false)
	Props.mug(m, ctx.CF(56.5, FY + 2.75, -12.3), false, Color3.fromRGB(180, 70, 60))
	Common.marker(ctx, "EventSpot", Vector3.new(54.8, FY + 2.75, -14.2), { Event = "ExtraMug" })
	Props.cabinet(m, ctx.CF(50.5, FY, -20.2), P.DirtyWhite)
	Props.table(m, ctx.CF(57, FY, -20.4), 7, 2.4, P.Stainless)
	local kettle = Builder.part({ name = "Kettle", size = Vector3.new(1.0, 1.0, 1.0), cframe = ctx.CF(58.5, FY + 3.1, -20.4), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Stainless, parent = m, canCollide = false })
	kettle.CFrame = ctx.CF(58.5, FY + 3.1, -20.4) * CFrame.Angles(0, 0, math.pi / 2)
	Props.radioSmall(m, ctx.CF(55, FY + 2.75, -20.6), "KitchenRadio")
	Props.wallClock(m, ctx.CF(55, FY + 9, -21.4), "KitchenClock")
	Props.photoFrame(m, ctx.CF(49, FY + 7.2, -16, math.pi / 2), "Зимовка")
	Props.noticeBoard(m, ctx.CF(61.3, FY + 6.5, -13, -math.pi / 2), 4, 3, { "МЕНЮ", "пн: борщ", "вт: макароны", "ср: —", "ВОДУ КИПЯТИТЬ" })
	Builder.fxAnchor(m, "KettleSteam", ctx.CF(58.5, FY + 3.8, -20.4), "Steam", nil, { Rate = 1 })
end

local function medical(ctx, handle)
	local r = R.Medical
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.SmoothPlastic, P.LabWhite, "concrete")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	Props.stretcher(m, ctx.CF(-36, FY, 14))
	Props.stretcher(m, ctx.CF(-32.5, FY, 14))
	local cab = Props.cabinet(ctx.interactive, ctx.CF(-48.9, FY, 14, math.pi / 2), P.DirtyWhite, "АПТЕЧКА")
	cab.Name = "MedCabinet"
	handle.medCabinet = cab
	Common.marker(ctx, "ItemSpot", Vector3.new(-47.6, FY + 2.0, 12.5), { ItemId = "Medkit" })
	Common.marker(ctx, "ItemSpot", Vector3.new(-47.6, FY + 2.0, 15.5), { ItemId = "Medkit" })
	Props.desk(m, ctx.CF(-44, FY, 20, math.pi))
	Props.chair(m, ctx.CF(-44, FY, 17.2))
	Common.marker(ctx, "DocumentSpot", Vector3.new(-45.5, FY + 2.75, 20.4), { Spot = "MedDesk" })
	Props.shelf(m, ctx.CF(-34, FY, 21.2, math.pi), 5, 3)
	for i = 0, 3 do
		Props.sampleJar(m, ctx.CF(-36 + i * 1.1, FY + 1.35, 21.2), Color3.fromRGB(220, 220, 230))
	end
	Common.wallSign(ctx, m, -40, FY + 9.6, 21.3, math.pi, 5, 0.8, "МЕДИЦИНСКИЙ ПУНКТ", P.LabWhite, P.Red, 20)
	Builder.part({ name = "Sink", size = Vector3.new(1.6, 1.0, 1.2), cframe = ctx.CF(-31, FY + 2.5, 20.8), material = Enum.Material.Metal, color = P.Stainless, parent = m })
	Builder.part({ name = "SinkStand", size = Vector3.new(1.4, 2.0, 1.0), cframe = ctx.CF(-31, FY + 1.0, 20.8), material = Enum.Material.Metal, color = P.DirtyWhiteDark, parent = m })
end

local function restRoom(ctx, _handle)
	local r = R.RestRoom
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Fabric, Color3.fromRGB(96, 84, 70), "wood")
	Common.roomLights(ctx, m, r)
	Common.roomTrim(ctx, m, r)
	Props.sofa(m, ctx.CF(-18, FY, 9.5))
	Props.sofa(m, ctx.CF(-26, FY, 14, math.pi / 2), P.Fabric)
	Props.table(m, ctx.CF(-18, FY, 14), 5, 2.6)
	Props.mug(m, ctx.CF(-19, FY + 2.75, 13.6), false)
	Props.mug(m, ctx.CF(-16.5, FY + 2.75, 14.5), false)
	Props.book(m, ctx.CF(-18.2, FY + 2.75, 15), P.Red)
	Common.marker(ctx, "EventSpot", Vector3.new(-17, FY + 2.75, 12.9), { Spot = "RestTable", Event = "ExtraMug" })
	Props.tv(m, ctx.CF(-10, FY, 18.5, math.pi), false)
	Props.table(m, ctx.CF(-10, FY, 18.5), 4, 2.6, P.WoodDark)
	Props.chair(m, ctx.CF(-12, FY, 11.5, 0.6))
	Common.marker(ctx, "EventSpot", Vector3.new(-12, FY, 11.5), { Event = "ChairMoved" })
	Props.floorLamp(m, ctx.CF(-28.5, FY, 6.5))
	Builder.heater(m, ctx.CF(-18, FY, 21.2), "Heating", GameConfig.Temperature.HeaterRange)
	Props.noticeBoard(m, ctx.CF(-7, FY + 6.5, 8, -math.pi / 2), 4.5, 3.2, { "ОБЪЯВЛЕНИЯ", "Баня — суббота", "Кино — вторник", "НЕ ОТКРЫВАТЬ ШЛЮЗ ПОСЛЕ 22:00", "ЖАРОВА: верни мою кружку" })
	Props.photoFrame(m, ctx.CF(-22, FY + 7, 21.3), "Смена 14")
	Props.photoFrame(m, ctx.CF(-24, FY + 7, 21.3), "Мищенко")
	Props.shelf(m, ctx.CF(-29.1, FY, 18, math.pi / 2), 4, 3)
	for i = 0, 2 do
		Props.book(m, ctx.CF(-29.1, FY + 1.3, 17 + i * 0.9), if i == 1 then P.OldGreenDark else P.Wood)
	end
	Props.wallClock(m, ctx.CF(-18, FY + 9, 21.4), "RestClock")
end

local function storage(ctx, _handle)
	local r = R.Storage
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Concrete, P.ConcreteFloor, "concrete")
	Common.roomLights(ctx, m, r, "cage")
	local shelf = Props.shelf(m, ctx.CF(1, FY, 21.0, math.pi), 8, 4)
	shelf.Name = "StorageShelf"
	Common.marker(ctx, "ItemSpot", Vector3.new(-1.5, FY + 1.3, 21.0), { ItemId = "Battery" })
	Common.marker(ctx, "ItemSpot", Vector3.new(3, FY + 3.0, 21.0), { ItemId = "Fuse" })
	Common.marker(ctx, "DocumentSpot", Vector3.new(1, FY + 4.7, 21.0), { Spot = "StorageWall" })
	Props.crate(m, ctx.CF(-3.5, FY, 8, 0.2), Vector3.new(3, 2.2, 2.4), P.Wood, "КОНСЕРВЫ")
	Props.crate(m, ctx.CF(-3.5, FY + 2.2, 8, 0.1), Vector3.new(2.6, 1.8, 2.0), P.Wood)
	Props.crate(m, ctx.CF(5, FY, 9), Vector3.new(3, 2, 2.4), P.OldGreenDark, "ЗИП")
	Props.barrel(m, ctx.CF(5.5, FY, 15), P.StationOrangeDark)
	Props.barrel(m, ctx.CF(-3.6, FY, 15), P.Graphite)
	Common.wallSign(ctx, m, -5.4, FY + 7, 14, math.pi / 2, 3.6, 1.6, "НЕ ВКЛЮЧАЙТЕ БУРОВУЮ ПОВТОРНО", P.DirtyWhiteDark, P.Red, 18)
end

local function cabin(ctx, _handle, id: string, blanket: Color3, name: string, twoMugs: boolean)
	local r = R[id]
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.WoodPlanks, P.Wood, "wood")
	Common.roomLights(ctx, m, r)
	local cx = (r.x1 + r.x2) / 2
	Props.bed(m, ctx.CF(r.x1 + 2.4, FY, 15.5), blanket)
	Props.locker(m, ctx.CF(r.x2 - 1.6, FY, 20.6, math.pi), P.OldGreen, name)
	Props.desk(m, ctx.CF(cx + 1, FY, 8.5))
	Props.chair(m, ctx.CF(cx + 1, FY, 11.3, math.pi))
	Props.boots(m, ctx.CF(r.x1 + 2.4, FY, 19.8))
	Props.mug(m, ctx.CF(cx - 1, FY + 2.75, 8.2), false)
	if twoMugs then
		Props.mug(m, ctx.CF(cx + 2.4, FY + 2.75, 8.9), false, Color3.fromRGB(180, 70, 60))
	end
	Props.photoFrame(m, ctx.CF(r.x1 + 0.3, FY + 6.5, 12, math.pi / 2), nil)
	Props.book(m, ctx.CF(cx + 2.6, FY + 2.75, 7.6), P.OldGreenDark)
end

local function washroom(ctx, _handle)
	local r = R.Washroom
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.SmoothPlastic, P.PanelWhite, "concrete")
	Common.roomLights(ctx, m, r)
	for i = 0, 2 do
		Builder.part({ name = "Sink", size = Vector3.new(1.6, 0.8, 1.2), cframe = ctx.CF(38.5 + i * 2.6, FY + 2.6, 20.8), material = Enum.Material.Metal, color = P.Stainless, parent = m })
		Builder.part({ name = "SinkStand", size = Vector3.new(1.4, 2.2, 1.0), cframe = ctx.CF(38.5 + i * 2.6, FY + 1.1, 20.8), material = Enum.Material.Metal, color = P.DirtyWhiteDark, parent = m })
		Builder.part({ name = "Tap", size = Vector3.new(0.15, 0.6, 0.6), cframe = ctx.CF(38.5 + i * 2.6, FY + 3.3, 21.2), material = Enum.Material.Metal, color = P.Stainless, parent = m, canCollide = false })
	end
	local mirror = Builder.part({ name = "Mirror", size = Vector3.new(7.6, 2.4, 0.08), cframe = ctx.CF(41.1, FY + 5.6, 21.4), material = Enum.Material.Glass, color = Color3.fromRGB(190, 200, 210), parent = m, reflectance = 0.7, canCollide = false })
	mirror:SetAttribute("Mirror", true)
	Builder.pipeRun(m, { ctx.W(37, FY + 0.6, 21.2), ctx.W(46, FY + 0.6, 21.2) }, 0.15, P.Galvanized)
	Builder.part({ name = "Partition", size = Vector3.new(0.2, 7, 4), cframe = ctx.CF(45, FY + 3.5, 8), material = Enum.Material.SmoothPlastic, color = P.DirtyWhiteDark, parent = m })
	Builder.part({ name = "Shower", size = Vector3.new(2.6, 0.2, 2.6), cframe = ctx.CF(46.5, FY + 9.5, 8), material = Enum.Material.Metal, color = P.Stainless, parent = m, canCollide = false })
	Builder.fxAnchor(m, "Drip", ctx.CF(46.5, FY + 9, 8), "Drip")
end

local function boiler(ctx, _handle)
	local r = R.Boiler
	local m = roomModel(ctx, r)
	Common.roomFloor(ctx, m, r, Enum.Material.Concrete, P.ConcreteFloor, "concrete")
	Common.roomLights(ctx, m, r, "cage")
	local unit = Builder.model(m, "BoilerUnit")
	Builder.part({ name = "Tank", size = Vector3.new(4, 6, 4), cframe = ctx.CF(56, FY + 3, 17), material = Enum.Material.Metal, color = P.OldGreenDark, parent = unit })
	Builder.part({ name = "Burner", size = Vector3.new(2.4, 2.4, 1.6), cframe = ctx.CF(56, FY + 1.5, 14.2), material = Enum.Material.Metal, color = P.Graphite, parent = unit })
	local glow = Builder.part({ name = "Lamp", size = Vector3.new(0.6, 0.6, 0.1), cframe = ctx.CF(56, FY + 1.5, 13.35), material = Enum.Material.Neon, color = P.Orange, parent = unit, canCollide = false, castShadow = false })
	Builder.pointLight(glow, P.Orange, 8, 0.6).Name = "Light"
	Builder.registerLamp(glow, "Heating", P.Orange, 0.6)
	Builder.pipeRun(m, { ctx.W(56, FY + 6.5, 17), ctx.W(56, FY + 9.5, 17), ctx.W(49, FY + 9.5, 17), ctx.W(49, FY + 9.5, 5) }, 0.4, P.Galvanized)
	Builder.pipeRun(m, { ctx.W(58, FY + 6.5, 17), ctx.W(58, FY + 9.0, 17), ctx.W(61.5, FY + 9.0, 17), ctx.W(61.5, FY + 9.0, 5) }, 0.3, P.StationOrangeFaded)
	for i = 0, 2 do
		Props.gauge(unit, ctx.CF(54.0 + i * 0.9, FY + 5.2, 14.95), if i == 0 then "бар" elseif i == 1 then "°C" else "л", 0.4 + i * 0.15)
	end
	Builder.heater(m, ctx.CF(50.5, FY, 21.2), "Heating", GameConfig.Temperature.HeaterRange)
	Builder.part({ name = "ExhaustStack", size = Vector3.new(1.2, 6, 1.2), cframe = ctx.CF(56, FY + H + 3, 17), material = Enum.Material.Metal, color = P.Graphite, parent = m })
	Builder.fxAnchor(m, "StackSteam", ctx.CF(56, FY + H + 6.2, 17), "Steam", nil, { Rate = 3 })
	Common.wallSign(ctx, m, 55, FY + 9.6, 21.3, math.pi, 5, 0.8, "КОТЕЛЬНАЯ · НЕ ЗАКРЫВАТЬ ВЕНТИЛЯЦИЮ", P.Yellow, P.WarningBlack, 16)
	local hum = Builder.sound(unit, require(ReplicatedStorage.Shared.Config.SoundLibrary).HeaterHum, "Hum")
	hum:SetAttribute("AutoPlay", true)
end

-- ===== Build =============================================================

function MainBuilding.build(ctx, handle)
	local b = Station.Buildings.Main
	local shellModel = Builder.model(ctx.root, "Shell_Main")
	local win = { width = 4, height = 3, sill = 4 }
	local function w(at)
		return { at = at, width = win.width, height = win.height, sill = win.sill }
	end
	Common.shell(ctx, shellModel, b, {
		W = { { at = 0, width = Station.DoorWidth + 1, height = Station.DoorHeight } },
		E = { { at = 0, width = Station.DoorWidth, height = Station.DoorHeight } },
		N = { w(-40), w(-26), w(33), w(55) },
		S = { w(-18), w(-40), w(29), w(15) },
	})
	-- Window glass in the openings.
	for _, x in { -40, -26, 33, 55 } do
		Builder.window(shellModel, ctx.CF(x, FY + win.sill + win.height / 2, b.z1), win.width, win.height)
	end
	for _, x in { -18, -40, 29, 15 } do
		Builder.window(shellModel, ctx.CF(x, FY + win.sill + win.height / 2, b.z2), win.width, win.height)
	end
	Common.partitions(ctx, shellModel, "Main", Station.Rooms, b)
	-- Roof vents and the big "ВОСТОК-9" sign.
	for _, x in { -30, 10, 45 } do
		Builder.part({ name = "RoofVent", size = Vector3.new(2, 2.4, 2), cframe = ctx.CF(x, FY + b.height + 2.2, -12), material = Enum.Material.Metal, color = P.Graphite, parent = shellModel })
	end
	Common.wallSign(ctx, shellModel, -20, FY + 8.5, b.z1 - 0.7, 0, 22, 2.6, "СТАНЦИЯ «ВОСТОК-9»  ·  КОРПУС 1", P.StationOrangeDark, P.Paper, 42)
	airlock(ctx, handle)
	corridor(ctx, handle)
	control(ctx, handle)
	radioRoom(ctx, handle)
	electrical(ctx, handle)
	archive(ctx, handle)
	kitchen(ctx, handle)
	medical(ctx, handle)
	restRoom(ctx, handle)
	storage(ctx, handle)
	cabin(ctx, handle, "CabinA", P.Blanket, "КАЛИНИН", false)
	cabin(ctx, handle, "CabinB", P.FabricWarm, "МИЩЕНКО", true)
	washroom(ctx, handle)
	boiler(ctx, handle)
	-- Ambient sounds: vent hum in the corridor, clock tick in the rest room.
	local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
	local vent = Builder.sound(ctx.root, Sounds.VentHum, "Vent")
	vent:SetAttribute("AutoPlay", true)
	local ventPart = Builder.ventGrille(shellModel, ctx.CF(5, FY + H - 1.6, -4.4), 2, 1)
	vent.Parent = ventPart
end

return MainBuilding
