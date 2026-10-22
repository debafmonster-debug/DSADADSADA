--!nonstrict
-- Authored layout of station «Восток-9». All coordinates are local to
-- GameConfig.World.StationOrigin (x east, z south, y up; snow surface at y=0).
-- Server builders, gameplay services and headless tests share this single
-- source of truth so nothing important is placed "by eye" in geometry code.
local Station = {}

Station.FloorY = 6 -- building floor height above the snow (buildings stand on piles)
Station.WallHeight = 11
Station.WallThickness = 1
Station.DoorWidth = 5
Station.DoorHeight = 8

-- Rooms: axis-aligned rectangles (x1 < x2, z1 < z2) at FloorY. `door` is the
-- corridor-side wall ("N" = -z, "S" = +z, "E" = +x, "W" = -x) and its position
-- along that wall; omitted doors are added by hand in the builder.
export type Room = {
	id: string,
	name: string,
	building: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	circuit: string?, -- lighting circuit
	heated: boolean?,
	door: { side: string, at: number? }?,
	lightColor: string?, -- Builder palette key for the fixtures
	lamps: number?, -- fixture count along the long axis
}

Station.Rooms = {
	-- ===== КОРПУС №1 (главный) : x -62..62, z -22..22
	{ id = "Airlock", name = "Входной шлюз", building = "Main", x1 = -62, z1 = -8, x2 = -50, z2 = 8, circuit = "LightsMain", heated = false, lightColor = "LightEmergencyWarm", lamps = 1 },
	{ id = "Corridor", name = "Коридор К-1", building = "Main", x1 = -50, z1 = -4.5, x2 = 62, z2 = 4.5, circuit = "LightsMain", heated = true, lightColor = "LightFluor", lamps = 7 },
	{ id = "Control", name = "Комната управления", building = "Main", x1 = -50, z1 = -22, x2 = -16, z2 = -4.5, circuit = "LightsMain", heated = true, door = { side = "S" }, lightColor = "LightFluor", lamps = 3 },
	{ id = "RadioRoom", name = "Радиорубка", building = "Main", x1 = -16, z1 = -22, x2 = 2, z2 = -4.5, circuit = "LightsMain", heated = true, door = { side = "S" }, lightColor = "LightWarmOld", lamps = 2 },
	{ id = "Electrical", name = "Электрощитовая", building = "Main", x1 = 2, z1 = -22, x2 = 18, z2 = -4.5, circuit = "LightsMain", heated = false, door = { side = "S" }, lightColor = "LightFluor", lamps = 1 },
	{ id = "Archive", name = "Архив и лаборатория", building = "Main", x1 = 18, z1 = -22, x2 = 48, z2 = -4.5, circuit = "Lab", heated = true, door = { side = "S" }, lightColor = "LightLab", lamps = 3 },
	{ id = "Kitchen", name = "Кают-компания", building = "Main", x1 = 48, z1 = -22, x2 = 62, z2 = -4.5, circuit = "LightsMain", heated = true, door = { side = "S" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "Medical", name = "Медицинская", building = "Main", x1 = -50, z1 = 4.5, x2 = -30, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightCold", lamps = 2 },
	{ id = "RestRoom", name = "Комната отдыха", building = "Main", x1 = -30, z1 = 4.5, x2 = -6, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 2 },
	{ id = "Storage", name = "Кладовая", building = "Main", x1 = -6, z1 = 4.5, x2 = 8, z2 = 22, circuit = "LightsMain", heated = false, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "CabinA", name = "Каюта 1", building = "Main", x1 = 8, z1 = 4.5, x2 = 22, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "CabinB", name = "Каюта 2", building = "Main", x1 = 22, z1 = 4.5, x2 = 36, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "Washroom", name = "Умывальная", building = "Main", x1 = 36, z1 = 4.5, x2 = 48, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightCold", lamps = 1 },
	{ id = "Boiler", name = "Котельная", building = "Main", x1 = 48, z1 = 4.5, x2 = 62, z2 = 22, circuit = "LightsMain", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
	-- ===== ПЕРЕХОД : x 62..92
	{ id = "Passage", name = "Переход", building = "Passage", x1 = 62, z1 = -5, x2 = 92, z2 = 5, circuit = "LightsDorm", heated = false, lightColor = "LightFluor", lamps = 3 },
	-- ===== КОРПУС №2 (спальный) : x 92..150, z -22..22
	{ id = "DormVestibule", name = "Тамбур К-2", building = "Dorm", x1 = 92, z1 = -6, x2 = 104, z2 = 6, circuit = "LightsDorm", heated = true, door = { side = "E" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "DormStore", name = "Бельевая", building = "Dorm", x1 = 92, z1 = -22, x2 = 104, z2 = -6, circuit = "LightsDorm", heated = false, door = { side = "S" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "Drying", name = "Сушилка", building = "Dorm", x1 = 92, z1 = 6, x2 = 104, z2 = 22, circuit = "LightsDorm", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
	{ id = "Dorm", name = "Спальный сектор", building = "Dorm", x1 = 104, z1 = -22, x2 = 150, z2 = 8, circuit = "LightsDorm", heated = true, lightColor = "LightWarmOld", lamps = 4 },
	{ id = "DormWash", name = "Умывальная К-2", building = "Dorm", x1 = 104, z1 = 8, x2 = 126, z2 = 22, circuit = "LightsDorm", heated = true, door = { side = "N" }, lightColor = "LightCold", lamps = 1 },
	{ id = "DormBoiler", name = "Тепловой узел К-2", building = "Dorm", x1 = 126, z1 = 8, x2 = 150, z2 = 22, circuit = "LightsDorm", heated = true, door = { side = "N" }, lightColor = "LightWarmOld", lamps = 1 },
}

Station.RoomById = {}
for _, r in Station.Rooms do
	Station.RoomById[r.id] = r
end

-- Buildings (outer shells).
Station.Buildings = {
	Main = { x1 = -62, z1 = -22, x2 = 62, z2 = 22, height = 11, color = "StationOrange" },
	Passage = { x1 = 62, z1 = -5, x2 = 92, z2 = 5, height = 10, color = "StationOrange" },
	Dorm = { x1 = 92, z1 = -22, x2 = 150, z2 = 22, height = 11, color = "StationOrange" },
}

-- Yard structures (ground level, y = 0).
Station.Yard = {
	GeneratorShed = { x1 = -29, z1 = 39, x2 = -11, z2 = 53, height = 9 },
	Warehouse = { x1 = 57, z1 = 39, x2 = 83, z2 = 49, height = 10 },
	Antenna = { x = -30, z = -70, height = 52 },
	MetStation = { x = -6, z = -66 },
	DrillGate = { x = 170, z = -120 },
	EvacApron = { x = -110, z = 60, radius = 26 },
	Floodlights = { { -84, 12 }, { 30, -46 }, { 74, 62 }, { 124, 42 }, { -46, 74 }, { -60, -40 } },
	GuideRopes = {
		{ from = { -74, 0 }, to = { -20, 38 } }, -- airlock stairs -> generator
		{ from = { -74, 0 }, to = { -30, -62 } }, -- airlock stairs -> antenna
		{ from = { 98, 32 }, to = { 60, 44 } }, -- dorm exit -> warehouse
		{ from = { -74, 0 }, to = { -100, 54 } }, -- airlock stairs -> evac apron
	},
	SnowSize = 760,
	SnowCenter = { 40, 10 },
}

-- Bunker (below the dorm). Floor y = -10.
Station.Bunker = {
	FloorY = -10,
	Height = 9,
	Shaft = { x = 127, z = 2, size = 4 }, -- hatch position in the dorm floor
	Antechamber = { x1 = 123, z1 = -2, x2 = 131, z2 = 6 },
	Room = { x1 = 103, z1 = -8, x2 = 123, z2 = 8 },
	DoorAt = { x = 123, z = 2 }, -- heavy door in the antechamber west wall
	LeverAt = { x = 121, z = -5 },
}

-- Named interaction points (local). Services look these up instead of
-- searching geometry by name.
Station.Points = {
	AirlockOuterDoor = Vector3.new(-62, 6, 0),
	AirlockInnerDoor = Vector3.new(-50, 6, 0),
	Scanner = Vector3.new(-50.6, 6, 4.2),
	ScannerOverride = Vector3.new(-49.4, 6, 4.2),
	ControlDesk = Vector3.new(-33, 6, -16),
	ControlBoard = Vector3.new(-33, 6, -21.4),
	Radio = Vector3.new(-7, 6, -19),
	BreakerPanel = Vector3.new(10, 6, -21.3),
	FuseBox = Vector3.new(16.5, 6, -14),
	SpareShelf = Vector3.new(1, 6, 20.5),
	MedCabinet = Vector3.new(-48.5, 6, 14),
	Generator = Vector3.new(-20, 0.5, 47),
	GeneratorPanel = Vector3.new(-14, 0.5, 47),
	GeneratorCover = Vector3.new(-20, 0.5, 43),
	GeneratorFuel = Vector3.new(-26, 0.5, 47),
	WarehouseDoor = Vector3.new(57, 1, 44),
	WarehouseLock = Vector3.new(56.6, 1, 47),
	AntennaPanel = Vector3.new(-30, 0, -64),
	DormDoor = Vector3.new(104, 6, 0),
	DormExitDoor = Vector3.new(98, 6, 22),
	PassageDoorMain = Vector3.new(62, 6, 0),
	PassageDoorDorm = Vector3.new(92, 6, 0),
	DormBoard = Vector3.new(127, 6, 7.4),
	DormClock = Vector3.new(146, 6, 7.4),
	Hatch = Vector3.new(127, 6, 2),
	DormCornerA = Vector3.new(106.5, 6, -19.5), -- north-west
	DormCornerB = Vector3.new(147.5, 6, 5.5), -- south-east
	BunkerDoor = Vector3.new(123, -10, 2),
	BunkerLever = Vector3.new(121, -10, -5),
	EvacZone = Vector3.new(-110, 0, 60),
	ArrivalSpawn = { Vector3.new(-96, 0, 52), Vector3.new(-100, 0, 56), Vector3.new(-96, 0, 60), Vector3.new(-100, 0, 64) },
	LostPoints = { Vector3.new(-170, 0, -40), Vector3.new(150, 0, 150), Vector3.new(-120, 0, 150), Vector3.new(210, 0, 30), Vector3.new(60, 0, -170) },
	GuestSpawns = { Vector3.new(150, 0, -110), Vector3.new(-140, 0, -90), Vector3.new(190, 0, 90), Vector3.new(-90, 0, 130) },
	Heaters = {
		{ pos = Vector3.new(-18, 6, 21), room = "RestRoom" },
		{ pos = Vector3.new(-33, 6, -21), room = "Control" },
		{ pos = Vector3.new(55, 6, 21), room = "Boiler" },
		{ pos = Vector3.new(138, 6, 21), room = "DormBoiler" },
		{ pos = Vector3.new(127, 6, -21), room = "Dorm" },
	},
}

-- Patrol graph for the Guest. Outdoor ring + indoor corridor nodes; the AI
-- only uses indoor nodes after escalation. Positions are feet-level.
Station.Patrol = {
	Outdoor = {
		Vector3.new(-90, 0, -20), Vector3.new(-70, 0, -60), Vector3.new(-20, 0, -90), Vector3.new(40, 0, -70),
		Vector3.new(90, 0, -50), Vector3.new(140, 0, -60), Vector3.new(170, 0, 0), Vector3.new(150, 0, 60),
		Vector3.new(100, 0, 70), Vector3.new(40, 0, 60), Vector3.new(0, 0, 70), Vector3.new(-50, 0, 60),
		Vector3.new(-80, 0, 30), Vector3.new(-40, 0, 36), Vector3.new(20, 0, 32), Vector3.new(70, 0, 30),
	},
	Indoor = {
		Vector3.new(-45, 6, 0), Vector3.new(-20, 6, 0), Vector3.new(5, 6, 0), Vector3.new(30, 6, 0), Vector3.new(55, 6, 0),
		Vector3.new(77, 6, 0), Vector3.new(98, 6, 0), Vector3.new(-33, 6, -13), Vector3.new(33, 6, -13), Vector3.new(-18, 6, 13),
	},
	Observe = { -- where the Guest stands to watch the buildings from the fog
		Vector3.new(-70, 0, -40), Vector3.new(30, 0, -44), Vector3.new(60, 0, 58), Vector3.new(130, 0, 46), Vector3.new(-60, 0, 50),
	},
}

-- Zones for temperature, night rule, noise occlusion and client FX.
export type Zone = { id: string, kind: "heated" | "indoor" | "shelter", sector: string, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number }
Station.Zones = {
	{ id = "Main", kind = "heated", sector = "Main", x1 = -62, y1 = 5, z1 = -22, x2 = 62, y2 = 18, z2 = 22 },
	{ id = "Passage", kind = "indoor", sector = "Passage", x1 = 62, y1 = 5, z1 = -5, x2 = 92, y2 = 17, z2 = 5 },
	{ id = "Dorm", kind = "heated", sector = "Dorm", x1 = 92, y1 = 5, z1 = -22, x2 = 150, y2 = 18, z2 = 22 },
	{ id = "Bunker", kind = "shelter", sector = "Dorm", x1 = 100, y1 = -12, z1 = -10, x2 = 133, y2 = 5, z2 = 10 },
	{ id = "GeneratorShed", kind = "shelter", sector = "Yard", x1 = -29, y1 = -1, z1 = 39, x2 = -11, y2 = 10, z2 = 53 },
	{ id = "Warehouse", kind = "shelter", sector = "Yard", x1 = 57, y1 = 0, z1 = 39, x2 = 83, y2 = 12, z2 = 49 },
}

Station.StationCenter = Vector3.new(40, 0, 0)

-- Night rule: after 22:00 players must stay within these zone ids.
Station.NightSafeZones = { Dorm = true, Bunker = true }

function Station.toWorld(origin: Vector3, v: Vector3): Vector3
	return origin + v
end

function Station.zoneAt(localPos: Vector3): Zone?
	for _, z in Station.Zones do
		if localPos.X >= z.x1 and localPos.X <= z.x2 and localPos.Y >= z.y1 and localPos.Y <= z.y2 and localPos.Z >= z.z1 and localPos.Z <= z.z2 then
			return z
		end
	end
	return nil
end

function Station.roomAt(localPos: Vector3): Room?
	local y = localPos.Y
	if y < Station.FloorY - 1 or y > Station.FloorY + Station.WallHeight + 1 then
		return nil
	end
	for _, r in Station.Rooms do
		if localPos.X >= r.x1 and localPos.X <= r.x2 and localPos.Z >= r.z1 and localPos.Z <= r.z2 then
			return r
		end
	end
	return nil
end

function Station.roomCenter(r: Room): Vector3
	return Vector3.new((r.x1 + r.x2) / 2, Station.FloorY, (r.z1 + r.z2) / 2)
end

return Station
