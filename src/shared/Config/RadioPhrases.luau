--!nonstrict
-- Preset radio phrases (players never type free text) and the scripted
-- dispatcher / creature reactions. Reactions are explicit rules: condition,
-- chance, effect, duration — never random mood.
local RadioPhrases = {}

export type Phrase = { id: string, text: string, reply: string?, nightReply: string?, reaction: string? }

RadioPhrases.List = {
	{ id = "hail", text = "Приём. Нас кто-нибудь слышит?", reply = "«Мирный-база» на связи. Слышим вас, «Восток-9». Доложите состояние.", nightReply = "«Мирный-база» на связи. Доложите состояние. Почему вы не в жилом секторе?" },
	{ id = "status_ok", text = "Генератор в норме, продолжаем работу.", reply = "Принято. Следующий сеанс через два часа." },
	{ id = "generator_damaged", text = "Генератор повреждён.", reply = "Принято. Запасные части в контейнере №2. Код — в журнале выдачи. Не оставляйте крышку открытой." },
	{ id = "evac", text = "Нам нужна эвакуация.", reply = "Борт сможет подойти только после рассвета. Держитесь. Соблюдайте регламент.", nightReply = "Посадка ночью невозможна. Оставайтесь в жилом секторе до 06:00." },
	{ id = "strange", text = "На станции происходит что-то странное.", reply = "Уточните. Технические неисправности или… что-то другое?", reaction = "attention" },
	{ id = "not_alone", text = "Мы здесь не одни.", reply = "…Повторите. Сколько человек в вашей группе?", reaction = "alert" },
	{ id = "identify", text = "Назовите себя.", reply = "Диспетчер Сафонов, «Мирный-база».", nightReply = "%s.", reaction = "echo" },
	{ id = "want", text = "Что вам от нас нужно?", reply = "Не понял вопроса. Повторите.", reaction = "attention" },
	{ id = "leave", text = "Оставьте нас в покое.", reply = "«Восток-9», уточните адресата.", reaction = "calm" },
	{ id = "repeat", text = "Повторите последнее сообщение.", reply = "Повторяю: подготовьте помещение. Количество мест ограничено.", nightReply = "Повторяю: не открывайте дверь." },
	{ id = "missing", text = "Один участник пропал.", reply = "Принято. Поиск только парами и до 22:00. Не выходите после." },
	{ id = "returning", text = "Мы возвращаемся в жилой сектор.", reply = "Принято. Пересчитайте людей на месте.", reaction = "calm" },
}

RadioPhrases.ById = {}
for _, p in RadioPhrases.List do
	RadioPhrases.ById[p.id] = p
end

-- Creature reactions keyed by phrase.reaction. `alertness` is added to the
-- Guest's activity level; `calmChance` instead suppresses it for `seconds`.
RadioPhrases.Reactions = {
	attention = { alertness = 0.15, seconds = 40 },
	alert = { alertness = 0.35, seconds = 60 },
	calm = { calmChance = 0.4, alertness = 0.2, seconds = 60 },
	echo = { alertness = 0.1, seconds = 30, echoCallsign = true }, -- at night the radio may answer with the caller's own callsign
}

return RadioPhrases
