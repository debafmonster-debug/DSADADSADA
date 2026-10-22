--!nonstrict
-- Lobby: the transport base from which expeditions leave. A warm rest room,
-- an equipment room with lockers, a briefing room, a radio/archive corner and
-- the exit airlock onto a snow apron with the waiting plane.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Airfield = require(ReplicatedStorage.Shared.Scenes.Airfield)
local P = Builder.Palette

local LobbyBuilder = {}

export type Anchors = {
	root: Model,
	spawn: SpawnLocation,
	shiftBoard: BasePart,
	shiftBoardScreen: TextLabel,
	briefingConsole: BasePart,
	briefingScreen: TextLabel,
	archiveTerminals: { BasePart },
	registration: BasePart,
	lockers: { [string]: BasePart },
	airlockDoor: Model,
}

local H = 11

local function Common_sign(parent, cf, w, h, text, bg, fg, size)
	return Builder.signPlate(parent, cf, w, h, text, bg, fg, size)
end

-- North wall of the hall rebuilt by hand so it can carry real window openings.
local function hallNorthWall(parent, origin: CFrame)
	local z = -19.5
	local function seg(x1: number, x2: number, y0: number, h: number)
		if x2 - x1 < 0.05 or h < 0.05 then
			return
		end
		Builder.part({ name = "WallN", size = Vector3.new(x2 - x1, h, 1), cframe = origin * CFrame.new((x1 + x2) / 2, y0 + h / 2, z), material = Enum.Material.SmoothPlastic, color = P.DirtyWhite, parent = parent })
	end
	local features = { { -24, -20, "win" }, { -12, -8, "win" }, { 0, 4, "win" }, { 15, 21, "door" } }
	local cursor = -30
	for _, f in features do
		seg(cursor, f[1], 0, H)
		if f[3] == "win" then
			seg(f[1], f[2], 0, 4)
			seg(f[1], f[2], 7, H - 7)
		else
			seg(f[1], f[2], 8, H - 8)
		end
		cursor = f[2]
	end
	seg(cursor, 30, 0, H)
end

local function roomShell(parent, cf: CFrame, w: number, d: number, doors, floorMat, floorColor, name)
	local f = Builder.shell(parent, cf, w, d, H, { doors = doors, floorMaterial = floorMat, floorColor = floorColor, wallMaterial = Enum.Material.SmoothPlastic, wallColor = P.DirtyWhite, ceilingColor = P.DirtyWhiteDark, ceilingMaterial = Enum.Material.SmoothPlastic })
	f.Name = name
	local floor = f:FindFirstChild("Floor")
	if floor then
		floor:SetAttribute("Floor", if floorMat == Enum.Material.WoodPlanks then "wood" else "concrete")
	end
	return f
end

function LobbyBuilder.build(parent: Instance, origin: CFrame): Anchors
	local root = Builder.model(nil, "Lobby")
	local anchors = { root = root, archiveTerminals = {}, lockers = {} }
	local DOOR = { width = 6, height = 8 }

	-- ===== Rest room (main hall) ==========================================
	local hall = Builder.model(root, "RestRoom")
	local hallShell = roomShell(hall, origin, 60, 40, { W = DOOR, E = DOOR, N = { width = 60, height = H }, S = { width = 7, height = 8.5 } }, Enum.Material.WoodPlanks, P.Wood, "Shell")
	hallNorthWall(hallShell, origin)
	for i = 0, 2 do
		Builder.fluorLamp(hall, origin * CFrame.new(-20 + i * 20, H - 0.35, -8), 6, "LightsMain", P.LightWarmOld, 0.9, i == 1)
		Builder.fluorLamp(hall, origin * CFrame.new(-20 + i * 20, H - 0.35, 8), 6, "LightsMain", P.LightWarmOld, 0.9, false)
	end
	-- Windows on the north wall look at the snow and the apron.
	for _, x in { -22, -10, 2 } do
		Builder.window(hall, origin * CFrame.new(x, 5.5, -19.5), 4, 3)
	end
	Props.sofa(hall, origin * CFrame.new(-18, 0, -8), P.FabricWarm)
	Props.sofa(hall, origin * CFrame.new(-18, 0, 2) * CFrame.Angles(0, math.pi, 0), P.Fabric)
	Props.table(hall, origin * CFrame.new(-18, 0, -3), 6, 3)
	Props.mug(hall, origin * CFrame.new(-19.5, 2.75, -3.4), true)
	Props.mug(hall, origin * CFrame.new(-16.5, 2.75, -2.4), false)
	Props.book(hall, origin * CFrame.new(-17.8, 2.75, -3.9), P.Red)
	Props.tv(hall, origin * CFrame.new(-28.4, 2.75, -3) * CFrame.Angles(0, math.pi / 2, 0), true)
	Props.table(hall, origin * CFrame.new(-28.4, 0, -3) * CFrame.Angles(0, math.pi / 2, 0), 5, 2.6, P.WoodDark)
	Props.wallClock(hall, origin * CFrame.new(0, 8.5, -19.4), "LobbyClock")
	Props.photoFrame(hall, origin * CFrame.new(-6, 7, -19.4), "Восток-9, 2021")
	Props.photoFrame(hall, origin * CFrame.new(-3.8, 7, -19.4), "Смена 14")
	Props.noticeBoard(hall, origin * CFrame.new(12, 6.5, -19.4), 7, 4.4, { "ДОСКА ОБЪЯВЛЕНИЙ", "Вылет на «Восток-9» — по готовности группы", "Фонари получать в экипировочной", "После 22:00 станционного времени — К-2", "Потерянная кружка: спросить Жарову" })
	Props.table(hall, origin * CFrame.new(10, 0, 8), 8, 3.4)
	for i = 0, 3 do
		Props.chair(hall, origin * CFrame.new(7 + i * 2.2, 0, 10.8) * CFrame.Angles(0, math.pi, 0), if i % 2 == 0 then P.Fabric else P.FabricWarm)
	end
	Props.mug(hall, origin * CFrame.new(9, 2.75, 7.6), false)
	Props.papers(hall, origin * CFrame.new(12, 2.75, 8.3), 3)
	Props.radioSmall(hall, origin * CFrame.new(14.5, 2.75, 8.6), "LobbyRadio")
	Props.coatRack(hall, origin * CFrame.new(24, 0, 19.2), 5)
	Props.boots(hall, origin * CFrame.new(21, 0, 18))
	Props.boots(hall, origin * CFrame.new(26.5, 0, 18.2) * CFrame.Angles(0, 0.3, 0))
	Builder.heater(hall, origin * CFrame.new(-10, 0, 19.3), "Heating", 10)
	Props.floorLamp(hall, origin * CFrame.new(-26, 0, 8))
	-- Shift board (rooms) on the east wall, next to the briefing room door.
	local boardConsole = Props.console(hall, origin * CFrame.new(22, 0, -12) * CFrame.Angles(0, -math.pi / 2, 0), 8, "ДОСКА СМЕН · КОМНАТЫ", { "ГОТ", "СВЯЗЬ" })
	boardConsole.Name = "ShiftBoard"
	local boardScreenPart = Builder.part({ name = "BoardScreen", size = Vector3.new(0.3, 6, 12), cframe = origin * CFrame.new(29.3, 6.5, -12), material = Enum.Material.Neon, color = Color3.fromRGB(26, 34, 44), parent = hall, canCollide = false, castShadow = false })
	local boardLabel = Builder.label(boardScreenPart, Enum.NormalId.Left, "ДОСКА СМЕН\nзагрузка…", { textSize = 22, font = Enum.Font.Code, textColor = P.LightCold, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 10, pixelsPerStud = 30 })
	Builder.registerLamp(boardScreenPart, "LightsMain", Color3.fromRGB(26, 34, 44), 0.2)
	Builder.pointLight(boardScreenPart, P.LightCold, 10, 0.5).Name = "Light"
	local boardPrompt = Builder.prompt(boardConsole.PrimaryPart, "Открыть доску смен", "Комнаты экспедиций", 0, Enum.KeyCode.E, 10)
	boardPrompt:SetAttribute("UI", "RoomBoard")
	anchors.shiftBoard = boardConsole.PrimaryPart
	anchors.shiftBoardScreen = boardLabel
	-- Registration / profile terminal near the entrance.
	local reg = Props.monitor(hall, origin * CFrame.new(-24, 2.75, 16), "РЕГИСТРАЦИЯ\nЭКСПЕДИЦИИ", P.ScreenBlue)
	Props.table(hall, origin * CFrame.new(-24, 0, 16), 4, 2.6, P.WoodDark)
	local regPrompt = Builder.prompt(reg.PrimaryPart, "Профиль сотрудника", "Регистрация", 0, Enum.KeyCode.E, 8)
	regPrompt:SetAttribute("UI", "Registration")
	anchors.registration = reg.PrimaryPart
	Common_sign(hall, origin * CFrame.new(0, 9.6, 19.4) * CFrame.Angles(0, math.pi, 0), 20, 1.8, "ТРАНСПОРТНАЯ БАЗА «МИРНЫЙ» · ЗАЛ ОЖИДАНИЯ", P.StationOrangeDark, P.Paper, 36)
	Common_sign(hall, origin * CFrame.new(-29.3, 9.2, 0) * CFrame.Angles(0, math.pi / 2, 0), 8, 1, "ЭКИПИРОВОЧНАЯ →", P.Graphite, P.Paper, 22)
	Common_sign(hall, origin * CFrame.new(29.3, 9.2, 0) * CFrame.Angles(0, -math.pi / 2, 0), 8, 1, "← БРИФИНГ", P.Graphite, P.Paper, 22)
	Common_sign(hall, origin * CFrame.new(18, 9.2, -19.4), 8, 1, "РАДИОРУБКА · АРХИВ", P.Graphite, P.Paper, 22)
	Common_sign(hall, origin * CFrame.new(0, 9.6, 19.0) * CFrame.Angles(0, math.pi, 0), 10, 1, "ВЫХОДНОЙ ШЛЮЗ · ПЛОЩАДКА", P.Yellow, P.WarningBlack, 24)

	-- ===== Equipment room (west) ===========================================
	local eq = Builder.model(root, "EquipmentRoom")
	roomShell(eq, origin * CFrame.new(-46, 0, 0), 32, 26, { E = DOOR }, Enum.Material.Concrete, P.ConcreteFloor, "Shell")
	Builder.fluorLamp(eq, origin * CFrame.new(-46, H - 0.35, -5), 6, "LightsMain", P.LightFluor, 1.1, true)
	Builder.fluorLamp(eq, origin * CFrame.new(-46, H - 0.35, 5), 6, "LightsMain", P.LightFluor, 1.1, false)
	for i, toolId in Tools.Order do
		local def = Tools.Defs[toolId]
		local locker = Props.locker(eq, origin * CFrame.new(-58 + (i - 1) * 6, 0, -12.1), def.color, def.name)
		locker.Name = "Locker_" .. toolId
		local body = locker.PrimaryPart
		local prompt = Builder.prompt(body, "Выбрать", def.name, 0, Enum.KeyCode.E, 8)
		prompt:SetAttribute("UI", "Equipment")
		prompt:SetAttribute("ToolId", toolId)
		anchors.lockers[toolId] = body
		Builder.signPlate(eq, origin * CFrame.new(-58 + (i - 1) * 6, 7.4, -11.1), 4, 1.2, def.name, P.Graphite, P.Paper, 18)
	end
	Props.shelf(eq, origin * CFrame.new(-46, 0, 12.1) * CFrame.Angles(0, math.pi, 0), 14, 4)
	for i = 0, 5 do
		Props.itemPickup(eq, origin * CFrame.new(-52 + i * 2.4, 1.3 + (i % 2) * 1.7, 12.1), if i % 2 == 0 then "Battery" else "Fuse", "").Name = "Display"
	end
	Props.bench(eq, origin * CFrame.new(-46, 0, 0), 8)
	Props.coatRack(eq, origin * CFrame.new(-61.3, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 4)
	Props.crate(eq, origin * CFrame.new(-33, 0, 10) * CFrame.Angles(0, 0.2, 0), Vector3.new(3, 2.2, 2.4), P.OldGreenDark, "ФОНАРИ")
	Props.noticeBoard(eq, origin * CFrame.new(-34.9, 6.5, -6) * CFrame.Angles(0, -math.pi / 2, 0), 5, 3.4, { "ВЫДАЧА", "Один инструмент на смену", "Фонарь — у каждого", "Аккумуляторы — на складе", "Инструмент выбирать до вылета" })
	Builder.cableTray(eq, origin:PointToWorldSpace(Vector3.new(-61, H - 1.2, -12)), origin:PointToWorldSpace(Vector3.new(-31, H - 1.2, -12)), 1.2)

	-- ===== Briefing room (east) ============================================
	local br = Builder.model(root, "BriefingRoom")
	roomShell(br, origin * CFrame.new(46, 0, 0), 32, 26, { W = DOOR }, Enum.Material.Fabric, Color3.fromRGB(70, 74, 80), "Shell")
	Builder.fluorLamp(br, origin * CFrame.new(46, H - 0.35, 0), 8, "LightsMain", P.LightFluor, 1.0, true)
	local screen = Builder.part({ name = "BigScreen", size = Vector3.new(16, 7, 0.3), cframe = origin * CFrame.new(46, 6, -12.3), material = Enum.Material.Neon, color = Color3.fromRGB(24, 32, 40), parent = br, canCollide = false, castShadow = false })
	local brLabel = Builder.label(screen, Enum.NormalId.Front, "БРИФИНГ\nзагрузка…", { textSize = 24, font = Enum.Font.Code, textColor = P.LightCold, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 14, pixelsPerStud = 28 })
	Builder.pointLight(screen, P.LightCold, 14, 0.6).Name = "Light"
	Builder.registerLamp(screen, "LightsMain", Color3.fromRGB(24, 32, 40), 0.3)
	Props.table(br, origin * CFrame.new(46, 0, -2), 14, 5, P.WoodDark)
	for i = 0, 4 do
		Props.chair(br, origin * CFrame.new(40 + i * 3, 0, 1.6) * CFrame.Angles(0, math.pi, 0))
	end
	local mapPlate = Builder.part({ name = "StationMap", size = Vector3.new(8, 0.04, 4.4), cframe = origin * CFrame.new(46, 2.75, -2), material = Enum.Material.SmoothPlastic, color = P.Paper, parent = br, canCollide = false })
	Builder.label(mapPlate, Enum.NormalId.Top, "СХЕМА СТАНЦИИ «ВОСТОК-9»\n[К-1] ═══ переход ═══ [К-2]\n  генератор ▪   склад №2 ▪   антенна ▲\n  буровой комплекс — сев.-вост.", { textSize = 14, textColor = P.WarningBlack, pixelsPerStud = 40 })
	local brConsole = Props.console(br, origin * CFrame.new(56, 0, 8) * CFrame.Angles(0, math.pi / 2, 0), 6, "ДОСКА ЗАДАЧ", { "ГЛ" })
	local brPrompt = Builder.prompt(brConsole.PrimaryPart, "Открыть брифинг", "Доска задач", 0, Enum.KeyCode.E, 9)
	brPrompt:SetAttribute("UI", "Briefing")
	anchors.briefingConsole = brConsole.PrimaryPart
	anchors.briefingScreen = brLabel
	Props.noticeBoard(br, origin * CFrame.new(61.3, 6.5, -4) * CFrame.Angles(0, -math.pi / 2, 0), 5, 3.6, { "ПРАВИЛА СТАНЦИИ", "1. Отметиться на сканере", "2. Крышку генератора закрыть", "3. После 22:00 — только К-2", "4. Считать людей" })

	-- ===== Radio / archive corner (north-east, off the hall) ===============
	local ar = Builder.model(root, "ArchiveRoom")
	roomShell(ar, origin * CFrame.new(18, 0, -32), 24, 22, { S = DOOR }, Enum.Material.WoodPlanks, P.WoodDark, "Shell")
	Builder.fluorLamp(ar, origin * CFrame.new(18, H - 0.35, -32), 6, "LightsMain", P.LightWarmOld, 0.9, true)
	Props.radioStation(ar, origin * CFrame.new(10, 0, -41.5), "Radio").Name = "LobbyRadioStation"
	Props.chair(ar, origin * CFrame.new(10, 0, -38))
	for i = 1, 2 do
		local term = Props.monitor(ar, origin * CFrame.new(22 + (i - 1) * 4, 2.75, -41.5), "АРХИВ СМЕН\nТЕРМИНАЛ " .. i, Color3.fromRGB(60, 90, 80))
		local tp = Builder.prompt(term.PrimaryPart, "Открыть архив", "Архив экспедиций", 0, Enum.KeyCode.E, 8)
		tp:SetAttribute("UI", "Archive")
		table.insert(anchors.archiveTerminals, term.PrimaryPart)
	end
	Props.table(ar, origin * CFrame.new(24, 0, -41.5), 9, 2.6, P.WoodDark)
	Props.shelf(ar, origin * CFrame.new(7, 0, -28) * CFrame.Angles(0, math.pi / 2, 0), 8, 4)
	for i = 0, 7 do
		Props.book(ar, origin * CFrame.new(7, 1.3 + math.floor(i / 4) * 1.7, -31 + (i % 4) * 1.2), if i % 3 == 0 then P.Red else P.OldGreenDark)
	end
	for i = 0, 3 do
		Props.photoFrame(ar, origin * CFrame.new(14 + i * 2.2, 7, -22.6), if i == 0 then "1998" elseif i == 1 then "2005" elseif i == 2 then "2014" else "2021")
	end
	Props.cableDrum(ar, origin * CFrame.new(27, 0, -26))

	-- ===== Exit airlock (south) and the apron outside =====================
	local ex = Builder.model(root, "ExitAirlock")
	roomShell(ex, origin * CFrame.new(0, 0, 27), 14, 14, { N = { width = 7, height = 8.5 }, S = { width = 7, height = 8.5 } }, Enum.Material.DiamondPlate, P.Graphite, "Shell")
	Builder.cageLamp(ex, origin * CFrame.new(0, H - 0.8, 27), "LightsMain", P.LightEmergencyWarm, 0.9, 16)
	Props.coatRack(ex, origin * CFrame.new(-6.3, 0, 27) * CFrame.Angles(0, math.pi / 2, 0), 3)
	Props.bench(ex, origin * CFrame.new(6, 0, 27) * CFrame.Angles(0, math.pi / 2, 0), 6)
	local airlock = Builder.door(ex, origin * CFrame.new(0, 0, 34), 7, 8.5, { heavy = true, name = "Door_ExitAirlock", label = "ВЫХОД НА ПЛОЩАДКУ", locked = true })
	anchors.airlockDoor = airlock
	Builder.fxAnchor(ex, "AirlockSnow", origin * CFrame.new(0, 4, 32), "SnowIn", Vector3.new(6, 6, 2))
	-- Outside: snow, drifts, floodlights, the plane parked far on the apron.
	local out = Builder.model(root, "Outside")
	local snow = Builder.part({ name = "Snow", size = Vector3.new(420, 8, 420), cframe = origin * CFrame.new(0, -4, 30), material = Enum.Material.Snow, color = P.Snow, parent = out })
	snow:SetAttribute("Floor", "snow")
	for _, d in { { -90, -60, 40, 6, 30 }, { 100, 90, 36, 5, 28 }, { -70, 120, 30, 5, 26 }, { 120, -90, 44, 7, 34 }, { 0, -120, 50, 6, 36 } } do
		Props.snowDrift(out, origin:PointToWorldSpace(Vector3.new(d[1], 0, d[2])), Vector3.new(d[3], d[4], d[5]))
	end
	Builder.part({ name = "Hull", size = Vector3.new(126, H + 2.4, 1), cframe = origin * CFrame.new(0, (H + 2.4) / 2, 20.9), material = Enum.Material.Metal, color = P.StationOrange, parent = out, transparency = 1, canCollide = false })
	Builder.floodlight(out, origin:PointToWorldSpace(Vector3.new(-20, 0, 50)), 14, origin:PointToWorldSpace(Vector3.new(0, 2, 60)), "Floodlights")
	Builder.floodlight(out, origin:PointToWorldSpace(Vector3.new(20, 0, 50)), 14, origin:PointToWorldSpace(Vector3.new(0, 2, 60)), "Floodlights")
	Airfield.buildPlane(out, origin * CFrame.new(0, 0, 95) * CFrame.Angles(0, math.pi / 2, 0), false)
	Props.guideRope(out, origin:PointToWorldSpace(Vector3.new(0, 0, 36)), origin:PointToWorldSpace(Vector3.new(0, 0, 80)))
	Builder.fxAnchor(out, "SnowField", origin * CFrame.new(0, 20, 60), "SnowField", Vector3.new(400, 40, 400))
	local wind = Builder.sound(snow, Sounds.Wind, "Wind")
	wind:SetAttribute("AutoPlay", true)
	-- Spawn.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = origin * CFrame.new(-12, 0.1, 12)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root
	anchors.spawn = spawn
	local hum = Builder.sound(hall, Sounds.VentHum, "Vent")
	hum:SetAttribute("AutoPlay", true)
	local tick = Builder.sound(hall, Sounds.ClockTick, "ClockTick")
	tick:SetAttribute("AutoPlay", true)
	root.Parent = parent
	return anchors
end

return LobbyBuilder
