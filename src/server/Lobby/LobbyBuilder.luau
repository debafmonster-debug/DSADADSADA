--!nonstrict
-- Builds the lobby: a safe administrative/technical block of COMPLEX-17.
-- Returns anchors (interaction parts, spawn, zones) used by LobbyService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Props = require(script.Parent.Parent.MapModules.Props)
local P = Builder.Palette

export type Anchors = {
	root: Model,
	spawn: SpawnLocation,
	registration: BasePart,
	shiftBoard: BasePart,
	shiftBoardScreen: TextLabel,
	briefingScreen: TextLabel,
	briefingConsole: BasePart,
	archiveTerminals: { BasePart },
	lockers: { [string]: BasePart },
	safeZone: BasePart,
	readyBoard: TextLabel,
}

local LobbyBuilder = {}

local ATRIUM_W, ATRIUM_D, ATRIUM_H = 90, 70, 22
local SIDE_W, SIDE_D, SIDE_H = 36, 30, 12

local function wallSign(parent: Instance, cf: CFrame, w: number, h: number, text: string, bg: Color3, fg: Color3, size: number?)
	return Builder.signPlate(parent, cf, w, h, text, bg, fg, size)
end

local function atrium(root: Model, origin: CFrame): Folder
	local f = Builder.folder(root, "Atrium")
	Builder.shell(f, origin, ATRIUM_W, ATRIUM_D, ATRIUM_H, {
		floorColor = P.ConcreteFloor,
		floorMaterial = Enum.Material.Concrete,
		wallColor = Color3.fromRGB(128, 130, 132),
		ceilingColor = P.ConcreteDark,
		doors = {
			W = { width = 10, height = 10, offset = 0 },
			E = { width = 10, height = 10, offset = 0 },
			N = { width = 10, height = 10, offset = 30 }, -- archive
		},
		thickness = 1.5,
	})
	-- Upper mezzanine band (visual only) + steel structure
	local hw, hd = ATRIUM_W / 2, ATRIUM_D / 2
	for _, x in { -hw + 10, -hw + 30, hw - 30, hw - 10 } do
		for _, z in { -hd + 8, hd - 8 } do
			Builder.column(f, origin:PointToWorldSpace(Vector3.new(x, 0, z)), 2.4, ATRIUM_H, P.ConcreteDark)
		end
	end
	for i = 0, 4 do
		local z = -hd + 7 + i * (ATRIUM_D - 14) / 4
		Builder.beam(f, origin:PointToWorldSpace(Vector3.new(-hw, ATRIUM_H - 1.2, z)), origin:PointToWorldSpace(Vector3.new(hw, ATRIUM_H - 1.2, z)), 1.6, 2, P.SteelPainted)
	end
	for _, x in { -30, 0, 30 } do
		Builder.beam(f, origin:PointToWorldSpace(Vector3.new(x, ATRIUM_H - 3.4, -hd)), origin:PointToWorldSpace(Vector3.new(x, ATRIUM_H - 3.4, hd)), 1.2, 1.2, P.SteelPainted)
	end
	Builder.cableTray(f, origin:PointToWorldSpace(Vector3.new(-hw + 6, ATRIUM_H - 4.5, -hd)), origin:PointToWorldSpace(Vector3.new(-hw + 6, ATRIUM_H - 4.5, hd)), 2)
	Builder.cableTray(f, origin:PointToWorldSpace(Vector3.new(hw - 6, ATRIUM_H - 4.5, -hd)), origin:PointToWorldSpace(Vector3.new(hw - 6, ATRIUM_H - 4.5, hd)), 2)
	Builder.ventDuct(f, origin:PointToWorldSpace(Vector3.new(-hw, ATRIUM_H - 5.5, 20)), origin:PointToWorldSpace(Vector3.new(hw, ATRIUM_H - 5.5, 20)), 3.2)
	Builder.ventDuct(f, origin:PointToWorldSpace(Vector3.new(-hw, ATRIUM_H - 5.5, -20)), origin:PointToWorldSpace(Vector3.new(hw, ATRIUM_H - 5.5, -20)), 3.2)
	for _, x in { -36, -12, 12, 36 } do
		Builder.ventGrille(f, origin * CFrame.new(x, ATRIUM_H - 5.5, 21.7), 4, 2)
	end
	-- Lighting: cold white grid, two warm accents over the reception desk.
	local lights = Builder.folder(f, "Lights")
	for i = 0, 3 do
		for j = 0, 2 do
			local x = -hw + 11.25 + i * 22.5
			local z = -hd + 11.7 + j * 23.3
			Builder.ceilingLamp(lights, origin * CFrame.new(x, ATRIUM_H - 0.4, z), Vector3.new(8, 0.3, 1.6), P.LightCold, 36, 1.0, i == 1 and j == 1)
		end
	end
	for _, x in { -6, 6 } do
		Builder.ceilingLamp(lights, origin * CFrame.new(x, 11, 22), Vector3.new(3, 0.3, 1), P.LightWarm, 16, 0.9)
	end
	-- Floor safety markings: main walkway and zone outlines.
	Builder.hazardStripes(f, origin * CFrame.new(0, 0.03, -hd + 3), 14, 1)
	Builder.part({ name = "WalkLine", size = Vector3.new(0.5, 0.04, ATRIUM_D - 10), cframe = origin * CFrame.new(-8, 0.02, 0), material = Enum.Material.SmoothPlastic, color = P.Yellow, parent = f, canCollide = false })
	Builder.part({ name = "WalkLine", size = Vector3.new(0.5, 0.04, ATRIUM_D - 10), cframe = origin * CFrame.new(8, 0.02, 0), material = Enum.Material.SmoothPlastic, color = P.Yellow, parent = f, canCollide = false })
	Builder.part({ name = "ZoneLine", size = Vector3.new(ATRIUM_W - 20, 0.04, 0.5), cframe = origin * CFrame.new(0, 0.02, -hd + 14), material = Enum.Material.SmoothPlastic, color = P.PanelWhite, parent = f, canCollide = false })
	-- Signage
	local signs = Builder.folder(f, "Signs")
	wallSign(signs, origin * CFrame.new(0, 17, -hd + 0.9), 30, 4, "COMPLEX-17", P.WarningBlack, Color3.fromRGB(235, 235, 235), 110)
	wallSign(signs, origin * CFrame.new(0, 13.6, -hd + 0.9), 30, 1.6, "АДМИНИСТРАТИВНО-ТЕХНИЧЕСКИЙ БЛОК · SECURITY LEVEL 01", P.Blue, Color3.fromRGB(235, 235, 235), 36)
	wallSign(signs, origin * CFrame.new(-hw + 0.9, 12, 0) * CFrame.Angles(0, math.pi / 2, 0), 12, 1.8, "← КОМНАТА ЭКИПИРОВКИ", P.Yellow, P.WarningBlack, 38)
	wallSign(signs, origin * CFrame.new(hw - 0.9, 12, 0) * CFrame.Angles(0, -math.pi / 2, 0), 12, 1.8, "БРИФИНГОВАЯ →", P.Yellow, P.WarningBlack, 38)
	wallSign(signs, origin * CFrame.new(30, 12, -hd + 0.9), 12, 1.8, "АРХИВ ↑", P.Yellow, P.WarningBlack, 38)
	wallSign(signs, origin * CFrame.new(0, 7, hd - 0.9) * CFrame.Angles(0, math.pi, 0), 18, 1.6, "AUTHORIZED PERSONNEL ONLY", P.Red, Color3.new(1, 1, 1), 40)
	wallSign(signs, origin * CFrame.new(-30, 9, hd - 0.9) * CFrame.Angles(0, math.pi, 0), 10, 1.4, "ЗОНА ОЖИДАНИЯ", P.PanelWhite, P.WarningBlack, 36)
	-- Sealed access shaft door on the north wall (where shifts "depart").
	local shaft = Builder.model(f, "AccessShaft")
	Builder.box(shaft, "Door", origin * CFrame.new(-28, 6, -hd + 0.5), Vector3.new(12, 12, 1.2), Enum.Material.DiamondPlate, P.SteelPainted)
	Props.securityDoorFrame(shaft, origin * CFrame.new(-28, 0, -hd + 0.5), 12, 12)
	wallSign(shaft, origin * CFrame.new(-28, 14.5, -hd + 0.9), 12, 1.4, "ШАХТА ДОСТУПА · COMPLEX-17 · УРОВЕНЬ -2", P.Orange, P.WarningBlack, 32)
	local shaftLamp = Builder.emergencyLamp(shaft, origin * CFrame.new(-28, 13.2, -hd + 1.2))
	shaftLamp.Transparency = 0.3
	;(shaftLamp:FindFirstChildOfClass("PointLight") :: PointLight).Enabled = true
	-- Ambient sound emitters
	local amb = Builder.part({ name = "AmbientEmitter", size = Vector3.new(1, 1, 1), cframe = origin * CFrame.new(0, 12, 0), transparency = 1, canCollide = false, parent = f })
	local hum = Builder.sound(amb, Sounds.AmbientHum, "Hum")
	hum.RollOffMaxDistance = 120
	hum:SetAttribute("AutoPlay", true)
	local vent = Builder.sound(amb, Sounds.VentHum, "Vent")
	vent.RollOffMaxDistance = 100
	vent:SetAttribute("AutoPlay", true)
	return f
end

local function reception(root: Model, origin: CFrame): BasePart
	local m = Builder.model(root, "Reception")
	local cf = origin * CFrame.new(0, 0, 20)
	Builder.box(m, "Counter", cf * CFrame.new(0, 2, 0), Vector3.new(18, 4, 3), Enum.Material.Metal, P.PanelBeige)
	Builder.box(m, "CounterTop", cf * CFrame.new(0, 4.1, 0), Vector3.new(18.6, 0.3, 3.6), Enum.Material.Metal, P.Stainless)
	Builder.box(m, "Front", cf * CFrame.new(0, 2, 1.6), Vector3.new(18, 3.4, 0.2), Enum.Material.Metal, P.SteelPainted)
	local plate = Builder.box(m, "FrontSign", cf * CFrame.new(0, 2.6, 1.72), Vector3.new(10, 1.2, 0.05), Enum.Material.SmoothPlastic, P.WarningBlack)
	Builder.label(plate, Enum.NormalId.Front, "РЕГИСТРАЦИЯ ПЕРСОНАЛА", { textColor = Color3.fromRGB(230, 230, 230), textSize = 40, bold = true })
	local term = Props.terminal(m, cf * CFrame.new(5, 0, -1.6) * CFrame.Angles(0, math.pi, 0), "PERSONNEL DESK\n> insert badge\n> shift status: PENDING")
	term.Name = "RegistrationTerminal"
	local body = term.PrimaryPart :: Part
	local prompt = Builder.prompt(body, "Регистрация", "Терминал персонала", 0, Enum.KeyCode.E, 10)
	prompt:SetAttribute("UI", "Registration")
	Props.chair(m, cf * CFrame.new(-3, 0, -2.4))
	Props.desk(m, cf * CFrame.new(-10, 0, -3) * CFrame.Angles(0, math.pi / 2, 0), true)
	Builder.box(m, "Papers", cf * CFrame.new(-4, 4.3, 0), Vector3.new(2, 0.08, 1.4), Enum.Material.SmoothPlastic, P.PanelWhite)
	Builder.box(m, "BadgeReader", cf * CFrame.new(-1, 4.4, 0.6), Vector3.new(1, 0.3, 0.8), Enum.Material.SmoothPlastic, P.WarningBlack)
	local led = Builder.box(m, "Led", cf * CFrame.new(-1, 4.6, 0.6), Vector3.new(0.2, 0.1, 0.2), Enum.Material.Neon, P.Green)
	led.CastShadow = false
	return body
end

local function shiftBoard(root: Model, origin: CFrame): (BasePart, TextLabel, TextLabel)
	local m = Builder.model(root, "ShiftBoard")
	local hd = ATRIUM_D / 2
	local cf = origin * CFrame.new(0, 0, -hd + 1)
	Builder.box(m, "Frame", cf * CFrame.new(0, 7, 0.2), Vector3.new(32, 10, 0.8), Enum.Material.Metal, P.WarningBlack)
	local screen = Builder.part({ name = "Screen", size = Vector3.new(20, 8.6, 0.1), cframe = cf * CFrame.new(-5, 7, 0.65), material = Enum.Material.Neon, color = Color3.fromRGB(16, 22, 30), parent = m, castShadow = false })
	Builder.pointLight(screen, P.ScreenBlue, 18, 0.5)
	local label = Builder.label(screen, Enum.NormalId.Front, "ДОСКА СМЕН\nзагрузка...", { textColor = Color3.fromRGB(220, 235, 255), textSize = 26, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 14, pixelsPerStud = 32 })
	local ready = Builder.part({ name = "ReadyScreen", size = Vector3.new(9, 8.6, 0.1), cframe = cf * CFrame.new(10.5, 7, 0.65), material = Enum.Material.Neon, color = Color3.fromRGB(20, 20, 24), parent = m, castShadow = false })
	local readyLabel = Builder.label(ready, Enum.NormalId.Front, "КОМАНДА\n—", { textColor = Color3.fromRGB(240, 220, 160), textSize = 24, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 12, pixelsPerStud = 32 })
	wallSign(m, cf * CFrame.new(0, 12.8, 0.6), 32, 1.4, "ДОСКА СМЕН · SHIFT BOARD", P.Yellow, P.WarningBlack, 36)
	-- Console in front of the board
	local console = Builder.box(m, "Console", cf * CFrame.new(0, 1.8, 4), Vector3.new(8, 3.6, 2), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "ConsoleTop", cf * CFrame.new(0, 3.7, 3.6) * CFrame.Angles(-0.45, 0, 0), Vector3.new(8, 0.3, 2), Enum.Material.Metal, P.SteelPaintedLight)
	local kb = Builder.box(m, "Keys", cf * CFrame.new(0, 3.95, 3.3) * CFrame.Angles(-0.45, 0, 0), Vector3.new(6, 0.1, 1.2), Enum.Material.SmoothPlastic, P.WarningBlack)
	kb.CastShadow = false
	local prompt = Builder.prompt(console, "Открыть", "Доска смен", 0, Enum.KeyCode.E, 12)
	prompt:SetAttribute("UI", "ShiftBoard")
	Builder.hazardStripes(m, cf * CFrame.new(0, 0.03, 6.2), 12, 0.8)
	return console, label, readyLabel
end

local function equipmentRoom(root: Model, origin: CFrame): { [string]: BasePart }
	local m = Builder.model(root, "EquipmentRoom")
	local cf = origin * CFrame.new(-(ATRIUM_W / 2 + SIDE_W / 2), 0, 0)
	Builder.shell(m, cf, SIDE_W, SIDE_D, SIDE_H, {
		doors = { E = { width = 10, height = 10 } },
		wallColor = Color3.fromRGB(112, 116, 118),
		floorColor = P.RubberFloor,
		floorMaterial = Enum.Material.Rubber,
		thickness = 1.5,
	})
	local lights = Builder.folder(m, "Lights")
	for _, x in { -10, 2, 12 } do
		Builder.ceilingLamp(lights, cf * CFrame.new(x, SIDE_H - 0.3, 0), Vector3.new(1.2, 0.2, 10), P.LightCold, 20, 0.85)
	end
	wallSign(m, cf * CFrame.new(0, 10.4, -SIDE_D / 2 + 1), 16, 1.5, "КОМНАТА ЭКИПИРОВКИ · ВЫБЕРИТЕ ОДИН ИНСТРУМЕНТ", P.Yellow, P.WarningBlack, 32)
	-- Tool lockers along the north wall
	local lockers: { [string]: BasePart } = {}
	local n = #Tools.Order
	for i, id in Tools.Order do
		local def = Tools.Defs[id]
		local x = -SIDE_W / 2 + 4 + (i - 0.5) * ((SIDE_W - 8) / n)
		local lcf = cf * CFrame.new(x, 0, -SIDE_D / 2 + 2.3) * CFrame.Angles(0, math.pi, 0)
		local locker = Props.locker(m, lcf, P.SteelPainted, string.format("%02d", i))
		locker.Name = "Locker_" .. id
		local body = locker.PrimaryPart :: Part
		-- Tool display: a glowing sample item on a small shelf in front
		local shelf = Builder.box(m, "Shelf", lcf * CFrame.new(0, 2.2, -2.3), Vector3.new(2.2, 0.2, 1.2), Enum.Material.Metal, P.Stainless)
		local item = Builder.box(shelf, "ToolDisplay", lcf * CFrame.new(0, 2.75, -2.3), Vector3.new(1.4, 0.9, 0.7), Enum.Material.SmoothPlastic, def.color)
		item:SetAttribute("ToolId", id)
		Builder.pointLight(item, def.color, 5, 0.4)
		local plate = Builder.box(m, "NamePlate", lcf * CFrame.new(0, 7.1, -1.2), Vector3.new(2.6, 0.7, 0.1), Enum.Material.SmoothPlastic, P.WarningBlack)
		Builder.label(plate, Enum.NormalId.Front, def.name, { textColor = Color3.fromRGB(230, 230, 230), textSize = 20, bold = true })
		local prompt = Builder.prompt(body, "Взять", def.name, 0.4, Enum.KeyCode.E, 8)
		prompt:SetAttribute("UI", "Equipment")
		prompt:SetAttribute("ToolId", id)
		lockers[id] = body
	end
	-- Workbenches, hooks, shelves
	Props.desk(m, cf * CFrame.new(-8, 0, 8), false)
	Props.desk(m, cf * CFrame.new(8, 0, 8), false)
	Builder.box(m, "Shelving", cf * CFrame.new(-SIDE_W / 2 + 1.5, 4, 6), Vector3.new(1.4, 8, 12), Enum.Material.Metal, P.SteelPaintedLight)
	for j = 1, 4 do
		Builder.box(m, "ShelfBox", cf * CFrame.new(-SIDE_W / 2 + 1.5, j * 1.8, 6), Vector3.new(1.6, 1, 10), Enum.Material.SmoothPlastic, if j % 2 == 0 then P.Yellow:Lerp(P.WarningBlack, 0.4) else P.SteelPainted)
	end
	for k = 0, 5 do
		Builder.box(m, "Hook", cf * CFrame.new(SIDE_W / 2 - 1, 7, -8 + k * 3), Vector3.new(0.5, 0.3, 0.3), Enum.Material.Metal, P.Stainless)
		Builder.box(m, "Harness", cf * CFrame.new(SIDE_W / 2 - 1.2, 5.4, -8 + k * 3), Vector3.new(0.3, 3, 1.2), Enum.Material.Fabric, P.Orange:Lerp(P.WarningBlack, 0.5))
	end
	Props.cart(m, cf * CFrame.new(0, 0, 11))
	Builder.hazardStripes(m, cf * CFrame.new(0, 0.03, -SIDE_D / 2 + 5.4), 28, 0.8)
	return lockers
end

local function briefingRoom(root: Model, origin: CFrame): (TextLabel, BasePart)
	local m = Builder.model(root, "BriefingRoom")
	local cf = origin * CFrame.new(ATRIUM_W / 2 + SIDE_W / 2, 0, 0)
	Builder.shell(m, cf, SIDE_W, SIDE_D, SIDE_H, {
		doors = { W = { width = 10, height = 10 } },
		wallColor = Color3.fromRGB(104, 106, 110),
		floorColor = Color3.fromRGB(70, 72, 76),
		floorMaterial = Enum.Material.Fabric,
		thickness = 1.5,
	})
	local lights = Builder.folder(m, "Lights")
	for _, x in { -8, 8 } do
		Builder.ceilingLamp(lights, cf * CFrame.new(x, SIDE_H - 0.3, 4), Vector3.new(6, 0.2, 1.2), P.LightWarm, 20, 0.6)
	end
	-- Big screen on the east wall
	Builder.box(m, "ScreenFrame", cf * CFrame.new(SIDE_W / 2 - 1.1, 6.5, 0), Vector3.new(0.6, 9, 20), Enum.Material.Metal, P.WarningBlack)
	local screen = Builder.part({ name = "Screen", size = Vector3.new(0.1, 8.2, 19), cframe = cf * CFrame.new(SIDE_W / 2 - 1.45, 6.5, 0), material = Enum.Material.Neon, color = Color3.fromRGB(14, 20, 28), parent = m, castShadow = false })
	Builder.pointLight(screen, P.ScreenBlue, 20, 0.6)
	local label = Builder.label(screen, Enum.NormalId.Left, "БРИФИНГ\n\nВыберите смену на доске смен, чтобы получить задание.", { textColor = Color3.fromRGB(225, 235, 250), textSize = 24, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 16, pixelsPerStud = 32 })
	-- Conference table and chairs
	local table_ = Builder.box(m, "Table", cf * CFrame.new(0, 2.9, 0), Vector3.new(16, 0.3, 6), Enum.Material.Metal, P.PanelBeige)
	Builder.box(m, "TableBase", cf * CFrame.new(0, 1.4, 0), Vector3.new(14, 2.8, 2), Enum.Material.Metal, P.SteelPainted)
	for i = -3, 3 do
		Props.chair(m, cf * CFrame.new(i * 2.4, 0, -4.5) * CFrame.Angles(0, math.pi, 0))
		Props.chair(m, cf * CFrame.new(i * 2.4, 0, 4.5))
	end
	local console = Builder.box(m, "Console", cf * CFrame.new(SIDE_W / 2 - 5, 1.8, -8), Vector3.new(3, 3.6, 2), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "ConsoleTop", cf * CFrame.new(SIDE_W / 2 - 5, 3.7, -8.3) * CFrame.Angles(-0.4, 0, 0), Vector3.new(3, 0.3, 1.6), Enum.Material.Metal, P.SteelPaintedLight)
	local prompt = Builder.prompt(console, "Брифинг", "Пульт брифинга", 0, Enum.KeyCode.E, 10)
	prompt:SetAttribute("UI", "Briefing")
	-- Wall schematic of the complex
	local map = Builder.box(m, "Schematic", cf * CFrame.new(0, 7, -SIDE_D / 2 + 1.1), Vector3.new(14, 7, 0.2), Enum.Material.SmoothPlastic, Color3.fromRGB(28, 32, 36))
	Builder.label(map, Enum.NormalId.Front, "СХЕМА COMPLEX-17\n\n[A] АДМИН  →  [B] ТЕХ  →  [C] ЛАБ  →  [E] ЭВАК\n                                  ↓\n                               [D] ИЗОЛЯЦИЯ (ДОПУСК 03)", { textColor = Color3.fromRGB(200, 220, 240), textSize = 24, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 12 })
	Builder.pointLight(map, P.ScreenBlue, 8, 0.3)
	wallSign(m, cf * CFrame.new(0, 10.4, -SIDE_D / 2 + 1), 12, 1.4, "БРИФИНГОВАЯ", P.Yellow, P.WarningBlack, 36)
	local _ = table_
	return label, console
end

local function archive(root: Model, origin: CFrame): { BasePart }
	local m = Builder.model(root, "Archive")
	local hd = ATRIUM_D / 2
	local cf = origin * CFrame.new(30, 0, -(hd + 15))
	Builder.shell(m, cf, 30, 30, SIDE_H, {
		doors = { S = { width = 10, height = 10 } },
		wallColor = Color3.fromRGB(96, 98, 104),
		floorColor = Color3.fromRGB(84, 86, 90),
		thickness = 1.5,
	})
	local lights = Builder.folder(m, "Lights")
	Builder.ceilingLamp(lights, cf * CFrame.new(0, SIDE_H - 0.3, -6), Vector3.new(8, 0.2, 1.2), P.LightWarm:Lerp(P.LightCold, 0.3), 22, 0.55)
	Builder.ceilingLamp(lights, cf * CFrame.new(0, SIDE_H - 0.3, 6), Vector3.new(8, 0.2, 1.2), P.LightWarm:Lerp(P.LightCold, 0.3), 22, 0.55)
	wallSign(m, cf * CFrame.new(0, 10.4, -14), 14, 1.4, "ПЕРСОНАЛЬНЫЙ АРХИВ", P.PanelWhite, P.WarningBlack, 36)
	-- Terminals
	local terminals = {}
	for i, x in { -9, 0, 9 } do
		local t = Props.terminal(m, cf * CFrame.new(x, 0, -12), string.format("ARCHIVE NODE %d\n> documents: --\n> chapters: --\n> access: PERSONAL", i))
		t.Name = "ArchiveTerminal" .. i
		local body = t.PrimaryPart :: Part
		local prompt = Builder.prompt(body, "Открыть архив", "Архивный терминал", 0, Enum.KeyCode.E, 10)
		prompt:SetAttribute("UI", "Archive")
		table.insert(terminals, body)
	end
	-- Filing cabinets, locked cabinets, photo wall
	for i = 0, 3 do
		Props.locker(m, cf * CFrame.new(-13, 0, -6 + i * 4) * CFrame.Angles(0, -math.pi / 2, 0), P.PanelBeige:Lerp(P.WarningBlack, 0.3), "АРХ-" .. (i + 1))
	end
	for i = 0, 3 do
		Props.locker(m, cf * CFrame.new(13, 0, -6 + i * 4) * CFrame.Angles(0, math.pi / 2, 0), P.Red:Lerp(P.WarningBlack, 0.7), "ЗАКР")
	end
	local wall = Builder.box(m, "PhotoWall", cf * CFrame.new(0, 6, 13.8), Vector3.new(16, 6, 0.2), Enum.Material.SmoothPlastic, P.WarningBlack)
	for i = 0, 4 do
		local photo = Builder.box(wall, "Photo", cf * CFrame.new(-6 + i * 3, 6 + (i % 2) * 1.2, 13.65), Vector3.new(2.2, 1.6, 0.05), Enum.Material.SmoothPlastic, Color3.fromRGB(140, 140, 150))
		Builder.label(photo, Enum.NormalId.Front, ({ "СМЕНА 38", "ГРУППА B-2", "ОБЪЕКТ 17", "[ИЗЪЯТО]", "КЕРНЕР М." })[i + 1], { textColor = P.WarningBlack, textSize = 18, font = Enum.Font.Code })
	end
	Props.desk(m, cf * CFrame.new(0, 0, 4), true)
	Props.chair(m, cf * CFrame.new(0, 0, 7))
	return terminals
end

local function waitingZone(root: Model, origin: CFrame)
	local m = Builder.model(root, "WaitingZone")
	local cf = origin * CFrame.new(-30, 0, 22)
	Props.bench(m, cf * CFrame.new(-6, 0, 6))
	Props.bench(m, cf * CFrame.new(2, 0, 6))
	Props.bench(m, cf * CFrame.new(-6, 0, -2) * CFrame.Angles(0, math.pi, 0))
	Props.vendingMachine(m, cf * CFrame.new(-11, 0, 10) * CFrame.Angles(0, math.pi, 0))
	Props.vendingMachine(m, cf * CFrame.new(-6.5, 0, 10) * CFrame.Angles(0, math.pi, 0))
	-- Observation window into a dark service shaft
	local hd = ATRIUM_D / 2
	local winCf = origin * CFrame.new(-30, 7, hd - 0.9)
	Builder.part({ name = "Window", size = Vector3.new(18, 5, 0.3), cframe = winCf, material = Enum.Material.Glass, color = P.GlassTint, transparency = 0.5, reflectance = 0.15, parent = m })
	Builder.box(m, "WindowFrame", winCf * CFrame.new(0, 2.8, 0), Vector3.new(19, 0.6, 0.6), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "WindowFrame", winCf * CFrame.new(0, -2.8, 0), Vector3.new(19, 0.6, 0.6), Enum.Material.Metal, P.SteelPainted)
	-- Behind the window: shallow shaft with pipes and a red lamp
	local shaft = Builder.model(m, "ServiceShaft")
	local scf = origin * CFrame.new(-30, 0, hd + 6)
	Builder.box(shaft, "Back", scf * CFrame.new(0, 8, 5), Vector3.new(20, 16, 1), Enum.Material.Concrete, P.ConcreteDark)
	Builder.box(shaft, "Floor", scf * CFrame.new(0, -0.5, 0), Vector3.new(20, 1, 12), Enum.Material.Concrete, P.ConcreteDark)
	Builder.box(shaft, "SideL", scf * CFrame.new(-10, 8, 0), Vector3.new(1, 16, 12), Enum.Material.Concrete, P.ConcreteDark)
	Builder.box(shaft, "SideR", scf * CFrame.new(10, 8, 0), Vector3.new(1, 16, 12), Enum.Material.Concrete, P.ConcreteDark)
	Builder.box(shaft, "Top", scf * CFrame.new(0, 16, 0), Vector3.new(20, 1, 12), Enum.Material.Concrete, P.ConcreteDark)
	Props.pipeCluster(shaft, scf * CFrame.new(0, 0, 3), 18, 5)
	Builder.pipeRun(shaft, { scf:PointToWorldSpace(Vector3.new(-8, 0, 2)), scf:PointToWorldSpace(Vector3.new(-8, 14, 2)) }, 0.6, P.Galvanized)
	Builder.pipeRun(shaft, { scf:PointToWorldSpace(Vector3.new(6, 0, 2)), scf:PointToWorldSpace(Vector3.new(6, 14, 2)) }, 0.45, P.Red:Lerp(P.Galvanized, 0.5))
	local red = Builder.emergencyLamp(shaft, scf * CFrame.new(0, 13, 4))
	;(red:FindFirstChildOfClass("PointLight") :: PointLight).Enabled = true
	-- Info panels
	local info = Builder.box(m, "InfoPanel", origin * CFrame.new(-12, 6, hd - 0.9), Vector3.new(6, 4, 0.2), Enum.Material.SmoothPlastic, Color3.fromRGB(28, 32, 36))
	Builder.label(info, Enum.NormalId.Front, "ПАМЯТКА СМЕНЫ\n1. Один инструмент на смену.\n2. Не открывать двери D-xx.\n3. При сигнале тревоги — к шлюзу E-1.\n4. Сообщайте о несовпадениях журналов.", { textColor = Color3.fromRGB(220, 220, 220), textSize = 20, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 10 })
	Builder.pointLight(info, P.ScreenBlue, 6, 0.25)
	-- Technical corner
	Builder.box(m, "Cabinet", origin * CFrame.new(-43, 4, 12) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(3.5, 8, 1.2), Enum.Material.Metal, P.SteelPaintedLight)
	Props.barrel(m, origin * CFrame.new(-42, 0, 6), P.Galvanized)
end

local function spawnAndZone(root: Model, origin: CFrame): (SpawnLocation, BasePart)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(12, 1, 6)
	spawn.CFrame = origin * CFrame.new(0, 0.05, 29) * CFrame.Angles(0, math.pi, 0)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root
	local zone = Builder.invisible(root, "SafeZone", origin * CFrame.new(0, 10, -15), Vector3.new(ATRIUM_W + SIDE_W * 2, 30, ATRIUM_D + 40))
	return spawn, zone
end

function LobbyBuilder.build(parent: Instance, origin: CFrame): Anchors
	local root = Builder.model(parent, "Lobby")
	atrium(root, origin)
	local registration = reception(root, origin)
	local board, boardLabel, readyLabel = shiftBoard(root, origin)
	local lockers = equipmentRoom(root, origin)
	local briefingLabel, briefingConsole = briefingRoom(root, origin)
	local terminals = archive(root, origin)
	waitingZone(root, origin)
	local spawn, zone = spawnAndZone(root, origin)
	-- Small decor in the atrium: equipment crates near the shaft, cable spool
	local decor = Builder.folder(root, "Decor")
	Props.crate(decor, origin * CFrame.new(-40, 0, -22), 3.5)
	Props.crate(decor, origin * CFrame.new(-36, 0, -24), 2.5, P.Orange:Lerp(P.WarningBlack, 0.5))
	Props.cart(decor, origin * CFrame.new(-14, 0, -28))
	Props.camera(decor, origin * CFrame.new(40, ATRIUM_H - 2, -30) * CFrame.Angles(0, math.pi * 0.25, 0), "L-01")
	Props.camera(decor, origin * CFrame.new(-40, ATRIUM_H - 2, 30) * CFrame.Angles(0, -math.pi * 0.75, 0), "L-02")
	return {
		root = root,
		spawn = spawn,
		registration = registration,
		shiftBoard = board,
		shiftBoardScreen = boardLabel,
		briefingScreen = briefingLabel,
		briefingConsole = briefingConsole,
		archiveTerminals = terminals,
		lockers = lockers,
		safeZone = zone,
		readyBoard = readyLabel,
	}
end

return LobbyBuilder
