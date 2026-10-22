--!nonstrict
-- Server model of the station electrical network: one diesel generator,
-- a main breaker and named circuits feeding lamps, heaters and equipment.
-- Nothing in the world "has power" unless this service says so; consumers are
-- plain parts tagged with attributes (Lamp/Heater + Circuit) that we drive.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)

local PW = GameConfig.Power

export type Circuit = { id: string, label: string, load: number, priority: number, on: boolean, powered: boolean }
export type Generator = {
	running: boolean,
	fuel: number,
	capacity: number,
	degraded: boolean,
	fault: string?, -- component id
	diagnosed: boolean,
	repaired: boolean,
	checked: boolean,
	panelOpen: boolean,
	coverOpen: boolean,
	tripped: boolean,
	overloadSince: number?,
	stopReason: string?,
}

local PowerGridService = {}
PowerGridService.CircuitChanged = Signal.new() :: Signal.Signal<string, boolean>
PowerGridService.GeneratorChanged = Signal.new() :: Signal.Signal<Generator>
PowerGridService.Tripped = Signal.new()
PowerGridService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local circuits: { Circuit } = {}
local byId: { [string]: Circuit } = {}
local gen: Generator
local lamps: { [string]: { BasePart } } = {}
local emergency: { [string]: { BasePart } } = {}
local heaters: { BasePart } = {}
local root: Instance? = nil
local panelPos: Vector3 = Vector3.zero
local generatorPos: Vector3 = Vector3.zero
local sounds: { [string]: Sound } = {}
local flickering: { [string]: boolean } = {}
local rng = SeededRandom.new(1)
local inventory = {
	has = function(_: Player, _: string)
		return false
	end,
	consume = function(_: Player, _: string)
		return false
	end,
	toolCap = function(_: Player, _: string)
		return false
	end,
}
local lastBroadcast = 0
local blownFuse: { [string]: boolean } = {}

local function resetState()
	circuits = {}
	byId = {}
	for _, c in PW.Circuits do
		local cc: Circuit = { id = c.id, label = c.label, load = c.load, priority = c.priority, on = c.defaultOn, powered = false }
		table.insert(circuits, cc)
		byId[c.id] = cc
	end
	gen = {
		running = false,
		fuel = PW.FuelStart,
		capacity = PW.Capacity,
		degraded = false,
		fault = nil,
		diagnosed = false,
		repaired = false,
		checked = false,
		panelOpen = false,
		coverOpen = false,
		tripped = false,
		overloadSince = nil,
		stopReason = nil,
	}
end
resetState()

function PowerGridService.Configure(api)
	for k, v in api do
		inventory[k] = v
	end
end

function PowerGridService.Generator(): Generator
	return gen
end

function PowerGridService.Circuits(): { Circuit }
	return circuits
end

function PowerGridService.Circuit(id: string): Circuit?
	return byId[id]
end

function PowerGridService.TotalLoad(): number
	local sum = 0
	for _, c in circuits do
		if c.on then
			sum += c.load
		end
	end
	return sum
end

function PowerGridService.IsPowered(id: string): boolean
	local c = byId[id]
	return c ~= nil and c.powered
end

function PowerGridService.Snapshot()
	local list = {}
	for _, c in circuits do
		table.insert(list, { id = c.id, label = c.label, load = c.load, on = c.on, powered = c.powered, fuse = not blownFuse[c.id] })
	end
	local faultLabel = nil
	if gen.fault then
		faultLabel = "НЕИСПРАВНОСТЬ"
		if gen.diagnosed then
			for _, comp in PW.Components do
				if comp.id == gen.fault then
					faultLabel = comp.label
				end
			end
		end
	end
	local overloadIn = nil
	if gen.overloadSince then
		overloadIn = math.max(0, PW.OverloadTripSeconds - (os.clock() - gen.overloadSince))
	end
	return {
		generator = {
			running = gen.running,
			fuel = math.floor(gen.fuel),
			capacity = gen.capacity,
			degraded = gen.degraded,
			fault = faultLabel,
			diagnosed = gen.diagnosed,
			repaired = gen.repaired,
			checked = gen.checked,
			panelOpen = gen.panelOpen,
			coverOpen = gen.coverOpen,
			tripped = gen.tripped,
			totalLoad = PowerGridService.TotalLoad(),
			overloadIn = overloadIn,
			stopReason = gen.stopReason,
		},
		circuits = list,
	}
end

local function broadcast()
	lastBroadcast = os.clock()
	Net.event("PowerState"):FireAllClients(PowerGridService.Snapshot())
end

-- ===== Lamp driving ======================================================

local function applyLamp(lamp: BasePart, on: boolean, dimFactor: number?)
	if not lamp.Parent then
		return
	end
	local color = lamp:GetAttribute("LampColor") :: Color3?
	local brightness = lamp:GetAttribute("LampBrightness") :: number?
	local matName = lamp:GetAttribute("LampMaterial") :: string?
	local light = lamp:FindFirstChildWhichIsA("Light")
	if on then
		lamp.Material = Enum.Material.Neon
		if color then
			local f = dimFactor or 1
			lamp.Color = Color3.new(color.R * f, color.G * f, color.B * f)
		end
		if light then
			light.Enabled = true
			if brightness then
				light.Brightness = brightness * (dimFactor or 1)
			end
		end
	else
		lamp.Material = if matName == "Neon" or matName == nil then Enum.Material.Glass else (Enum.Material :: any)[matName]
		if color then
			lamp.Color = Color3.new(color.R * 0.18, color.G * 0.18, color.B * 0.18)
		end
		if light then
			light.Enabled = false
		end
	end
end

local function playAt(parent: Instance, key: string)
	local def = Sounds[key]
	if not def or not def.id then
		return
	end
	local s = Builder.sound(parent, def, key)
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local function setCircuitPowered(c: Circuit, powered: boolean)
	if c.powered == powered then
		return
	end
	c.powered = powered
	PowerGridService.CircuitChanged:Fire(c.id, powered)
	local list = lamps[c.id] or {}
	-- Fixtures die in order of distance from the switchboard: a wave of darkness
	-- rolling down the corridor instead of a global switch.
	table.sort(list, function(a, b)
		return (a.CFrame.Position - panelPos).Magnitude < (b.CFrame.Position - panelPos).Magnitude
	end)
	for i, lamp in list do
		task.delay((i - 1) * PW.LampOffStagger, function()
			if c.powered == powered then
				applyLamp(lamp, powered)
			end
		end)
	end
	for _, e in emergency[c.id] or {} do
		local light = e:FindFirstChildWhichIsA("Light")
		if light then
			light.Enabled = not powered
		end
		e.Transparency = if powered then 0.6 else 0
	end
	if list[1] then
		playAt(list[1], "Relay")
	end
end

local function recompute()
	local supply = gen.running and not gen.tripped
	for _, c in circuits do
		setCircuitPowered(c, supply and c.on and not blownFuse[c.id])
	end
	if sounds.hum then
		sounds.hum.Playing = gen.running
		sounds.hum.PlaybackSpeed = if gen.degraded then 0.42 else 0.55
	end
end

-- Scan a built map for consumers. Call once after the map exists.
function PowerGridService.BindMap(mapRoot: Instance, breakerPanelPos: Vector3, generatorPosition: Vector3, generatorSoundParent: Instance?)
	root = mapRoot
	panelPos = breakerPanelPos
	generatorPos = generatorPosition
	lamps = {}
	emergency = {}
	heaters = {}
	for _, inst in mapRoot:GetDescendants() do
		if inst:IsA("BasePart") then
			local circuit = inst:GetAttribute("Circuit")
			if inst:GetAttribute("Lamp") and circuit then
				lamps[circuit] = lamps[circuit] or {}
				table.insert(lamps[circuit], inst)
			elseif inst:GetAttribute("IsEmergency") and circuit then
				emergency[circuit] = emergency[circuit] or {}
				table.insert(emergency[circuit], inst)
			elseif inst:GetAttribute("Heater") then
				table.insert(heaters, inst)
			end
		end
	end
	if generatorSoundParent then
		sounds.hum = Builder.sound(generatorSoundParent, Sounds.GeneratorHum, "GeneratorHum")
		sounds.hum:SetAttribute("AutoPlay", true)
	end
end

function PowerGridService.Heaters(): { BasePart }
	return heaters
end

function PowerGridService.LampCount(): number
	local n = 0
	for _, list in lamps do
		n += #list
	end
	return n
end

-- ===== Generator control =================================================

function PowerGridService.StartShift(seed: number)
	rng = SeededRandom.new(seed)
	resetState()
	table.clear(blownFuse)
	gen.running = true
	recompute()
	broadcast()
end

function PowerGridService.StopShift()
	resetState()
	for _, list in lamps do
		for _, lamp in list do
			applyLamp(lamp, true)
		end
	end
	if sounds.hum then
		sounds.hum:Destroy()
		sounds.hum = nil
	end
	lamps = {}
	emergency = {}
	heaters = {}
	root = nil
end

function PowerGridService.SetSwitch(id: string, on: boolean, actor: Player?): boolean
	local c = byId[id]
	if not c or c.on == on then
		return false
	end
	c.on = on
	if root and lamps[id] and lamps[id][1] then
		playAt(lamps[id][1], "Switch")
	end
	PowerGridService.Noise:Fire(panelPos, "Keypad", actor)
	recompute()
	broadcast()
	return true
end

-- A blown line fuse keeps a circuit dark even when its switch is on.
function PowerGridService.SetFuse(id: string, ok: boolean)
	blownFuse[id] = if ok then nil else true
	recompute()
	broadcast()
end

function PowerGridService.FuseBlown(id: string): boolean
	return blownFuse[id] == true
end

function PowerGridService.Trip(reason: string?)
	if gen.tripped then
		return
	end
	gen.tripped = true
	gen.overloadSince = nil
	gen.stopReason = reason or "overload"
	PowerGridService.Tripped:Fire()
	if root then
		playAt(root, "PowerDown")
	end
	recompute()
	broadcast()
end

-- Reset is only accepted when the connected load fits the capacity, otherwise
-- the breaker trips again a few seconds later (and the team learns why).
function PowerGridService.ResetBreaker(actor: Player?): (boolean, string?)
	if not gen.tripped then
		return false, "Автомат не сработал"
	end
	if not gen.running then
		return false, "Генератор остановлен"
	end
	gen.tripped = false
	gen.stopReason = nil
	if root then
		playAt(root, "PowerUp")
	end
	PowerGridService.Noise:Fire(panelPos, "Door", actor)
	recompute()
	broadcast()
	if PowerGridService.TotalLoad() > gen.capacity then
		task.delay(5, function()
			if not gen.tripped and gen.running and PowerGridService.TotalLoad() > gen.capacity then
				PowerGridService.Trip("overload")
			end
		end)
		return true, "Нагрузка выше допустимой: автомат сработает повторно"
	end
	return true, nil
end

function PowerGridService.InjectFault(componentId: string?)
	if gen.fault then
		return
	end
	local comp = componentId
	if not comp then
		comp = PW.Components[rng:nextInteger(1, #PW.Components)].id
	end
	gen.fault = comp
	gen.degraded = true
	gen.capacity = PW.DegradedCapacity
	gen.diagnosed = false
	gen.repaired = false
	gen.checked = false
	if sounds.hum then
		sounds.hum.PlaybackSpeed = 0.42
	end
	PowerGridService.GeneratorChanged:Fire(gen)
	broadcast()
	-- Degraded running lasts a short while, then the unit stops entirely.
	task.delay(28, function()
		if gen.fault == comp and gen.running then
			PowerGridService.StopGenerator("fault")
		end
	end)
end

function PowerGridService.StopGenerator(reason: string)
	if not gen.running then
		return
	end
	gen.running = false
	gen.stopReason = reason
	gen.overloadSince = nil
	if root then
		playAt(root, "PowerDown")
	end
	PowerGridService.GeneratorChanged:Fire(gen)
	recompute()
	broadcast()
end

function PowerGridService.SetCover(open: boolean, actor: Player?)
	if gen.coverOpen == open then
		return
	end
	gen.coverOpen = open
	PowerGridService.Noise:Fire(generatorPos, "DoorHeavy", actor)
	PowerGridService.GeneratorChanged:Fire(gen)
	broadcast()
end

-- Repair state machine. Returns ok, message. Order is enforced server-side.
function PowerGridService.Action(player: Player, step: string): (boolean, string)
	if step == "inspect" then
		local parts = {}
		table.insert(parts, if gen.running then "Генератор работает" else "Генератор остановлен")
		table.insert(parts, string.format("Топливо %d%%", math.floor(gen.fuel)))
		table.insert(parts, string.format("Нагрузка %d/%d кВт", PowerGridService.TotalLoad(), gen.capacity))
		if gen.fault then
			table.insert(parts, if gen.diagnosed then "Неисправность определена" else "Показатели нестабильны — нужна диагностика")
		end
		if gen.tripped then
			table.insert(parts, "Сработал главный автомат в щитовой")
		end
		return true, table.concat(parts, ". ")
	elseif step == "openPanel" then
		if gen.panelOpen then
			return false, "Панель уже открыта"
		end
		gen.panelOpen = true
		PowerGridService.Noise:Fire(generatorPos, "Door", player)
		broadcast()
		return true, "Защитная панель открыта"
	elseif step == "closePanel" then
		if not gen.panelOpen then
			return false, "Панель закрыта"
		end
		if gen.fault and not gen.repaired then
			return false, "Сначала устраните неисправность"
		end
		gen.panelOpen = false
		broadcast()
		return true, "Панель закрыта"
	elseif step == "diagnose" then
		if not gen.panelOpen then
			return false, "Откройте защитную панель"
		end
		if not gen.fault then
			return false, "Неисправностей не найдено"
		end
		gen.diagnosed = true
		PowerGridService.Noise:Fire(generatorPos, "Repair", player)
		broadcast()
		local label = ""
		for _, comp in PW.Components do
			if comp.id == gen.fault then
				label = comp.label
			end
		end
		return true, "Неисправен компонент: " .. label
	elseif step == "replace" then
		if not gen.panelOpen or not gen.fault then
			return false, "Нечего заменять"
		end
		if not gen.diagnosed then
			return false, "Сначала проведите диагностику"
		end
		local partId = nil
		for _, comp in PW.Components do
			if comp.id == gen.fault then
				partId = comp.part
			end
		end
		if not partId or not inventory.has(player, partId) then
			return false, "Нужна запасная деталь: проверьте склад"
		end
		if not inventory.consume(player, partId) then
			return false, "Деталь недоступна"
		end
		gen.fault = nil
		gen.repaired = true
		gen.checked = false
		PowerGridService.Noise:Fire(generatorPos, "Repair", player)
		broadcast()
		return true, "Компонент заменён. Проверьте соединения"
	elseif step == "check" then
		if not gen.repaired then
			return false, "Соединения в норме"
		end
		gen.checked = true
		broadcast()
		return true, "Соединения проверены"
	elseif step == "start" then
		if gen.running then
			return false, "Генератор уже работает"
		end
		if gen.fuel <= 0 then
			return false, "Нет топлива"
		end
		if gen.fault then
			return false, "Генератор неисправен"
		end
		if gen.repaired and not gen.checked then
			return false, "Проверьте соединения перед пуском"
		end
		gen.running = true
		gen.degraded = false
		gen.capacity = PW.Capacity
		gen.repaired = false
		gen.checked = false
		gen.stopReason = nil
		if root then
			playAt(root, "PowerUp")
		end
		PowerGridService.Noise:Fire(generatorPos, "Generator", player)
		PowerGridService.GeneratorChanged:Fire(gen)
		recompute()
		broadcast()
		return true, "Генератор запущен. Показатели в норме"
	elseif step == "refuel" then
		if not inventory.has(player, "FuelCanister") then
			return false, "Нужна канистра топлива"
		end
		if gen.fuel >= 95 then
			return false, "Бак полон"
		end
		inventory.consume(player, "FuelCanister")
		gen.fuel = math.min(100, gen.fuel + PW.FuelCanisterAmount)
		broadcast()
		return true, string.format("Заправлено. Топливо %d%%", math.floor(gen.fuel))
	end
	return false, "Неизвестное действие"
end

-- Called by the creature when it tampers with an open generator.
function PowerGridService.Sabotage()
	if gen.coverOpen and gen.running then
		PowerGridService.InjectFault(nil)
		return true
	end
	return false
end

-- ===== Simulation tick ===================================================

local function flickerCircuit(c: Circuit)
	if flickering[c.id] then
		return
	end
	flickering[c.id] = true
	task.spawn(function()
		local list = lamps[c.id] or {}
		while flickering[c.id] and c.powered do
			local lamp = list[rng:nextInteger(1, math.max(1, #list))]
			if lamp then
				applyLamp(lamp, false)
				playAt(lamp, "LampFlicker")
				task.wait(0.05 + rng:nextNumber() * 0.12)
				if c.powered then
					applyLamp(lamp, true)
				end
			end
			task.wait(0.15 + rng:nextNumber() * 0.5)
		end
		flickering[c.id] = nil
	end)
end

-- Pure tick (also used by tests): dt in real seconds, gameMinutes elapsed.
function PowerGridService.Tick(_dt: number, gameMinutes: number)
	if gen.running then
		gen.fuel = math.max(0, gen.fuel - PW.FuelPerGameMinute * gameMinutes)
		if gen.fuel <= 0 then
			PowerGridService.StopGenerator("fuel")
			return
		end
		local load = PowerGridService.TotalLoad()
		if not gen.tripped and load > gen.capacity then
			gen.overloadSince = gen.overloadSince or os.clock()
			local elapsed = os.clock() - gen.overloadSince
			if elapsed >= PW.OverloadTripSeconds then
				PowerGridService.Trip("overload")
			elseif elapsed >= PW.OverloadTripSeconds - PW.FlickerBeforeTripSeconds then
				for _, c in circuits do
					if c.powered and c.priority >= 2 then
						flickerCircuit(c)
					end
				end
			end
		else
			gen.overloadSince = nil
			for id in flickering do
				flickering[id] = nil
			end
		end
		if gen.degraded then
			for _, c in circuits do
				if c.powered and c.id ~= "Scanner" then
					flickerCircuit(c)
				end
			end
		end
	end
end

function PowerGridService.Init() end

function PowerGridService.Start()
	task.spawn(function()
		local ClockService = require(script.Parent.ClockService)
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			if root then
				local snap = ClockService.Snapshot()
				PowerGridService.Tick(dt, dt * snap.scale / 60)
				if now - lastBroadcast > 5 then
					broadcast()
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(1, function()
			if p.Parent then
				Net.event("PowerState"):FireClient(p, PowerGridService.Snapshot())
			end
		end)
	end)
end

return PowerGridService
