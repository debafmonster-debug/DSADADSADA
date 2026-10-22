--!nonstrict
-- Chapters and mission templates. A mission template describes what the layout
-- generator must place and which tasks become the main objective / optional / complication.

export type TaskSpec = { kind: string, sector: string, label: string }

export type MissionDef = {
	id: string,
	chapter: number,
	title: string,
	kind: string,
	danger: string,
	briefing: { string },
	warnings: { string },
	mainTask: TaskSpec,
	optionalTask: TaskSpec?,
	complication: string, -- "WardenRelease" | "CameraBlackout"
	evacuation: string,
	sectors: { string }, -- sectors that must appear
	documents: { string }, -- document ids that may spawn
	lockedSectors: { string },
}

export type ChapterDef = {
	index: number,
	title: string,
	summary: string,
	unlockRequires: { documents: number, chapter: number? },
	missions: { string },
}

local Missions: { [string]: MissionDef } = {
	ch1_last_shift = {
		id = "ch1_last_shift",
		chapter = 1,
		title = "Смена 17-A: Последняя смена",
		kind = "Восстановление питания",
		danger = "Низкий (по отчёту диспетчера)",
		briefing = {
			"Объект COMPLEX-17 перешёл в аварийный режим в 23:40. Диспетчер сообщает об отказе линии питания технического сектора.",
			"Задача: восстановить питание через распределительный щит сектора B и подтвердить состояние систем.",
			"После завершения работ вернуться к эвакуационному шлюзу сектора E и дождаться открытия.",
		},
		warnings = {
			"Журнал доступа за последние 6 часов содержит пропуски.",
			"Камеры сектора C частично не отвечают.",
			"Изоляционный сектор D закрыт. Доступ уровня 01 недействителен.",
		},
		mainTask = { kind = "PowerRestore", sector = "B", label = "Восстановить питание сектора B" },
		optionalTask = { kind = "CameraRepair", sector = "C", label = "Восстановить камеру наблюдения" },
		complication = "WardenRelease",
		evacuation = "Technical airlock E-1",
		sectors = { "A", "B", "C", "D", "E" },
		documents = { "doc_shift_report_41", "doc_access_log_mismatch", "doc_memo_cameras", "doc_note_tech_orlov" },
		lockedSectors = { "D" },
	},
	ch1_diagnostics = {
		id = "ch1_diagnostics",
		chapter = 1,
		title = "Смена 17-B: Диагностика",
		kind = "Диагностика оборудования",
		danger = "Низкий",
		briefing = {
			"Серверная сектора B выдаёт ошибки контроллера. Требуется диагностика компонентов и замена неисправного блока.",
			"Вентиляционная B-08 работает в нештатном режиме. При возможности выровнять давление.",
		},
		warnings = {
			"Персонал предыдущей смены не вышел на связь после 02:10.",
			"Запрещено открывать двери с маркировкой D-xx.",
		},
		mainTask = { kind = "Diagnostics", sector = "B", label = "Найти и заменить неисправный блок" },
		optionalTask = { kind = "Ventilation", sector = "B", label = "Выровнять давление вентиляции" },
		complication = "WardenRelease",
		evacuation = "Technical airlock E-1",
		sectors = { "A", "B", "C", "D", "E" },
		documents = { "doc_incident_0217", "doc_medical_kern", "doc_note_tech_orlov", "doc_protocol_black_excerpt" },
		lockedSectors = { "D" },
	},
	ch2_protocol_breach = {
		id = "ch2_protocol_breach",
		chapter = 2,
		title = "Смена 18-A: Нарушение протокола",
		kind = "Ремонт системы блокировки",
		danger = "Повышенный",
		briefing = {
			"Контрольный шлюз сектора D сообщает о повреждении панели блокировки. Требуется ремонт панели и проверка замка.",
			"Доступ в сектор D временно разрешён для технической группы.",
		},
		warnings = {
			"Изоляционные системы отключены вручную. Автор команды не установлен.",
			"В секторе D зафиксировано движение без идентификатора.",
		},
		mainTask = { kind = "DoorRepair", sector = "D", label = "Отремонтировать панель шлюза D" },
		optionalTask = { kind = "PowerRestore", sector = "B", label = "Восстановить резервное питание" },
		complication = "WardenRelease",
		evacuation = "Technical airlock E-1",
		sectors = { "A", "B", "C", "D", "E" },
		documents = { "doc_access_log_edited", "doc_memo_isolation_off", "doc_note_security" },
		lockedSectors = {},
	},
}

local Chapters: { ChapterDef } = {
	{
		index = 1,
		title = "Глава I — Последняя смена",
		summary = "Обычная ночная смена на объекте COMPLEX-17. Восстановление питания и первые несовпадения в журналах.",
		unlockRequires = { documents = 0 },
		missions = { "ch1_last_shift", "ch1_diagnostics" },
	},
	{
		index = 2,
		title = "Глава II — Нарушение протокола",
		summary = "Изоляционные системы отключены. Кто-то пытался открыть закрытый сектор.",
		unlockRequires = { documents = 2, chapter = 1 },
		missions = { "ch2_protocol_breach" },
	},
	{
		index = 3,
		title = "Глава III — Нижний сектор",
		summary = "Лаборатории под основным комплексом. (В разработке)",
		unlockRequires = { documents = 5, chapter = 2 },
		missions = {},
	},
	{
		index = 4,
		title = "Глава IV — Чёрный протокол",
		summary = "Почему объект нельзя просто отключить. (В разработке)",
		unlockRequires = { documents = 8, chapter = 3 },
		missions = {},
	},
}

return { Defs = Missions, Chapters = Chapters }
