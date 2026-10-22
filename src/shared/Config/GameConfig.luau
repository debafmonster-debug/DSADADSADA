--!nonstrict
-- Central tunables. Everything timing/balance related lives here so designers
-- can adjust the vertical slice without touching service code.
local GameConfig = {
	GameName = "NIGHT SHIFT: BLACKSITE",
	Version = "0.1.0",
	DataVersion = 1,

	-- Set to true only after the mission place is published and Teleport API is
	-- enabled. In Studio / single-place mode a shift runs inside the lobby server.
	UseTeleportForShifts = false,
	MissionPlaceId = 0,

	MaxShiftPlayers = 4,
	MinShiftPlayers = 1,

	Grid = {
		Cell = 40, -- studs per layout cell
		WallHeight = 12,
		WallThickness = 1,
		MapOrigin = Vector3.new(0, 0, 1200), -- far from the lobby
		LobbyOrigin = Vector3.new(0, 0, 0),
		CinemaOrigin = Vector3.new(-1600, 400, 0), -- client-local diorama sets for in-engine shorts
	},

	Character = {
		WalkSpeed = 11,
		SprintSpeed = 17,
		CrouchSpeed = 6,
		StaminaMax = 8, -- seconds of sprint
		StaminaRegenPerSecond = 1.6,
		HealthMax = 100,
	},

	Flashlight = {
		Range = 56,
		Angle = 42,
		Brightness = 2.4,
		BatterySeconds = 180,
		RechargeIdlePerSecond = 0.35,
	},

	Round = {
		PrepSeconds = 6,
		BriefingSeconds = 10,
		IncidentTriggerProgress = 0.4, -- fraction of main task progress that triggers the incident
		EvacuationCountdown = 45,
		EvacuationZoneRadius = 14,
		ResultsSeconds = 15,
		ShiftTimeLimit = 15 * 60,
	},

	Rescue = {
		DownedSeconds = 75,
		ReviveHoldSeconds = 5,
		ReviveHoldSecondsMedkit = 2.5,
		SelfRescueCharges = 1,
		SelfRescueHoldSeconds = 4,
		SelfRescueCooldownAfterUse = 9999,
		CrawlSpeed = 3.5,
		ReviveHealth = 45,
	},

	Warden = {
		WalkSpeed = 7,
		SearchSpeed = 9,
		ChaseSpeed = 15.5,
		ViewDistance = 48,
		ViewAngle = 95,
		HearDistanceWalk = 10,
		HearDistanceSprint = 34,
		HearDistanceTool = 26,
		AttackRange = 4.5,
		AttackCooldown = 2.2,
		AttackDamage = 60,
		LoseTargetSeconds = 4,
		SearchSeconds = 14,
		SuspicionSeconds = 2.2,
		PathRepathInterval = 0.6,
		PerceptionInterval = 0.2,
		StuckSeconds = 3,
		PatrolIdleSeconds = { 1.5, 4 },
		FlashlightNoticeMultiplier = 1.5,
	},

	Difficulty = {
		Normal = { wardenSpeedMult = 1.0, faultCount = 1, breakerSteps = 3, hearMult = 1.0 },
		Elevated = { wardenSpeedMult = 1.07, faultCount = 2, breakerSteps = 4, hearMult = 1.15 },
		Critical = { wardenSpeedMult = 1.12, faultCount = 3, breakerSteps = 5, hearMult = 1.3 },
	},

	Rewards = {
		MainObjective = 120,
		OptionalObjective = 45,
		FullTeamEvac = 60,
		FailurePenaltyFraction = 0.6,
		DocumentFound = 10,
	},

	Communication = {
		SignalCooldown = 2.5,
		SignalLifetime = 6,
	},

	Debug = {
		-- Developers flip this attribute on Workspace at runtime; off by default.
		AttributeName = "NS_DebugLayout",
	},
}

export type DifficultyName = "Normal" | "Elevated" | "Critical"

return GameConfig
