--!nonstrict
-- Diorama set for the prologue short "Станция Восток". Four stages stand in a
-- row along +X (exterior, drill shed, lab module, radio room); every stage
-- origin is its floor-level center with north = -Z. The set is built locally on
-- the viewer's client by CinematicController and headless by tests, so it only
-- uses Builder and plain instances — no Props (server-side) and no runtime APIs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local P = Builder.Palette

export type Set = {
	root: Model,
	origin: CFrame,
	stages: { [string]: CFrame },
	actors: { [string]: Instance },
}

local VostokStation = {}

VostokStation.StageSpacing = 160
VostokStation.StageOrder = { "Exterior", "Drill", "Lab", "Radio" }

local SNOW = Color3.fromRGB(226, 232, 240)
local ICE = Color3.fromRGB(150, 210, 240)
local ICE_GLOW = Color3.fromRGB(170, 236, 255)
local NIGHT = Color3.fromRGB(6, 8, 14)
local WINDOW_WARM = Color3.fromRGB(255, 196, 120)
local PARKA = Color3.fromRGB(222, 96, 32)
local SKIN = Color3.fromRGB(230, 190, 160)
local HULL = Color3.fromRGB(118, 140, 148)
local AURORA_COLORS = {
	Color3.fromRGB(80, 230, 160),
	Color3.fromRGB(60, 200, 200),
	Color3.fromRGB(110, 240, 140),
	Color3.fromRGB(140, 110, 230),
}

-- Cylinder parts have their axis along X; this stands one upright.
local function upright(parent: Instance, name: string, cf: CFrame, height: number, diameter: number, material: Enum.Material?, color: Color3?): Part
	return Builder.part({
		name = name,
		size = Vector3.new(height, diameter, diameter),
		cframe = cf * CFrame.Angles(0, 0, math.pi / 2),
		material = material,
		color = color,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
end

local function emitter(parent: BasePart, name: string, color: Color3, rate: number, size: number, lifetime: NumberRange, speed: NumberRange, accel: Vector3, dir: Enum.NormalId): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = lifetime
	e.Speed = speed
	e.SpreadAngle = Vector2.new(25, 25)
	e.Size = NumberSequence.new(size)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.8, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.25
	e.Acceleration = accel
	e.Drag = 0.4
	e.EmissionDirection = dir
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Enabled = false
	e.Parent = parent
	return e
end

local function snowEmitter(parent: Instance, name: string, cf: CFrame, size: Vector3, rate: number): ParticleEmitter
	local host = Builder.invisible(parent, name .. "Host", cf, size)
	return emitter(host, name, SNOW, rate, 0.32, NumberRange.new(5, 8), NumberRange.new(8, 14), Vector3.new(-8, -3, 0), Enum.NormalId.Bottom)
end

-- Blocky polar researcher. Facing -Z of `cf`; `sitting` folds the legs forward.
local function figure(parent: Instance, name: string, cf: CFrame, coat: Color3, sitting: boolean?): (Model, Part)
	local m = Builder.model(parent, name)
	local legY = if sitting then 1.0 else 1.0
	for _, x in { -0.5, 0.5 } do
		if sitting then
			Builder.box(m, "Thigh", cf * CFrame.new(x, 2.0, -0.9), Vector3.new(0.9, 0.8, 1.8), Enum.Material.Fabric, P.RubberFloor)
			Builder.box(m, "Shin", cf * CFrame.new(x, 1.0, -1.6), Vector3.new(0.9, 2.0, 0.8), Enum.Material.Fabric, P.RubberFloor)
		else
			Builder.box(m, "Leg", cf * CFrame.new(x, legY, 0), Vector3.new(0.9, 2.0, 0.9), Enum.Material.Fabric, P.RubberFloor)
		end
		Builder.box(m, "Boot", cf * CFrame.new(x, 0.25, if sitting then -1.8 else -0.1), Vector3.new(0.95, 0.5, 1.2), Enum.Material.SmoothPlastic, P.WarningBlack)
	end
	local torsoY = if sitting then 3.3 else 3.1
	Builder.box(m, "Torso", cf * CFrame.new(0, torsoY, 0), Vector3.new(2.1, 2.2, 1.1), Enum.Material.Fabric, coat)
	Builder.box(m, "Belt", cf * CFrame.new(0, torsoY - 1.0, 0), Vector3.new(2.15, 0.3, 1.15), Enum.Material.SmoothPlastic, P.WarningBlack)
	for _, x in { -1.4, 1.4 } do
		Builder.box(m, "Arm", cf * CFrame.new(x, torsoY - 0.2, -0.6) * CFrame.Angles(-0.9, 0, 0), Vector3.new(0.7, 2.0, 0.7), Enum.Material.Fabric, coat)
		Builder.box(m, "Glove", cf * CFrame.new(x, torsoY - 0.9, -1.45), Vector3.new(0.7, 0.6, 0.7), Enum.Material.Fabric, P.WarningBlack)
	end
	local headY = torsoY + 1.8
	local head = Builder.part({ name = "Head", size = Vector3.new(1.3, 1.3, 1.3), cframe = cf * CFrame.new(0, headY, 0), material = Enum.Material.SmoothPlastic, color = SKIN, shape = Enum.PartType.Ball, parent = m })
	Builder.box(head, "Hood", cf * CFrame.new(0, headY + 0.1, 0.45), Vector3.new(1.8, 1.7, 1.0), Enum.Material.Fabric, coat)
	Builder.box(head, "Goggles", cf * CFrame.new(0, headY + 0.25, -0.55), Vector3.new(1.3, 0.4, 0.35), Enum.Material.SmoothPlastic, P.WarningBlack)
	Builder.box(head, "Beard", cf * CFrame.new(0, headY - 0.45, -0.5), Vector3.new(0.9, 0.5, 0.4), Enum.Material.Fabric, Color3.fromRGB(96, 70, 50))
	m.PrimaryPart = head
	return m, head
end

------------------------------------------------------------------------------
local function exterior(root: Model, cf: CFrame, actors: { [string]: Instance })
	local m = Builder.model(root, "Exterior")
	Builder.part({ name = "Snowfield", size = Vector3.new(240, 2, 240), cframe = cf * CFrame.new(0, -1, 0), material = Enum.Material.Snow, color = SNOW, parent = m })
	for _, d in { { -30, 20, 18, 9, 1.6, 0.3 }, { 24, -14, 14, 8, 1.2, -0.5 }, { 10, 30, 22, 10, 2.0, 0.8 }, { -18, -34, 16, 7, 1.4, 0.2 }, { 40, 18, 12, 6, 1.0, 1.1 }, { -44, -6, 20, 9, 1.8, -0.9 } } do
		Builder.part({ name = "Drift", size = Vector3.new(d[3], d[5], d[4]), cframe = cf * CFrame.new(d[1], d[5] / 2 - 0.4, d[2]) * CFrame.Angles(0, d[6], 0), material = Enum.Material.Snow, color = SNOW, parent = m, canCollide = false })
	end

	-- Main living module on stilts, entrance facing south (+Z)
	local building = Builder.model(m, "MainModule")
	for _, x in { -13, 0, 13 } do
		for _, z in { -5, 5 } do
			Builder.box(building, "Stilt", cf * CFrame.new(x, 1.5, z), Vector3.new(1, 3, 1), Enum.Material.Metal, P.SteelPainted)
		end
	end
	Builder.box(building, "Hull", cf * CFrame.new(0, 6.5, 0), Vector3.new(30, 7, 12), Enum.Material.Metal, HULL)
	Builder.part({ name = "Roof", size = Vector3.new(31, 0.7, 13), cframe = cf * CFrame.new(0, 10.35, 0), material = Enum.Material.Snow, color = SNOW, parent = building })
	local windows = Builder.folder(building, "Windows")
	for _, x in { -12, -7, 7, 12 } do
		local w = Builder.part({ name = "Window", size = Vector3.new(2.2, 1.6, 0.2), cframe = cf * CFrame.new(x, 7.2, 6.1), material = Enum.Material.Neon, color = WINDOW_WARM, parent = windows, castShadow = false })
		Builder.pointLight(w, WINDOW_WARM, 16, 0.7)
	end
	actors.Windows = windows
	Builder.box(building, "Door", cf * CFrame.new(0, 5.5, 6.1), Vector3.new(3, 5, 0.3), Enum.Material.Metal, P.SteelPainted)
	Builder.box(building, "Porch", cf * CFrame.new(0, 3, 8), Vector3.new(6, 0.4, 4), Enum.Material.DiamondPlate, P.Galvanized)
	for i = 1, 4 do
		Builder.box(building, "Step", cf * CFrame.new(0, 3 - i * 0.7, 10 + i * 0.8), Vector3.new(4, 0.3, 0.9), Enum.Material.DiamondPlate, P.Galvanized)
	end
	Builder.box(building, "Rail", cf * CFrame.new(3.1, 4.2, 9), Vector3.new(0.2, 2, 6), Enum.Material.Metal, P.SteelPaintedLight)
	Builder.signPlate(building, cf * CFrame.new(0, 9.3, 6.3) * CFrame.Angles(0, math.pi, 0), 12, 1.8, "СТАНЦИЯ ВОСТОК", Color3.fromRGB(150, 30, 30), P.PanelWhite, 48)
	Builder.signPlate(building, cf * CFrame.new(0, 8.2, 6.3) * CFrame.Angles(0, math.pi, 0), 12, 0.9, "3488 м над уровнем моря · −89,2 °C", P.WarningBlack, P.PanelWhite, 22)

	-- Diesel power station with a smoking stack
	local des = Builder.model(m, "DieselStation")
	Builder.box(des, "Hull", cf * CFrame.new(-30, 3, -10), Vector3.new(12, 6, 8), Enum.Material.Metal, HULL:Lerp(P.WarningBlack, 0.3))
	Builder.part({ name = "Roof", size = Vector3.new(13, 0.6, 9), cframe = cf * CFrame.new(-30, 6.3, -10), material = Enum.Material.Snow, color = SNOW, parent = des })
	for _, x in { -33, -27 } do
		Builder.part({ name = "Window", size = Vector3.new(1.6, 1.2, 0.2), cframe = cf * CFrame.new(x, 3.6, -5.9), material = Enum.Material.Neon, color = WINDOW_WARM, parent = des, castShadow = false })
	end
	upright(des, "Stack", cf * CFrame.new(-33, 10, -12), 12, 1.2, Enum.Material.Metal, P.WarningBlack)
	local smokeHost = Builder.invisible(des, "SmokeHost", cf * CFrame.new(-33, 16.2, -12), Vector3.new(1, 1, 1))
	local smoke = emitter(smokeHost, "Smoke", Color3.fromRGB(90, 92, 96), 7, 2.4, NumberRange.new(4, 6), NumberRange.new(2, 4), Vector3.new(-3, 1.2, 0), Enum.NormalId.Top)
	smoke.Enabled = true
	actors.Smoke = smoke

	-- Radio mast with a blinking top light and guy wires
	local mast = Builder.model(m, "Mast")
	upright(mast, "Pole", cf * CFrame.new(28, 18, -18), 36, 0.8, Enum.Material.Metal, P.Galvanized)
	local top = cf:PointToWorldSpace(Vector3.new(28, 36, -18))
	for _, a in { Vector3.new(44, 0, -26), Vector3.new(14, 0, -32), Vector3.new(30, 0, -2) } do
		Builder.beam(mast, top, cf:PointToWorldSpace(a), 0.12, 0.12, P.Cable)
	end
	local mastLight = Builder.part({ name = "MastLight", size = Vector3.new(0.8, 0.8, 0.8), cframe = cf * CFrame.new(28, 36.6, -18), material = Enum.Material.Neon, color = P.LightEmergency, shape = Enum.PartType.Ball, parent = mast, castShadow = false })
	Builder.pointLight(mastLight, P.LightEmergency, 22, 1)
	actors.MastLight = mastLight

	-- Flag by the entrance
	upright(m, "FlagPole", cf * CFrame.new(12, 6, 12), 12, 0.3, Enum.Material.Metal, P.Galvanized)
	local flag = Builder.part({ name = "Flag", size = Vector3.new(3, 1.8, 0.1), cframe = cf * CFrame.new(13.7, 11, 12), material = Enum.Material.Fabric, color = P.Red, parent = m, canCollide = false })
	actors.Flag = flag

	-- Tracked snow vehicle ("Харьковчанка") parked by the module, nose to -X
	local tractor = Builder.model(m, "Tractor")
	local tcf = cf * CFrame.new(-16, 0, 17)
	for _, z in { -2.6, 2.6 } do
		Builder.box(tractor, "Track", tcf * CFrame.new(0, 1.2, z), Vector3.new(12, 2.4, 1.8), Enum.Material.SmoothPlastic, P.WarningBlack)
	end
	Builder.box(tractor, "Body", tcf * CFrame.new(0, 4, 0), Vector3.new(11, 3.2, 6), Enum.Material.Metal, Color3.fromRGB(212, 96, 28))
	Builder.box(tractor, "Cabin", tcf * CFrame.new(-2.5, 7, 0), Vector3.new(5, 2.8, 5.6), Enum.Material.Metal, Color3.fromRGB(212, 96, 28))
	Builder.part({ name = "CabinGlass", size = Vector3.new(0.2, 1.6, 4.8), cframe = tcf * CFrame.new(-5.05, 7.3, 0), material = Enum.Material.Glass, color = Color3.fromRGB(40, 60, 90), transparency = 0.3, parent = tractor })
	Builder.part({ name = "SnowCap", size = Vector3.new(5.2, 0.5, 5.8), cframe = tcf * CFrame.new(-2.5, 8.6, 0), material = Enum.Material.Snow, color = SNOW, parent = tractor })
	upright(tractor, "Exhaust", tcf * CFrame.new(2.5, 7.2, -2), 3, 0.5, Enum.Material.Metal, P.WarningBlack)
	local headlights = Builder.folder(tractor, "Headlights")
	for _, z in { -1.8, 1.8 } do
		Builder.part({ name = "Headlight", size = Vector3.new(0.2, 0.6, 0.6), cframe = tcf * CFrame.new(-5.6, 4.5, z), material = Enum.Material.Neon, color = Color3.fromRGB(255, 236, 170), parent = headlights, castShadow = false })
	end
	local beam = Builder.invisible(headlights, "Beam", tcf * CFrame.new(-7, 4.5, 0), Vector3.new(1, 1, 1))
	Builder.pointLight(beam, Color3.fromRGB(255, 236, 170), 20, 1)
	actors.Headlights = headlights

	-- Drill tower silhouette in the distance
	local tower = Builder.model(m, "DrillTower")
	local towerCF = cf * CFrame.new(45, 0, -40)
	for _, x in { -2.5, 2.5 } do
		for _, z in { -2.5, 2.5 } do
			Builder.box(tower, "Leg", towerCF * CFrame.new(x, 15, z), Vector3.new(0.6, 30, 0.6), Enum.Material.Metal, P.SteelPainted)
		end
	end
	for _, y in { 6, 14, 22, 29 } do
		Builder.box(tower, "Ring", towerCF * CFrame.new(0, y, -2.5), Vector3.new(5.6, 0.4, 0.4), Enum.Material.Metal, P.SteelPainted)
		Builder.box(tower, "Ring", towerCF * CFrame.new(0, y, 2.5), Vector3.new(5.6, 0.4, 0.4), Enum.Material.Metal, P.SteelPainted)
		Builder.box(tower, "Ring", towerCF * CFrame.new(-2.5, y, 0), Vector3.new(0.4, 0.4, 5.6), Enum.Material.Metal, P.SteelPainted)
		Builder.box(tower, "Ring", towerCF * CFrame.new(2.5, y, 0), Vector3.new(0.4, 0.4, 5.6), Enum.Material.Metal, P.SteelPainted)
	end
	Builder.box(tower, "Shed", towerCF * CFrame.new(0, 2.5, 7), Vector3.new(10, 5, 8), Enum.Material.Metal, HULL:Lerp(P.WarningBlack, 0.4))
	Builder.part({ name = "ShedWindow", size = Vector3.new(0.2, 1.2, 2.4), cframe = towerCF * CFrame.new(-5.1, 3, 7), material = Enum.Material.Neon, color = P.LightCold, parent = tower, castShadow = false })
	local towerLamp = Builder.part({ name = "TowerLamp", size = Vector3.new(1, 0.6, 1), cframe = towerCF * CFrame.new(0, 30.5, 0), material = Enum.Material.Neon, color = P.LightCold, parent = tower, castShadow = false })
	Builder.pointLight(towerLamp, P.LightCold, 34, 1.2)
	actors.TowerLamp = towerLamp

	-- Lamp post at the entrance path
	upright(m, "LampPole", cf * CFrame.new(8, 4, 20), 8, 0.4, Enum.Material.Metal, P.Galvanized)
	Builder.box(m, "LampHead", cf * CFrame.new(8, 8.2, 20), Vector3.new(1.8, 0.5, 0.9), Enum.Material.Metal, P.SteelPainted)
	local lampPost = Builder.part({ name = "LampPost", size = Vector3.new(1.4, 0.15, 0.6), cframe = cf * CFrame.new(8, 7.9, 20), material = Enum.Material.Neon, color = P.LightCold, parent = m, castShadow = false })
	Builder.pointLight(lampPost, P.LightCold, 28, 1.3)
	actors.LampPost = lampPost

	-- Aurora bands far to the north
	local aurora = Builder.folder(m, "Aurora")
	for i, color in AURORA_COLORS do
		Builder.part({
			name = "Band",
			size = Vector3.new(90, 16, 0.2),
			cframe = cf * CFrame.new(-30 + i * 18, 56 + i * 7, -120) * CFrame.Angles(0.2, 0.12 * i, 0),
			material = Enum.Material.Neon,
			color = color,
			transparency = 0.78,
			parent = aurora,
			canCollide = false,
			castShadow = false,
		})
	end
	actors.Aurora = aurora

	actors.SnowExterior = snowEmitter(m, "SnowExterior", cf * CFrame.new(0, 36, 0), Vector3.new(140, 1, 140), 360)
end

------------------------------------------------------------------------------
local function drillShed(root: Model, cf: CFrame, actors: { [string]: Instance })
	local m = Builder.model(root, "Drill")
	Builder.shell(m, cf, 30, 30, 16, {
		doors = { S = { width = 6, height = 8 } },
		wallMaterial = Enum.Material.CorrodedMetal,
		wallColor = Color3.fromRGB(84, 90, 96),
		floorMaterial = Enum.Material.Metal,
		floorColor = Color3.fromRGB(58, 62, 68),
		ceilingColor = Color3.fromRGB(50, 54, 58),
		thickness = 1,
	})
	-- Derrick over the borehole
	local derrick = Builder.model(m, "Derrick")
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			Builder.box(derrick, "Leg", cf * CFrame.new(x, 6.5, z), Vector3.new(0.7, 13, 0.7), Enum.Material.Metal, P.Orange)
		end
	end
	for _, y in { 4, 8, 12 } do
		for _, s in { -3, 3 } do
			Builder.box(derrick, "Brace", cf * CFrame.new(0, y, s), Vector3.new(6.7, 0.4, 0.4), Enum.Material.Metal, P.Orange)
			Builder.box(derrick, "Brace", cf * CFrame.new(s, y, 0), Vector3.new(0.4, 0.4, 6.7), Enum.Material.Metal, P.Orange)
		end
	end
	-- Crown wheel: rim + hub + spokes rotate together (axis X)
	local wheel = Builder.model(derrick, "DrillWheel")
	local wcf = cf * CFrame.new(0, 13.5, 0)
	local rim = Builder.part({ name = "Rim", size = Vector3.new(0.8, 4, 4), cframe = wcf, material = Enum.Material.DiamondPlate, color = P.Galvanized, shape = Enum.PartType.Cylinder, parent = wheel })
	Builder.part({ name = "Hub", size = Vector3.new(1.2, 1.4, 1.4), cframe = wcf, material = Enum.Material.Metal, color = P.WarningBlack, shape = Enum.PartType.Cylinder, parent = wheel })
	for i = 0, 3 do
		Builder.box(wheel, "Spoke", wcf * CFrame.Angles(i * math.pi / 4, 0, 0), Vector3.new(0.3, 3.6, 0.3), Enum.Material.Metal, P.WarningBlack)
	end
	wheel.PrimaryPart = rim
	actors.DrillWheel = wheel
	local cable = Builder.box(derrick, "Cable", cf * CFrame.new(0, 6.75, 0), Vector3.new(0.25, 13, 0.25), Enum.Material.Metal, P.Cable)
	actors.Cable = cable
	upright(m, "Collar", cf * CFrame.new(0, 0.2, 0), 0.4, 4.2, Enum.Material.Metal, P.Galvanized)
	upright(m, "Borehole", cf * CFrame.new(0, 0.45, 0), 0.2, 3.2, Enum.Material.Slate, NIGHT)
	for i = 0, 3 do
		Builder.hazardStripes(m, cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.03, 4.2), 10, 0.6)
	end
	-- Winch and drive
	local winch = Builder.model(m, "Winch")
	Builder.part({ name = "Drum", size = Vector3.new(3, 2.2, 2.2), cframe = cf * CFrame.new(-8, 1.5, 3), material = Enum.Material.Metal, color = P.SteelPainted, shape = Enum.PartType.Cylinder, parent = winch })
	for _, x in { -9.8, -6.2 } do
		Builder.box(winch, "Frame", cf * CFrame.new(x, 1.2, 3), Vector3.new(0.4, 2.4, 2.6), Enum.Material.Metal, P.Orange)
	end
	Builder.box(winch, "Motor", cf * CFrame.new(-8, 1, 5.5), Vector3.new(2.2, 2, 1.8), Enum.Material.Metal, P.WarningBlack)
	Builder.cableTray(m, cf:PointToWorldSpace(Vector3.new(-8, 0.1, 6.5)), cf:PointToWorldSpace(Vector3.new(10, 0.1, -7.5)), 0.6)
	-- Control cabinet with the depth counter
	Builder.box(m, "Cabinet", cf * CFrame.new(10, 2.5, -8), Vector3.new(3, 5, 1), Enum.Material.Metal, P.SteelPainted)
	for i, c in { P.Green, P.Orange, P.Green } do
		Builder.part({ name = "Gauge", size = Vector3.new(0.3, 0.3, 0.1), cframe = cf * CFrame.new(9.2 + (i - 1) * 0.8, 3.5, -7.45), material = Enum.Material.Neon, color = c, parent = m, castShadow = false })
	end
	local depthScreen = Builder.part({ name = "DepthScreen", size = Vector3.new(4.4, 2.2, 0.3), cframe = cf * CFrame.new(10, 6.2, -8) * CFrame.Angles(0, math.pi, 0), material = Enum.Material.Neon, color = Color3.fromRGB(10, 16, 22), parent = m, castShadow = false })
	Builder.pointLight(depthScreen, P.Terminal or P.ScreenBlue, 8, 0.4)
	actors.DepthScreen = Builder.label(depthScreen, Enum.NormalId.Front, "ГЛУБИНА\n3 623 м", { textColor = Color3.fromRGB(120, 230, 170), textSize = 34, font = Enum.Font.Code, pixelsPerStud = 32 })
	-- Ice core rack along the east wall
	local rack = Builder.model(m, "CoreRack")
	for _, y in { 1.5, 3.5, 5.5 } do
		Builder.box(rack, "Shelf", cf * CFrame.new(12.5, y, 4), Vector3.new(3.4, 0.2, 8), Enum.Material.Metal, P.SteelPaintedLight)
		for z = 1, 7, 2 do
			Builder.part({ name = "Core", size = Vector3.new(3, 0.6, 0.6), cframe = cf * CFrame.new(12.5, y + 0.4, z), material = Enum.Material.Glass, color = ICE, transparency = 0.35, shape = Enum.PartType.Cylinder, parent = rack })
		end
	end
	Builder.box(rack, "Post", cf * CFrame.new(11, 3, 0), Vector3.new(0.3, 6, 0.3), Enum.Material.Metal, P.SteelPaintedLight)
	Builder.box(rack, "Post", cf * CFrame.new(11, 3, 8), Vector3.new(0.3, 6, 0.3), Enum.Material.Metal, P.SteelPaintedLight)
	Builder.pipeRun(m, { cf:PointToWorldSpace(Vector3.new(-14, 11, -14)), cf:PointToWorldSpace(Vector3.new(14, 11, -14)), cf:PointToWorldSpace(Vector3.new(14, 11, 10)) }, 0.35, P.Galvanized)
	Builder.signPlate(m, cf * CFrame.new(-8, 7, -14.3) * CFrame.Angles(0, math.pi, 0), 9, 1.4, "СКВАЖИНА 5Г · ОПАСНАЯ ЗОНА", P.Yellow, P.WarningBlack, 34)
	for _, d in { { -11, -10, 2.5 }, { -12, -6, 2 }, { 8, 10, 3 } } do
		Builder.box(m, "Crate", cf * CFrame.new(d[1], d[3] / 2, d[2]), Vector3.new(d[3], d[3], d[3]), Enum.Material.Wood, Color3.fromRGB(120, 96, 64))
	end
	local lamps = Builder.folder(m, "DrillLamps")
	for _, x in { -7, 7 } do
		Builder.ceilingLamp(lamps, cf * CFrame.new(x, 15.6, 0), Vector3.new(5, 0.2, 1), P.LightCold, 28, 0.7)
	end
	actors.DrillLamps = lamps
end

------------------------------------------------------------------------------
local function labModule(root: Model, cf: CFrame, actors: { [string]: Instance })
	local m = Builder.model(root, "Lab")
	Builder.shell(m, cf, 24, 20, 11, {
		wallMaterial = Enum.Material.SmoothPlastic,
		wallColor = P.PanelBeige,
		floorMaterial = Enum.Material.SmoothPlastic,
		floorColor = P.RubberFloor,
		ceilingColor = P.PanelWhite,
		thickness = 1,
	})
	Builder.box(m, "TableTop", cf * CFrame.new(0, 3, 0), Vector3.new(10, 0.3, 4), Enum.Material.SmoothPlastic, P.LabWhite)
	for _, x in { -4.7, 4.7 } do
		Builder.box(m, "TableLeg", cf * CFrame.new(x, 1.45, 0), Vector3.new(0.3, 2.9, 3.6), Enum.Material.Metal, P.SteelPaintedLight)
	end
	-- The sample: a glowing ice core in a cradle
	local core = Builder.model(m, "Core")
	for _, x in { -1.6, 1.6 } do
		Builder.box(core, "Cradle", cf * CFrame.new(x, 3.3, 0), Vector3.new(0.4, 0.3, 1.4), Enum.Material.Metal, P.SteelPainted)
	end
	Builder.part({ name = "Shell", size = Vector3.new(4.4, 0.9, 0.9), cframe = cf * CFrame.new(0, 3.75, 0), material = Enum.Material.Glass, color = ICE, transparency = 0.25, shape = Enum.PartType.Cylinder, parent = core })
	local glow = Builder.part({ name = "Glow", size = Vector3.new(4, 0.5, 0.5), cframe = cf * CFrame.new(0, 3.75, 0), material = Enum.Material.Neon, color = ICE_GLOW, transparency = 0.5, shape = Enum.PartType.Cylinder, parent = core, castShadow = false })
	Builder.pointLight(glow, ICE_GLOW, 12, 0.5)
	core.PrimaryPart = glow
	actors.Core = core
	-- Bench clutter: microscope, notebook, mug
	Builder.box(m, "ScopeBase", cf * CFrame.new(3.4, 3.3, 0.6), Vector3.new(1.2, 0.3, 1.4), Enum.Material.Metal, P.WarningBlack)
	Builder.box(m, "ScopeArm", cf * CFrame.new(3.8, 4.1, 1.0), Vector3.new(0.3, 1.4, 0.3), Enum.Material.Metal, P.WarningBlack)
	Builder.part({ name = "ScopeTube", size = Vector3.new(1.6, 0.45, 0.45), cframe = cf * CFrame.new(3.4, 4.6, 0.6) * CFrame.Angles(0, 0, math.pi / 2 - 0.5), material = Enum.Material.Metal, color = P.SteelPaintedLight, shape = Enum.PartType.Cylinder, parent = m })
	Builder.box(m, "Notebook", cf * CFrame.new(-3.4, 3.2, 1.0), Vector3.new(1.3, 0.1, 1.7), Enum.Material.SmoothPlastic, P.PanelWhite)
	upright(m, "Mug", cf * CFrame.new(-3.6, 3.5, -1.2), 0.7, 0.7, Enum.Material.SmoothPlastic, P.Blue)
	-- Researcher leaning over the bench
	local _, head = figure(m, "Scientist", cf * CFrame.new(0, 0, 3.4), PARKA)
	actors.ScientistHead = head
	-- Shelf with jars, heater, storage poster, window into the night
	Builder.box(m, "Shelf", cf * CFrame.new(-8, 6, -9.3), Vector3.new(6, 0.2, 1.2), Enum.Material.Metal, P.SteelPaintedLight)
	for i = 0, 3 do
		upright(m, "Jar", cf * CFrame.new(-10 + i * 1.4, 6.6, -9.3), 1, 0.7, Enum.Material.Glass, P.GlassTint)
	end
	Builder.box(m, "Heater", cf * CFrame.new(9, 1.2, -9.2), Vector3.new(4, 2.4, 1), Enum.Material.Metal, P.PanelWhite)
	local coil = Builder.part({ name = "Coil", size = Vector3.new(3.4, 0.3, 0.1), cframe = cf * CFrame.new(9, 1.4, -8.65), material = Enum.Material.Neon, color = P.Orange, parent = m, castShadow = false })
	Builder.pointLight(coil, P.Orange, 8, 0.4)
	Builder.signPlate(m, cf * CFrame.new(3, 7, -9.3) * CFrame.Angles(0, math.pi, 0), 7, 2.4, "ПРОТОКОЛ ХРАНЕНИЯ КЕРНА\n−20 °C · НЕ ВСКРЫВАТЬ", P.PanelWhite, P.WarningBlack, 24)
	Builder.part({ name = "Window", size = Vector3.new(0.2, 2.4, 6), cframe = cf * CFrame.new(11.8, 6, 0), material = Enum.Material.Glass, color = NIGHT, transparency = 0.1, parent = m })
	local lamps = Builder.folder(m, "LabLamps")
	for _, x in { -5, 5 } do
		Builder.ceilingLamp(lamps, cf * CFrame.new(x, 10.6, 0), Vector3.new(4, 0.2, 1), P.LightWarm, 22, 0.7)
	end
	actors.LabLamps = lamps
	actors.LabEmergency = Builder.emergencyLamp(m, cf * CFrame.new(-11.4, 9, 0) * CFrame.Angles(0, math.pi / 2, 0))
end

------------------------------------------------------------------------------
local function radioRoom(root: Model, cf: CFrame, actors: { [string]: Instance })
	local m = Builder.model(root, "Radio")
	Builder.shell(m, cf, 20, 20, 11, {
		doors = { N = { width = 5, height = 8 } },
		wallMaterial = Enum.Material.Metal,
		wallColor = HULL:Lerp(P.WarningBlack, 0.2),
		floorMaterial = Enum.Material.Wood,
		floorColor = Color3.fromRGB(96, 76, 52),
		ceilingColor = P.SteelPainted,
		thickness = 1,
	})
	-- Outside the north door: snow, darkness and the visitor's hiding spot
	Builder.part({ name = "SnowOutside", size = Vector3.new(16, 1, 14), cframe = cf * CFrame.new(0, -0.5, -17), material = Enum.Material.Snow, color = SNOW, parent = m })
	Builder.box(m, "NightBackdrop", cf * CFrame.new(0, 7, -24.5), Vector3.new(16, 14, 1), Enum.Material.SmoothPlastic, NIGHT)
	actors.SnowDoor = emitter(Builder.invisible(m, "SnowDoorHost", cf * CFrame.new(0, 7.5, -10.5), Vector3.new(5, 1, 1)), "SnowDoor", SNOW, 120, 0.28, NumberRange.new(2, 3), NumberRange.new(6, 10), Vector3.new(0, -6, 5), Enum.NormalId.Back)
	actors.VisitorDoor = Builder.invisible(m, "VisitorDoor", cf * CFrame.new(0, 4.5, -9.5), Vector3.new(1, 1, 1))
	-- Operator's desk along the east wall
	Builder.box(m, "DeskTop", cf * CFrame.new(8.3, 2.9, -2), Vector3.new(3, 0.3, 8), Enum.Material.Wood, Color3.fromRGB(120, 96, 64))
	for _, z in { -5.6, 1.6 } do
		Builder.box(m, "DeskLeg", cf * CFrame.new(8.3, 1.4, z), Vector3.new(2.8, 2.8, 0.3), Enum.Material.Wood, Color3.fromRGB(120, 96, 64))
	end
	Builder.box(m, "RadioSet", cf * CFrame.new(8.6, 3.85, -3.5), Vector3.new(2.2, 1.6, 3), Enum.Material.Metal, P.SteelPainted)
	for i, c in { P.Green, P.Orange, P.Green, P.LightEmergency } do
		Builder.part({ name = "Dial", size = Vector3.new(0.1, 0.3, 0.3), cframe = cf * CFrame.new(7.45, 3.9, -4.6 + (i - 1) * 0.7), material = Enum.Material.Neon, color = c, parent = m, castShadow = false })
	end
	local radioScreen = Builder.part({ name = "RadioScreen", size = Vector3.new(0.3, 2.6, 4), cframe = cf * CFrame.new(9.3, 5.6, -1), material = Enum.Material.Neon, color = Color3.fromRGB(10, 16, 22), parent = m, castShadow = false })
	Builder.pointLight(radioScreen, Color3.fromRGB(120, 220, 170), 10, 0.5)
	actors.RadioScreen = Builder.label(radioScreen, Enum.NormalId.Left, "", { textColor = Color3.fromRGB(120, 230, 170), textSize = 18, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 8, pixelsPerStud = 32 })
	local _, head = figure(m, "Operator", cf * CFrame.new(5.6, 0.1, -2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(70, 110, 140), true)
	Builder.box(head, "Headphones", head.CFrame * CFrame.new(0, 0.3, 0), Vector3.new(1.6, 0.35, 0.5), Enum.Material.SmoothPlastic, P.WarningBlack)
	actors.OperatorHead = head
	Builder.box(m, "ChairSeat", cf * CFrame.new(4.4, 1.9, -2), Vector3.new(1.8, 0.3, 1.8), Enum.Material.Fabric, P.RubberFloor)
	Builder.box(m, "ChairBack", cf * CFrame.new(3.6, 3.1, -2), Vector3.new(0.3, 2.4, 1.8), Enum.Material.Fabric, P.RubberFloor)
	-- Wall clock stopped at the last contact, bunk and a map of the ice sheet
	local clock = Builder.box(m, "Clock", cf * CFrame.new(-3, 7.5, 9.3), Vector3.new(2.2, 2.2, 0.2), Enum.Material.SmoothPlastic, P.PanelWhite)
	Builder.label(clock, Enum.NormalId.Front, "02:10", { textColor = P.WarningBlack, textSize = 30, font = Enum.Font.Code })
	Builder.box(m, "Bunk", cf * CFrame.new(-7, 1.2, 6), Vector3.new(4, 0.6, 7), Enum.Material.Fabric, Color3.fromRGB(70, 90, 70))
	Builder.box(m, "Pillow", cf * CFrame.new(-7, 1.7, 8.5), Vector3.new(2.4, 0.5, 1.6), Enum.Material.Fabric, P.PanelWhite)
	Builder.signPlate(m, cf * CFrame.new(-6, 6.5, -9.3) * CFrame.Angles(0, math.pi, 0), 7, 3.2, "ОЗЕРО ВОСТОК\n~3750 м подо льдом\n5Г ●", Color3.fromRGB(28, 32, 36), Color3.fromRGB(200, 220, 240), 26)
	local lamps = Builder.folder(m, "RadioLamps")
	Builder.ceilingLamp(lamps, cf * CFrame.new(0, 10.6, 0), Vector3.new(4, 0.2, 1), P.LightWarm, 22, 0.6)
	actors.RadioLamps = lamps
	actors.RadioEmergency = Builder.emergencyLamp(m, cf * CFrame.new(9.4, 9, 4) * CFrame.Angles(0, math.pi / 2, 0))

	-- The visitor: a tall dark figure waiting beyond the backdrop, facing +Z (into the room)
	local v = Builder.model(m, "Visitor")
	local vcf = cf * CFrame.new(0, 0, -32)
	local vroot = Builder.invisible(v, "Root", vcf * CFrame.new(0, 4.5, 0), Vector3.new(2, 9, 2))
	for _, x in { -0.6, 0.6 } do
		Builder.box(v, "Leg", vcf * CFrame.new(x, 1.7, 0), Vector3.new(0.9, 3.4, 0.9), Enum.Material.Slate, NIGHT)
	end
	Builder.box(v, "Torso", vcf * CFrame.new(0, 5.4, 0), Vector3.new(2.4, 4.2, 1.4), Enum.Material.Slate, NIGHT)
	Builder.box(v, "Shoulders", vcf * CFrame.new(0, 7.2, 0), Vector3.new(3.6, 0.8, 1.6), Enum.Material.Slate, NIGHT)
	for _, x in { -1.9, 1.9 } do
		Builder.box(v, "Arm", vcf * CFrame.new(x, 4.6, 0), Vector3.new(0.7, 4.8, 0.7), Enum.Material.Slate, NIGHT)
		Builder.box(v, "Claw", vcf * CFrame.new(x, 2.0, 0.2), Vector3.new(0.5, 1.0, 0.5), Enum.Material.Slate, NIGHT)
	end
	Builder.box(v, "Head", vcf * CFrame.new(0, 8.3, 0), Vector3.new(1.2, 1.4, 1.2), Enum.Material.Slate, NIGHT)
	local eye = Builder.part({ name = "Eye", size = Vector3.new(0.9, 0.12, 0.3), cframe = vcf * CFrame.new(0, 8.4, 0.62), material = Enum.Material.Neon, color = P.LightEmergency, parent = v, castShadow = false })
	Builder.pointLight(eye, P.LightEmergency, 12, 1.5)
	v.PrimaryPart = vroot
	actors.Visitor = v
	actors.VisitorEye = eye
end

------------------------------------------------------------------------------
function VostokStation.build(parent: Instance, origin: CFrame): Set
	local root = Builder.model(parent, "VostokStationSet")
	local stages: { [string]: CFrame } = {}
	local actors: { [string]: Instance } = {}
	local builders = { Exterior = exterior, Drill = drillShed, Lab = labModule, Radio = radioRoom }
	for i, name in VostokStation.StageOrder do
		local cf = origin * CFrame.new((i - 1) * VostokStation.StageSpacing, 0, 0)
		stages[name] = cf
		builders[name](root, cf, actors)
	end
	return { root = root, origin = origin, stages = stages, actors = actors }
end

return VostokStation
