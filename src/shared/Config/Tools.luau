--!nonstrict
-- Equipment: one personal tool per shift (chosen in the lobby) plus the
-- flashlight everyone carries. Consumables are inventory items validated by
-- EquipmentService. Capability values are read by prompts via ToolCap.
local Tools = {}

export type ToolDef = {
	id: string,
	name: string,
	description: string,
	color: Color3,
	accent: Color3,
	capabilities: { [string]: number },
	noise: number,
	useSound: string,
}

Tools.Defs = {
	Multimeter = {
		id = "Multimeter",
		name = "Мультиметр",
		description = "Проверка напряжения и прозвонка цепей. Ускоряет диагностику генератора и щита.",
		color = Color3.fromRGB(220, 170, 40),
		accent = Color3.fromRGB(40, 40, 44),
		capabilities = { probe_power = 1, read_voltage = 1, diagnose_fast = 1 },
		noise = 0.1,
		useSound = "ToolBeep",
	},
	RepairKit = {
		id = "RepairKit",
		name = "Ремонтный набор",
		description = "Ключи, изолента, хомуты. Ускоряет механический ремонт и замену компонентов.",
		color = Color3.fromRGB(180, 60, 40),
		accent = Color3.fromRGB(60, 60, 64),
		capabilities = { repair_speed = 1, fuse_swap = 1, component_swap = 1 },
		noise = 0.3,
		useSound = "ToolWrench",
	},
	Diagnostic = {
		id = "Diagnostic",
		name = "Диагностический прибор",
		description = "Считывает показатели систем и биометрию. Единственный способ надёжно проверить участника.",
		color = Color3.fromRGB(80, 140, 110),
		accent = Color3.fromRGB(30, 36, 34),
		capabilities = { sensor_check = 1, identity_check = 1, antenna_fast = 1 },
		noise = 0.1,
		useSound = "ToolBeep",
	},
	MedBag = {
		id = "MedBag",
		name = "Медицинская сумка",
		description = "Быстрее поднимает товарища и согревает при переохлаждении.",
		color = Color3.fromRGB(200, 200, 205),
		accent = Color3.fromRGB(190, 40, 40),
		capabilities = { revive_fast = 1, warm_ally = 1 },
		noise = 0.1,
		useSound = "ToolZip",
	},
}

Tools.Order = { "Multimeter", "RepairKit", "Diagnostic", "MedBag" }

-- Consumable / spare-part items. `stack` caps a player's count.
Tools.Items = {
	Fuse = { id = "Fuse", name = "Предохранитель", stack = 3 },
	Battery = { id = "Battery", name = "Аккумулятор фонаря", stack = 2 },
	Medkit = { id = "Medkit", name = "Аптечка", stack = 2 },
	SpareRelay = { id = "SpareRelay", name = "Реле напряжения", stack = 1 },
	SpareInjector = { id = "SpareInjector", name = "Топливный инжектор", stack = 1 },
	FuelCanister = { id = "FuelCanister", name = "Канистра топлива", stack = 1 },
}

Tools.ItemOrder = { "Fuse", "Battery", "Medkit", "SpareRelay", "SpareInjector", "FuelCanister" }

return Tools
