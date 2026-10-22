--!nonstrict
-- Server-authoritative technical tasks. Each task kind owns its state, wires
-- ProximityPrompts on the physical target and validates every step.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local FacilityService = require(script.Parent.FacilityService)
local P = Builder.Palette

export type TaskState = {
	id: string,
	kind: string,
	label: string,
	isMain: boolean,
	status: "active" | "complete" | "failed",
	progress: number,
	steps: { string },
	hint: string,
	sector: string,
	data: { [string]: any },
	prompts: { ProximityPrompt },
	connections: { RBXScriptConnection },
}

local TaskService = {}
TaskService.TaskCompleted = Signal.new() :: Signal.Signal<TaskState>
TaskService.ToolUsed = Signal.new() :: Signal.Signal<Player, string>

local tasks: { [string]: TaskState } = {}
local toolOf: (Player) -> string? = function(_: Player)
	return nil
end
local rng = SeededRandom.new(1)
local holdBegan: { [Player]: { [ProximityPrompt]: number } } = {}

function TaskService.SetToolResolver(fn: (Player) -> string?)
	toolOf = fn
end

local function hasCap(player: Player, cap: string): number
	local id = toolOf(player)
	local def = id and Tools.Defs[id]
	return if def then (def.capabilities[cap] or 0) else 0
end

local function broadcast(t: TaskState)
	Net.event("TaskUpdated"):FireAllClients({
		id = t.id,
		kind = t.kind,
		label = t.label,
		isMain = t.isMain,
		status = t.status,
		progress = t.progress,
		steps = t.steps,
		hint = t.hint,
		sector = t.sector,
	})
end

local function notify(player: Player, title: string, text: string, kind: string?)
	Net.event("Notification"):FireClient(player, { title = title, text = text, kind = kind or "info" })
end

local function near(player: Player, target: Instance, maxDist: number): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local pos = if target:IsA("BasePart") then target.Position elseif target:IsA("Model") and target.PrimaryPart then target.PrimaryPart.Position else nil
	if not pos then
		return false
	end
	return (hrp.Position - pos).Magnitude <= maxDist
end

local function playSound(parent: Instance, def: any)
	local s = Builder.sound(parent, def, "Fx")
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

-- Prompt with per-tool hold time. Client shortens the hold locally when it has
-- the capability; the server re-checks the real hold time on Triggered.
local function taskPrompt(t: TaskState, part: BasePart, action: string, object: string, baseHold: number, cap: string?, toolHold: number?, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Builder.prompt(part, action, object, baseHold, key, 9)
	prompt:SetAttribute("UI", "Task")
	prompt:SetAttribute("TaskId", t.id)
	prompt:SetAttribute("HoldBase", baseHold)
	if cap then
		prompt:SetAttribute("ToolCap", cap)
		prompt:SetAttribute("HoldTool", toolHold or baseHold)
	end
	table.insert(t.prompts, prompt)
	table.insert(t.connections, prompt.PromptButtonHoldBegan:Connect(function(player)
		holdBegan[player] = holdBegan[player] or {}
		holdBegan[player][prompt] = os.clock()
	end))
	return prompt
end

local function holdOk(player: Player, prompt: ProximityPrompt): boolean
	local base = prompt:GetAttribute("HoldBase") :: number? or 0
	if base <= 0 then
		return true
	end
	local cap = prompt:GetAttribute("ToolCap") :: string?
	local required = base
	if cap and hasCap(player, cap) > 0 then
		required = prompt:GetAttribute("HoldTool") :: number? or base
	end
	local began = holdBegan[player] and holdBegan[player][prompt]
	if not began then
		return false
	end
	return os.clock() - began >= required - 0.2
end

local function complete(t: TaskState)
	if t.status ~= "active" then
		return
	end
	t.status = "complete"
	t.progress = 1
	for _, p in t.prompts do
		p.Enabled = false
	end
	broadcast(t)
	TaskService.TaskCompleted:Fire(t)
end

local function setProgress(t: TaskState, p: number, hint: string?)
	t.progress = math.clamp(p, 0, 1)
	if hint then
		t.hint = hint
	end
	broadcast(t)
end

local function noise(player: Player, position: Vector3, radius: number)
	FacilityService.Noise:Fire(position, radius, player)
end

local function connectTriggered(t: TaskState, prompt: ProximityPrompt, fn: (Player) -> ())
	table.insert(t.connections, prompt.Triggered:Connect(function(player)
		if t.status ~= "active" then
			return
		end
		if not holdOk(player, prompt) then
			notify(player, "Слишком быстро", "Действие не было завершено.", "warn")
			return
		end
		local part = prompt.Parent :: BasePart
		if not near(player, part, 14) then
			return
		end
		fn(player)
	end))
end

------------------------------------------------------------------------------
-- PowerRestore: switch lines in the right order, then throw the main lever.
------------------------------------------------------------------------------
local function setupPowerRestore(t: TaskState, target: Instance, difficulty: string)
	local panel = target :: Model
	local switches = (panel:FindFirstChild("Switches") :: Folder):GetChildren()
	table.sort(switches, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	local steps = GameConfig.Difficulty[difficulty].breakerSteps
	local order = rng:shuffle({ 1, 2, 3, 4, 5 })
	local sequence = {}
	for i = 1, math.min(steps, #order) do
		table.insert(sequence, order[i])
	end
	t.data.sequence = sequence
	t.data.position = 0
	t.data.lever = false
	local title = panel:FindFirstChild("Title") :: Part
	local titleLabel = title:FindFirstChildOfClass("SurfaceGui") and (title:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
	-- The work order is partly legible: first step visible, rest requires probing.
	local function orderText(revealed: number): string
		local parts = {}
		for i, idx in sequence do
			table.insert(parts, if i <= revealed then "L" .. idx else "L?")
		end
		return "ЩИТ B-02 · ПОРЯДОК: " .. table.concat(parts, " → ")
	end
	if titleLabel then
		titleLabel.Text = orderText(1)
	end
	t.steps = { "Определить порядок включения линий", "Включить линии в правильном порядке", "Включить главный рубильник" }
	t.hint = "Порядок включения частично повреждён. Мультиметр покажет линии под напряжением."

	local function setLamp(sw: Instance, color: Color3)
		local lamp = sw:FindFirstChild("Lamp") :: Part?
		if lamp then
			lamp.Color = color
		end
	end
	local function resetAll()
		t.data.position = 0
		for _, sw in switches do
			sw:SetAttribute("On", false)
			setLamp(sw, P.Red)
		end
	end
	resetAll()
	for _, sw in switches do
		local part = sw :: Part
		local idx = part:GetAttribute("Index") :: number
		local prompt = taskPrompt(t, part, "Включить линию", "Линия L" .. idx, 0.6)
		connectTriggered(t, prompt, function(player)
			if t.data.lever then
				return
			end
			local expected = sequence[t.data.position + 1]
			noise(player, part.Position, 10)
			if part:GetAttribute("On") then
				notify(player, "Линия L" .. idx, "Уже включена.")
				return
			end
			if idx == expected then
				part:SetAttribute("On", true)
				setLamp(part, P.Green)
				t.data.position += 1
				playSound(part, Sounds.Switch)
				setProgress(t, 0.15 + 0.6 * (t.data.position / #sequence), if t.data.position == #sequence then "Все линии включены. Переведите главный рубильник." else "Линия L" .. idx .. " под нагрузкой.")
				if titleLabel then
					titleLabel.Text = orderText(math.min(#sequence, t.data.position + 1))
				end
			else
				-- Breaker trips: everything resets.
				playSound(part, Sounds.MetalHit)
				resetAll()
				noise(player, part.Position, 22)
				setProgress(t, 0.1, "Защита сработала: неверный порядок. Линии сброшены.")
				notify(player, "Сработала защита", "Линия L" .. idx .. " включена не по порядку. Щит сброшен.", "warn")
				if titleLabel then
					titleLabel.Text = orderText(1)
				end
			end
		end)
	end
	-- Multimeter probe reveals full order (capability probe_power).
	local body = panel.PrimaryPart :: Part
	local probe = taskPrompt(t, body, "Прозвонить щит", "Проверка мультиметром", 2.5, "probe_power", 1.5, Enum.KeyCode.F)
	connectTriggered(t, probe, function(player)
		if hasCap(player, "probe_power") <= 0 then
			notify(player, "Нужен мультиметр", "Без мультиметра порядок линий можно определить только опытным путём.", "warn")
			return
		end
		TaskService.ToolUsed:Fire(player, "Multimeter")
		if titleLabel then
			titleLabel.Text = orderText(#sequence)
		end
		notify(player, "Мультиметр", "Порядок линий определён: " .. table.concat(sequence, " → "):gsub("(%d)", "L%1"))
		setProgress(t, math.max(t.progress, 0.15), "Порядок известен. Включайте линии по порядку.")
	end)
	local lever = panel:FindFirstChild("MainLever") :: Part
	local leverPrompt = taskPrompt(t, lever, "Главный рубильник", "Подать питание", 1.2)
	connectTriggered(t, leverPrompt, function(player)
		if t.data.position < #sequence then
			playSound(lever, Sounds.UIError)
			notify(player, "Рубильник", "Не все линии включены. Подача питания невозможна.", "warn")
			return
		end
		t.data.lever = true
		lever.Color = P.Green
		playSound(lever, Sounds.PowerUp)
		noise(player, lever.Position, 30)
		FacilityService.SetSectorPower(t.sector, true)
		complete(t)
	end)
end

------------------------------------------------------------------------------
-- Diagnostics: scan racks, replace the faulty one, confirm at the terminal.
------------------------------------------------------------------------------
local function setupDiagnostics(t: TaskState, target: Instance, difficulty: string)
	local racks = {}
	for _, r in (target :: Folder):GetChildren() do
		if r:IsA("Model") then
			table.insert(racks, r)
		end
	end
	local faultCount = math.min(GameConfig.Difficulty[difficulty].faultCount, #racks)
	local shuffled = rng:shuffle(racks)
	local faulty: { [Model]: boolean } = {}
	for i = 1, faultCount do
		faulty[shuffled[i]] = true
	end
	t.data.faulty = faulty
	t.data.repaired = 0
	t.data.faultCount = faultCount
	t.data.scanned = {}
	t.steps = { "Просканировать узлы", "Заменить неисправные блоки (" .. faultCount .. ")", "Подтвердить на терминале" }
	t.hint = "Диагностический сканер ускоряет проверку узлов."
	for _, rack in racks do
		local body = rack.PrimaryPart :: Part
		local idx = rack:GetAttribute("Index")
		local scan = taskPrompt(t, body, "Сканировать", "Узел " .. tostring(idx), 4, "scan_component", 1.6)
		local replace = taskPrompt(t, body, "Заменить блок", "Узел " .. tostring(idx), 4, "repair_speed", 2.5, Enum.KeyCode.F)
		replace.Enabled = false
		connectTriggered(t, scan, function(player)
			TaskService.ToolUsed:Fire(player, "Scanner")
			noise(player, body.Position, 8)
			t.data.scanned[rack] = true
			local temp = if faulty[rack] then rng:nextInteger(66, 84) else rng:nextInteger(28, 41)
			if faulty[rack] then
				notify(player, "Узел " .. tostring(idx), string.format("Температура %d°C · ошибки шины · НЕИСПРАВЕН", temp), "warn")
				replace.Enabled = true
				scan.Enabled = false
				setProgress(t, math.max(t.progress, 0.3), "Неисправный узел найден. Замените блок.")
			else
				notify(player, "Узел " .. tostring(idx), string.format("Температура %d°C · в норме", temp))
				setProgress(t, math.max(t.progress, 0.1), nil)
			end
		end)
		connectTriggered(t, replace, function(player)
			if not faulty[rack] then
				return
			end
			faulty[rack] = false
			replace.Enabled = false
			t.data.repaired += 1
			playSound(body, Sounds.ToolWrench)
			noise(player, body.Position, 16)
			for _, d in rack:GetDescendants() do
				if d:GetAttribute("RackLed") and d:IsA("Part") then
					d.Color = P.Green
				end
			end
			setProgress(t, 0.3 + 0.5 * (t.data.repaired / faultCount), if t.data.repaired >= faultCount then "Все блоки заменены. Подтвердите на терминале." else "Блок заменён. Остались неисправные узлы.")
		end)
	end
	local terminal = target.Parent and target.Parent:FindFirstChild("Terminal")
	local termBody = terminal and (terminal :: Model).PrimaryPart
	if termBody then
		local confirm = taskPrompt(t, termBody, "Подтвердить диагностику", "Терминал B-06", 2)
		connectTriggered(t, confirm, function(player)
			if t.data.repaired < faultCount then
				notify(player, "Терминал", "Контроллер всё ещё сообщает об ошибках. Замените неисправные блоки.", "warn")
				return
			end
			playSound(termBody, Sounds.UIConfirm)
			complete(t)
		end)
	end
end

------------------------------------------------------------------------------
-- CameraRepair: find the dead channel, fix the camera, verify at terminal.
------------------------------------------------------------------------------
local function setupCameraRepair(t: TaskState, target: Instance, map: FacilityService.MapHandle)
	local terminal = target :: Model
	local cameras: { Model } = {}
	for _, handle in map.nodes do
		if handle.node.sector == t.sector then
			for _, d in handle.model:GetDescendants() do
				if d:IsA("Model") and d.Name == "Camera" and d.PrimaryPart then
					table.insert(cameras, d)
				end
			end
		end
	end
	if #cameras == 0 then
		complete(t)
		return
	end
	local faultyCam = rng:pick(cameras)
	t.data.faulty = faultyCam
	t.data.fixed = false
	t.data.channels = {}
	for i, cam in cameras do
		local ch = string.format("CH-%02d", i)
		cam:SetAttribute("Display", ch)
		table.insert(t.data.channels, { channel = ch, room = cam:GetAttribute("Channel"), ok = cam ~= faultyCam })
		local led = cam:FindFirstChild("Led", true) :: Part?
		if led then
			led.Color = if cam == faultyCam then P.Red else P.Green
		end
	end
	t.steps = { "Проверить каналы на терминале", "Найти и восстановить камеру", "Проверить результат на терминале" }
	t.hint = "Сканер определяет помещение камеры по номеру канала. Иначе ищите красный индикатор."
	for _, cam in cameras do
		local body = cam.PrimaryPart :: Part
		local fix = taskPrompt(t, body, "Восстановить соединение", "Камера " .. tostring(cam:GetAttribute("Display")), 3, "repair_speed", 2)
		connectTriggered(t, fix, function(player)
			noise(player, body.Position, 10)
			if cam ~= faultyCam then
				notify(player, "Камера", "Соединение в норме.")
				return
			end
			if t.data.fixed then
				return
			end
			t.data.fixed = true
			playSound(body, Sounds.ToolBeep)
			local led = cam:FindFirstChild("Led", true) :: Part?
			if led then
				led.Color = P.Green
			end
			for _, c in t.data.channels do
				c.ok = true
			end
			setProgress(t, 0.7, "Камера восстановлена. Проверьте канал на терминале.")
		end)
	end
	local termBody = terminal.PrimaryPart :: Part
	local check = taskPrompt(t, termBody, "Проверить каналы", "Терминал CCTV", 1.2)
	connectTriggered(t, check, function(player)
		TaskService.ToolUsed:Fire(player, "Terminal")
		if t.data.fixed then
			playSound(termBody, Sounds.UIConfirm)
			complete(t)
		else
			local reveal = hasCap(player, "camera_trace") > 0
			local lines = {}
			for _, c in t.data.channels do
				table.insert(lines, string.format("%s %s%s", c.channel, if c.ok then "LIVE" else "NO SIGNAL", if reveal and not c.ok then " · " .. tostring(c.room) else ""))
			end
			Net.event("Notification"):FireClient(player, { title = "CCTV MATRIX", text = table.concat(lines, "\n"), kind = "terminal" })
			setProgress(t, math.max(t.progress, 0.25), if reveal then "Помещение неисправной камеры определено." else "Канал без сигнала найден. Нужно найти камеру.")
		end
	end)
end

------------------------------------------------------------------------------
-- DoorRepair: swap four fuses in the airlock panel, then test the lock.
------------------------------------------------------------------------------
local function setupDoorRepair(t: TaskState, target: Instance)
	local panel = target :: Model
	local slots = (panel:FindFirstChild("Slots") :: Folder):GetChildren()
	t.data.state = {} -- per slot: 0 burnt, 1 empty, 2 new
	t.data.done = 0
	t.steps = { "Извлечь сгоревшие предохранители", "Установить новые предохранители", "Проверить замок" }
	t.hint = "Ремонтный набор ускоряет замену предохранителей."
	local screen = panel:FindFirstChild("Screen") :: Part
	local screenLabel = (screen:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
	for _, slot in slots do
		local part = slot :: Part
		local idx = part:GetAttribute("Index") :: number
		t.data.state[idx] = 0
		part.Color = Color3.fromRGB(70, 30, 20)
		local pull = taskPrompt(t, part, "Извлечь", "Предохранитель " .. idx, 1.5, "fuse_swap", 0.7)
		local insert = taskPrompt(t, part, "Установить", "Предохранитель " .. idx, 1.5, "fuse_swap", 0.7, Enum.KeyCode.F)
		insert.Enabled = false
		connectTriggered(t, pull, function(player)
			if t.data.state[idx] ~= 0 then
				return
			end
			t.data.state[idx] = 1
			part.Color = P.WarningBlack
			pull.Enabled = false
			insert.Enabled = true
			playSound(part, Sounds.ToolWrench)
			noise(player, part.Position, 9)
			setProgress(t, t.progress + 0.1, nil)
		end)
		connectTriggered(t, insert, function(player)
			if t.data.state[idx] ~= 1 then
				return
			end
			t.data.state[idx] = 2
			part.Color = P.Green:Lerp(P.WarningBlack, 0.3)
			insert.Enabled = false
			t.data.done += 1
			playSound(part, Sounds.Switch)
			noise(player, part.Position, 9)
			TaskService.ToolUsed:Fire(player, "RepairKit")
			setProgress(t, 0.1 + 0.7 * (t.data.done / #slots), if t.data.done >= #slots then "Предохранители заменены. Проверьте замок." else nil)
		end)
	end
	local test = taskPrompt(t, panel.PrimaryPart :: Part, "Проверить замок", "Панель шлюза", 3)
	connectTriggered(t, test, function(player)
		if t.data.done < #slots then
			notify(player, "Панель", "Не все предохранители заменены.", "warn")
			return
		end
		if screenLabel then
			screenLabel.Text = "LOCK OK"
		end
		screen.Color = P.Green
		playSound(screen, Sounds.PowerUp)
		noise(player, screen.Position, 14)
		FacilityService.UnlockSector("D")
		complete(t)
	end)
end

------------------------------------------------------------------------------
-- Ventilation: bring the pressure to 1.00 with a laggy valve, then lock it.
------------------------------------------------------------------------------
local function setupVentilation(t: TaskState, target: Instance)
	local valve = target :: Model
	local wheel = valve:FindFirstChild("Wheel") :: Part
	local gauge = valve:FindFirstChild("Gauge") :: Part
	local gaugeLabel = (gauge:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass("TextLabel")
	local start = if rng:chance(0.5) then rng:nextNumber(0.5, 0.7) else rng:nextNumber(1.3, 1.5)
	t.data.pressure = start
	t.data.target = 1.0
	t.steps = { "Проверить давление", "Довести давление до 1.00", "Зафиксировать клапан" }
	t.hint = "Показания манометра отстают от положения клапана. Анализатор показывает давление мгновенно."
	local function render()
		if gaugeLabel then
			gaugeLabel.Text = string.format("%.2f", t.data.pressure)
		end
		local diff = math.abs(t.data.pressure - t.data.target)
		gauge.Color = if diff <= 0.05 then P.Green elseif diff <= 0.2 then P.Yellow else P.PanelWhite
	end
	render()
	local function turn(player: Player, delta: number)
		t.data.pressure = math.clamp(t.data.pressure + delta, 0.2, 2.0)
		wheel.CFrame = wheel.CFrame * CFrame.Angles(delta * 6, 0, 0)
		playSound(wheel, Sounds.Relay)
		noise(player, wheel.Position, 8)
		if hasCap(player, "read_pressure") > 0 then
			render()
			TaskService.ToolUsed:Fire(player, "Analyzer")
		else
			task.delay(1.2, render) -- laggy gauge without the analyzer
		end
		setProgress(t, math.clamp(0.2 + 0.6 * (1 - math.abs(t.data.pressure - 1) / 0.5), 0.2, 0.8), nil)
	end
	local plus = taskPrompt(t, wheel, "Открыть (+)", "Клапан P-1", 0.4)
	local minus = taskPrompt(t, wheel, "Закрыть (−)", "Клапан P-1", 0.4, nil, nil, Enum.KeyCode.Q)
	connectTriggered(t, plus, function(player)
		turn(player, 0.1)
	end)
	connectTriggered(t, minus, function(player)
		turn(player, -0.1)
	end)
	local lock = taskPrompt(t, gauge, "Зафиксировать", "Манометр", 2, "read_pressure", 1)
	connectTriggered(t, lock, function(player)
		render()
		if math.abs(t.data.pressure - t.data.target) > 0.051 then
			notify(player, "Манометр", string.format("Давление %.2f — вне допуска (1.00 ± 0.05).", t.data.pressure), "warn")
			return
		end
		playSound(gauge, Sounds.UIConfirm)
		complete(t)
	end)
end

------------------------------------------------------------------------------

function TaskService.Setup(map: FacilityService.MapHandle, mission: any, difficulty: string, seed: number)
	TaskService.Clear()
	rng = SeededRandom.new(seed + 17)
	local function create(spec: any, isMain: boolean): TaskState?
		local target = map.taskTargets[spec.kind]
		if not target then
			warn("[Task] no target for " .. spec.kind)
			return nil
		end
		local t: TaskState = {
			id = spec.kind,
			kind = spec.kind,
			label = spec.label,
			isMain = isMain,
			status = "active",
			progress = 0,
			steps = {},
			hint = "",
			sector = target.node.node.sector,
			data = {},
			prompts = {},
			connections = {},
		}
		tasks[t.id] = t
		if spec.kind == "PowerRestore" then
			setupPowerRestore(t, target.model, difficulty)
			FacilityService.SetSectorPower(t.sector, false)
		elseif spec.kind == "Diagnostics" then
			setupDiagnostics(t, target.model, difficulty)
		elseif spec.kind == "CameraRepair" then
			setupCameraRepair(t, target.model, map)
		elseif spec.kind == "DoorRepair" then
			setupDoorRepair(t, target.model)
		elseif spec.kind == "Ventilation" then
			setupVentilation(t, target.model)
		else
			warn("[Task] unknown kind " .. spec.kind)
		end
		broadcast(t)
		return t
	end
	create(mission.mainTask, true)
	if mission.optionalTask then
		create(mission.optionalTask, false)
	end
end

function TaskService.Clear()
	for _, t in tasks do
		for _, c in t.connections do
			c:Disconnect()
		end
	end
	table.clear(tasks)
	table.clear(holdBegan)
end

function TaskService.All(): { [string]: TaskState }
	return tasks
end

function TaskService.MainComplete(): boolean
	for _, t in tasks do
		if t.isMain and t.status ~= "complete" then
			return false
		end
	end
	return true
end

function TaskService.OptionalComplete(): boolean
	for _, t in tasks do
		if not t.isMain and t.status ~= "complete" then
			return false
		end
	end
	return true
end

function TaskService.MainProgress(): number
	for _, t in tasks do
		if t.isMain then
			return t.progress
		end
	end
	return 0
end

function TaskService.Snapshot(): { any }
	local out = {}
	for _, t in tasks do
		table.insert(out, { id = t.id, kind = t.kind, label = t.label, isMain = t.isMain, status = t.status, progress = t.progress, steps = t.steps, hint = t.hint, sector = t.sector })
	end
	return out
end

function TaskService.Init()
	Players.PlayerRemoving:Connect(function(p)
		holdBegan[p] = nil
	end)
end

function TaskService.Start() end

return TaskService
