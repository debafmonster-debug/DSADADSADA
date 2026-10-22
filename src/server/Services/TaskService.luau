--!nonstrict
-- Shift tasks and every hands-on station interaction (generator steps, fuse
-- box, breaker panel, antenna drive, headcount). Prompts are the input; the
-- server re-checks hold time, distance, state order and inventory.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local PowerGridService = require(script.Parent.PowerGridService)
local EquipmentService = require(script.Parent.EquipmentService)
local FacilityService = require(script.Parent.FacilityService)
local IdentityService = require(script.Parent.IdentityService)

export type TaskState = { id: string, kind: string, label: string, optional: boolean, status: "active" | "complete" | "failed", progress: number, hint: string?, data: { [string]: any } }

local TaskService = {}
TaskService.TaskCompleted = Signal.new() :: Signal.Signal<TaskState>
TaskService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>
TaskService.AntennaAligned = Signal.new()
TaskService.HeadcountDone = Signal.new() :: Signal.Signal<Player, number, number>

local tasks: { TaskState } = {}
local byKind: { [string]: TaskState } = {}
local prompts: { ProximityPrompt } = {}
local connections: { RBXScriptConnection } = {}
local map = nil
local rng = SeededRandom.new(1)
local lastHeadcount = 0
local deps = {
	inShift = function(_: Player)
		return false
	end,
	notifyAll = function(_payload) end,
	teamNames = function()
		return {}
	end,
}

function TaskService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function TaskService.All(): { TaskState }
	return tasks
end

function TaskService.Get(kind: string): TaskState?
	return byKind[kind]
end

function TaskService.Snapshot()
	local out = {}
	for _, t in tasks do
		table.insert(out, { id = t.id, kind = t.kind, label = t.label, optional = t.optional, status = t.status, progress = t.progress, hint = t.hint })
	end
	return out
end

function TaskService.MainComplete(): boolean
	for _, t in tasks do
		if not t.optional and t.status ~= "complete" then
			return false
		end
	end
	return true
end

function TaskService.MainProgress(): number
	local n, done = 0, 0
	for _, t in tasks do
		if not t.optional then
			n += 1
			if t.status == "complete" then
				done += 1
			else
				done += t.progress
			end
		end
	end
	return if n == 0 then 1 else done / n
end

local function broadcast(t: TaskState)
	Net.event("TaskUpdated"):FireAllClients({ id = t.id, kind = t.kind, label = t.label, optional = t.optional, status = t.status, progress = t.progress, hint = t.hint })
end

local function complete(t: TaskState)
	if t.status == "complete" then
		return
	end
	t.status = "complete"
	t.progress = 1
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

-- Hold-validated prompt helper: server re-checks the hold and distance.
local function holdPrompt(part: BasePart, action: string, object: string, hold: number, cap: string?, holdFast: number?, onDone: (Player) -> ()): ProximityPrompt
	local prompt = Builder.prompt(part, action, object, hold, Enum.KeyCode.E, 8)
	prompt:SetAttribute("UI", "Task")
	prompt:SetAttribute("HoldBase", hold)
	if cap then
		prompt:SetAttribute("ToolCap", cap)
		prompt:SetAttribute("HoldTool", holdFast or hold * 0.5)
	end
	local began = {}
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function(p)
		began[p] = os.clock()
	end))
	table.insert(connections, prompt.Triggered:Connect(function(player)
		if not deps.inShift(player) then
			return
		end
		local required = if cap and EquipmentService.HasCap(player, cap) then (holdFast or hold * 0.5) else hold
		local t0 = began[player]
		if required > 0 and (not t0 or os.clock() - t0 < required - 0.25) then
			return
		end
		if not Net.near(player, part.CFrame.Position, 12) then
			return
		end
		onDone(player)
	end))
	table.insert(prompts, prompt)
	return prompt
end

local function notify(player: Player, title: string, text: string, kind: string?)
	Net.event("Notification"):FireClient(player, { title = title, text = text, kind = kind or "info" })
end

local function playAt(part: BasePart, key: string)
	local def = Sounds[key]
	if not def or not def.id then
		return
	end
	local s = Builder.sound(part, def, key)
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

-- ===== Generator interactions ===========================================

local genPrompt: ProximityPrompt? = nil

local function nextGeneratorStep(): (string, string, number, string?)
	local g = PowerGridService.Generator()
	if g.fault and not g.panelOpen then
		return "openPanel", "Открыть защитную панель", 1.5, nil
	elseif g.panelOpen and g.fault and not g.diagnosed then
		return "diagnose", "Диагностика", 4, "diagnose_fast"
	elseif g.panelOpen and g.fault and g.diagnosed then
		local label = "деталь"
		for _, c in GameConfig.Power.Components do
			if c.id == g.fault then
				label = c.label
			end
		end
		return "replace", "Заменить: " .. label, 3.5, "component_swap"
	elseif g.repaired and not g.checked then
		return "check", "Проверить соединения", 3, "probe_power"
	elseif not g.running then
		return "start", "Запустить генератор", 2.5, nil
	elseif g.panelOpen then
		return "closePanel", "Закрыть панель", 1.2, nil
	end
	return "inspect", "Осмотреть показатели", 1.5, nil
end

local function refreshGeneratorPrompt()
	if not genPrompt then
		return
	end
	local step, text, hold, cap = nextGeneratorStep()
	genPrompt.ActionText = text
	genPrompt.HoldDuration = hold
	genPrompt:SetAttribute("HoldBase", hold)
	genPrompt:SetAttribute("Step", step)
	if cap then
		genPrompt:SetAttribute("ToolCap", cap)
		genPrompt:SetAttribute("HoldTool", hold * 0.5)
	else
		genPrompt:SetAttribute("ToolCap", nil)
		genPrompt:SetAttribute("HoldTool", nil)
	end
end

local function updateGeneratorVisuals()
	if not map or not map.generator then
		return
	end
	local g = PowerGridService.Generator()
	local gen = map.generator
	local cover = gen:FindFirstChild("Cover")
	if cover then
		cover.CFrame = if g.coverOpen then cover:GetAttribute("OpenCFrame") else cover:GetAttribute("ClosedCFrame")
	end
	local panel = gen:FindFirstChild("ServicePanel")
	if panel then
		panel.CFrame = if g.panelOpen then panel:GetAttribute("OpenCFrame") else panel:GetAttribute("ClosedCFrame")
	end
	local run = gen:FindFirstChild("RunLamp")
	if run then
		run.Color = if g.running then (if g.degraded then Builder.Palette.Yellow else Builder.Palette.Green) else Builder.Palette.Red
		local l = run:FindFirstChildWhichIsA("Light")
		if l then
			l.Color = run.Color
		end
	end
	for _, c in gen:GetChildren() do
		if c.Name:sub(1, 10) == "Component_" then
			local led = c:FindFirstChild("Led")
			if led then
				local id = led:GetAttribute("ComponentId")
				led.Color = if g.fault == id and g.diagnosed then Builder.Palette.Red else (if g.fault == id then Builder.Palette.Yellow else Builder.Palette.Green)
			end
		end
	end
	local load = PowerGridService.TotalLoad()
	FacilityService.SetGauge(gen:FindFirstChild("Gauge_1"), if g.running then load / 100 else 0)
	FacilityService.SetGauge(gen:FindFirstChild("Gauge_2"), if g.running then (if g.degraded then 0.45 else 0.75) else 0)
	FacilityService.SetGauge(gen:FindFirstChild("Gauge_3"), if g.running then 0.7 else 0)
	FacilityService.SetGauge(gen:FindFirstChild("Gauge_4"), if g.running then (if g.degraded then 0.9 else 0.55) else 0.1)
	FacilityService.SetGauge(gen:FindFirstChild("FuelGauge"), g.fuel / 100)
	if map.powerConsole then
		FacilityService.SetGauge(map.powerConsole:FindFirstChild("Gauge_кВт"), if g.running then load / 100 else 0)
		FacilityService.SetGauge(map.powerConsole:FindFirstChild("Gauge_ТОПЛ"), g.fuel / 100)
	end
end

local function wireGenerator()
	local gen = map.generator
	local panel = gen:FindFirstChild("Panel")
	genPrompt = holdPrompt(panel, "Осмотреть показатели", "Генератор ДГ-100", 1.5, nil, nil, function(player)
		local step = genPrompt:GetAttribute("Step") or "inspect"
		local ok, msg = PowerGridService.Action(player, step)
		notify(player, "Генератор", msg, if ok then "info" else "warn")
		playAt(panel, if step == "inspect" then "ToolBeep" else "ToolWrench")
		if ok and step == "inspect" then
			local t = byKind.PowerCheck
			if t and t.status == "active" then
				complete(t)
			end
		end
		refreshGeneratorPrompt()
		updateGeneratorVisuals()
	end)
	genPrompt:SetAttribute("Step", "inspect")
	local cover = gen:FindFirstChild("Cover")
	local coverPrompt = holdPrompt(cover, "Открыть крышку", "Защитная крышка", 1.5, nil, nil, function(player)
		local g = PowerGridService.Generator()
		PowerGridService.SetCover(not g.coverOpen, player)
		playAt(cover, "DoorHeavy")
		updateGeneratorVisuals()
	end)
	table.insert(connections, PowerGridService.GeneratorChanged:Connect(function(g)
		coverPrompt.ActionText = if g.coverOpen then "Закрыть крышку" else "Открыть крышку"
		refreshGeneratorPrompt()
		updateGeneratorVisuals()
		local t = byKind.GeneratorRepair
		if t and t.status == "active" and g.running and not g.fault then
			complete(t)
			deps.notifyAll({ title = "Генератор восстановлен", text = "Показатели в норме. Закройте крышку перед ночью.", kind = "good" })
		end
	end))
	local tank = gen:FindFirstChild("FuelTank")
	holdPrompt(tank, "Заправить", "Топливный бак", 3, nil, nil, function(player)
		local ok, msg = PowerGridService.Action(player, "refuel")
		notify(player, "Топливо", msg, if ok then "good" else "warn")
		updateGeneratorVisuals()
	end)
	updateGeneratorVisuals()
end

-- ===== Breaker panel =====================================================

local function wireBreakers()
	local panel = map.breakerPanel
	local switches = panel:FindFirstChild("Switches")
	for _, sw in switches:GetChildren() do
		local id = sw:GetAttribute("CircuitId")
		local c = PowerGridService.Circuit(id)
		if not c then
			continue
		end
		sw:SetAttribute("On", c.on)
		local lamp = sw:FindFirstChild("Lamp")
		local function refresh()
			local cc = PowerGridService.Circuit(id)
			sw:SetAttribute("On", cc.on)
			if lamp then
				lamp.Color = if cc.powered then Builder.Palette.Green elseif cc.on then Builder.Palette.Yellow else Builder.Palette.Graphite
			end
			sw.CFrame = sw.CFrame -- no-op placeholder for authored animation
		end
		local p = holdPrompt(sw, if c.on then "Отключить" else "Включить", c.label, 0.5, nil, nil, function(player)
			local cc = PowerGridService.Circuit(id)
			PowerGridService.SetSwitch(id, not cc.on, player)
			playAt(sw, "Switch")
		end)
		table.insert(connections, PowerGridService.CircuitChanged:Connect(function(cid)
			if cid == id then
				refresh()
				p.ActionText = if PowerGridService.Circuit(id).on then "Отключить" else "Включить"
			end
		end))
		refresh()
	end
	local lever = panel:FindFirstChild("MainLever")
	local tripLamp = panel:FindFirstChild("TripLamp")
	holdPrompt(lever, "Сбросить автомат", "Главный автомат", 2, nil, nil, function(player)
		local ok, msg = PowerGridService.ResetBreaker(player)
		notify(player, "Щит К-1", msg or (if ok then "Автомат взведён" else "Ошибка"), if ok then "good" else "warn")
		playAt(lever, "Relay")
	end)
	table.insert(connections, PowerGridService.Tripped:Connect(function()
		if tripLamp then
			tripLamp.Color = Builder.Palette.Red
		end
		lever:SetAttribute("Tripped", true)
		deps.notifyAll({ title = "Сработал главный автомат", text = "Перегрузка сети. Снизьте нагрузку и сбросьте автомат в щитовой.", kind = "danger" })
	end))
	table.insert(connections, PowerGridService.CircuitChanged:Connect(function()
		if tripLamp and not PowerGridService.Generator().tripped then
			tripLamp.Color = Builder.Palette.Green
			lever:SetAttribute("Tripped", false)
		end
	end))
end

-- ===== Fuse box ============================================================

local function wireFuseBox()
	local box = map.fuseBox
	local slots = box:FindFirstChild("Slots"):GetChildren()
	local t = byKind.FuseReplace
	local blownIndex = rng:nextInteger(1, #slots)
	-- The blown fuse takes the floodlights down until replaced.
	local circuitId = "Floodlights"
	for _, slot in slots do
		local idx = slot:GetAttribute("Index")
		local blown = t ~= nil and idx == blownIndex
		slot:SetAttribute("Blown", blown)
		slot.Color = if blown then Builder.Palette.Bakelite else Builder.Palette.Paper
		local prompt = holdPrompt(slot, "Заменить предохранитель", "Гнездо " .. tostring(idx), 3, "fuse_swap", 1.5, function(player)
			if not slot:GetAttribute("Blown") then
				notify(player, "Предохранитель", "Этот предохранитель исправен.", "info")
				return
			end
			if not EquipmentService.Has(player, "Fuse") then
				notify(player, "Нужен предохранитель", "Запасные — в кладовой, щитовой или на складе.", "warn")
				return
			end
			EquipmentService.Consume(player, "Fuse")
			slot:SetAttribute("Blown", false)
			slot.Color = Builder.Palette.Paper
			PowerGridService.SetFuse(circuitId, true)
			playAt(slot, "ToolWrench")
			TaskService.Noise:Fire(slot.CFrame.Position, "Repair", player)
			if t then
				complete(t)
			end
			notify(player, "Предохранитель заменён", "Линия «ПРОЖЕКТОРЫ» восстановлена.", "good")
		end)
		prompt.Enabled = true
	end
	if t then
		PowerGridService.SetFuse(circuitId, false)
		t.hint = "Щитовая К-1: найдите сгоревший предохранитель (тёмное гнездо)"
	end
end

-- ===== Antenna =============================================================

local function wireAntenna()
	local panel = map.antennaPanel
	local body = panel.PrimaryPart
	local t = byKind.AntennaAlign
	if not t then
		return
	end
	local step = 0
	local labels = { "Ослабить фиксатор", "Повернуть антенну", "Зафиксировать привод" }
	local holds = { 2.5, 4.5, 2 }
	local prompt
	prompt = holdPrompt(body, labels[1], "Привод антенны", holds[1], "antenna_fast", 2.5, function(player)
		if t.status ~= "active" then
			return
		end
		step += 1
		TaskService.Noise:Fire(body.CFrame.Position, "Repair", player)
		playAt(body, if step == 2 then "MetalCreak" else "ToolWrench")
		if step == 2 and map.antenna then
			local dish = map.antenna:FindFirstChild("Dish")
			if dish then
				local center = dish:GetAttribute("Center")
				dish.CFrame = center * CFrame.Angles(0, math.rad(-35), 0) * CFrame.Angles(0, 0, math.pi / 2)
			end
			FacilityService.SetGauge(panel:FindFirstChild("Azimuth"), 0.72)
		end
		if step >= 3 then
			complete(t)
			TaskService.AntennaAligned:Fire()
			deps.notifyAll({ title = "Антенна выровнена", text = "Ретранслятор Р-1 в норме. Сигнал усилился.", kind = "good" })
			prompt.Enabled = false
		else
			setProgress(t, step / 3, labels[step + 1])
			prompt.ActionText = labels[step + 1]
			prompt.HoldDuration = holds[step + 1]
			prompt:SetAttribute("HoldBase", holds[step + 1])
			prompt:SetAttribute("HoldTool", holds[step + 1] * 0.55)
		end
	end)
	t.hint = "Метеоплощадка, основание антенны. Холодно — работайте быстро."
end

-- ===== Headcount ===========================================================

local function wireHeadcount()
	local board = map.dormBoard
	holdPrompt(board, "Пересчитать участников", "Журнал смены К-2", 2, nil, nil, function(player)
		if os.clock() - lastHeadcount < GameConfig.Round.HeadcountCooldown then
			return
		end
		lastHeadcount = os.clock()
		local _people, bodies = IdentityService.CountInDorm()
		local names = deps.teamNames()
		FacilityService.SetBoardText(board, { "ЖУРНАЛ СМЕНЫ · К-2", "Состав: " .. table.concat(names, ", "), "В секторе: " .. tostring(bodies), "Пересчёт: " .. player.DisplayName })
		Net.event("HeadcountResult"):FireAllClients({ bodies = bodies, roster = #names, by = player.DisplayName })
		TaskService.HeadcountDone:Fire(player, bodies, #names)
		playAt(board, "UIConfirm")
	end)
end

-- ===== Setup / teardown ====================================================

function TaskService.Setup(mapHandle, shiftDef, seed: number)
	TaskService.Clear()
	map = mapHandle
	rng = SeededRandom.new(seed + 101)
	for i, spec in shiftDef.tasks do
		local t: TaskState = { id = spec.kind .. "_" .. i, kind = spec.kind, label = spec.label, optional = spec.optional == true, status = "active", progress = 0, hint = nil, data = {} }
		table.insert(tasks, t)
		byKind[spec.kind] = t
	end
	wireGenerator()
	wireBreakers()
	wireFuseBox()
	wireAntenna()
	wireHeadcount()
	if byKind.PowerCheck then
		byKind.PowerCheck.hint = "Генераторная южнее К-1. Панель с приборами."
	end
	if byKind.RadioRestore then
		byKind.RadioRestore.hint = "Радиорубка: частота диспетчера записана в журнале частот."
	end
	if byKind.LogRetrieve then
		byKind.LogRetrieve.hint = "Архив и лаборатория. Нужен свет: линия «ЛАБОРАТОРИЯ» в щитовой."
	end
	for _, t in tasks do
		broadcast(t)
	end
end

-- Incident: the generator fault becomes a visible task.
function TaskService.AddGeneratorRepair()
	if byKind.GeneratorRepair then
		return
	end
	local t: TaskState = { id = "GeneratorRepair_x", kind = "GeneratorRepair", label = "Восстановить генератор", optional = false, status = "active", progress = 0, hint = "Панель → диагностика → запчасть → соединения → пуск → крышка", data = {} }
	table.insert(tasks, 1, t)
	byKind.GeneratorRepair = t
	broadcast(t)
	refreshGeneratorPrompt()
	updateGeneratorVisuals()
end

function TaskService.OnDocumentRead(docId: string)
	local t = byKind.LogRetrieve
	if t and docId == "doc_drill_log" then
		complete(t)
	end
end

function TaskService.OnRadioContact()
	local t = byKind.RadioRestore
	if t then
		complete(t)
	end
end

function TaskService.RefreshGenerator()
	refreshGeneratorPrompt()
	updateGeneratorVisuals()
end

function TaskService.Clear()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, p in prompts do
		p:Destroy()
	end
	table.clear(prompts)
	table.clear(tasks)
	table.clear(byKind)
	genPrompt = nil
	map = nil
end

function TaskService.Init() end
function TaskService.Start() end

return TaskService
