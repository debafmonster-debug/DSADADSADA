--!nonstrict
-- Story chapters and shift definitions. Chapter I is fully playable; later
-- chapters are declared so progression, archive and the briefing room can
-- reference them, but they carry no shifts yet (shown as "в разработке").
local Chapters = {}

export type TaskSpec = { kind: string, label: string, optional: boolean? }

export type ShiftDef = {
	id: string,
	chapter: number,
	title: string,
	kind: string,
	danger: string,
	briefing: { string },
	warnings: { string },
	tasks: { TaskSpec },
	documents: { string },
	events: { string },
}

Chapters.Shifts = {
	ch1_last_signal = {
		id = "ch1_last_signal",
		chapter = 1,
		title = "Последний сигнал",
		kind = "Техническая смена",
		danger = "Низкая",
		briefing = {
			"Станция «Восток-9» третий день не выходит на связь по основному каналу. Последняя телеметрия показывала просадку напряжения генератора.",
			"Ваша группа — техническая смена. Задача: проверить генератор, восстановить радиосвязь с диспетчером и выровнять антенну после шторма.",
			"Персонал станции должен находиться на месте. Если вы никого не встретите — действуйте по регламенту и ведите журнал.",
		},
		warnings = {
			"После 22:00 по станционному времени выход из спального сектора запрещён регламентом.",
			"Перед ночью проверьте, что защитная крышка генератора закрыта.",
			"На улице быстро теряется тепло. Возвращайтесь внутрь при первых признаках переохлаждения.",
		},
		tasks = {
			{ kind = "PowerCheck", label = "Проверить показатели генератора" },
			{ kind = "FuseReplace", label = "Заменить предохранитель в щитовой" },
			{ kind = "AntennaAlign", label = "Выровнять антенну" },
			{ kind = "RadioRestore", label = "Выйти на связь с диспетчером" },
			{ kind = "LogRetrieve", label = "Найти журнал бурения", optional = true },
		},
		documents = { "doc_duty_log", "doc_supply_journal", "doc_freq_journal", "doc_drill_log", "doc_note_wall", "doc_medical" },
		events = { "ExtraMug", "ChairMoved", "RadioCallsign", "DoorHandle", "FootstepsRoof" },
	},
	ch1_cold_watch = {
		id = "ch1_cold_watch",
		chapter = 1,
		title = "Холодная вахта",
		kind = "Ночное дежурство",
		danger = "Средняя",
		briefing = {
			"Диспетчер потерял связь со станцией через сорок минут после вашего последнего отчёта.",
			"Повторная смена: удержать генератор в рабочем состоянии до рассвета и не нарушать ночной регламент.",
		},
		warnings = {
			"Погода ухудшается. Наружные работы выполняйте парами.",
			"Если показания сканера на входе расходятся с числом людей в группе — не открывайте дверь вручную.",
		},
		tasks = {
			{ kind = "PowerCheck", label = "Проверить показатели генератора" },
			{ kind = "AntennaAlign", label = "Выровнять антенну" },
			{ kind = "RadioRestore", label = "Доложить диспетчеру" },
			{ kind = "FuseReplace", label = "Заменить предохранитель в щитовой", optional = true },
			{ kind = "LogRetrieve", label = "Найти журнал бурения", optional = true },
		},
		documents = { "doc_duty_log", "doc_supply_journal", "doc_freq_journal", "doc_drill_log", "doc_photo", "doc_medical" },
		events = { "ExtraMug", "ChairMoved", "RadioCallsign", "DoorHandle", "FootstepsRoof", "Reflection" },
	},
}

Chapters.List = {
	{ index = 1, title = "Глава I. Последний сигнал", summary = "Знакомство со станцией, генератором, радиосвязью и первыми аномалиями.", unlockRequires = { documents = 0 }, shifts = { "ch1_last_signal", "ch1_cold_watch" } },
	{ index = 2, title = "Глава II. Полярная ночь", summary = "Наружные работы, антенна, плохая видимость и первые опасные события.", unlockRequires = { documents = 3, chapter = 1 }, shifts = {} },
	{ index = 3, title = "Глава III. Неизвестный образец", summary = "Научный блок, архив и первые доказательства жизни подо льдом.", unlockRequires = { documents = 6, chapter = 2 }, shifts = {} },
	{ index = 4, title = "Глава IV. Глубокое бурение", summary = "Буровой комплекс, сбои оборудования и исчезновения.", unlockRequires = { documents = 9, chapter = 3 }, shifts = {} },
	{ index = 5, title = "Глава V. Подо льдом", summary = "Нижние зоны и старые сооружения.", unlockRequires = { documents = 12, chapter = 4 }, shifts = {} },
	{ index = 6, title = "Глава VI. Предыдущий цикл", summary = "Подземный комплекс с датами, архивами и фотографиями.", unlockRequires = { documents = 15, chapter = 5 }, shifts = {} },
	{ index = 7, title = "Глава VII. Освободите свои места", summary = "Система двойников и условие выхода из петли.", unlockRequires = { documents = 18, chapter = 6 }, shifts = {} },
}

Chapters.ByIndex = {}
for _, ch in Chapters.List do
	Chapters.ByIndex[ch.index] = ch
end

-- Compatibility aliases used by data / matchmaking code.
Chapters.Defs = Chapters.Shifts
Chapters.Chapters = Chapters.ByIndex

return Chapters
