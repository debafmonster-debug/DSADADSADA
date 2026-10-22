--!nonstrict
-- Instantiates a validated layout into Workspace.ActiveMap and owns the
-- physical state of the facility: doors, sector power, alarm lighting,
-- the evacuation shutter and flickering lamps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Catalog = require(script.Parent.Parent.MapModules.Catalog)
local Common = require(script.Parent.Parent.MapModules.Common)
local LayoutValidator = require(script.Parent.LayoutValidator)
local P = Builder.Palette

type Layout = LayoutValidator.Layout
type Node = LayoutValidator.Node

export type NodeHandle = { node: Node, model: Model, markers: Folder, cframe: CFrame }
export type DoorHandle = { model: Model, leaves: { Part }, edge: LayoutValidator.Edge, position: Vector3, open: boolean, locked: boolean, busy: boolean, autoCloseAt: number, prompt: ProximityPrompt, sideAxis: Vector3 }
export type MapHandle = {
	root: Model,
	layout: Layout,
	nodes: { [number]: NodeHandle },
	doors: { DoorHandle },
	spawnPoints: { CFrame },
	patrolPoints: { Vector3 },
	wardenSpawns: { Vector3 },
	evacZone: Vector3?,
	taskTargets: { [string]: { model: Instance, node: NodeHandle } },
	documentSpots: { { cframe: CFrame, sector: string } },
	power: { [string]: boolean },
	alarm: boolean,
}

local FacilityService = {}
FacilityService.DoorOpened = Signal.new() :: Signal.Signal<Vector3, string>
FacilityService.Noise = Signal.new() :: Signal.Signal<Vector3, number, Player?>

local current: MapHandle? = nil
local flickerThread: thread? = nil
local CELL = GameConfig.Grid.Cell
local HEIGHT = GameConfig.Grid.WallHeight

local function cellCFrame(x: number, z: number): CFrame
	return CFrame.new(GameConfig.Grid.MapOrigin + Vector3.new(x * CELL, 0, z * CELL))
end

local function buildDoor(root: Model, a: NodeHandle, b: NodeHandle, edge: LayoutValidator.Edge): DoorHandle
	local mid = (a.cframe.Position + b.cframe.Position) / 2
	local axis = (b.cframe.Position - a.cframe.Position).Unit -- direction a -> b
	local cf = CFrame.lookAt(mid, mid + axis) -- door plane perpendicular to axis
	local w, h = Common.DoorOpening.width, Common.DoorOpening.height
	local m = Builder.model(root, string.format("Door_%d_%d", edge.a, edge.b))
	local security = edge.doorType == "security"
	local frameColor = if security then P.Red:Lerp(P.WarningBlack, 0.5) else P.SteelPainted
	Builder.box(m, "FrameL", cf * CFrame.new(-w / 2 - 0.3, h / 2, 0), Vector3.new(0.6, h, 1.4), Enum.Material.Metal, frameColor)
	Builder.box(m, "FrameR", cf * CFrame.new(w / 2 + 0.3, h / 2, 0), Vector3.new(0.6, h, 1.4), Enum.Material.Metal, frameColor)
	Builder.box(m, "FrameT", cf * CFrame.new(0, h + 0.3, 0), Vector3.new(w + 1.2, 0.6, 1.4), Enum.Material.Metal, frameColor)
	local leaves = {}
	for i, sx in { -1, 1 } do
		local leaf = Builder.part({
			name = "Leaf" .. i,
			size = Vector3.new(w / 2, h - 0.1, 0.5),
			cframe = cf * CFrame.new(sx * w / 4, h / 2, 0),
			material = Enum.Material.Metal,
			color = if security then Color3.fromRGB(120, 60, 56) else P.SteelPaintedLight,
			parent = m,
		})
		leaf:SetAttribute("ClosedOffset", sx * w / 4)
		local stripe = Builder.part({ name = "Stripe", size = Vector3.new(w / 2 - 0.4, 0.3, 0.52), cframe = leaf.CFrame * CFrame.new(0, -1, 0), material = Enum.Material.SmoothPlastic, color = if security then P.Red else P.Yellow, parent = leaf, canCollide = false })
		stripe.CastShadow = false
		stripe.Anchored = false -- welded parts must be unanchored to follow the tweened leaf
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = leaf
		weld.Part1 = stripe
		weld.Parent = leaf
		-- Navmesh ignores door leaves; the Warden opens doors it walks into.
		local mod = Instance.new("PathfindingModifier")
		mod.PassThrough = true
		mod.Label = if edge.locked then "LockedDoor" else "Door"
		mod.Parent = leaf
		table.insert(leaves, leaf)
	end
	local window = Builder.part({ name = "Window", size = Vector3.new(1.2, 2, 0.1), cframe = cf * CFrame.new(-w / 4, h * 0.62, 0.3), material = Enum.Material.Glass, color = P.GlassTint, transparency = 0.5, parent = leaves[1], canCollide = false })
	window.Anchored = false
	local ww = Instance.new("WeldConstraint")
	ww.Part0 = leaves[1]
	ww.Part1 = window
	ww.Parent = window
	local lampColor = if edge.locked then P.Red else P.Green
	for _, sz in { -1, 1 } do
		local lamp = Builder.part({ name = "StatusLamp", size = Vector3.new(0.6, 0.6, 0.2), cframe = cf * CFrame.new(w / 2 + 1.4, h - 1.2, sz * 0.75), material = Enum.Material.Neon, color = lampColor, parent = m, canCollide = false, castShadow = false })
		Builder.pointLight(lamp, lampColor, 6, 0.4)
	end
	local prompt = Builder.prompt(leaves[1], if edge.locked then "Заблокировано" else "Открыть", if security then "Шлюз · допуск 03" else "Дверь", 0, Enum.KeyCode.E, 9)
	prompt:SetAttribute("UI", "Door")
	local slide = Builder.sound(leaves[1], Sounds.DoorSlide, "Slide")
	slide.Name = "Slide"
	local locked = Builder.sound(leaves[1], Sounds.DoorLocked, "Locked")
	locked.Name = "LockedSound"
	m:SetAttribute("Locked", edge.locked)
	m:SetAttribute("Security", security)
	return {
		model = m,
		leaves = leaves,
		edge = edge,
		position = mid + Vector3.new(0, 3, 0),
		open = false,
		locked = edge.locked,
		busy = false,
		autoCloseAt = 0,
		prompt = prompt,
		sideAxis = cf.RightVector,
	}
end

local function setDoorOpen(door: DoorHandle, open: boolean)
	if door.open == open or door.busy then
		return
	end
	door.busy = true
	door.open = open
	local w = Common.DoorOpening.width
	for _, leaf in door.leaves do
		local closedOffset = leaf:GetAttribute("ClosedOffset") :: number
		local sign = if closedOffset < 0 then -1 else 1
		local targetOffset = if open then closedOffset + sign * (w / 2 - 0.2) else closedOffset
		local target = leaf.CFrame * CFrame.new(targetOffset - (leaf:GetAttribute("CurrentOffset") :: number? or closedOffset), 0, 0)
		leaf:SetAttribute("CurrentOffset", targetOffset)
		local tween = TweenService:Create(leaf, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target })
		tween:Play()
	end
	local slide = door.leaves[1]:FindFirstChild("Slide") :: Sound?
	if slide then
		slide:Play()
	end
	door.prompt.ActionText = if open then "Закрыть" else "Открыть"
	door.model:SetAttribute("Open", open)
	task.delay(0.75, function()
		door.busy = false
	end)
	if open then
		door.autoCloseAt = os.clock() + 7
		FacilityService.DoorOpened:Fire(door.position, "door")
	end
end

function FacilityService.OpenDoor(door: DoorHandle, actor: string): boolean
	if door.locked then
		return false
	end
	setDoorOpen(door, true)
	if actor == "warden" then
		door.autoCloseAt = os.clock() + 4
	end
	return true
end

function FacilityService.ToggleDoor(door: DoorHandle, player: Player?): boolean
	if door.locked then
		local s = door.leaves[1]:FindFirstChild("LockedSound") :: Sound?
		if s then
			s:Play()
		end
		if player then
			Net.event("Notification"):FireClient(player, { title = "Доступ запрещён", text = "Требуется допуск уровня 03. Панель блокировки повреждена.", kind = "warn" })
		end
		return false
	end
	setDoorOpen(door, not door.open)
	if player then
		FacilityService.Noise:Fire(door.position, 12, player)
	end
	return true
end

function FacilityService.UnlockSector(sector: string)
	local map = current
	if not map then
		return
	end
	for _, door in map.doors do
		local a, b = map.nodes[door.edge.a], map.nodes[door.edge.b]
		if door.locked and (a.node.sector == sector or b.node.sector == sector) then
			door.locked = false
			door.model:SetAttribute("Locked", false)
			door.prompt.ActionText = "Открыть"
			for _, leaf in door.leaves do
				local mod = leaf:FindFirstChildOfClass("PathfindingModifier")
				if mod then
					mod.Label = "Door"
				end
			end
			for _, lamp in door.model:GetChildren() do
				if lamp.Name == "StatusLamp" and lamp:IsA("Part") then
					lamp.Color = P.Green
					local pl = lamp:FindFirstChildOfClass("PointLight")
					if pl then
						pl.Color = P.Green
					end
				end
			end
		end
	end
end

function FacilityService.DoorsNear(position: Vector3, radius: number): { DoorHandle }
	local out = {}
	local map = current
	if not map then
		return out
	end
	for _, door in map.doors do
		if (door.position - position).Magnitude <= radius then
			table.insert(out, door)
		end
	end
	return out
end

-- Lamp control --------------------------------------------------------------

local function forEachLamp(model: Instance, fn: (Part, PointLight) -> ())
	for _, d in model:GetDescendants() do
		if d:IsA("Part") and d.Name == "Lamp" and d:GetAttribute("LampColor") then
			local pl = d:FindFirstChildOfClass("PointLight")
			if pl then
				fn(d, pl)
			end
		end
	end
end

local function forEachEmergency(model: Instance, fn: (Part, PointLight) -> ())
	for _, d in model:GetDescendants() do
		if d:IsA("Part") and d:GetAttribute("IsEmergency") then
			local pl = d:FindFirstChildOfClass("PointLight")
			if pl then
				fn(d, pl)
			end
		end
	end
end

local function applyLighting(handle: NodeHandle, powered: boolean, alarm: boolean)
	forEachLamp(handle.model, function(lamp, pl)
		if powered then
			local base = lamp:GetAttribute("LampColor") :: Color3
			lamp.Color = if alarm then base:Lerp(P.LightEmergency, 0.35) else base
			lamp.Material = Enum.Material.Neon
			pl.Enabled = true
			pl.Brightness = (lamp:GetAttribute("LampBrightness") :: number) * (if alarm then 0.55 else 1)
			pl.Color = lamp.Color
		else
			lamp.Material = Enum.Material.SmoothPlastic
			lamp.Color = Color3.fromRGB(60, 60, 62)
			pl.Enabled = false
		end
	end)
	forEachEmergency(handle.model, function(lamp, pl)
		local on = (not powered) or alarm
		pl.Enabled = on
		lamp.Transparency = if on then 0 else 0.6
	end)
	handle.model:SetAttribute("Powered", powered)
end

function FacilityService.SetSectorPower(sector: string, on: boolean)
	local map = current
	if not map then
		return
	end
	map.power[sector] = on
	for _, handle in map.nodes do
		if handle.node.sector == sector then
			applyLighting(handle, on, map.alarm)
		end
	end
	Net.event("FacilityState"):FireAllClients({ power = map.power, alarm = map.alarm })
end

function FacilityService.SetAlarm(on: boolean)
	local map = current
	if not map then
		return
	end
	map.alarm = on
	for _, handle in map.nodes do
		applyLighting(handle, map.power[handle.node.sector] ~= false, on)
	end
	local alarmSound = map.root:FindFirstChild("AlarmSound") :: Sound?
	if alarmSound then
		if on then
			alarmSound:Play()
		else
			alarmSound:Stop()
		end
	end
	Net.event("FacilityState"):FireAllClients({ power = map.power, alarm = map.alarm })
end

function FacilityService.IsPowered(sector: string): boolean
	local map = current
	return map ~= nil and map.power[sector] ~= false
end

function FacilityService.OpenEvacShutter()
	local map = current
	if not map then
		return
	end
	local evac = map.taskTargets.Evacuation
	if not evac then
		return
	end
	local shutter = evac.node.model:FindFirstChild("EvacShutter", true) :: Part?
	if shutter and shutter:GetAttribute("Closed") then
		shutter:SetAttribute("Closed", false)
		local tween = TweenService:Create(shutter, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = shutter.CFrame * CFrame.new(0, 9.6, 0) })
		tween:Play()
		local s = Builder.sound(shutter, Sounds.PowerUp, "ShutterSound")
		s:Play()
		local lamp = evac.node.model:FindFirstChild("ExitLamp", true) :: Part?
		if lamp then
			lamp.Color = P.Green
			local pl = lamp:FindFirstChildOfClass("PointLight")
			if pl then
				pl.Color = P.Green
			end
		end
	end
end

-- Flicker loop: one thread for every flagged lamp on the map.
local function startFlicker(map: MapHandle)
	if flickerThread then
		task.cancel(flickerThread)
	end
	local lamps: { Part } = {}
	for _, handle in map.nodes do
		for _, d in handle.model:GetDescendants() do
			if d:IsA("Part") and d:GetAttribute("Flicker") then
				table.insert(lamps, d)
			end
		end
	end
	if #lamps == 0 then
		return
	end
	flickerThread = task.spawn(function()
		local rng = SeededRandom.new(map.layout.seed + 99)
		while true do
			task.wait(rng:nextNumber(0.08, 0.6))
			local lamp = lamps[rng:nextInteger(1, #lamps)]
			if lamp.Parent and lamp.Material == Enum.Material.Neon then
				local pl = lamp:FindFirstChildOfClass("PointLight")
				if pl then
					local off = rng:chance(0.5)
					pl.Enabled = not off
					lamp.Transparency = if off then 0.7 else 0
					task.wait(rng:nextNumber(0.03, 0.2))
					pl.Enabled = true
					lamp.Transparency = 0
				end
			end
		end
	end)
end

-- Build ---------------------------------------------------------------------

function FacilityService.BuildMap(layout: Layout, rngSeed: number): MapHandle
	FacilityService.ClearMap()
	local root = Builder.model(workspace, "ActiveMap")
	root:SetAttribute("Seed", layout.seed)
	root:SetAttribute("MissionId", layout.missionId)
	local map: MapHandle = {
		root = root,
		layout = layout,
		nodes = {},
		doors = {},
		spawnPoints = {},
		patrolPoints = {},
		wardenSpawns = {},
		evacZone = nil,
		taskTargets = {},
		documentSpots = {},
		power = {},
		alarm = false,
	}
	local rng = SeededRandom.new(rngSeed)
	local byId: { [number]: Node } = {}
	for _, n in layout.nodes do
		byId[n.id] = n
	end
	-- Which sides of each node have doors
	local doorsOf: { [number]: { [string]: boolean } } = {}
	for _, n in layout.nodes do
		doorsOf[n.id] = { N = false, E = false, S = false, W = false }
	end
	for _, e in layout.edges do
		doorsOf[e.a][e.side] = true
		local a, b = byId[e.a], byId[e.b]
		local back = LayoutValidator.sideBetween(b, a)
		if back then
			doorsOf[e.b][back] = true
		end
	end
	local rooms = Builder.folder(root, "Rooms")
	for i, n in layout.nodes do
		local def = Catalog.ById[n.moduleId]
		local model = Builder.model(rooms, n.roomCode)
		model:SetAttribute("NodeId", n.id)
		model:SetAttribute("ModuleId", n.moduleId)
		model:SetAttribute("Sector", n.sector)
		model:SetAttribute("RoomCode", n.roomCode)
		local markers = Builder.folder(model, "Markers")
		local cf = cellCFrame(n.x, n.z)
		local damage = if n.sector == "D" then rng:nextNumber(0.5, 1) elseif n.sector == "A" then rng:nextNumber(0, 0.3) else rng:nextNumber(0.1, 0.6)
		local ctx: Common.Ctx = {
			model = model,
			cframe = cf,
			size = CELL,
			height = HEIGHT,
			doors = doorsOf[n.id],
			rng = SeededRandom.new(layout.seed * 31 + n.id),
			sector = n.sector,
			roomCode = n.roomCode,
			markers = markers,
			damage = damage,
		}
		def.build(ctx)
		local handle: NodeHandle = { node = n, model = model, markers = markers, cframe = cf }
		map.nodes[n.id] = handle
		for _, mk in markers:GetChildren() do
			if not mk:IsA("BasePart") then
				continue
			end
			if mk.Name == "Spawn" then
				table.insert(map.spawnPoints, mk.CFrame)
			elseif mk.Name == "Patrol" then
				table.insert(map.patrolPoints, mk.Position)
			elseif mk.Name == "WardenSpawn" then
				table.insert(map.wardenSpawns, mk.Position)
			elseif mk.Name == "EvacZone" then
				map.evacZone = mk.Position
			elseif mk.Name == "TaskTarget" then
				local kind = mk:GetAttribute("Kind") :: string
				local targetName = mk:GetAttribute("TargetName") :: string
				local target = model:FindFirstChild(targetName, true)
				if target then
					map.taskTargets[kind] = { model = target, node = handle }
				end
			elseif mk.Name == "DocumentSpot" then
				table.insert(map.documentSpots, { cframe = mk.CFrame, sector = n.sector })
			end
		end
		-- Camera channels follow the room code so tasks can name them.
		local camIndex = 0
		for _, d in model:GetDescendants() do
			if d:IsA("Model") and d.Name == "Camera" then
				camIndex += 1
				d:SetAttribute("Channel", string.format("%s/%d", n.roomCode, camIndex))
			end
		end
		-- Sounds flagged AutoPlay start now.
		for _, d in model:GetDescendants() do
			if d:IsA("Sound") and d:GetAttribute("AutoPlay") then
				d:Play()
			end
		end
		if i % 4 == 0 then
			task.wait()
		end
	end
	local doorsFolder = Builder.folder(root, "Doors")
	for _, e in layout.edges do
		local door = buildDoor(doorsFolder :: any, map.nodes[e.a], map.nodes[e.b], e)
		table.insert(map.doors, door)
		door.prompt.Triggered:Connect(function(player)
			-- ProximityPrompt enforces distance; double-check on server anyway.
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp or (hrp.Position - door.position).Magnitude > 14 then
				return
			end
			FacilityService.ToggleDoor(door, player)
		end)
	end
	-- Global alarm sound emitter
	local alarmSound = Builder.sound(root, Sounds.Alarm, "AlarmSound")
	alarmSound.RollOffMaxDistance = 10000
	alarmSound.Name = "AlarmSound"
	-- Defaults: all sectors powered except those a mission turns off.
	for _, n in layout.nodes do
		map.power[n.sector] = true
	end
	current = map
	for _, handle in map.nodes do
		applyLighting(handle, true, false)
	end
	startFlicker(map)
	return map
end

function FacilityService.ClearMap()
	if flickerThread then
		task.cancel(flickerThread)
		flickerThread = nil
	end
	local old = workspace:FindFirstChild("ActiveMap")
	if old then
		old:Destroy()
	end
	current = nil
end

function FacilityService.Current(): MapHandle?
	return current
end

-- Doors auto-close; one heartbeat-free loop.
function FacilityService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local map = current
			if map then
				local now = os.clock()
				for _, door in map.doors do
					if door.open and door.autoCloseAt > 0 and now >= door.autoCloseAt then
						-- Don't close on a character standing in the doorway.
						local blocked = false
						for _, p in Players:GetPlayers() do
							local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
							if hrp and (hrp.Position - door.position).Magnitude < 5 then
								blocked = true
								break
							end
						end
						if blocked then
							door.autoCloseAt = now + 2
						else
							setDoorOpen(door, false)
						end
					end
				end
			end
		end
	end)
end

function FacilityService.Init() end

return FacilityService
