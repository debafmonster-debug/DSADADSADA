--!nonstrict
-- Module catalog: every room/corridor that the layout generator can place.
-- Each builder fills ctx.model with geometry and ctx.markers with gameplay
-- anchors (Spawn, Patrol, TaskTarget, DocumentSpot, EvacZone, WardenSpawn).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(script.Parent.Props)
local Common = require(script.Parent.Common)
local P = Builder.Palette

type Ctx = Common.Ctx

export type ModuleDef = {
	id: string,
	sector: string,
	kind: "room" | "corridor",
	name: string,
	tags: { string },
	weight: number,
	unique: boolean?,
	build: (ctx: Ctx) -> (),
}

local Catalog: { ModuleDef } = {}

local function add(def: ModuleDef)
	table.insert(Catalog, def)
end

local function roomBase(ctx: Ctx, title: string, cols: number, rows: number, brightness: number?)
	Common.roomShell(ctx)
	Common.lights(ctx, cols, rows, brightness)
	Common.emergencyLights(ctx)
	Common.ceilingDetail(ctx, 0.5)
	Common.doorSigns(ctx, ctx.roomCode)
	Common.wear(ctx)
	local sf = ctx.model:FindFirstChild("Signs") :: Folder
	-- Title plate on a free wall segment
	local cf = Common.wallSpot(ctx, 0.7)
	Builder.signPlate(sf, cf * CFrame.new(0, 8.5, 0), 7, 1.3, title, P.WarningBlack, Color3.fromRGB(230, 230, 230), 34)
end

local function wallProp(ctx: Ctx, fn: (Instance, CFrame) -> any, inset: number?)
	local cf = Common.wallSpot(ctx, inset or 1.6)
	return fn(ctx.model, cf)
end

------------------------------------------------------------------------------
-- SECTOR A — administrative
------------------------------------------------------------------------------
add({
	id = "A_Checkpoint", sector = "A", kind = "room", name = "Контрольный пункт", tags = { "start" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "КПП A-01 · ВХОД", 2, 2, 1.0)
		local m = ctx.model
		-- Reception counter + turnstiles
		Builder.box(m, "Counter", ctx.cframe * CFrame.new(0, 2, 8), Vector3.new(14, 4, 2.5), Enum.Material.Metal, P.PanelBeige)
		Builder.box(m, "CounterTop", ctx.cframe * CFrame.new(0, 4.1, 8), Vector3.new(14.4, 0.3, 3), Enum.Material.Metal, P.Stainless)
		Props.terminal(m, ctx.cframe * CFrame.new(-4, 0, 10) * CFrame.Angles(0, math.pi, 0), "ACCESS CONTROL\n> gate: OPEN\n> shift: 17-A\n> alarm: ARMED")
		for _, x in { -5, 5 } do
			Builder.box(m, "Turnstile", ctx.cframe * CFrame.new(x, 1.8, 0), Vector3.new(0.6, 3.6, 3), Enum.Material.Metal, P.Stainless)
			Builder.box(m, "TurnstileArm", ctx.cframe * CFrame.new(x + 1, 2.4, 0), Vector3.new(2, 0.2, 0.2), Enum.Material.Metal, P.Galvanized)
		end
		Builder.hazardStripes(m, ctx.cframe * CFrame.new(0, 0.03, -4), 16, 1)
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 8, 9.2) * CFrame.Angles(0, math.pi, 0), "COMPLEX-17 · ТОЛЬКО ДЛЯ ПЕРСОНАЛА", P.Yellow)
		Props.camera(m, ctx.cframe * CFrame.new(16, 10.5, -16), "A-01")
		for i = 1, 4 do
			Common.marker(ctx, "Spawn", ctx.cframe * CFrame.new(-9 + i * 3.6, 3, 14), { Index = i })
		end
		Common.docSpot(ctx, ctx.cframe * CFrame.new(3, 4.3, 8))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "A_Office", sector = "A", kind = "room", name = "Кабинеты персонала", tags = { "office" }, weight = 2,
	build = function(ctx)
		roomBase(ctx, "КАБИНЕТЫ A-0" .. ctx.rng:nextInteger(2, 6), 2, 2, 0.9)
		local m = ctx.model
		local n = ctx.rng:nextInteger(2, 4)
		for i = 1, n do
			local x = -12 + (i - 1) * 8
			local z = ctx.rng:pick({ -10, -2 })
			if not Common.laneBlocked(ctx, x, z) then
				Props.desk(m, ctx.cframe * CFrame.new(x, 0, z), ctx.rng:chance(0.7))
				Props.chair(m, ctx.cframe * CFrame.new(x, 0, z + 2.6))
			end
		end
		wallProp(ctx, function(parent, cf)
			return Props.locker(parent, cf * CFrame.new(0, 0, -1.2), nil, "A")
		end)
		Props.camera(m, ctx.cframe * CFrame.new(-16, 10.5, 16) * CFrame.Angles(0, math.pi, 0), "A-0X")
		Common.docSpot(ctx, ctx.cframe * CFrame.new(-12, 3.1, -10.6))
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "A_Archive", sector = "A", kind = "room", name = "Архив документов", tags = { "archive", "documents" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "АРХИВ A-07", 2, 2, 0.75)
		local m = ctx.model
		for i = 0, 3 do
			local x = -12 + i * 8
			if not Common.laneBlocked(ctx, x, -8) then
				local shelf = Builder.box(m, "Shelf", ctx.cframe * CFrame.new(x, 4, -8), Vector3.new(1.5, 8, 10), Enum.Material.Metal, P.SteelPaintedLight)
				for j = 1, 4 do
					Builder.box(shelf, "Boxes", ctx.cframe * CFrame.new(x, j * 1.8 - 0.2, -8), Vector3.new(1.7, 1.2, 9), Enum.Material.SmoothPlastic, Color3.fromRGB(150, 140, 120))
				end
			end
		end
		Props.desk(m, ctx.cframe * CFrame.new(8, 0, 10) * CFrame.Angles(0, math.pi, 0), true)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(8, 3.1, 10.4))
		Common.docSpot(ctx, ctx.cframe * CFrame.new(-4, 5.5, -3.2))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "A_DutyRoom", sector = "A", kind = "room", name = "Комната дежурного", tags = { "duty" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ДЕЖУРНЫЙ A-03", 2, 2, 0.85)
		local m = ctx.model
		local cf = ctx.cframe * CFrame.new(0, 0, -12)
		-- Monitor wall
		Builder.box(m, "MonitorWall", cf * CFrame.new(0, 6, -4.5), Vector3.new(14, 6, 0.6), Enum.Material.Metal, P.WarningBlack)
		for i = -1, 1 do
			for j = 0, 1 do
				local scr = Builder.box(m, "Monitor", cf * CFrame.new(i * 4.4, 4.8 + j * 2.6, -4.1), Vector3.new(4, 2.2, 0.05), Enum.Material.Neon, if ctx.rng:chance(0.8) then P.ScreenBlue:Lerp(P.WarningBlack, 0.5) else Color3.fromRGB(120, 120, 120))
				scr.Transparency = 0.1
				Builder.label(scr, Enum.NormalId.Front, string.format("CAM %s-%02d\n%s", ctx.rng:pick({ "A", "B", "C" }), ctx.rng:nextInteger(1, 9), if ctx.rng:chance(0.75) then "LIVE" else "NO SIGNAL"), { textColor = Color3.new(1, 1, 1), textSize = 20, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, padding = 6 })
			end
		end
		Props.desk(m, cf * CFrame.new(0, 0, 1), false)
		Props.chair(m, cf * CFrame.new(0, 0, 3.6))
		Builder.pointLight(m:FindFirstChild("MonitorWall") :: Part, P.ScreenBlue, 12, 0.6)
		Props.bench(m, ctx.cframe * CFrame.new(12, 0, 12))
		Props.locker(m, ctx.cframe * CFrame.new(-14, 0, 12) * CFrame.Angles(0, -math.pi / 2, 0), nil, "D-1")
		Common.docSpot(ctx, cf * CFrame.new(1.4, 3.1, 0.5))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "A_Storage", sector = "A", kind = "room", name = "Складское помещение", tags = { "storage" }, weight = 2,
	build = function(ctx)
		roomBase(ctx, "СКЛАД A-1" .. ctx.rng:nextInteger(0, 4), 1, 2, 0.6)
		local m = ctx.model
		for _ = 1, ctx.rng:nextInteger(4, 7) do
			local x, z = ctx.rng:nextNumber(-14, 14), ctx.rng:nextNumber(-14, 14)
			if not Common.laneBlocked(ctx, x, z) then
				if ctx.rng:chance(0.6) then
					Props.crate(m, ctx.cframe * CFrame.new(x, 0, z) * CFrame.Angles(0, ctx.rng:nextNumber(0, 1), 0), ctx.rng:nextNumber(2.5, 4))
				else
					Props.barrel(m, ctx.cframe * CFrame.new(x, 0, z), ctx.rng:pick({ P.Blue, P.Galvanized, P.Yellow }))
				end
			end
		end
		wallProp(ctx, function(parent, cf)
			return Props.cart(parent, cf * CFrame.new(0, 0, -2))
		end)
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "A_Corridor", sector = "A", kind = "corridor", name = "Коридор A", tags = {}, weight = 3,
	build = function(ctx)
		Common.corridor(ctx, "СЕКТОР A → B")
	end,
})

------------------------------------------------------------------------------
-- SECTOR B — technical
------------------------------------------------------------------------------
add({
	id = "B_Switchgear", sector = "B", kind = "room", name = "Электрощитовая", tags = { "PowerRestore" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ЭЛЕКТРОЩИТОВАЯ B-02", 2, 2, 0.7)
		local m = ctx.model
		local cf, side = Common.wallSpot(ctx, 0.8)
		local panel = Props.breakerPanel(m, cf, 5, "ЩИТ B-02 · ЛИНИИ 1-5")
		panel.Name = "BreakerPanel"
		Common.marker(ctx, "TaskTarget", cf * CFrame.new(0, 3, -4), { Kind = "PowerRestore", TargetName = "BreakerPanel" })
		-- Secondary cabinets for atmosphere
		for i = 1, 3 do
			local c2 = Common.wallSpot(ctx, 1)
			Builder.box(m, "Cabinet", c2 * CFrame.new(0, 4, -0.6), Vector3.new(3.5, 7, 1.2), Enum.Material.Metal, P.SteelPaintedLight)
			local lamp = Builder.box(m, "CabinetLamp", c2 * CFrame.new(1.2, 6.4, -1.25), Vector3.new(0.3, 0.3, 0.1), Enum.Material.Neon, if i == 2 then P.Red else P.Green)
			lamp.CastShadow = false
		end
		Props.pipeCluster(m, ctx.cframe * CFrame.new(0, 0, -16), 36, 4)
		Builder.hazardStripes(m, cf * CFrame.new(0, 0.03, -3), 8, 0.8)
		Props.warningSign(m, cf * CFrame.new(5, 6, -0.3), "ОПАСНО · 380 В", P.Yellow)
		Common.docSpot(ctx, cf * CFrame.new(-4, 0.1, -2.5))
		Common.roomPatrol(ctx, 2)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(0, 3, 0))
		local _ = side
	end,
})

add({
	id = "B_Generator", sector = "B", kind = "room", name = "Генераторная", tags = { "generator" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ГЕНЕРАТОРНАЯ B-04", 2, 1, 0.65)
		local m = ctx.model
		local gen = Props.generator(m, ctx.cframe * CFrame.new(0, 0, 0))
		local hum = Builder.sound(gen.PrimaryPart :: Part, { id = "rbxasset://sounds/bass.wav", volume = 0.25, looped = true, pitch = 0.45, rollOff = 50 }, "GeneratorHum")
		hum:SetAttribute("AutoPlay", true)
		Builder.hazardStripes(m, ctx.cframe * CFrame.new(0, 0.03, -3.4), 12, 0.8)
		Builder.hazardStripes(m, ctx.cframe * CFrame.new(0, 0.03, 3.4), 12, 0.8)
		Props.pipeCluster(m, ctx.cframe * CFrame.new(0, 0, 16), 36, 3)
		for _ = 1, 3 do
			local c = Common.wallSpot(ctx, 1.5)
			Props.barrel(m, c * CFrame.new(0, 0, -1.5), P.Yellow:Lerp(P.WarningBlack, 0.3))
		end
		Common.roomPatrol(ctx, 2)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(12, 3, 12))
	end,
})

add({
	id = "B_ServerRoom", sector = "B", kind = "room", name = "Серверная", tags = { "Diagnostics" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "СЕРВЕРНАЯ B-06", 2, 2, 0.55)
		local m = ctx.model
		local racks = Builder.folder(m, "Racks")
		local i = 0
		for _, x in { -12, -4, 4, 12 } do
			for _, z in { -11, 11 } do
				if not Common.laneBlocked(ctx, x, z) then
					i += 1
					local r = Props.serverRack(racks, ctx.cframe * CFrame.new(x, 0, z) * CFrame.Angles(0, if z < 0 then 0 else math.pi, 0), true)
					r.Name = "Rack" .. i
					r:SetAttribute("Index", i)
				end
			end
		end
		Common.marker(ctx, "TaskTarget", ctx.cframe * CFrame.new(0, 3, 0), { Kind = "Diagnostics", TargetName = "Racks" })
		Props.terminal(m, ctx.cframe * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), "CORE CTRL B-06\n> node 3: FAULT\n> node 5: OK\n> temp: 31C"):SetAttribute("TerminalName", "DiagnosticsTerminal")
		local lamp = (m:FindFirstChild("Lights") :: Folder):GetChildren()[1] :: Part
		if lamp then
			local l = lamp:FindFirstChildOfClass("Part")
			if l then
				l.Color = P.LightCold:Lerp(P.Blue, 0.3)
			end
		end
		Common.docSpot(ctx, ctx.cframe * CFrame.new(3, 0.1, -2))
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "B_Ventilation", sector = "B", kind = "room", name = "Вентиляционная", tags = { "Ventilation" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ВЕНТИЛЯЦИОННАЯ B-08", 2, 2, 0.6)
		local m = ctx.model
		-- Big AHU box
		Builder.box(m, "AHU", ctx.cframe * CFrame.new(-8, 4, -10), Vector3.new(14, 8, 7), Enum.Material.Metal, P.Galvanized)
		Builder.box(m, "AHUGrille", ctx.cframe * CFrame.new(-8, 4, -6.4), Vector3.new(10, 5, 0.2), Enum.Material.DiamondPlate, P.WarningBlack)
		Builder.ventDuct(m, ctx.cframe:PointToWorldSpace(Vector3.new(-8, 9, -10)), ctx.cframe:PointToWorldSpace(Vector3.new(-8, 9, 18)), 3)
		Builder.ventDuct(m, ctx.cframe:PointToWorldSpace(Vector3.new(-1, 9, -10)), ctx.cframe:PointToWorldSpace(Vector3.new(18, 9, -10)), 3)
		local ahu = m:FindFirstChild("AHU") :: Part
		local hum = Builder.sound(ahu, { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.2, looped = true, pitch = 0.3, rollOff = 45 }, "VentHum")
		hum:SetAttribute("AutoPlay", true)
		local cf = Common.wallSpot(ctx, 1.2)
		local valve = Props.valve(m, cf * CFrame.new(0, 0, -1), "P-1")
		valve.Name = "VentValve"
		Common.marker(ctx, "TaskTarget", cf * CFrame.new(0, 3, -4), { Kind = "Ventilation", TargetName = "VentValve" })
		Props.pipeCluster(m, ctx.cframe * CFrame.new(0, 0, 16), 36, 3)
		Props.warningSign(m, cf * CFrame.new(4.5, 7, -0.3), "ДАВЛЕНИЕ · НОРМА 1.00", P.Yellow)
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "B_PipeMaintenance", sector = "B", kind = "room", name = "Обслуживание труб", tags = { "pipes" }, weight = 2,
	build = function(ctx)
		roomBase(ctx, "ТРУБОПРОВОД B-1" .. ctx.rng:nextInteger(0, 5), 1, 2, 0.5)
		local m = ctx.model
		Props.pipeCluster(m, ctx.cframe * CFrame.new(0, 0, -17), 36, 5)
		Props.pipeCluster(m, ctx.cframe * CFrame.new(0, 0, 17), 36, 5)
		Props.pipeCluster(m, ctx.cframe * CFrame.new(-17, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 36, 4)
		-- Floor-level pipes with a valve
		local a = ctx.cframe:PointToWorldSpace(Vector3.new(-17, 1.5, -12))
		local b = ctx.cframe:PointToWorldSpace(Vector3.new(-6, 1.5, -12))
		local c = ctx.cframe:PointToWorldSpace(Vector3.new(-6, 1.5, 12))
		Builder.pipeRun(m, { a, b, c }, 0.6, P.Blue:Lerp(P.Galvanized, 0.4))
		if ctx.rng:chance(0.5) then
			Props.debrisPile(m, ctx.cframe * CFrame.new(10, 0, 12))
		end
		wallProp(ctx, function(parent, cf)
			return Props.cart(parent, cf * CFrame.new(0, 0, -2))
		end)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(12, 2.7, 12))
		Common.roomPatrol(ctx, 2)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(10, 3, -10))
	end,
})

add({
	id = "B_Distribution", sector = "B", kind = "room", name = "Узел распределения", tags = { "power" }, weight = 1,
	build = function(ctx)
		roomBase(ctx, "РАСПРЕД. УЗЕЛ B-05", 2, 2, 0.6)
		local m = ctx.model
		for _ = 1, 4 do
			local c = Common.wallSpot(ctx, 1)
			Builder.box(m, "Cabinet", c * CFrame.new(0, 4, -0.7), Vector3.new(4, 8, 1.4), Enum.Material.Metal, P.SteelPaintedLight)
			local lamp = Builder.box(m, "CabinetLamp", c * CFrame.new(1.4, 7, -1.45), Vector3.new(0.3, 0.3, 0.1), Enum.Material.Neon, P.Green)
			lamp.CastShadow = false
		end
		-- Transformer in the middle, fenced
		Builder.box(m, "Transformer", ctx.cframe * CFrame.new(0, 3, 0), Vector3.new(6, 6, 5), Enum.Material.Metal, P.SteelPainted)
		local t = m:FindFirstChild("Transformer") :: Part
		local hum = Builder.sound(t, { id = "rbxasset://sounds/bass.wav", volume = 0.18, looped = true, pitch = 0.6, rollOff = 35 }, "TransformerHum")
		hum:SetAttribute("AutoPlay", true)
		for _, z in { -4, 4 } do
			Builder.box(m, "Fence", ctx.cframe * CFrame.new(0, 2.5, z), Vector3.new(9, 5, 0.15), Enum.Material.DiamondPlate, P.Yellow).Transparency = 0.4
		end
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 6.5, -4.2), "ВЫСОКОЕ НАПРЯЖЕНИЕ", P.Yellow)
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "B_Corridor", sector = "B", kind = "corridor", name = "Сервисный коридор B", tags = {}, weight = 3,
	build = function(ctx)
		Common.corridor(ctx, "СЕРВИС B")
	end,
})

------------------------------------------------------------------------------
-- SECTOR C — research
------------------------------------------------------------------------------
add({
	id = "C_Lab", sector = "C", kind = "room", name = "Лаборатория", tags = { "lab" }, weight = 2,
	build = function(ctx)
		roomBase(ctx, "ЛАБОРАТОРИЯ C-0" .. ctx.rng:nextInteger(1, 4), 3, 3, 0.8)
		local m = ctx.model
		for _, z in { -10, 2 } do
			for _, x in { -11, 0, 11 } do
				if not Common.laneBlocked(ctx, x, z) and ctx.rng:chance(0.8) then
					Props.labTable(m, ctx.cframe * CFrame.new(x, 0, z))
				end
			end
		end
		Props.camera(m, ctx.cframe * CFrame.new(16, 10.5, -16), "C-0X")
		wallProp(ctx, function(parent, cf)
			return Props.sampleCabinet(parent, cf * CFrame.new(0, 0, -1.2))
		end)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(-11, 3.2, 2.6))
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "C_Observation", sector = "C", kind = "room", name = "Комната наблюдения", tags = { "CameraRepair" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "НАБЛЮДЕНИЕ C-05", 2, 2, 0.6)
		local m = ctx.model
		local cf = Common.wallSpot(ctx, 1.2)
		local term = Props.terminal(m, cf * CFrame.new(0, 0, -1.5), "CCTV MATRIX\n> C-05 LIVE\n> C-07 NO SIGNAL\n> C-09 LIVE")
		term.Name = "CameraTerminal"
		Common.marker(ctx, "TaskTarget", cf * CFrame.new(0, 3, -4), { Kind = "CameraRepair", TargetName = "CameraTerminal" })
		-- Observation glass toward a closed cell
		Props.glassWall(m, ctx.cframe * CFrame.new(0, 0, -8), 20, 9)
		Builder.box(m, "CellFloor", ctx.cframe * CFrame.new(0, 0.1, -14), Vector3.new(20, 0.2, 11), Enum.Material.SmoothPlastic, P.LabWhite)
		Props.chair(m, ctx.cframe * CFrame.new(0, 0, -13))
		Builder.box(m, "CellTable", ctx.cframe * CFrame.new(0, 1.5, -15.5), Vector3.new(4, 3, 2), Enum.Material.Metal, P.PanelWhite)
		Props.camera(m, ctx.cframe * CFrame.new(-8, 10.5, -17), "C-07")
		Props.camera(m, ctx.cframe * CFrame.new(16, 10.5, 16) * CFrame.Angles(0, math.pi, 0), "C-05")
		Props.desk(m, cf * CFrame.new(5, 0, -2), true)
		Common.docSpot(ctx, cf * CFrame.new(6.4, 3.1, -2.4))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "C_SampleStorage", sector = "C", kind = "room", name = "Хранилище образцов", tags = { "samples" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ХРАНИЛИЩЕ C-08", 2, 2, 0.55)
		local m = ctx.model
		for i = 1, 5 do
			local c = Common.wallSpot(ctx, 1.3)
			Props.sampleCabinet(m, c * CFrame.new(0, 0, -1.1))
			if i == 3 then
				Common.docSpot(ctx, c * CFrame.new(3, 0.1, -3))
			end
		end
		Builder.box(m, "ColdUnit", ctx.cframe * CFrame.new(0, 3, 0), Vector3.new(8, 6, 5), Enum.Material.Metal, P.PanelWhite)
		local cu = m:FindFirstChild("ColdUnit") :: Part
		Builder.pointLight(cu, P.LightLab, 10, 0.5)
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 6.5, -2.6), "БИОЛОГИЧЕСКАЯ ОПАСНОСТЬ", P.Orange)
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "C_ControlTerminals", sector = "C", kind = "room", name = "Контрольные терминалы", tags = { "control" }, weight = 1,
	build = function(ctx)
		roomBase(ctx, "КОНТРОЛЬ C-03", 2, 2, 0.7)
		local m = ctx.model
		for i = 1, 4 do
			local c = Common.wallSpot(ctx, 1.4)
			Props.terminal(m, c * CFrame.new(0, 0, -1.4), string.format("SENSOR NET %d\n> drift: %+.2f\n> link: %s", i, ctx.rng:nextNumber(-1, 1), if ctx.rng:chance(0.7) then "OK" else "LOST"), if ctx.rng:chance(0.7) then P.ScreenBlue else P.Orange)
		end
		Props.glassWall(m, ctx.cframe * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 14, 9)
		Props.camera(m, ctx.cframe * CFrame.new(-16, 10.5, -16) * CFrame.Angles(0, -math.pi / 2, 0), "C-0X")
		Common.docSpot(ctx, ctx.cframe * CFrame.new(4, 0.1, 4))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "C_RestrictedLab", sector = "C", kind = "room", name = "Закрытая лаборатория", tags = { "restricted" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ЛАБ. C-11 · ДОПУСК 02", 2, 2, 0.45)
		local m = ctx.model
		Props.labTable(m, ctx.cframe * CFrame.new(0, 0, -10))
		Props.glassWall(m, ctx.cframe * CFrame.new(0, 0, -4), 20, 9)
		for _, x in { -12, 12 } do
			Props.sampleCabinet(m, ctx.cframe * CFrame.new(x, 0, -16))
		end
		Props.debrisPile(m, ctx.cframe * CFrame.new(10, 0, 8))
		Builder.box(m, "SpilledCabinet", ctx.cframe * CFrame.new(-10, 1.1, 10) * CFrame.Angles(0, 0.3, math.pi / 2), Vector3.new(4, 7, 2.2), Enum.Material.Metal, P.PanelWhite)
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 7, -3.8), "ОБЪЕКТ НАБЛЮДЕНИЯ · НЕ ВЫКЛЮЧАТЬ СВЕТ", P.Red)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(0, 3.2, -10.4))
		Common.roomPatrol(ctx, 1)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(0, 3, -12))
		-- One flickering lamp: tagged so FacilityService animates it
		local lights = m:FindFirstChild("Lights") :: Folder
		local lamp = lights:GetChildren()[2]
		if lamp then
			local neon = lamp:FindFirstChild("Lamp")
			if neon then
				neon:SetAttribute("Flicker", true)
			end
		end
	end,
})

add({
	id = "C_Corridor", sector = "C", kind = "corridor", name = "Коридор C", tags = {}, weight = 3,
	build = function(ctx)
		Common.corridor(ctx, "ЛАБ. БЛОК C")
		Props.camera(ctx.model, ctx.cframe * CFrame.new(Common.CorridorWidth / 2 - 0.6, ctx.height - 1.2, -Common.CorridorWidth / 2 + 0.6) * CFrame.Angles(0, math.pi * 0.75, 0), "C-0X")
	end,
})

------------------------------------------------------------------------------
-- SECTOR D — isolation
------------------------------------------------------------------------------
add({
	id = "D_Airlock", sector = "D", kind = "room", name = "Контрольный шлюз", tags = { "DoorRepair", "isolation_entry" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ШЛЮЗ D-01", 2, 2, 0.4)
		local m = ctx.model
		-- Inner blast door (decorative, closed) across the middle
		Builder.box(m, "BlastDoor", ctx.cframe * CFrame.new(0, 5, -6), Vector3.new(12, 10, 1.2), Enum.Material.Metal, P.SteelPainted)
		Props.securityDoorFrame(m, ctx.cframe * CFrame.new(0, 0, -6), 12, 10)
		local cf = ctx.cframe * CFrame.new(9, 0, -5.3)
		local panel = Props.doorPanel(m, cf, "LOCK FAULT")
		panel.Name = "AirlockPanel"
		Common.marker(ctx, "TaskTarget", cf * CFrame.new(0, 3, -4), { Kind = "DoorRepair", TargetName = "AirlockPanel" })
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 11, -5.3), "ИЗОЛЯЦИОННЫЙ СЕКТОР · ДОПУСК 03", P.Red)
		for _, x in { -14, 14 } do
			Props.camera(m, ctx.cframe * CFrame.new(x, 10.5, 16) * CFrame.Angles(0, math.pi, 0), "D-01")
		end
		Props.debrisPile(m, ctx.cframe * CFrame.new(-10, 0, 10))
		Common.docSpot(ctx, ctx.cframe * CFrame.new(12, 0.1, 10))
		Common.roomPatrol(ctx, 1)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(0, 3, 10))
		local lights = m:FindFirstChild("Lights") :: Folder
		for _, lamp in lights:GetChildren() do
			local neon = lamp:FindFirstChild("Lamp")
			if neon and ctx.rng:chance(0.5) then
				neon:SetAttribute("Flicker", true)
			end
		end
	end,
})

add({
	id = "D_Monitoring", sector = "D", kind = "room", name = "Пост наблюдения D", tags = { "monitoring" }, weight = 1,
	build = function(ctx)
		roomBase(ctx, "ПОСТ D-02", 1, 2, 0.4)
		local m = ctx.model
		Props.terminal(m, ctx.cframe * CFrame.new(-8, 0, -12), "ISOLATION CTRL\n> cell 1: OPEN ?\n> cell 2: ---\n> lock: MANUAL OVERRIDE", P.Orange)
		Props.desk(m, ctx.cframe * CFrame.new(0, 0, -12), true)
		Props.chair(m, ctx.cframe * CFrame.new(0, 0, -9) * CFrame.Angles(0, math.pi, 0))
		Props.locker(m, ctx.cframe * CFrame.new(14, 0, -12) * CFrame.Angles(0, math.pi / 2, 0), P.Red:Lerp(P.WarningBlack, 0.6), "SEC")
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 8, -17.3), "НЕ ОТКРЫВАТЬ БЕЗ СОПРОВОЖДЕНИЯ", P.Red)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(1.4, 3.1, -12.4))
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "D_Containment", sector = "D", kind = "room", name = "Камера содержания", tags = { "containment" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "КАМЕРА D-03", 1, 1, 0.3)
		local m = ctx.model
		Props.glassWall(m, ctx.cframe * CFrame.new(0, 0, -6), 24, 10)
		Builder.box(m, "CellFloor", ctx.cframe * CFrame.new(0, 0.1, -13), Vector3.new(24, 0.2, 12), Enum.Material.SmoothPlastic, P.LabWhite:Lerp(P.WarningBlack, 0.3))
		Builder.box(m, "Restraint", ctx.cframe * CFrame.new(0, 1.5, -14), Vector3.new(3, 3, 6), Enum.Material.Metal, P.SteelPainted)
		-- Broken glass shards: glass wall has a hole
		local glass = m:FindFirstChild("GlassPartition") :: Model
		local g = glass.PrimaryPart :: Part
		g.Size = Vector3.new(14, g.Size.Y, 0.3)
		g.CFrame = g.CFrame * CFrame.new(-5, 0, 0)
		Props.debrisPile(m, ctx.cframe * CFrame.new(8, 0, -3))
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 11, -5.8), "ИЗОЛЯЦИЯ НАРУШЕНА", P.Red)
		Common.emergencyLights(ctx)
		Common.docSpot(ctx, ctx.cframe * CFrame.new(-8, 0.1, 6))
		Common.roomPatrol(ctx, 1)
		Common.marker(ctx, "WardenSpawn", ctx.cframe * CFrame.new(0, 3, -12))
		local lights = m:FindFirstChild("Lights") :: Folder
		local lamp = lights:GetChildren()[1]
		if lamp then
			local neon = lamp:FindFirstChild("Lamp")
			if neon then
				neon:SetAttribute("Flicker", true)
			end
		end
	end,
})

add({
	id = "D_Corridor", sector = "D", kind = "corridor", name = "Коридор D", tags = {}, weight = 2,
	build = function(ctx)
		Common.corridor(ctx, "СЕКТОР D · ДОПУСК 03")
		local m = ctx.model
		for _, lamp in (m:FindFirstChild("Lights") :: Folder):GetChildren() do
			local neon = lamp:FindFirstChild("Lamp") :: Part?
			if neon then
				neon.Color = Common.style("D").light
				local pl = neon:FindFirstChildOfClass("PointLight")
				if pl then
					pl.Brightness = 0.45
					pl.Color = neon.Color
				end
			end
		end
	end,
})

------------------------------------------------------------------------------
-- SECTOR E — evacuation
------------------------------------------------------------------------------
add({
	id = "E_Loading", sector = "E", kind = "room", name = "Погрузочный коридор", tags = { "loading" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ПОГРУЗКА E-01", 2, 2, 0.7)
		local m = ctx.model
		for _ = 1, 5 do
			local x, z = ctx.rng:nextNumber(-14, 14), ctx.rng:nextNumber(-14, 14)
			if not Common.laneBlocked(ctx, x, z) then
				Props.crate(m, ctx.cframe * CFrame.new(x, 0, z), ctx.rng:nextNumber(3, 5), P.Orange:Lerp(P.WarningBlack, 0.5))
			end
		end
		Builder.hazardStripes(m, ctx.cframe * CFrame.new(0, 0.03, 0), 30, 1)
		Props.cart(m, ctx.cframe * CFrame.new(-12, 0, 12))
		Props.warningSign(m, ctx.cframe * CFrame.new(0, 9, -17.3), "→ ЭВАКУАЦИОННЫЙ ШЛЮЗ E-1", P.Orange)
		Common.roomPatrol(ctx, 2)
	end,
})

add({
	id = "E_Airlock", sector = "E", kind = "room", name = "Эвакуационный шлюз", tags = { "evac" }, weight = 1, unique = true,
	build = function(ctx)
		roomBase(ctx, "ШЛЮЗ E-1 · ВЫХОД", 2, 2, 0.8)
		local m = ctx.model
		-- Shutter at the north wall (closed until evacuation completes)
		local shutter = Builder.box(m, "EvacShutter", ctx.cframe * CFrame.new(0, 5, -17), Vector3.new(14, 10, 1.5), Enum.Material.DiamondPlate, P.SteelPainted)
		shutter:SetAttribute("Closed", true)
		Props.securityDoorFrame(m, ctx.cframe * CFrame.new(0, 0, -17), 14, 10)
		-- Beyond the shutter: short tunnel with light (destination)
		Builder.box(m, "TunnelFloor", ctx.cframe * CFrame.new(0, -0.5, -24), Vector3.new(14, 1, 14), Enum.Material.DiamondPlate, P.RubberFloor)
		Builder.box(m, "TunnelCeil", ctx.cframe * CFrame.new(0, 12.5, -24), Vector3.new(14, 1, 14), Enum.Material.Concrete, P.ConcreteDark)
		Builder.box(m, "TunnelL", ctx.cframe * CFrame.new(-7.5, 6, -24), Vector3.new(1, 12, 14), Enum.Material.Concrete, P.ConcreteDark)
		Builder.box(m, "TunnelR", ctx.cframe * CFrame.new(7.5, 6, -24), Vector3.new(1, 12, 14), Enum.Material.Concrete, P.ConcreteDark)
		Builder.box(m, "TunnelEnd", ctx.cframe * CFrame.new(0, 6, -31.5), Vector3.new(14, 12, 1), Enum.Material.Concrete, P.ConcreteDark)
		local exitLight = Builder.ceilingLamp(m, ctx.cframe * CFrame.new(0, 11.7, -24), Vector3.new(6, 0.2, 2), P.LightWarm, 24, 1.4)
		exitLight.Name = "ExitLamp"
		Builder.signPlate(m, ctx.cframe * CFrame.new(0, 10.8, -16.1), 6, 1.2, "ВЫХОД", P.Green, Color3.new(1, 1, 1), 40)
		local cf = ctx.cframe * CFrame.new(11, 0, -14) * CFrame.Angles(0, 0, 0)
		local term = Props.terminal(m, cf, "EVAC CONTROL E-1\n> shutter: LOCKED\n> power: ---\n> transport: STANDBY", P.Orange)
		term.Name = "EvacTerminal"
		Common.marker(ctx, "TaskTarget", cf * CFrame.new(0, 3, -4), { Kind = "Evacuation", TargetName = "EvacTerminal" })
		Common.marker(ctx, "EvacZone", ctx.cframe * CFrame.new(0, 3, -24))
		Builder.hazardStripes(m, ctx.cframe * CFrame.new(0, 0.03, -15.5), 16, 1)
		for _, x in { -14, 14 } do
			Props.barrel(m, ctx.cframe * CFrame.new(x, 0, 12), P.Orange)
		end
		Common.roomPatrol(ctx, 1)
	end,
})

add({
	id = "E_Corridor", sector = "E", kind = "corridor", name = "Технический выход", tags = {}, weight = 2,
	build = function(ctx)
		Common.corridor(ctx, "→ ЭВАКУАЦИЯ E")
	end,
})

local ById: { [string]: ModuleDef } = {}
for _, def in Catalog do
	ById[def.id] = def
end

return { List = Catalog, ById = ById }
