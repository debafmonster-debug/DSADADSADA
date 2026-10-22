--!nonstrict
-- Primary tools. One is selected per shift in the equipment room. None are weapons.
export type ToolDef = {
	id: string,
	name: string,
	description: string,
	color: Color3,
	accent: Color3,
	-- which task actions this tool unlocks or speeds up
	capabilities: { [string]: number },
	noise: number, -- hearing radius multiplier when used
	useSound: string,
}

local Tools: { [string]: ToolDef } = {
	Multimeter = {
		id = "Multimeter",
		name = "Технический мультиметр",
		description = "Проверка электрических цепей. Показывает, какие линии щита под напряжением, и ускоряет диагностику питания.",
		color = Color3.fromRGB(230, 170, 40),
		accent = Color3.fromRGB(40, 40, 44),
		capabilities = { probe_power = 1, read_voltage = 1, repair_speed = 1 },
		noise = 0.6,
		useSound = "ToolBeep",
	},
	RepairKit = {
		id = "RepairKit",
		name = "Ремонтный набор",
		description = "Замена предохранителей и механический ремонт. Открывает быстрый вариант ремонта дверных панелей и вентиляции.",
		color = Color3.fromRGB(170, 50, 40),
		accent = Color3.fromRGB(60, 60, 60),
		capabilities = { fuse_swap = 1, repair_speed = 1.6, valve_force = 1 },
		noise = 1.4,
		useSound = "ToolWrench",
	},
	Scanner = {
		id = "Scanner",
		name = "Диагностический сканер",
		description = "Находит неисправные компоненты оборудования и считывает их состояние. Не обнаруживает существ.",
		color = Color3.fromRGB(60, 160, 220),
		accent = Color3.fromRGB(30, 34, 40),
		capabilities = { scan_component = 1, read_voltage = 0.5, camera_trace = 1 },
		noise = 0.5,
		useSound = "ToolBeep",
	},
	MedBag = {
		id = "MedBag",
		name = "Медицинская сумка",
		description = "Быстрее поднимает выведенных из строя коллег и даёт одну дополнительную инъекцию для самопомощи.",
		color = Color3.fromRGB(220, 220, 225),
		accent = Color3.fromRGB(200, 40, 40),
		capabilities = { revive_fast = 1, extra_stim = 1 },
		noise = 0.4,
		useSound = "ToolZip",
	},
	Analyzer = {
		id = "Analyzer",
		name = "Анализатор систем",
		description = "Проверка датчиков, давления вентиляции и технических узлов. Показывает целевые параметры систем.",
		color = Color3.fromRGB(90, 200, 120),
		accent = Color3.fromRGB(30, 36, 32),
		capabilities = { read_pressure = 1, sensor_check = 1, scan_component = 0.5 },
		noise = 0.5,
		useSound = "ToolBeep",
	},
}

local Order = { "Multimeter", "RepairKit", "Scanner", "MedBag", "Analyzer" }

return { Defs = Tools, Order = Order }
