--!nonstrict
-- Scripted dialogue: intro phone call, dispatcher briefings, final stinger.
-- Each line has a speaker, text, duration (seconds) and an optional voice hook
-- (SoundLibrary key + clip index). Voice ids are nil until audio is authored;
-- the client shows subtitles for the declared duration either way.
local Dialogue = {}

export type Line = { speaker: string, text: string, seconds: number, voice: string?, pauseAfter: number?, distort: boolean? }

Dialogue.IntroCall = {
	{ speaker = "Вы", text = "Алло?", seconds = 1.6, voice = "VoicePlayer" },
	{ speaker = "Звонящий", text = "Добрый вечер. Нам нужен сотрудник для технической экспедиции на антарктическую станцию «Восток-9».", seconds = 5.2, voice = "VoiceDispatcher" },
	{ speaker = "Вы", text = "Антарктида? Сейчас?", seconds = 2.0, voice = "VoicePlayer" },
	{ speaker = "Звонящий", text = "Срочная работа. Хорошая оплата. Выезд в ближайшее время. Подробности получите после прибытия.", seconds = 5.0, voice = "VoiceDispatcher" },
	{ speaker = "Вы", text = "И что мне нужно делать?", seconds = 2.0, voice = "VoicePlayer" },
	{ speaker = "Звонящий", text = "Проверять оборудование, помогать персоналу и соблюдать инструкции. Главное — не нарушайте правила станции.", seconds = 5.6, voice = "VoiceDispatcher", pauseAfter = 1.2 },
	{ speaker = "Вы", text = "Какие ещё правила?", seconds = 1.8, voice = "VoicePlayer" },
	{ speaker = "Звонящий", text = "Вы узнаете на месте.", seconds = 2.4, voice = "VoiceDispatcher", distort = true, pauseAfter = 0.8 },
}

Dialogue.Arrival = {
	{ speaker = "Диспетчер", text = "«Восток-9», борт на подходе к площадке. Персонал станции на вызов не отвечает. Войдите через шлюз К-1 и доложите.", seconds = 6.5, voice = "VoiceDispatcher" },
	{ speaker = "Диспетчер", text = "Напоминаю регламент: после двадцати двух часов станционного времени — только спальный сектор.", seconds = 5.0, voice = "VoiceDispatcher" },
}

Dialogue.NightWarning = {
	{ speaker = "Диспетчер", text = "«Восток-9», до двадцати двух часов двадцать минут. Проверьте крышку генератора и возвращайтесь в К-2.", seconds = 5.5, voice = "VoiceDispatcher" },
}

Dialogue.Dawn = {
	{ speaker = "Диспетчер", text = "«Восток-9», рассвет. Борт заходит на площадку. У вас две минуты. Выходите к огням.", seconds = 5.5, voice = "VoiceDispatcher" },
}

Dialogue.Final = {
	{ speaker = "Радио", text = "Станция «Восток-9», приём. Мы приближаемся. Подготовьте помещение для новой группы.", seconds = 6.0, voice = "VoiceDispatcher", pauseAfter = 1.5 },
	{ speaker = "Радио", text = "Количество мест ограничено. Освободите свои.", seconds = 4.5, voice = "VoiceDispatcher", distort = true },
}

Dialogue.DeclineMessage = "Вы отказались от работы. Экспедиция на «Восток-9» отправится без вас. Перезайдите, если передумаете."

return Dialogue
