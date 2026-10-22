--!nonstrict
-- Owns the built station: map lifecycle, doors (swing, locks, auto-close),
-- zone/room queries, clocks and gauges. Other services ask this one where a
-- player is and whether a door between them and the cold is open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local StationBuilder = require(script.Parent.Parent.Map.StationBuilder)

export type DoorState = { model: Model, leaf: BasePart, hinge: BasePart, open: boolean, locked: boolean, heavy: boolean, exterior: boolean, openedAt: number, openedBy: string?, prompt: ProximityPrompt?, room: string?, sign: number }

local FacilityService = {}
FacilityService.DoorChanged = Signal.new() :: Signal.Signal<DoorState, string?>
FacilityService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local handle: StationBuilder.Handle? = nil
local doors: { [Model]: DoorState } = {}
local clockOffsets: { [string]: number } = { KitchenClock = 37 / 60, ControlClock = 0, RestClock = 0, DormClock = 0 }

function FacilityService.Current(): StationBuilder.Handle?
	return handle
end

function FacilityService.Origin(): Vector3
	return if handle then handle.origin else GameConfig.World.StationOrigin
end

function FacilityService.ToLocal(world: Vector3): Vector3
	return world - FacilityService.Origin()
end

function FacilityService.ToWorld(localPos: Vector3): Vector3
	return FacilityService.Origin() + localPos
end

function FacilityService.ZoneAt(world: Vector3): Station.Zone?
	return Station.zoneAt(FacilityService.ToLocal(world))
end

function FacilityService.RoomAt(world: Vector3): Station.Room?
	return Station.roomAt(FacilityService.ToLocal(world))
end

function FacilityService.PlayerPosition(player: Player): Vector3?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.CFrame.Position
	end
	return nil
end

function FacilityService.PlayerZone(player: Player): Station.Zone?
	local pos = FacilityService.PlayerPosition(player)
	return if pos then FacilityService.ZoneAt(pos) else nil
end

function FacilityService.IsInNightSafeZone(player: Player): boolean
	local z = FacilityService.PlayerZone(player)
	return z ~= nil and Station.NightSafeZones[z.id] == true
end

-- ===== Doors =============================================================

local function playDoorSound(d: DoorState, key: string)
	local def = Sounds[key]
	if not def or not def.id then
		return
	end
	local s = Builder.sound(d.leaf, def, key)
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

local function swing(d: DoorState, open: boolean, towards: Vector3?)
	local closed = d.hinge.CFrame * (d.model:GetAttribute("ClosedOffset") :: CFrame)
	local target = closed
	if open then
		-- Swing away from whoever opened it so the leaf never pushes through them.
		local sign = d.sign
		if towards then
			local rel = d.leaf.CFrame:PointToObjectSpace(towards)
			sign = if rel.Z > 0 then -1 else 1
			d.sign = sign
		end
		target = d.hinge.CFrame * CFrame.Angles(0, sign * math.rad(if d.heavy then 92 else 104), 0) * (d.model:GetAttribute("ClosedOffset") :: CFrame)
	end
	local info = TweenInfo.new(if d.heavy then 1.2 else 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(d.leaf, info, { CFrame = target })
	tw:Play()
end

function FacilityService.SetDoor(d: DoorState, open: boolean, actor: Player?, by: string?): boolean
	if d.open == open then
		return false
	end
	if open and d.locked then
		playDoorSound(d, "DoorLocked")
		return false
	end
	d.open = open
	d.openedAt = os.clock()
	d.openedBy = by or (if actor then "player" else nil)
	d.model:SetAttribute("Open", open)
	local towards = if actor then FacilityService.PlayerPosition(actor) else nil
	swing(d, open, towards)
	playDoorSound(d, if d.heavy then "DoorHeavy" else "DoorSwing")
	if d.prompt then
		d.prompt.ActionText = if open then "Закрыть" else "Открыть"
	end
	FacilityService.Noise:Fire(d.leaf.CFrame.Position, if d.heavy then "DoorHeavy" else "Door", actor)
	FacilityService.DoorChanged:Fire(d, by)
	return true
end

function FacilityService.SetLocked(model: Model, locked: boolean)
	local d = doors[model]
	if not d then
		return
	end
	d.locked = locked
	model:SetAttribute("Locked", locked)
	local mod = d.leaf:FindFirstChildOfClass("PathfindingModifier")
	if mod then
		mod.Label = if locked then "LockedDoor" else "Door"
	end
	if d.prompt then
		d.prompt.ActionText = if locked then "Заблокировано" else (if d.open then "Закрыть" else "Открыть")
	end
end

function FacilityService.Door(model: Model): DoorState?
	return doors[model]
end

function FacilityService.OpenDoor(model: Model, by: string?): boolean
	local d = doors[model]
	if not d then
		return false
	end
	return FacilityService.SetDoor(d, true, nil, by)
end

function FacilityService.CloseDoor(model: Model, by: string?): boolean
	local d = doors[model]
	if not d then
		return false
	end
	return FacilityService.SetDoor(d, false, nil, by)
end

function FacilityService.DoorsNear(pos: Vector3, radius: number): { DoorState }
	local out = {}
	for _, d in doors do
		if (d.leaf.CFrame.Position - pos).Magnitude <= radius then
			table.insert(out, d)
		end
	end
	return out
end

-- True when any exterior door of the given zone is open (heat leak, snow).
function FacilityService.ExteriorDoorOpen(zoneId: string): boolean
	for _, d in doors do
		if d.exterior and d.open then
			local z = FacilityService.ZoneAt(d.leaf.CFrame.Position + d.leaf.CFrame.LookVector * -2)
			local z2 = FacilityService.ZoneAt(d.leaf.CFrame.Position + d.leaf.CFrame.LookVector * 2)
			if (z and z.id == zoneId) or (z2 and z2.id == zoneId) then
				return true
			end
		end
	end
	return false
end

local function wireDoor(model: Model)
	local leaf = model:FindFirstChild("Leaf") :: BasePart
	local hinge = model:FindFirstChild("Hinge") :: BasePart
	if not leaf or not hinge then
		return
	end
	local d: DoorState = {
		model = model,
		leaf = leaf,
		hinge = hinge,
		open = false,
		locked = model:GetAttribute("Locked") == true,
		heavy = model:GetAttribute("Heavy") == true,
		exterior = model:GetAttribute("Exterior") == true,
		openedAt = 0,
		openedBy = nil,
		prompt = nil,
		room = model:GetAttribute("Room"),
		sign = 1,
	}
	doors[model] = d
	if model:GetAttribute("LeverOnly") then
		return -- bunker door: only the lever operates it
	end
	local prompt = Builder.prompt(leaf, if d.locked then "Заблокировано" else "Открыть", if d.heavy then "Тяжёлая дверь" else "Дверь", 0, Enum.KeyCode.E, 9)
	prompt:SetAttribute("UI", "Door")
	d.prompt = prompt
	prompt.Triggered:Connect(function(player)
		local pos = FacilityService.PlayerPosition(player)
		if not pos or (pos - leaf.CFrame.Position).Magnitude > 11 then
			return
		end
		if d.locked then
			playDoorSound(d, "DoorLocked")
			if model:GetAttribute("KeypadLocked") then
				FacilityService.Notify(player, { title = "Заперто", text = "Кодовый замок. Код — в журнале выдачи.", kind = "warn" })
			elseif model:GetAttribute("ScannerLocked") then
				FacilityService.Notify(player, { title = "Заперто", text = "Пройдите контроль входа на сканере.", kind = "warn" })
			end
			return
		end
		FacilityService.SetDoor(d, not d.open, player, "player")
	end)
end

function FacilityService.Notify(player: Player, payload)
	local Net = require(ReplicatedStorage.Shared.Utilities.Net)
	Net.event("Notification"):FireClient(player, payload)
end

-- ===== Clocks & gauges ===================================================

function FacilityService.UpdateClocks(hour: number)
	if not handle then
		return
	end
	for _, clock in handle.clocks do
		local center = clock:GetAttribute("Center") :: CFrame?
		if not center then
			continue
		end
		local h = hour + (clockOffsets[clock.Name] or 0)
		local hourAngle = -(h % 12) / 12 * math.pi * 2
		local minAngle = -((h * 60) % 60) / 60 * math.pi * 2
		for _, hand in clock:GetChildren() do
			local kind = hand:GetAttribute("Hand")
			if kind == "hour" then
				hand.CFrame = center * CFrame.new(0, 0, 0.15) * CFrame.Angles(0, 0, hourAngle) * CFrame.new(0, 0.35, 0)
			elseif kind == "minute" then
				hand.CFrame = center * CFrame.new(0, 0, 0.17) * CFrame.Angles(0, 0, minAngle) * CFrame.new(0, 0.45, 0)
			end
		end
	end
end

function FacilityService.SetGauge(face: BasePart?, value: number)
	if not face then
		return
	end
	local v = math.clamp(value, 0, 1)
	face:SetAttribute("Value", v)
	local center = face:GetAttribute("Center") :: CFrame?
	local needle = face:FindFirstChild("Needle")
	if center and needle then
		local ang = math.rad(120) - v * math.rad(240)
		needle.CFrame = center * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.2, 0)
	end
end

function FacilityService.SetStatusBoard(lines: { string })
	if not handle or not handle.statusBoard then
		return
	end
	local gui = handle.statusBoard:FindFirstChildOfClass("SurfaceGui")
	local lbl = gui and gui:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.Text = table.concat(lines, "\n")
	end
end

function FacilityService.SetBoardText(board: BasePart?, lines: { string })
	if not board then
		return
	end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	local lbl = gui and gui:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.Text = table.concat(lines, "\n")
	end
end

-- ===== Lifecycle =========================================================

function FacilityService.BuildMap(seed: number): StationBuilder.Handle
	FacilityService.ClearMap()
	local h = StationBuilder.build(workspace, GameConfig.World.StationOrigin, seed, 1)
	handle = h
	doors = {}
	for _, d in h.allDoors do
		wireDoor(d)
	end
	-- Scanner-controlled inner door and lever-only bunker door start locked.
	if h.doors.airlockInner then
		h.doors.airlockInner:SetAttribute("ScannerLocked", true)
		FacilityService.SetLocked(h.doors.airlockInner, true)
	end
	if h.doors.bunker then
		FacilityService.SetLocked(h.doors.bunker, true)
	end
	for _, s in h.root:GetDescendants() do
		if s:IsA("Sound") and s:GetAttribute("AutoPlay") then
			s.Looped = true
			s:Play()
		end
	end
	return h
end

function FacilityService.ClearMap()
	if handle then
		handle.root:Destroy()
		handle = nil
	end
	doors = {}
	local stale = workspace:FindFirstChild("ActiveMap")
	if stale then
		stale:Destroy()
	end
end

function FacilityService.Init() end

function FacilityService.Start()
	-- Interior doors auto-close; exterior doors stay as the player left them
	-- (and leak heat), which is the whole point of the airlock rules.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, d in doors do
				if d.open and not d.exterior and now - d.openedAt > (if d.openedBy == "guest" then 4 else 8) then
					local blocked = false
					for _, p in Players:GetPlayers() do
						local pos = FacilityService.PlayerPosition(p)
						if pos and (pos - d.leaf.CFrame.Position).Magnitude < 5 then
							blocked = true
							break
						end
					end
					if not blocked then
						FacilityService.SetDoor(d, false, nil, "auto")
					end
				end
			end
		end
	end)
end

return FacilityService
