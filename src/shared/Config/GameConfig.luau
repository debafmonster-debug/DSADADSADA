--!nonstrict
-- Central tunables for СТАНЦИЯ «ВОСТОК-9». Balance, timing and thresholds live
-- here so services stay free of magic numbers. Everything is server-authoritative
-- unless a section explicitly says it is a client presentation hint.
local GameConfig = {
	GameName = "СТАНЦИЯ «ВОСТОК-9»",
	GameNameEn = "VOSTOK-9: THE LAST EXPEDITION",
	Version = "0.2.0",
	DataVersion = 2,

	-- Cross-server mode. Both stay off until a mission place is published and
	-- the Teleport / MemoryStore APIs are enabled for the experience.
	UseTeleportForShifts = false,
	MissionPlaceId = 0,
	UseMemoryStoreRooms = false,

	MaxShiftPlayers = 4,
	MinShiftPlayers = 1,

	World = {
		LobbyOrigin = Vector3.new(0, 0, 0),
		StationOrigin = Vector3.new(0, 0, 1400),
		-- Client-only cinematic sets are built far away from both areas.
		ApartmentOrigin = Vector3.new(-1500, 400, -1500),
		AirfieldOrigin = Vector3.new(1500, 300, -1500),
	},

	Character = {
		WalkSpeed = 11,
		SprintSpeed = 16.5,
		CrouchSpeed = 6,
		StaminaMax = 8,
		StaminaRegenPerSecond = 1.5,
		HealthMax = 100,
		-- Server-side sanity bound for reported movement; above this the
		-- NoiseDirector treats the player as sprinting.
		SprintNoiseSpeed = 13.5,
	},

	Flashlight = {
		Range = 72,
		Angle = 32,
		Brightness = 2.6,
		FillRange = 16,
		FillBrightness = 0.3,
		BatterySeconds = 260,
		RechargeIdlePerSecond = 0, -- batteries are replaced, not recharged
		FrostDimBelowHeat = 40, -- client hint: below this body heat the lens frosts
		FrostDimMin = 0.55,
	},

	-- Station time. Shift starts in the evening; the clock runs faster at night
	-- so one shift lasts roughly 12-15 real minutes.
	Clock = {
		StartHour = 18.75,
		DayScale = 24, -- game seconds per real second before NightStart
		NightScale = 80,
		NightStart = 22,
		NightEnd = 6,
		NightWarningMinutes = 20,
	},

	Round = {
		BoardingSeconds = 26,
		ArrivalBriefingSeconds = 8,
		ResultsSeconds = 20,
		ShiftTimeLimit = 26 * 60,
		-- The first incident (generator fault) fires inside this station-time window
		-- unless the team already triggered it through tasks.
		IncidentWindowHours = { 20.0, 21.0 },
		EvacuationCountdown = 120,
		EvacuationZoneRadius = 16,
		HeadcountCooldown = 6,
	},

	Weather = {
		-- Visibility in studs is a target for the client fog tween; cooling multiplies
		-- the outdoor heat loss; windNoise scales hearing attenuation outdoors.
		States = {
			Calm = { visibility = 180, cooling = 1.0, wind = 0.2, snow = 0.1, label = "Спокойная полярная ночь" },
			LightSnow = { visibility = 120, cooling = 1.2, wind = 0.4, snow = 0.4, label = "Слабый снег" },
			Fog = { visibility = 70, cooling = 1.3, wind = 0.3, snow = 0.2, label = "Туман" },
			Blizzard = { visibility = 34, cooling = 2.0, wind = 0.9, snow = 1.0, label = "Плотная метель" },
			Whiteout = { visibility = 14, cooling = 2.7, wind = 1.0, snow = 1.0, label = "Экстремальная видимость" },
		},
		Order = { "Calm", "LightSnow", "Fog", "Blizzard", "Whiteout" },
		ChangeIntervalSeconds = { 75, 150 },
		TransitionSeconds = 25,
		StartState = "LightSnow",
	},

	Temperature = {
		Max = 100,
		Start = 100,
		OutdoorLossPerSecond = 1.05,
		IndoorHeatedGainPerSecond = 3.0,
		IndoorUnheatedGainPerSecond = 0.25,
		ShelterGainPerSecond = 0.5, -- unheated but windless (shed, warehouse, bunker)
		HeaterGainPerSecond = 5.0,
		HeaterRange = 10,
		ShiverBelow = 60,
		DisorientBelow = 35,
		CollapseBelow = 12,
		RecoverAbove = 30,
		TickSeconds = 1,
	},

	Power = {
		Capacity = 100,
		DegradedCapacity = 62,
		OverloadTripSeconds = 18,
		FlickerBeforeTripSeconds = 6,
		FuelStart = 100,
		FuelPerGameMinute = 0.28,
		FuelCanisterAmount = 45,
		LampOffStagger = 0.09, -- seconds between fixtures when a circuit dies
		-- Ordered for the breaker panel. Loads are in "kW" of a 100 kW generator.
		Circuits = {
			{ id = "LightsMain", label = "ОСВЕЩЕНИЕ К-1", load = 18, priority = 2, defaultOn = true },
			{ id = "LightsDorm", label = "ОСВЕЩЕНИЕ К-2", load = 9, priority = 2, defaultOn = true },
			{ id = "Heating", label = "ОТОПЛЕНИЕ", load = 34, priority = 1, defaultOn = true },
			{ id = "Radio", label = "РАДИОСВЯЗЬ", load = 7, priority = 1, defaultOn = true },
			{ id = "Scanner", label = "КОНТРОЛЬ ВХОДА", load = 4, priority = 1, defaultOn = true },
			{ id = "Floodlights", label = "ПРОЖЕКТОРЫ", load = 14, priority = 3, defaultOn = true },
			{ id = "Lab", label = "ЛАБОРАТОРИЯ", load = 19, priority = 3, defaultOn = false },
		},
		-- Generator components a fault can hit. Spare parts are inventory items.
		Components = {
			{ id = "Relay", label = "Реле напряжения", part = "SpareRelay" },
			{ id = "Injector", label = "Топливный инжектор", part = "SpareInjector" },
			{ id = "Fuse", label = "Главный предохранитель", part = "Fuse" },
		},
	},

	Guest = {
		WalkSpeed = 6.5,
		StalkSpeed = 8.5,
		ChaseSpeed = 15.5,
		ViewDistance = 58,
		ViewDistanceDark = 30,
		ViewAngle = 100,
		AttackRange = 5,
		AttackCooldown = 2.6,
		AttackDamage = 70,
		LoseTargetSeconds = 5,
		SearchSeconds = 16,
		ObserveSeconds = { 6, 14 },
		ObserveDistance = { 28, 50 },
		StalkDistance = 20,
		PerceptionInterval = 0.25,
		RepathInterval = 0.7,
		StuckSeconds = 3,
		PatrolIdleSeconds = { 2, 6 },
		IndoorAfterEscalation = true,
		FlashlightNoticeMultiplier = 1.4,
		SafeTeleportMinPlayerDistance = 70,
	},

	Noise = {
		WallAttenuation = 0.35, -- multiplier per solid hit between source and listener
		DoorAttenuation = 0.55,
		MemorySeconds = 25,
		SectorHeatDecayPerSecond = 0.015,
		SectorHeatPerEvent = 0.12,
		Sources = {
			Sprint = { loud = 0.55, radius = 34 },
			Walk = { loud = 0.12, radius = 9 },
			Door = { loud = 0.4, radius = 22 },
			DoorHeavy = { loud = 0.65, radius = 34 },
			Generator = { loud = 0.5, radius = 42 },
			Repair = { loud = 0.45, radius = 20 },
			Radio = { loud = 0.5, radius = 26 },
			Keypad = { loud = 0.2, radius = 10 },
			Hatch = { loud = 0.55, radius = 24 },
			Violation = { loud = 0.7, radius = 60 },
			Scanner = { loud = 0.35, radius = 18 },
		},
	},

	Identity = {
		OutsideSecondsForShadow = 55,
		ShadowChance = 0.55,
		CheckIntervalSeconds = 5,
		SpawnDistance = { 70, 110 },
		DespawnAfterDeniedSeconds = 30,
		InspectHoldSeconds = 3,
		MaxDoublesPerShift = 2,
		MinStationHour = 20.5, -- doubles never appear before this station time
	},

	Rescue = {
		DownedSeconds = 90,
		ReviveHoldSeconds = 5,
		ReviveHoldSecondsMedkit = 2.5,
		CrawlSpeed = 3.2,
		ReviveHealth = 45,
		ColdReviveHeat = 40,
	},

	Hallucination = {
		Stage1Distance = 150,
		Stage2Distance = 210,
		BlackoutDistance = 290,
		CheckIntervalSeconds = 1.5,
	},

	Warehouse = {
		MaxAttempts = 3,
		CodeLength = 4,
	},

	Bunker = {
		CornerRadius = 3.5,
		HatchOpenSeconds = 25,
	},

	Rewards = {
		TaskMain = 90,
		TaskOptional = 40,
		NightSurvived = 70,
		FullTeamEvac = 60,
		RescueAlly = 25,
		DocumentFound = 10,
		FailurePenaltyFraction = 0.6,
	},

	Communication = {
		SignalCooldown = 2.5,
		SignalLifetime = 6,
		RadioMinFreq = 2000,
		RadioMaxFreq = 9000,
		RadioFreqTolerance = 18,
		RadioSendCooldown = 4,
	},

	Footprints = {
		StrideStuds = 2.7,
		MaxPrints = 220,
		LifetimeSeconds = 150,
	},

	Debug = {
		AttributeName = "V9_Debug",
	},
}

export type DifficultyName = "Normal" | "Elevated" | "Critical"

return GameConfig
