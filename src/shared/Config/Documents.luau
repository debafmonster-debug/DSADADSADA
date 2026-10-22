--!nonstrict
-- Story documents found inside the complex. Each one carries real information.
export type DocumentDef = {
	id: string,
	kind: string, -- ShiftReport | AccessLog | Manual | Memo | Medical | Incident | Protocol | Note
	title: string,
	author: string,
	body: string,
	sector: string, -- preferred spawn sector
	chapter: number,
}

local Documents: { [string]: DocumentDef } = {
	doc_shift_report_41 = {
		id = "doc_shift_report_41",
		kind = "ShiftReport",
		title = "Отчёт о смене №41",
		author = "Ст. техник И. Орлов",
		sector = "A",
		chapter = 1,
		body = "22:05 — Принял смену. Питание в норме, вентиляция 1.02 бар.\n23:12 — Диспетчер запросил проверку щита B-2. Линия 3 нестабильна, заменил предохранитель.\n23:40 — Камера C-07 потеряла сигнал. Канал физически цел. Заявка передана в ночной отдел.\n00:30 — Слышал удары по трубам в сервисном коридоре. Обход ничего не показал. Записываю для порядка.",
	},
	doc_access_log_mismatch = {
		id = "doc_access_log_mismatch",
		kind = "AccessLog",
		title = "Журнал доступа — выдержка",
		author = "Система контроля доступа",
		sector = "A",
		chapter = 1,
		body = "01:02:14  D-01  ВХОД   ID 4471 (Кернер М.)\n01:02:14  D-01  ВЫХОД  ID 4471 (Кернер М.)\n01:17:50  D-01  ВХОД   ID ----  [ОШИБКА ИДЕНТИФИКАЦИИ]\n01:17:50  C-03  ВХОД   ID 4471 (Кернер М.)\n\nПримечание системы: временные отметки не совпадают с внутренними часами (+00:00:00 / −00:14:36).",
	},
	doc_memo_cameras = {
		id = "doc_memo_cameras",
		kind = "Memo",
		title = "Служебная записка: камеры сектора C",
		author = "Нач. безопасности Р. Велес",
		sector = "C",
		chapter = 1,
		body = "Всем сменам. Расхождения между записями камер C-05…C-09 и данными датчиков движения считать техническим артефактом. Заявки на проверку перенаправлять мне лично, а не в ночной отдел.\n\nНапоминаю: обсуждение содержимого записей вне служебной переписки запрещено.",
	},
	doc_note_tech_orlov = {
		id = "doc_note_tech_orlov",
		kind = "Note",
		title = "Записка на столе",
		author = "И. Орлов",
		sector = "B",
		chapter = 1,
		body = "Если читаешь это — не включай линию 4 без проверки изоляции D. Я три раза видел, как она сама включается после полуночи. Велес говорит — артефакт. Артефакты не оставляют следы на пыли.",
	},
	doc_incident_0217 = {
		id = "doc_incident_0217",
		kind = "Incident",
		title = "Отчёт о происшествии 02-17",
		author = "Дежурный инженер",
		sector = "B",
		chapter = 1,
		body = "02:10 — Потеря связи с группой обслуживания (2 чел.) в секторе B.\n02:16 — Срабатывание датчика давления в вентиляционной. Давление 0.61 бар.\n02:19 — Самопроизвольная разблокировка двери D-02. Команда на разблокировку в журнале отсутствует.\n02:31 — Один сотрудник обнаружен в сервисном коридоре. Второй не найден.\nСтатус: передано руководству. Объект переведён в аварийный режим.",
	},
	doc_medical_kern = {
		id = "doc_medical_kern",
		kind = "Medical",
		title = "Медицинская запись: Кернер М.",
		author = "Медпункт COMPLEX-17",
		sector = "C",
		chapter = 1,
		body = "Жалобы: нарушение сна, ощущение наблюдения в закрытых помещениях, провалы памяти длительностью до 15 минут.\nОбъективно: без особенностей.\nРекомендация: отстранить от работ в секторе D. Отклонено руководством (подпись Р. Велес).",
	},
	doc_protocol_black_excerpt = {
		id = "doc_protocol_black_excerpt",
		kind = "Protocol",
		title = "Протокол «Чёрный» — выдержка",
		author = "[ЗАСЕКРЕЧЕНО]",
		sector = "C",
		chapter = 1,
		body = "§3. При утрате контроля над объектом наблюдения запрещается полное обесточивание комплекса. Системы изоляции питаются от линии 4 и не имеют независимого резерва.\n§4. Персонал, допущенный к объекту наблюдения, не должен находиться в изоляционном секторе без включённого освещения.\n[страница повреждена]",
	},
	doc_access_log_edited = {
		id = "doc_access_log_edited",
		kind = "AccessLog",
		title = "Журнал доступа (изменённая копия)",
		author = "Система контроля доступа",
		sector = "A",
		chapter = 2,
		body = "Запись 01:17:50 удалена пользователем VELES_R.\nЗапись 02:19:03 изменена: «D-02 РАЗБЛОКИРОВКА (ручная)» → «D-02 ТЕХ. СБОЙ».\nКонтрольная сумма журнала не совпадает с резервной копией.",
	},
	doc_memo_isolation_off = {
		id = "doc_memo_isolation_off",
		kind = "Memo",
		title = "Распоряжение: отключение изоляции",
		author = "Р. Велес",
		sector = "D",
		chapter = 2,
		body = "Отключить системы изоляции сектора D на 20 минут для «калибровки датчиков». Контрольной группе покинуть сектор. Возражения не принимаются.\n\nПриписка карандашом: «Их не было 20 минут. Их не было 4 часа.»",
	},
	doc_note_security = {
		id = "doc_note_security",
		kind = "Note",
		title = "Записка охраны",
		author = "Пост D-01",
		sector = "D",
		chapter = 2,
		body = "Он не ломает двери. Он ждёт, пока их откроют. Не открывайте.",
	},
}

local Order = {
	"doc_shift_report_41", "doc_access_log_mismatch", "doc_memo_cameras", "doc_note_tech_orlov",
	"doc_incident_0217", "doc_medical_kern", "doc_protocol_black_excerpt",
	"doc_access_log_edited", "doc_memo_isolation_off", "doc_note_security",
}

return { Defs = Documents, Order = Order }
