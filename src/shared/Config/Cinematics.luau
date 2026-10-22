--!nonstrict
-- In-engine shorts ("мини-мультики"): a scripted camera over a code-built
-- diorama set, timed captions and cues. CinematicController plays them;
-- cinematic.spec checks that every shot/cue refers to a real stage/actor.
-- Camera positions are relative to the stage origin (floor-level center,
-- north = -Z); `pos` is where the camera is, `look` what it points at.

export type CamPoint = { pos: Vector3, look: Vector3 }
export type Caption = { at: number, text: string }
export type Cue = { at: number, kind: string, actor: string?, value: any? }
export type Shot = {
	stage: string,
	from: CamPoint,
	to: CamPoint,
	duration: number,
	fov: number?,
	fadeIn: number?,
	fadeOut: number?,
	black: boolean?, -- screen stays black (narration over darkness)
	captions: { Caption },
	cues: { Cue }?,
}
export type CinematicDef = {
	id: string,
	title: string,
	set: string, -- module name under ReplicatedStorage.Shared.Cinematics
	music: string?, -- SoundLibrary track forced for the duration
	lighting: { [string]: any }?, -- Lighting overrides (restored afterwards)
	shots: { Shot },
	titleCard: { lines: { string }, seconds: number }?,
}

local function cam(px: number, py: number, pz: number, lx: number, ly: number, lz: number): CamPoint
	return { pos = Vector3.new(px, py, pz), look = Vector3.new(lx, ly, lz) }
end

local Defs: { [string]: CinematicDef } = {}

-- Prologue: how the sample that became the Warden left Antarctica.
Defs.vostok = {
	id = "vostok",
	title = "Хроника: Станция Восток",
	set = "VostokStation",
	music = "MusicCinematic",
	lighting = {
		Ambient = Color3.fromRGB(44, 52, 70),
		OutdoorAmbient = Color3.fromRGB(30, 36, 54),
		Brightness = 0.8,
		FogColor = Color3.fromRGB(12, 16, 26),
		FogStart = 30,
		FogEnd = 230,
		ExposureCompensation = 0,
	},
	shots = {
		{
			stage = "Exterior",
			from = cam(-58, 16, 72, 0, 6, 0),
			to = cam(-44, 12, 62, 4, 6, -4),
			duration = 9,
			fov = 62,
			fadeIn = 1.8,
			captions = {
				{ at = 0.8, text = "Антарктида. Станция Восток. Полярная ночь." },
				{ at = 4.6, text = "3 488 метров над уровнем моря. Самое холодное место на Земле." },
			},
			cues = {
				{ at = 0, kind = "sound", actor = "CineWind", value = true },
				{ at = 0, kind = "snow", actor = "SnowExterior", value = true },
			},
		},
		{
			stage = "Exterior",
			from = cam(16, 4.5, 28, 0, 6, 6),
			to = cam(10, 4.2, 22, -1, 6.5, 6),
			duration = 7,
			fov = 50,
			captions = {
				{ at = 0.6, text = "Под станцией — почти четыре километра льда. Под ним — озеро, запертое миллион лет." },
			},
		},
		{
			stage = "Exterior",
			from = cam(12, 5, 8, 45, 18, -40),
			to = cam(18, 7, 2, 45, 22, -40),
			duration = 6,
			fov = 55,
			fadeOut = 0.6,
			captions = {
				{ at = 0.6, text = "Скважина 5Г. Январь 1998 года." },
			},
		},
		{
			stage = "Drill",
			from = cam(-9, 3, 11, 0, 7, 0),
			to = cam(-6, 5, 8, 0, 9, 0),
			duration = 10,
			fov = 60,
			fadeIn = 0.6,
			captions = {
				{ at = 0.6, text = "Бурение остановили на отметке 3 623 метра — в ста двадцати метрах над озером. Официально." },
				{ at = 5.8, text = "Неофициально — продолжили." },
			},
			cues = {
				{ at = 0, kind = "sound", actor = "CineWind", value = false },
				{ at = 0, kind = "sound", actor = "CineDrill", value = true },
				{ at = 0, kind = "spin", actor = "DrillWheel", value = 2.5 },
				{ at = 2, kind = "counter", actor = "DepthScreen", value = { from = 3623, to = 3650, seconds = 7, format = "ГЛУБИНА\n%s м" } },
				{ at = 7.5, kind = "flicker", actor = "DrillLamps", value = 1.5 },
			},
		},
		{
			stage = "Drill",
			from = cam(6, 4, 8, 12, 3.5, 4),
			to = cam(7.5, 3.5, 6, 12, 3, 4),
			duration = 6,
			fov = 48,
			fadeOut = 0.5,
			captions = {
				{ at = 0.6, text = "Керн 5Г-3650. Структуры, которых не должно быть во льду." },
			},
		},
		{
			stage = "Lab",
			from = cam(-8, 5.5, 8, 0, 4, 1),
			to = cam(-5, 5, 6, 0, 3.8, 0.5),
			duration = 9,
			fov = 55,
			fadeIn = 0.5,
			captions = {
				{ at = 0.6, text = "Образец не таял при плюс двадцати." },
				{ at = 4.6, text = "Он отвечал на свет." },
			},
			cues = {
				{ at = 0, kind = "sound", actor = "CineDrill", value = false },
				{ at = 0, kind = "pulse", actor = "Core", value = { base = 0.5, amp = 0.6, speed = 2.2 } },
				{ at = 5, kind = "surge", actor = "Core", value = 1.5 },
			},
		},
		{
			stage = "Lab",
			from = cam(-3.5, 4.8, -3.6, 0, 3.7, 0),
			to = cam(-2, 4.4, -2.6, 0, 3.7, 0.4),
			duration = 6,
			fov = 40,
			fadeOut = 0.5,
			captions = {
				{ at = 0.6, text = "Через три часа на станции погас свет." },
			},
			cues = {
				{ at = 1.2, kind = "surge", actor = "Core", value = 2 },
				{ at = 3.4, kind = "sound", actor = "CineRelay", value = true },
				{ at = 3.5, kind = "lightsOut", actor = "LabLamps" },
				{ at = 3.6, kind = "sound", actor = "CineSting", value = true },
				{ at = 3.8, kind = "emergency", actor = "LabEmergency", value = true },
			},
		},
		{
			stage = "Radio",
			from = cam(-6, 5.5, 6, 6, 4.5, -2),
			to = cam(-2.5, 5, 3, 7, 4.8, -2),
			duration = 10,
			fov = 55,
			fadeIn = 0.4,
			captions = {
				{ at = 1.0, text = "Последний сеанс связи — 02:10." },
				{ at = 6.4, text = "«Он знает, где мы.»" },
			},
			cues = {
				{ at = 0, kind = "lightsOut", actor = "RadioLamps" },
				{ at = 0, kind = "emergency", actor = "RadioEmergency", value = true },
				{ at = 0.5, kind = "type", actor = "RadioScreen", value = { text = "ВОСТОК → МИРНЫЙ  02:10\n> ОБРАЗЕЦ 5Г-3650 АКТИВЕН\n> ПОВТОРЯЮ: АКТИВЕН\n> ЗАПРАШИВАЕМ ЭВАКУАЦИЮ\n> ОН ЗНАЕТ, ГДЕ МЫ", cps = 16 } },
				{ at = 6.5, kind = "sound", actor = "CineStatic", value = true },
			},
		},
		{
			stage = "Radio",
			from = cam(3, 4.5, 7, 0, 5, -10),
			to = cam(2, 4.8, 4, 0, 5.5, -10),
			duration = 10,
			fov = 52,
			captions = {
				{ at = 1.4, text = "Дверь открылась сама." },
				{ at = 5.2, text = "Внутрь вошёл холод. И кто-то ещё." },
			},
			cues = {
				{ at = 0.3, kind = "snow", actor = "SnowDoor", value = true },
				{ at = 0.3, kind = "sound", actor = "CineWind", value = true },
				{ at = 1.0, kind = "reveal", actor = "Visitor", value = { seconds = 6, distance = 3.5 } },
				{ at = 5.5, kind = "turn", actor = "OperatorHead", value = { angle = 1.4, seconds = 0.9 } },
				{ at = 8.2, kind = "sound", actor = "CineBoom", value = true },
				{ at = 8.3, kind = "blackout" },
				{ at = 8.3, kind = "sound", actor = "CineStatic", value = false },
				{ at = 8.3, kind = "sound", actor = "CineWind", value = false },
			},
		},
		{
			stage = "Radio",
			from = cam(0, 5, 0, 0, 5, -10),
			to = cam(0, 5, 0, 0, 5, -10),
			duration = 5,
			black = true,
			captions = {
				{ at = 0.6, text = "Связь со станцией прервана. Спасательная группа нашла пустые модули и один вскрытый керн." },
			},
		},
	},
	titleCard = {
		lines = {
			"ОБРАЗЕЦ 5Г-3650 ПЕРЕВЕДЁН НА ОБЪЕКТ COMPLEX-17",
			"ОБОЗНАЧЕНИЕ: «СМОТРИТЕЛЬ»",
			"",
			"NIGHT SHIFT: BLACKSITE",
			"Пролог · Станция Восток",
		},
		seconds = 6.5,
	},
}

local CueKinds = { "sound", "snow", "spin", "counter", "flicker", "lightsOut", "emergency", "pulse", "surge", "type", "reveal", "turn", "blackout" }

local function duration(def: CinematicDef): number
	local total = 0
	for _, shot in def.shots do
		total += shot.duration
	end
	if def.titleCard then
		total += def.titleCard.seconds
	end
	return total
end

return { Defs = Defs, CueKinds = CueKinds, duration = duration }
