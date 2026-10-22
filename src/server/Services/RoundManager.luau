--!nonstrict
-- Shift orchestration: boarding → arrival → evening work → incident →
-- escalation → night rules → dawn evacuation → results. Wires every service
-- together for one shift and tears it all down afterwards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Chapters = require(ReplicatedStorage.Shared.Config.Chapters)
local Dialogue = require(ReplicatedStorage.Shared.Config.Dialogue)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Airfield = require(ReplicatedStorage.Shared.Scenes.Airfield)

local S = script.Parent
local ClockService = require(S.ClockService)
local WeatherService = require(S.WeatherService)
local FacilityService = require(S.FacilityService)
local PowerGridService = require(S.PowerGridService)
local NoiseDirector = require(S.NoiseDirector)
local TemperatureService = require(S.TemperatureService)
local CreatureService = require(S.CreatureService)
local IdentityService = require(S.IdentityService)
local EquipmentService = require(S.EquipmentService)
local TaskService = require(S.TaskService)
local WarehouseService = require(S.WarehouseService)
local BunkerService = require(S.BunkerService)
local CommunicationService = require(S.CommunicationService)
local StoryService = require(S.StoryService)
local EventDirector = require(S.EventDirector)
local RescueService = require(S.RescueService)
local RewardService = require(S.RewardService)
local FootprintService = require(S.FootprintService)

local R = GameConfig.Round

export type Phase = "Idle" | "Boarding" | "Arrival" | "Active" | "Evacuation" | "Results"
export type Shift = {
	id: string,
	shiftId: string,
	def: any,
	seed: number,
	players: { Player },
	phase: Phase,
	stage: string,
	startedAt: number,
	phaseAt: number,
	incident: boolean,
	escalated: boolean,
	nightSurvived: boolean,
	evacuated: { [Player]: boolean },
	evacCountdown: number?,
	plane: Model?,
	rescues: { [Player]: number },
	violations: { [Player]: number },
	warned: { [Player]: boolean },
	connections: { any },
	result: { success: boolean, reason: string }?,
}

local RoundManager = {}
RoundManager.ShiftEnded = Signal.new() :: Signal.Signal<Shift>
RoundManager.ReturnToLobby = Signal.new() :: Signal.Signal<Player>

local current: Shift? = nil

function RoundManager.Current(): Shift?
	return current
end

function RoundManager.InShift(player: Player): boolean
	return current ~= nil and table.find(current.players, player) ~= nil
end

local function shiftPlayers(): { Player }
	local out = {}
	if current then
		for _, p in current.players do
			if p.Parent == Players then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function notifyAll(payload)
	for _, p in shiftPlayers() do
		Net.event("Notification"):FireClient(p, payload)
	end
end

local function subtitlesAll(lines)
	for _, p in shiftPlayers() do
		Net.event("Subtitle"):FireClient(p, { lines = lines })
	end
end

local function snapshot(shift: Shift)
	local players = {}
	for _, p in shift.players do
		table.insert(players, {
			userId = p.UserId,
			name = p.DisplayName,
			downed = RescueService.IsDowned(p),
			eliminated = RescueService.IsEliminated(p),
			evacuated = shift.evacuated[p] == true,
			heat = math.floor(TemperatureService.Heat(p)),
			present = p.Parent == Players,
		})
	end
	return {
		phase = shift.phase,
		stage = shift.stage,
		shiftId = shift.shiftId,
		title = shift.def.title,
		seed = shift.seed,
		elapsed = os.clock() - shift.startedAt,
		clock = ClockService.Snapshot(),
		tasks = TaskService.Snapshot(),
		players = players,
		evacCountdown = shift.evacCountdown,
		incident = shift.incident,
		timeLimit = R.ShiftTimeLimit,
	}
end

local function broadcastState()
	if not current then
		return
	end
	local snap = snapshot(current)
	for _, p in shiftPlayers() do
		Net.event("RoundState"):FireClient(p, snap)
	end
end

local function setPhase(shift: Shift, phase: Phase, stage: string?)
	shift.phase = phase
	shift.phaseAt = os.clock()
	if stage then
		shift.stage = stage
	end
	broadcastState()
end

local function setStage(shift: Shift, stage: string)
	shift.stage = stage
	broadcastState()
end

-- ===== Wiring ==============================================================

local function wireServices(shift: Shift, map)
	local c = shift.connections
	local function noise(pos, source, player)
		NoiseDirector.Report(pos, source, player)
	end
	table.insert(c, FacilityService.Noise:Connect(noise))
	table.insert(c, PowerGridService.Noise:Connect(noise))
	table.insert(c, TaskService.Noise:Connect(noise))
	table.insert(c, WarehouseService.Noise:Connect(noise))
	table.insert(c, BunkerService.Noise:Connect(noise))
	table.insert(c, CommunicationService.Noise:Connect(noise))
	table.insert(c, IdentityService.Noise:Connect(noise))
	table.insert(c, TaskService.TaskCompleted:Connect(function(t)
		notifyAll({ title = "Задача выполнена", text = t.label, kind = "good" })
		broadcastState()
	end))
	table.insert(c, TaskService.AntennaAligned:Connect(function()
		CommunicationService.SetAntennaAligned(true)
	end))
	table.insert(c, CommunicationService.Contacted:Connect(function(_player)
		TaskService.OnRadioContact()
		shift.contacted = true
	end))
	table.insert(c, StoryService.DocumentRead:Connect(function(_player, docId)
		TaskService.OnDocumentRead(docId)
	end))
	table.insert(c, CreatureService.Interacted:Connect(function(kind, inst)
		if kind == "sabotage" then
			if PowerGridService.Sabotage() then
				notifyAll({ title = "Генератор", text = "Показатели резко изменились. Крышка была открыта.", kind = "danger" })
				TaskService.AddGeneratorRepair()
			end
		elseif kind == "knock" and inst then
			local leaf = inst:FindFirstChild("Leaf")
			if leaf then
				local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
				local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
				local s = Builder.sound(leaf, Sounds.Knock, "Knock")
				s:Play()
				task.delay(3, function()
					s:Destroy()
				end)
			end
		end
	end))
	table.insert(c, PowerGridService.GeneratorChanged:Connect(function(g)
		if g.fault and not shift.faultAnnounced then
			shift.faultAnnounced = true
			notifyAll({ title = "Генератор: нестабильные показатели", text = "Лампы мерцают. Проверьте генераторную.", kind = "warn" })
			TaskService.AddGeneratorRepair()
		end
		if not g.running and g.stopReason == "fuel" then
			notifyAll({ title = "Генератор остановлен", text = "Закончилось топливо. Канистра — на складе.", kind = "danger" })
		end
		if not g.fault then
			shift.faultAnnounced = false
		end
		TaskService.RefreshGenerator()
	end))
	table.insert(c, PowerGridService.CircuitChanged:Connect(function(id, on)
		if id == "Heating" then
			notifyAll({ title = if on then "Отопление включено" else "Отопление отключено", text = if on then "Помещения прогреваются." else "Корпуса начнут остывать.", kind = if on then "good" else "warn" })
		end
		local g = PowerGridService.Generator()
		FacilityService.SetStatusBoard({ "СОСТОЯНИЕ СИСТЕМ", "генератор: " .. (if g.running then "работает" else "СТОП"), "отопление: " .. (if PowerGridService.IsPowered("Heating") then "норма" else "НЕТ"), "связь: " .. (if PowerGridService.IsPowered("Radio") then "питание" else "НЕТ"), "контроль входа: " .. (if PowerGridService.IsPowered("Scanner") then "активен" else "ОТКЛ") })
	end))
	table.insert(c, RescueService.PlayerRevived:Connect(function(player, by)
		if by and by ~= player then
			shift.rescues[by] = (shift.rescues[by] or 0) + 1
		end
		broadcastState()
	end))
	table.insert(c, RescueService.PlayerDowned:Connect(function(player)
		notifyAll({ title = "Участник выведен из строя", text = player.DisplayName .. " нуждается в помощи.", kind = "danger" })
		broadcastState()
		if #shift.players == 1 then
			RescueService.GrantSelfCharge(player)
		end
	end))
	table.insert(c, ClockService.NightWarning:Connect(function()
		setStage(shift, "NightPrep")
		subtitlesAll(Dialogue.NightWarning)
		notifyAll({ title = "Скоро 22:00", text = "Проверьте крышку генератора, двери и людей. Возвращайтесь в К-2.", kind = "warn" })
	end))
	table.insert(c, ClockService.NightStarted:Connect(function()
		setStage(shift, "Night")
		notifyAll({ title = "22:00 — ночной регламент", text = "Выход из спального сектора запрещён. Пересчитайте участников.", kind = "danger" })
		CreatureService.SetIndoorAllowed(true)
		if not CreatureService.IsActive() then
			RoundManager.SpawnGuest(shift, map)
		end
	end))
	table.insert(c, ClockService.NightEnded:Connect(function()
		if shift.phase == "Active" then
			shift.nightSurvived = true
			RoundManager.BeginEvacuation(shift, map)
		end
	end))
	table.insert(c, IdentityService.Scanned:Connect(function(_player, ok, _reason)
		if not ok then
			shift.scannerDenials = (shift.scannerDenials or 0) + 1
		end
	end))
	table.insert(c, WarehouseService.LockedOut:Connect(function(_player)
		notifyAll({ title = "Склад заблокирован", text = "Три ошибки. Замок откроется только на следующий день.", kind = "danger" })
	end))
	table.insert(c, WarehouseService.Unlocked:Connect(function(player)
		notifyAll({ title = "Склад открыт", text = player.DisplayName .. " ввёл верный код.", kind = "good" })
	end))
end

function RoundManager.SpawnGuest(shift: Shift, map)
	if CreatureService.IsActive() then
		return
	end
	-- Spawn point farthest from everyone.
	local best, bestD = nil, -1
	for _, sp in map.guestSpawns do
		local d = math.huge
		for _, p in shiftPlayers() do
			local pos = FacilityService.PlayerPosition(p)
			if pos then
				d = math.min(d, (pos - sp).Magnitude)
			end
		end
		if d > bestD then
			best, bestD = sp, d
		end
	end
	if best then
		CreatureService.Spawn(best, map, shift.seed)
		CreatureService.SetIndoorAllowed(shift.escalated or ClockService.IsNight())
	end
end

-- ===== Start ===============================================================

function RoundManager.StartShift(players: { Player }, shiftId: string, seed: number?, roomId: string?): (boolean, string?)
	if current then
		return false, "Смена уже идёт"
	end
	local def = Chapters.Shifts[shiftId]
	if not def then
		return false, "Неизвестная смена"
	end
	local shift: Shift = {
		id = roomId or tostring(os.time()),
		shiftId = shiftId,
		def = def,
		seed = seed or (os.time() % 1000000),
		players = table.clone(players),
		phase = "Boarding",
		stage = "Boarding",
		startedAt = os.clock(),
		phaseAt = os.clock(),
		incident = false,
		escalated = false,
		nightSurvived = false,
		evacuated = {},
		evacCountdown = nil,
		plane = nil,
		rescues = {},
		violations = {},
		warned = {},
		connections = {},
		result = nil,
	}
	current = shift
	-- Boarding cinematic plays on every client while the server builds the map.
	local ids = {}
	for _, p in players do
		table.insert(ids, p.UserId)
	end
	for _, p in players do
		Net.event("Cinematic"):FireClient(p, { kind = "Boarding", players = ids, seconds = R.BoardingSeconds })
	end
	broadcastState()
	task.spawn(function()
		local ok, err = pcall(function()
			local map = FacilityService.BuildMap(shift.seed)
			RoundManager.Configure(shift, map)
		end)
		if not ok then
			warn("[Round] setup failed: " .. tostring(err))
			RoundManager.EndShift()
			return
		end
		local waited = os.clock() - shift.startedAt
		if waited < R.BoardingSeconds then
			task.wait(R.BoardingSeconds - waited)
		end
		if current ~= shift then
			return
		end
		RoundManager.Arrive(shift)
	end)
	return true, nil
end

function RoundManager.Configure(shift: Shift, map)
	local seed = shift.seed
	local inShift = function(p)
		return RoundManager.InShift(p)
	end
	PowerGridService.Configure({
		has = function(p, item)
			return EquipmentService.Has(p, item)
		end,
		consume = function(p, item)
			return EquipmentService.Consume(p, item)
		end,
		toolCap = function(p, cap)
			return EquipmentService.HasCap(p, cap)
		end,
	})
	PowerGridService.BindMap(map.root, map.point("BreakerPanel"), map.point("Generator"), map.generatorSoundParent)
	PowerGridService.StartShift(seed)
	NoiseDirector.Configure(function(pos)
		local z = FacilityService.ZoneAt(pos)
		return z and z.id or nil
	end, {})
	NoiseDirector.SetEnabled(true)
	TemperatureService.Configure({
		zoneOf = function(p)
			return FacilityService.PlayerZone(p)
		end,
		weatherCooling = function()
			return WeatherService.Def().cooling
		end,
		heatingPowered = function()
			return PowerGridService.IsPowered("Heating")
		end,
		exteriorDoorOpen = function(zoneId)
			return FacilityService.ExteriorDoorOpen(zoneId)
		end,
		heaters = function()
			return PowerGridService.Heaters()
		end,
		position = function(p)
			return FacilityService.PlayerPosition(p)
		end,
		isDowned = function(p)
			return RescueService.IsDowned(p)
		end,
	})
	TemperatureService.Begin(shift.players)
	CreatureService.SetLightResolver(function(zoneId)
		if zoneId == "Main" or zoneId == "Passage" then
			return PowerGridService.IsPowered("LightsMain")
		elseif zoneId == "Dorm" or zoneId == "Bunker" then
			return PowerGridService.IsPowered("LightsDorm")
		end
		return PowerGridService.IsPowered("Floodlights")
	end)
	IdentityService.Configure({
		scannerPowered = function()
			return PowerGridService.IsPowered("Scanner")
		end,
		stationHour = function()
			return ClockService.Hour()
		end,
		isNight = function()
			return ClockService.IsNight()
		end,
		weatherSeverity = function()
			return WeatherService.Def().wind
		end,
		toolCap = function(p, cap)
			return EquipmentService.HasCap(p, cap)
		end,
		inShift = inShift,
		creatureAlert = function(a)
			CreatureService.AddAlertness(a)
		end,
	})
	IdentityService.BeginShift(shift.players, map, seed)
	EquipmentService.Configure({
		inShift = inShift,
		warm = function(p, amount)
			TemperatureService.Warm(p, amount)
		end,
		revive = function(p, by)
			RescueService.Revive(p, by)
		end,
		isDowned = function(p)
			return RescueService.IsDowned(p)
		end,
	})
	for _, p in shift.players do
		EquipmentService.Equip(p)
	end
	EquipmentService.PlacePickups(map.root, map.itemSpots)
	WarehouseService.Configure({ inShift = inShift, stationDay = function()
		return ClockService.Day()
	end })
	WarehouseService.BeginShift(map, seed)
	BunkerService.Configure({ inShift = inShift, teamSize = function()
		return #shiftPlayers()
	end })
	BunkerService.BeginShift(map)
	CommunicationService.Configure({
		inShift = inShift,
		radioPowered = function()
			return PowerGridService.IsPowered("Radio")
		end,
		isNight = function()
			return ClockService.IsNight()
		end,
		weatherState = function()
			return WeatherService.Current()
		end,
		creatureAlert = function(a)
			CreatureService.AddAlertness(a)
		end,
		creatureCalm = function(s)
			CreatureService.Calm(s)
		end,
	})
	CommunicationService.SetRecipientResolver(function(_)
		return shiftPlayers()
	end)
	CommunicationService.BeginShift(map, seed)
	StoryService.Configure({ inShift = inShift })
	StoryService.PlaceDocuments(map, shift.def, { WarehouseCode = WarehouseService.Code(), RadioFrequency = tostring(CommunicationService.DispatcherFrequency()) })
	TaskService.Configure({
		inShift = inShift,
		notifyAll = notifyAll,
		teamNames = function()
			local names = {}
			for _, p in shift.players do
				table.insert(names, p.DisplayName)
			end
			return names
		end,
	})
	TaskService.Setup(map, shift.def, seed)
	EventDirector.Configure({
		stationHour = function()
			return ClockService.Hour()
		end,
		isNight = function()
			return ClockService.IsNight()
		end,
		escalated = function()
			return shift.escalated
		end,
		roomOccupied = function(roomId)
			for _, p in shiftPlayers() do
				local pos = FacilityService.PlayerPosition(p)
				if pos then
					if roomId == "Bunker" then
						local z = FacilityService.ZoneAt(pos)
						if z and z.id == "Bunker" then
							return true
						end
					else
						local r = FacilityService.RoomAt(pos)
						if r and r.id == roomId then
							return true
						end
					end
				end
			end
			return false
		end,
		anyPlayerNear = function(pos, r)
			for _, p in shiftPlayers() do
				local pp = FacilityService.PlayerPosition(p)
				if pp and (pp - pos).Magnitude <= r then
					return true
				end
			end
			return false
		end,
		teamPlayers = shiftPlayers,
	})
	EventDirector.BeginShift(map, shift.def, seed)
	RescueService.Configure(inShift, function(p)
		return EquipmentService.ActiveTool(p)
	end)
	RescueService.BeginShift(shift.players)
	FootprintService.Begin(map)
	WeatherService.StartShift(seed, function()
		return ClockService.IsNight()
	end)
	wireServices(shift, map)
	FacilityService.SetStatusBoard({ "СОСТОЯНИЕ СИСТЕМ", "генератор: работает", "отопление: норма", "связь: питание", "контроль входа: активен" })
end

function RoundManager.Arrive(shift: Shift)
	local map = FacilityService.Current()
	if not map then
		return
	end
	ClockService.StartShift()
	for i, p in shift.players do
		local char = p.Character
		if char then
			local cf = map.spawns[((i - 1) % #map.spawns) + 1]
			char:PivotTo(cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.pi / 2, 0))
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = hum.MaxHealth
				hum.WalkSpeed = GameConfig.Character.WalkSpeed
			end
		end
		Net.event("Cinematic"):FireClient(p, { kind = "Arrive" })
		Net.event("Briefing"):FireClient(p, { title = shift.def.title, kind = shift.def.kind, danger = shift.def.danger, briefing = shift.def.briefing, warnings = shift.def.warnings, tasks = TaskService.Snapshot(), seconds = R.ArrivalBriefingSeconds })
	end
	setPhase(shift, "Arrival", "Arrival")
	subtitlesAll(Dialogue.Arrival)
	task.delay(R.ArrivalBriefingSeconds, function()
		if current == shift then
			setPhase(shift, "Active", "Exploration")
			task.spawn(RoundManager.ActiveLoop, shift)
		end
	end)
end

-- ===== Active loop =========================================================

local function checkHallucinations(shift: Shift)
	local H = GameConfig.Hallucination
	local center = FacilityService.ToWorld(Station.StationCenter)
	local map = FacilityService.Current()
	for _, p in shiftPlayers() do
		if RescueService.IsDowned(p) or RescueService.IsEliminated(p) then
			continue
		end
		local pos = FacilityService.PlayerPosition(p)
		if not pos or FacilityService.ZoneAt(pos) then
			if shift.hallucination and shift.hallucination[p] and shift.hallucination[p] > 0 then
				shift.hallucination[p] = 0
				Net.event("Hallucination"):FireClient(p, { kind = "Stage", stage = 0 })
			end
			continue
		end
		local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
		local stage = if d > H.BlackoutDistance then 3 elseif d > H.Stage2Distance then 2 elseif d > H.Stage1Distance then 1 else 0
		shift.hallucination = shift.hallucination or {}
		if stage ~= (shift.hallucination[p] or 0) then
			shift.hallucination[p] = stage
			if stage == 3 and map then
				-- Blackout: wake up somewhere far, cold, needing the team.
				local pt = map.lostPoints[math.random(1, #map.lostPoints)]
				local char = p.Character
				if char then
					char:PivotTo(CFrame.new(pt + Vector3.new(0, 4, 0)))
				end
				TemperatureService.Warm(p, -100)
				TemperatureService.Warm(p, GameConfig.Temperature.DisorientBelow - 8)
				Net.event("Hallucination"):FireClient(p, { kind = "Blackout" })
				notifyAll({ title = "Участник пропал", text = p.DisplayName .. " не отвечает. Найдите его до 22:00.", kind = "danger" })
				shift.hallucination[p] = 0
			else
				Net.event("Hallucination"):FireClient(p, { kind = "Stage", stage = stage })
			end
		end
	end
end

local function checkNightRule(shift: Shift)
	if not ClockService.IsNight() then
		return
	end
	local now = os.clock()
	for _, p in shiftPlayers() do
		if RescueService.IsEliminated(p) then
			continue
		end
		if FacilityService.IsInNightSafeZone(p) then
			shift.violations[p] = nil
			shift.warned[p] = nil
			continue
		end
		local since = shift.violations[p]
		if not since then
			shift.violations[p] = now
			if not shift.warned[p] then
				shift.warned[p] = true
				Net.event("Notification"):FireClient(p, { title = "Нарушение ночного регламента", text = "После 22:00 нельзя покидать спальный сектор. Вернитесь в К-2.", kind = "danger" })
			end
		elseif now - since > 20 then
			shift.violations[p] = now
			local pos = FacilityService.PlayerPosition(p)
			if pos then
				NoiseDirector.Report(pos, "Violation", p)
				CreatureService.OnViolation(p)
			end
			Net.event("Notification"):FireClient(p, { title = "Вы снаружи сектора", text = "Что-то изменило маршрут. Возвращайтесь.", kind = "danger" })
		end
	end
end

function RoundManager.ActiveLoop(shift: Shift)
	local map = FacilityService.Current()
	local lastHalluc = 0
	while current == shift and (shift.phase == "Active" or shift.phase == "Evacuation") do
		task.wait(1)
		if current ~= shift then
			break
		end
		local now = os.clock()
		local hour = ClockService.Hour()
		-- Incident: generator fault in the configured window, or earlier if the team is fast.
		if shift.phase == "Active" and not shift.incident then
			local window = R.IncidentWindowHours
			if (hour >= window[1] and hour < 23) or (TaskService.MainProgress() >= 0.6 and hour >= window[1] - 0.75) then
				shift.incident = true
				setStage(shift, "Incident")
				PowerGridService.InjectFault(nil)
				RoundManager.SpawnGuest(shift, map)
				if WeatherService.Current() == "Calm" then
					WeatherService.Set("LightSnow")
				end
			end
		end
		if shift.incident and not shift.escalated and (now - shift.phaseAt > 25 or hour >= 21) then
			shift.escalated = true
			if shift.stage == "Incident" then
				setStage(shift, "Escalation")
			end
			CreatureService.SetIndoorAllowed(true)
		end
		if now - lastHalluc >= GameConfig.Hallucination.CheckIntervalSeconds then
			lastHalluc = now
			pcall(checkHallucinations, shift)
		end
		pcall(checkNightRule, shift)
		-- Evacuation handling
		if shift.phase == "Evacuation" and shift.evacCountdown then
			shift.evacCountdown = math.max(0, shift.evacCountdown - 1)
			for _, p in shiftPlayers() do
				local pos = FacilityService.PlayerPosition(p)
				if pos and not RescueService.IsDowned(p) and not RescueService.IsEliminated(p) and (pos - map.evacZone).Magnitude <= R.EvacuationZoneRadius then
					if not shift.evacuated[p] then
						shift.evacuated[p] = true
						notifyAll({ title = "На борту", text = p.DisplayName .. " поднялся в самолёт.", kind = "good" })
					end
				end
			end
			local allIn, anyIn = true, false
			for _, p in shiftPlayers() do
				if not RescueService.IsEliminated(p) then
					if shift.evacuated[p] then
						anyIn = true
					else
						allIn = false
					end
				end
			end
			if allIn and anyIn then
				RoundManager.Finish(shift, true, "Команда эвакуирована")
			elseif shift.evacCountdown <= 0 then
				if anyIn then
					RoundManager.Finish(shift, true, "Борт ушёл: часть команды осталась на станции")
				else
					RoundManager.Finish(shift, false, "Борт ушёл без вас")
				end
			end
		end
		-- Failure conditions
		if RescueService.AllOut(shiftPlayers()) and #shiftPlayers() > 0 then
			RoundManager.Finish(shift, false, "Вся команда выведена из строя")
		elseif now - shift.startedAt > R.ShiftTimeLimit then
			RoundManager.Finish(shift, false, "Смена затянулась: связь с базой потеряна")
		elseif #shiftPlayers() == 0 then
			RoundManager.EndShift()
		end
		broadcastState()
	end
end

function RoundManager.BeginEvacuation(shift: Shift, map)
	if shift.phase ~= "Active" then
		return
	end
	shift.evacCountdown = R.EvacuationCountdown
	-- The plane lands on the apron: everyone sees the same model.
	shift.plane = Airfield.buildPlane(map.root, CFrame.new(map.evacZone + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), true)
	setPhase(shift, "Evacuation", "Dawn")
	subtitlesAll(Dialogue.Dawn)
	notifyAll({ title = "Рассвет. Борт на площадке", text = string.format("Выходите к огням площадки. %d с.", R.EvacuationCountdown), kind = "good" })
	CreatureService.SetHunting(false)
	CreatureService.Calm(60)
end

-- ===== Finish / teardown ===================================================

function RoundManager.Finish(shift: Shift, success: boolean, reason: string)
	if shift.result then
		return
	end
	shift.result = { success = success, reason = reason }
	setPhase(shift, "Results", "Results")
	CreatureService.Despawn()
	local mainDone = TaskService.MainComplete()
	local optionalDone = true
	for _, t in TaskService.All() do
		if t.optional and t.status ~= "complete" then
			optionalDone = false
		end
	end
	local fullTeam = true
	for _, p in shift.players do
		if p.Parent == Players and not shift.evacuated[p] then
			fullTeam = false
		end
	end
	local outcome: RewardService.Outcome = { success = success, mainDone = mainDone, optionalDone = optionalDone, nightSurvived = shift.nightSurvived, fullTeamEvac = fullTeam, evacuated = shift.evacuated, rescues = shift.rescues }
	for _, p in shiftPlayers() do
		local reward = RewardService.Grant(p, shift.id, shift.shiftId, shift.seed, outcome)
		Net.event("Results"):FireClient(p, {
			success = success,
			title = shift.def.title,
			reason = reason,
			duration = os.clock() - shift.startedAt,
			seed = shift.seed,
			mainDone = mainDone,
			optionalDone = optionalDone,
			nightSurvived = shift.nightSurvived,
			evacuated = shift.evacuated[p] == true,
			documents = StoryService.FoundThisShift(p),
			lines = reward.lines,
			reward = reward.total,
			seconds = R.ResultsSeconds,
		})
	end
	task.delay(R.ResultsSeconds, function()
		if current == shift then
			RoundManager.EndShift()
		end
	end)
end

function RoundManager.EndShift()
	local shift = current
	if not shift then
		return
	end
	current = nil
	for _, c in shift.connections do
		pcall(function()
			c:Disconnect()
		end)
	end
	CreatureService.Despawn()
	EventDirector.EndShift()
	IdentityService.EndShift()
	TaskService.Clear()
	StoryService.ClearShift()
	EquipmentService.ClearPickups()
	WarehouseService.EndShift()
	BunkerService.EndShift()
	CommunicationService.EndShift()
	CommunicationService.SetRecipientResolver(nil)
	RescueService.EndShift()
	TemperatureService.End()
	NoiseDirector.SetEnabled(false)
	FootprintService.End()
	PowerGridService.StopShift()
	WeatherService.StopShift()
	ClockService.StopShift()
	FacilityService.ClearMap()
	for _, p in shift.players do
		if p.Parent == Players then
			EquipmentService.Unequip(p)
			Net.event("RoundState"):FireClient(p, { phase = "Idle" })
			RoundManager.ReturnToLobby:Fire(p)
		end
	end
	RoundManager.ShiftEnded:Fire(shift)
end

function RoundManager.Init()
	Net.func("ReturnToLobby").OnServerInvoke = function(player)
		if not current or not RoundManager.InShift(player) then
			return Net.fail("Не в смене")
		end
		if current.phase ~= "Results" then
			return Net.fail("Смена ещё идёт")
		end
		local shift = current
		local i = table.find(shift.players, player)
		if i then
			table.remove(shift.players, i)
		end
		EquipmentService.Unequip(player)
		Net.event("RoundState"):FireClient(player, { phase = "Idle" })
		RoundManager.ReturnToLobby:Fire(player)
		if #shift.players == 0 then
			RoundManager.EndShift()
		end
		return Net.ok()
	end
	Players.PlayerRemoving:Connect(function(p)
		local shift = current
		if not shift then
			return
		end
		local i = table.find(shift.players, p)
		if i then
			table.remove(shift.players, i)
		end
		if #shift.players == 0 then
			RoundManager.EndShift()
		end
	end)
end

function RoundManager.Start() end

return RoundManager
