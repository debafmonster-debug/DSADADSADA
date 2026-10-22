--!nonstrict
-- Shift lifecycle: Prep -> Briefing -> Active -> (Incident) -> Evacuation ->
-- Results -> back to lobby. One shift per server in local mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local LayoutGenerator = require(script.Parent.LayoutGenerator)
local FacilityService = require(script.Parent.FacilityService)
local TaskService = require(script.Parent.TaskService)
local CreatureService = require(script.Parent.CreatureService)
local RescueService = require(script.Parent.RescueService)
local StoryService = require(script.Parent.StoryService)
local EquipmentService = require(script.Parent.EquipmentService)
local RewardService = require(script.Parent.RewardService)
local CommunicationService = require(script.Parent.CommunicationService)

export type Phase = "Idle" | "Prep" | "Briefing" | "Active" | "Evacuation" | "Results"

export type Shift = {
	id: string,
	missionId: string,
	mission: Missions.MissionDef,
	seed: number,
	difficulty: string,
	players: { Player },
	phase: Phase,
	startedAt: number,
	phaseAt: number,
	incident: boolean,
	evacStarted: number?,
	shutterOpen: boolean,
	evacuated: { [Player]: boolean },
	result: string?,
	map: FacilityService.MapHandle?,
	connections: { RBXScriptConnection | { Disconnect: (any) -> () } },
	objective: string,
}

local RoundManager = {}
RoundManager.ShiftEnded = Signal.new() :: Signal.Signal<Shift>
RoundManager.ReturnToLobby = Signal.new() :: Signal.Signal<Player>

local current: Shift? = nil
local loopThread: thread? = nil

local function inShift(player: Player): boolean
	local s = current
	return s ~= nil and table.find(s.players, player) ~= nil and s.phase ~= "Idle"
end
RoundManager.InShift = inShift

function RoundManager.Current(): Shift?
	return current
end

local function broadcastState(s: Shift)
	local payload = {
		phase = s.phase,
		missionId = s.missionId,
		title = s.mission.title,
		objective = s.objective,
		seed = s.seed,
		difficulty = s.difficulty,
		elapsed = os.clock() - s.startedAt,
		phaseElapsed = os.clock() - s.phaseAt,
		incident = s.incident,
		evacCountdown = if s.evacStarted and not s.shutterOpen then math.max(0, GameConfig.Round.EvacuationCountdown - (os.clock() - s.evacStarted)) else nil,
		shutterOpen = s.shutterOpen,
		tasks = TaskService.Snapshot(),
		timeLimit = GameConfig.Round.ShiftTimeLimit,
		players = (function()
			local list = {}
			for _, p in s.players do
				table.insert(list, { userId = p.UserId, name = p.DisplayName, downed = RescueService.IsDowned(p), eliminated = RescueService.IsEliminated(p), evacuated = s.evacuated[p] == true })
			end
			return list
		end)(),
	}
	for _, p in s.players do
		Net.event("RoundState"):FireClient(p, payload)
	end
end

local function setPhase(s: Shift, phase: Phase)
	s.phase = phase
	s.phaseAt = os.clock()
	broadcastState(s)
end

local function notifyAll(s: Shift, title: string, text: string, kind: string?)
	for _, p in s.players do
		Net.event("Notification"):FireClient(p, { title = title, text = text, kind = kind or "info" })
	end
end

local function difficultyFor(mission: Missions.MissionDef, count: number): string
	local level = mission.chapter -- 1 Normal, 2 Elevated, 3+ Critical
	if count >= 4 then
		level += 1
	end
	return if level <= 1 then "Normal" elseif level == 2 then "Elevated" else "Critical"
end

local function teleportToSpawns(s: Shift)
	local map = s.map :: FacilityService.MapHandle
	for i, p in s.players do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local cf = map.spawnPoints[((i - 1) % #map.spawnPoints) + 1] or CFrame.new(GameConfig.Grid.MapOrigin + Vector3.new(0, 4, 0))
		if hrp and hum then
			hum.Health = hum.MaxHealth
			hum.WalkSpeed = GameConfig.Character.WalkSpeed
			char:PivotTo(cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.pi, 0))
		end
	end
end

local function farthestWardenSpawn(s: Shift): Vector3
	local map = s.map :: FacilityService.MapHandle
	local best, bestD = nil, -1
	for _, spawn in map.wardenSpawns do
		local minD = math.huge
		for _, p in s.players do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				minD = math.min(minD, (hrp.Position - spawn).Magnitude)
			end
		end
		if minD > bestD then
			best, bestD = spawn, minD
		end
	end
	return best or (map.patrolPoints[#map.patrolPoints] or GameConfig.Grid.MapOrigin)
end

local function triggerIncident(s: Shift)
	if s.incident then
		return
	end
	s.incident = true
	FacilityService.SetAlarm(true)
	notifyAll(s, "ТРЕВОГА", "Нарушение изоляции в секторе D. Персоналу завершить работы и следовать к шлюзу E-1.", "danger")
	CreatureService.Spawn(farthestWardenSpawn(s), s.difficulty)
	-- Power flicker on alarm: brief blackout in research sector for drama.
	task.delay(1.5, function()
		if current == s then
			FacilityService.SetSectorPower("C", false)
			task.delay(6, function()
				if current == s then
					FacilityService.SetSectorPower("C", true)
				end
			end)
		end
	end)
	broadcastState(s)
end

local function wireEvacuation(s: Shift)
	local map = s.map :: FacilityService.MapHandle
	local evac = map.taskTargets.Evacuation
	if not evac then
		warn("[Round] no evacuation terminal")
		return
	end
	local body = (evac.model :: Model).PrimaryPart :: Part
	local prompt = Builder.prompt(body, "Активировать эвакуацию", "Терминал E-1", 2.5, Enum.KeyCode.E, 9)
	prompt:SetAttribute("UI", "Task")
	prompt:SetAttribute("HoldBase", 2.5)
	local held: { [Player]: number } = {}
	table.insert(s.connections, prompt.PromptButtonHoldBegan:Connect(function(p)
		held[p] = os.clock()
	end))
	table.insert(s.connections, prompt.Triggered:Connect(function(player)
		if current ~= s or not inShift(player) or not RescueService.IsActive(player) then
			return
		end
		if not held[player] or os.clock() - held[player] < 2.3 then
			return
		end
		if s.evacStarted then
			return
		end
		if not TaskService.MainComplete() and not s.incident then
			Net.event("Notification"):FireClient(player, { title = "Терминал E-1", text = "Эвакуация недоступна: основная задача не выполнена.", kind = "warn" })
			return
		end
		if not FacilityService.IsPowered("E") then
			Net.event("Notification"):FireClient(player, { title = "Терминал E-1", text = "Нет питания шлюза.", kind = "warn" })
			return
		end
		s.evacStarted = os.clock()
		s.objective = "Дождаться открытия шлюза и собраться на площадке"
		prompt.Enabled = false
		local screen = (evac.model :: Model):FindFirstChild("Screen") :: Part?
		if screen then
			local lbl = (screen:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
			if lbl then
				lbl.Text = "EVAC CONTROL E-1\n> shutter: OPENING\n> transport: EN ROUTE\n> hold position"
			end
			screen.Color = Color3.fromRGB(60, 170, 90)
		end
		local s2 = Builder.sound(body, Sounds.Announce, "EvacAnnounce")
		s2:Play()
		FacilityService.Noise:Fire(body.Position, 40, player)
		notifyAll(s, "Эвакуация запущена", string.format("Шлюз откроется через %d с. Соберитесь на площадке E-1.", GameConfig.Round.EvacuationCountdown), "good")
		setPhase(s, "Evacuation")
	end))
end

local function finish(s: Shift, success: boolean, reason: string)
	if s.phase == "Results" or s.phase == "Idle" then
		return
	end
	s.result = reason
	setPhase(s, "Results")
	CreatureService.Despawn()
	FacilityService.SetAlarm(false)
	local mainDone = TaskService.MainComplete()
	local optionalDone = TaskService.OptionalComplete()
	local fullTeam = true
	for _, p in s.players do
		if p.Parent and not s.evacuated[p] then
			fullTeam = false
		end
	end
	local outcome: RewardService.Outcome = { success = success, mainDone = mainDone, optionalDone = optionalDone, fullTeamEvac = fullTeam, evacuated = s.evacuated }
	for _, p in s.players do
		if not p.Parent then
			continue
		end
		local reward = RewardService.Grant(p, s.id, s.missionId, s.seed, outcome)
		Net.event("Results"):FireClient(p, {
			success = success,
			reason = reason,
			title = s.mission.title,
			reward = reward.total,
			lines = reward.lines,
			documents = StoryService.FoundThisShift(p),
			duration = os.clock() - s.startedAt,
			seed = s.seed,
			evacuated = s.evacuated[p] == true,
			mainDone = mainDone,
			optionalDone = optionalDone,
		})
	end
	task.delay(GameConfig.Round.ResultsSeconds, function()
		if current == s then
			RoundManager.EndShift()
		end
	end)
end

local function activeLoop(s: Shift)
	while current == s and (s.phase == "Active" or s.phase == "Evacuation") do
		task.wait(1)
		local now = os.clock()
		if s.phase == "Active" then
			local elapsed = now - s.startedAt
			if not s.incident and (TaskService.MainProgress() >= GameConfig.Round.IncidentTriggerProgress or elapsed > 300) then
				triggerIncident(s)
			end
			if TaskService.MainComplete() and s.objective ~= "Добраться до шлюза E-1 и активировать эвакуацию" then
				s.objective = "Добраться до шлюза E-1 и активировать эвакуацию"
				notifyAll(s, "Задача выполнена", "Диспетчер: работы завершены. Следуйте к эвакуационному шлюзу E-1.", "good")
				if not s.incident then
					triggerIncident(s)
				end
			end
		elseif s.phase == "Evacuation" then
			local since = now - (s.evacStarted or now)
			if not s.shutterOpen and since >= GameConfig.Round.EvacuationCountdown then
				s.shutterOpen = true
				FacilityService.OpenEvacShutter()
				notifyAll(s, "Шлюз открыт", "Покиньте объект через шлюз E-1.", "good")
			end
			if s.shutterOpen then
				local map = s.map :: FacilityService.MapHandle
				local zone = map.evacZone
				local anyAlive = false
				local allIn = true
				for _, p in s.players do
					if not p.Parent or RescueService.IsEliminated(p) then
						continue
					end
					anyAlive = true
					local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if zone and hrp and (hrp.Position - zone).Magnitude <= GameConfig.Round.EvacuationZoneRadius and not RescueService.IsDowned(p) then
						if not s.evacuated[p] then
							s.evacuated[p] = true
							Net.event("Notification"):FireClient(p, { title = "Вы на площадке", text = "Ожидайте остальных членов команды.", kind = "good" })
						end
					elseif not s.evacuated[p] then
						allIn = false
					end
				end
				local anyEvac = next(s.evacuated) ~= nil
				if anyAlive and allIn then
					finish(s, true, "Команда эвакуирована")
					return
				end
				-- Transport leaves 60 s after the shutter opens if someone is aboard.
				if anyEvac and since >= GameConfig.Round.EvacuationCountdown + 60 then
					finish(s, true, "Транспорт отбыл. Не все успели.")
					return
				end
			end
		end
		if RescueService.AllOut(s.players) then
			finish(s, false, "Вся команда выведена из строя")
			return
		end
		if now - s.startedAt > GameConfig.Round.ShiftTimeLimit then
			finish(s, false, "Время смены истекло")
			return
		end
		local present = 0
		for _, p in s.players do
			if p.Parent then
				present += 1
			end
		end
		if present == 0 then
			RoundManager.EndShift()
			return
		end
		broadcastState(s)
	end
end

function RoundManager.StartShift(players: { Player }, missionId: string, seed: number?, shiftId: string?): (boolean, string?)
	if current and current.phase ~= "Idle" then
		return false, "Смена уже идёт"
	end
	local mission = Missions.Defs[missionId]
	if not mission then
		return false, "Неизвестная миссия"
	end
	local realSeed = seed or (os.time() % 1000000)
	local s: Shift = {
		id = shiftId or HttpService:GenerateGUID(false),
		missionId = missionId,
		mission = mission,
		seed = realSeed,
		difficulty = difficultyFor(mission, #players),
		players = table.clone(players),
		phase = "Prep",
		startedAt = os.clock(),
		phaseAt = os.clock(),
		incident = false,
		evacStarted = nil,
		shutterOpen = false,
		evacuated = {},
		result = nil,
		map = nil,
		connections = {},
		objective = mission.mainTask.label,
	}
	current = s
	local layout, log = LayoutGenerator.generate(realSeed, missionId)
	s.seed = layout.seed
	for _, line in log do
		print("[Layout] " .. line)
	end
	print(string.format("[Round] shift %s mission=%s seed=%d nodes=%d fallback=%s difficulty=%s", s.id, missionId, layout.seed, #layout.nodes, tostring(layout.fallback), s.difficulty))
	s.map = FacilityService.BuildMap(layout, layout.seed)
	TaskService.Setup(s.map, mission, s.difficulty, layout.seed)
	StoryService.PlaceDocuments(s.map, mission, layout.seed)
	wireEvacuation(s)
	for _, p in players do
		EquipmentService.Equip(p)
	end
	RescueService.BeginShift(players)
	CommunicationService.SetRecipientResolver(function()
		return s.players
	end)
	setPhase(s, "Prep")
	teleportToSpawns(s)
	for _, p in players do
		Net.event("Briefing"):FireClient(p, {
			title = mission.title,
			kind = mission.kind,
			danger = mission.danger,
			briefing = mission.briefing,
			warnings = mission.warnings,
			mainTask = mission.mainTask.label,
			optionalTask = if mission.optionalTask then mission.optionalTask.label else nil,
			evacuation = mission.evacuation,
			seconds = GameConfig.Round.BriefingSeconds,
		})
	end
	task.delay(GameConfig.Round.PrepSeconds, function()
		if current ~= s then
			return
		end
		setPhase(s, "Briefing")
		task.delay(GameConfig.Round.BriefingSeconds, function()
			if current ~= s then
				return
			end
			s.startedAt = os.clock()
			setPhase(s, "Active")
			notifyAll(s, "Смена началась", mission.mainTask.label, "info")
			loopThread = task.spawn(activeLoop, s)
		end)
	end)
	return true, nil
end

function RoundManager.EndShift()
	local s = current
	if not s then
		return
	end
	for _, c in s.connections do
		c:Disconnect()
	end
	CreatureService.Despawn()
	RescueService.EndShift()
	TaskService.Clear()
	StoryService.ClearShift()
	FacilityService.ClearMap()
	CommunicationService.SetRecipientResolver(function()
		return Players:GetPlayers()
	end)
	s.phase = "Idle"
	current = nil
	for _, p in s.players do
		if p.Parent then
			EquipmentService.Unequip(p)
			Net.event("RoundState"):FireClient(p, { phase = "Idle" })
			RoundManager.ReturnToLobby:Fire(p)
		end
	end
	RoundManager.ShiftEnded:Fire(s)
	if loopThread then
		loopThread = nil
	end
end

function RoundManager.Init()
	RescueService.Configure(inShift, function(p)
		return EquipmentService.ActiveTool(p)
	end)
	TaskService.SetToolResolver(function(p)
		return EquipmentService.ActiveTool(p)
	end)
	TaskService.TaskCompleted:Connect(function(t)
		local s = current
		if not s then
			return
		end
		notifyAll(s, if t.isMain then "Основная задача выполнена" else "Дополнительная задача выполнена", t.label, "good")
		broadcastState(s)
	end)
	Net.func("ReturnToLobby").OnServerInvoke = function(player)
		local s = current
		if s and s.phase == "Results" and table.find(s.players, player) then
			RoundManager.EndShift()
			return Net.ok()
		end
		return Net.fail("not in results")
	end
	Players.PlayerRemoving:Connect(function(p)
		local s = current
		if s then
			local i = table.find(s.players, p)
			if i then
				table.remove(s.players, i)
				if #s.players == 0 then
					RoundManager.EndShift()
				end
			end
		end
	end)
end

function RoundManager.Start() end

return RoundManager
