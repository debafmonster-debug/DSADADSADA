--!nonstrict
-- Identity control. The airlock scanner enforces one rule: two instances of
-- the same identity cannot both be accepted inside. Doubles are server-owned
-- NPCs copying a participant; they try the scanner like anyone else. Players
-- can inspect any participant with the diagnostic device; the truth lives
-- only in server tables.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local FacilityService = require(script.Parent.FacilityService)
local DoppelgangerModel = require(script.Parent.Parent.Creatures.DoppelgangerModel)

local I = GameConfig.Identity

export type Identity = { userId: number, player: Player, originalInside: boolean, doubleInside: boolean, outsideSeconds: number, lastScanAt: number, denials: number }
export type Double = { body: DoppelgangerModel.Body, identity: Identity, phase: string, goal: Vector3?, waypoints: { PathWaypoint }, wpIndex: number, pathAt: number, since: number, exposed: boolean, seatName: string?, lookDelayUntil: number }

local IdentityService = {}
IdentityService.Scanned = Signal.new() :: Signal.Signal<Player?, boolean, string>
IdentityService.DoubleSpawned = Signal.new() :: Signal.Signal<Double>
IdentityService.DoubleExposed = Signal.new() :: Signal.Signal<Double, Player?>
IdentityService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local identities: { [number]: Identity } = {}
local doubles: { Double } = {}
local active = false
local spawnedCount = 0
local rng = SeededRandom.new(3)
local map = nil
local deps = {
	scannerPowered = function()
		return true
	end,
	stationHour = function()
		return 0
	end,
	isNight = function()
		return false
	end,
	weatherSeverity = function()
		return 0
	end,
	toolCap = function(_: Player, _: string)
		return false
	end,
	inShift = function(_: Player)
		return false
	end,
	creatureAlert = function(_: number) end,
}

function IdentityService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function IdentityService.Identity(player: Player): Identity?
	return identities[player.UserId]
end

function IdentityService.Doubles(): { Double }
	return doubles
end

function IdentityService.IsDouble(model: Instance?): boolean
	for _, d in doubles do
		if d.body.model == model then
			return true
		end
	end
	return false
end

-- ===== Scanner ===========================================================

local function setScannerText(text: string, color: Color3)
	if not map or not map.scanner then
		return
	end
	local screen = map.scanner:FindFirstChild("Screen")
	local lbl = screen and screen:FindFirstChildOfClass("SurfaceGui")
	lbl = lbl and lbl:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.Text = "КОНТРОЛЬ ВХОДА\n" .. text
	end
	local lamp = map.scanner:FindFirstChild("StatusLamp")
	if lamp then
		lamp.Color = color
		local light = lamp:FindFirstChildWhichIsA("Light")
		if light then
			light.Color = color
		end
	end
end

local function scannerSound(key: string)
	if not map or not map.scanner then
		return
	end
	local s = Builder.sound(map.scanner.PrimaryPart, Sounds[key], key)
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

local function admit(seconds: number)
	if not map or not map.doors.airlockInner then
		return
	end
	local door = map.doors.airlockInner
	FacilityService.SetLocked(door, false)
	FacilityService.OpenDoor(door, "scanner")
	task.delay(seconds, function()
		if map and map.doors.airlockInner == door then
			FacilityService.CloseDoor(door, "scanner")
			if deps.scannerPowered() then
				FacilityService.SetLocked(door, true)
			end
		end
	end)
end

-- Core rule. `who` is a Player or a Double. Returns accepted, reason.
function IdentityService.Scan(who: any): (boolean, string)
	local isDouble = typeof(who) == "table" and who.identity ~= nil
	local identity: Identity? = if isDouble then who.identity else identities[who.UserId]
	if not identity then
		return false, "НЕИЗВЕСТНАЯ ЛИЧНОСТЬ"
	end
	identity.lastScanAt = os.clock()
	if not deps.scannerPowered() then
		-- Fail-open: without power the door is simply unlocked, nothing is verified.
		return true, "НЕТ ПИТАНИЯ · ПРОХОД СВОБОДЕН"
	end
	if isDouble then
		if identity.originalInside then
			identity.denials += 1
			return false, "ОТКАЗ: ЛИЧНОСТЬ УЖЕ ВНУТРИ"
		end
		identity.doubleInside = true
		return true, "ДОПУСК: " .. string.upper(identity.player.DisplayName)
	else
		if identity.doubleInside then
			identity.denials += 1
			return false, "ОТКАЗ: ЛИЧНОСТЬ УЖЕ ВНУТРИ"
		end
		identity.originalInside = true
		return true, "ДОПУСК: " .. string.upper(identity.player.DisplayName)
	end
end

local function onScanPrompt(player: Player)
	if not map or not deps.inShift(player) then
		return
	end
	if not Net.near(player, map.scanner.PrimaryPart.CFrame.Position, 9) then
		return
	end
	local ok, reason = IdentityService.Scan(player)
	IdentityService.Noise:Fire(map.scanner.PrimaryPart.CFrame.Position, "Scanner", player)
	if ok then
		setScannerText(reason, Builder.Palette.Green)
		scannerSound("ScannerOk")
		admit(6)
	else
		setScannerText(reason, Builder.Palette.Red)
		scannerSound("ScannerDeny")
		Net.event("Notification"):FireClient(player, { title = "Контроль входа", text = reason, kind = "danger" })
	end
	Net.event("ScannerEvent"):FireAllClients({ name = player.DisplayName, ok = ok, reason = reason })
	IdentityService.Scanned:Fire(player, ok, reason)
	task.delay(5, function()
		setScannerText("ОЖИДАНИЕ", Builder.Palette.LightCold)
	end)
end

local function onOverride(player: Player)
	if not map or not deps.inShift(player) then
		return
	end
	if not Net.near(player, map.scannerOverride.CFrame.Position, 8) then
		return
	end
	-- Must be on the inside of the inner door.
	local zone = FacilityService.PlayerZone(player)
	if not zone or zone.id ~= "Main" then
		return
	end
	IdentityService.Noise:Fire(map.scannerOverride.CFrame.Position, "Scanner", player)
	setScannerText("РУЧНАЯ РАЗБЛОКИРОВКА", Builder.Palette.Yellow)
	admit(8)
	Net.event("ScannerEvent"):FireAllClients({ name = player.DisplayName, ok = true, reason = "РУЧНАЯ РАЗБЛОКИРОВКА", manual = true })
end

-- ===== Doubles ===========================================================

local function computePath(d: Double, goal: Vector3)
	local ok, path = pcall(function()
		local p = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 5, Costs = { Door = 1, LockedDoor = math.huge } })
		p:ComputeAsync(d.body.root.CFrame.Position, goal)
		return p
	end)
	d.pathAt = os.clock()
	if ok and path.Status == Enum.PathStatus.Success then
		d.waypoints = path:GetWaypoints()
		d.wpIndex = 2
	else
		d.waypoints = {}
		d.wpIndex = 1
	end
end

local function moveTowards(d: Double, goal: Vector3)
	if d.goal ~= goal or os.clock() - d.pathAt > 3 then
		d.goal = goal
		computePath(d, goal)
	end
	local wp = d.waypoints[d.wpIndex]
	if wp and (wp.Position - d.body.root.CFrame.Position).Magnitude < 3 then
		d.wpIndex += 1
		wp = d.waypoints[d.wpIndex]
	end
	d.body.humanoid:MoveTo(if wp then wp.Position else goal)
	for _, door in FacilityService.DoorsNear(d.body.root.CFrame.Position, 5) do
		if not door.open and not door.locked then
			FacilityService.SetDoor(door, true, nil, "double")
		end
	end
end

local function arrived(d: Double, goal: Vector3, tol: number): boolean
	local p = d.body.root.CFrame.Position
	return (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude <= tol
end

local function freeBed(): (Vector3?, string?)
	if not map then
		return nil, nil
	end
	local taken = {}
	for _, d in doubles do
		if d.seatName then
			taken[d.seatName] = true
		end
	end
	local dormRoom = map.root:FindFirstChild("Room_Dorm")
	if not dormRoom then
		return nil, nil
	end
	local beds = {}
	for _, m in dormRoom:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("BedIndex") and not taken[m.Name] then
			table.insert(beds, m)
		end
	end
	if #beds == 0 then
		return nil, nil
	end
	local bed = beds[rng:nextInteger(1, #beds)]
	local seat = bed:FindFirstChild("Seat")
	local pos = if seat then seat.CFrame.Position else bed:GetPivot().Position
	return pos + Vector3.new(0, 0, 3.2), bed.Name
end

local function despawnDouble(d: Double)
	local i = table.find(doubles, d)
	if i then
		table.remove(doubles, i)
	end
	if d.identity.doubleInside then
		d.identity.doubleInside = false
	end
	d.body.model:Destroy()
end

local function stepDouble(d: Double, now: number)
	if not map then
		return
	end
	local body = d.body
	if d.phase == "approach" then
		local outer = map.point("AirlockOuterDoor") + Vector3.new(-8, 0, 0)
		if arrived(d, outer, 4) then
			d.phase = "enter"
			d.since = now
		else
			moveTowards(d, outer)
		end
	elseif d.phase == "enter" then
		-- Open the exterior door like a person would, step to the scanner.
		local outerDoor = map.doors.airlockOuter
		if outerDoor and not outerDoor:GetAttribute("Open") then
			FacilityService.OpenDoor(outerDoor, "double")
		end
		local scanPos = map.scanner.PrimaryPart.CFrame.Position + Vector3.new(-2, -4, -2)
		if arrived(d, scanPos, 3) then
			d.phase = "scan"
			d.since = now
			body.humanoid:MoveTo(body.root.CFrame.Position)
		else
			moveTowards(d, scanPos)
		end
	elseif d.phase == "scan" then
		if now - d.since > 1.5 then
			local ok, reason = IdentityService.Scan(d)
			IdentityService.Noise:Fire(map.scanner.PrimaryPart.CFrame.Position, "Scanner", nil)
			Net.event("ScannerEvent"):FireAllClients({ name = d.identity.player.DisplayName, ok = ok, reason = reason })
			IdentityService.Scanned:Fire(nil, ok, reason)
			if ok then
				setScannerText(reason, Builder.Palette.Green)
				scannerSound("ScannerOk")
				admit(6)
				d.phase = "inside"
				d.since = now
				d.goal, d.seatName = freeBed()
			else
				setScannerText(reason, Builder.Palette.Red)
				scannerSound("ScannerDeny")
				Net.event("Notification"):FireAllClients({ title = "Контроль входа", text = reason .. " — " .. d.identity.player.DisplayName, kind = "danger" })
				d.phase = "denied"
				d.since = now
			end
			task.delay(5, function()
				setScannerText("ОЖИДАНИЕ", Builder.Palette.LightCold)
			end)
		end
	elseif d.phase == "denied" then
		if now - d.since > 4 then
			local away = map.point("AirlockOuterDoor") + Vector3.new(-80, 0, rng:nextNumber(-40, 40))
			if now - d.since > I.DespawnAfterDeniedSeconds or arrived(d, away, 6) then
				despawnDouble(d)
			else
				moveTowards(d, away)
			end
		end
	elseif d.phase == "inside" then
		local goal = d.goal
		if not goal then
			goal = map.point("DormBoard") + Vector3.new(-6, 0, -4)
		end
		if arrived(d, goal, 2.5) then
			d.phase = "wait"
			d.since = now
			body.humanoid:MoveTo(body.root.CFrame.Position)
			-- Face the room, then stay unnaturally still.
			local look = body.root.CFrame.Position + Vector3.new(0, 0, -6)
			body.root.CFrame = CFrame.lookAt(body.root.CFrame.Position, Vector3.new(look.X, body.root.CFrame.Position.Y, look.Z))
			body.root.Anchored = true
		else
			moveTowards(d, goal)
		end
	elseif d.phase == "wait" then
		-- Clue: delayed head/body turn towards whoever comes close and looks.
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.CFrame.Position - body.root.CFrame.Position).Magnitude < 5 then
				if d.lookDelayUntil == 0 then
					d.lookDelayUntil = now + 1.6 + rng:nextNumber() * 1.2
				elseif now >= d.lookDelayUntil and now - d.lookDelayUntil < 0.2 then
					local target = Vector3.new(hrp.CFrame.Position.X, body.root.CFrame.Position.Y, hrp.CFrame.Position.Z)
					body.root.CFrame = CFrame.lookAt(body.root.CFrame.Position, target)
				end
				return
			end
		end
		d.lookDelayUntil = 0
	elseif d.phase == "flee" then
		local exit = map.point("DormExitDoor") + Vector3.new(0, 0, 30)
		if arrived(d, exit, 6) or now - d.since > 40 then
			despawnDouble(d)
		else
			moveTowards(d, exit)
		end
	end
end

function IdentityService.SpawnDouble(player: Player): Double?
	if not map or spawnedCount >= I.MaxDoublesPerShift then
		return nil
	end
	local identity = identities[player.UserId]
	if not identity or identity.doubleInside then
		return nil
	end
	-- Spawn out in the fog, away from everyone.
	local best, bestD = nil, -1
	for _ = 1, 8 do
		local ang = rng:nextNumber() * math.pi * 2
		local dist = rng:nextNumber(I.SpawnDistance[1], I.SpawnDistance[2])
		local pos = map.point("AirlockOuterDoor") + Vector3.new(math.cos(ang) * dist - 20, 0, math.sin(ang) * dist)
		local nearest = math.huge
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				nearest = math.min(nearest, (hrp.CFrame.Position - pos).Magnitude)
			end
		end
		if nearest > bestD then
			best, bestD = pos, nearest
		end
	end
	if not best or bestD < 45 then
		return nil
	end
	local body = DoppelgangerModel.build(player, map.root, CFrame.new(best + Vector3.new(0, 4, 0)))
	if not body then
		return nil
	end
	local d: Double = { body = body, identity = identity, phase = "approach", goal = nil, waypoints = {}, wpIndex = 1, pathAt = 0, since = os.clock(), exposed = false, seatName = nil, lookDelayUntil = 0 }
	table.insert(doubles, d)
	spawnedCount += 1
	-- Inspection prompt: identical to the one real participants carry.
	IdentityService.AttachInspectPrompt(body.root, player.DisplayName, function(inspector)
		IdentityService.Expose(d, inspector)
	end)
	IdentityService.DoubleSpawned:Fire(d)
	return d
end

function IdentityService.Expose(d: Double, by: Player?)
	if d.exposed then
		return
	end
	d.exposed = true
	d.body.root.Anchored = false
	d.body.humanoid.WalkSpeed = 15
	local s = Builder.sound(d.body.root, Sounds.DoubleReveal, "Reveal")
	s:Play()
	d.phase = "flee"
	d.since = os.clock()
	if d.identity.doubleInside then
		d.identity.doubleInside = false
	end
	Net.event("Notification"):FireAllClients({ title = "Биометрия не совпадает", text = (if by then by.DisplayName .. ": " else "") .. "«" .. d.identity.player.DisplayName .. "» — не человек.", kind = "danger" })
	deps.creatureAlert(0.3)
	IdentityService.DoubleExposed:Fire(d, by)
end

-- Same prompt for everyone so inspecting is not a tell by itself.
function IdentityService.AttachInspectPrompt(root: BasePart, displayName: string, onDouble: ((Player) -> ())?)
	local existing = root:FindFirstChild("InspectPrompt")
	if existing then
		existing:Destroy()
	end
	local prompt = Builder.prompt(root, "Проверить прибором", displayName, I.InspectHoldSeconds, Enum.KeyCode.Q, 6)
	prompt.Name = "InspectPrompt"
	prompt:SetAttribute("UI", "Inspect")
	prompt:SetAttribute("HoldBase", I.InspectHoldSeconds)
	prompt:SetAttribute("ToolCap", "identity_check")
	local began = {}
	prompt.PromptButtonHoldBegan:Connect(function(p)
		began[p] = os.clock()
	end)
	prompt.Triggered:Connect(function(inspector)
		if not deps.inShift(inspector) or not deps.toolCap(inspector, "identity_check") then
			Net.event("Notification"):FireClient(inspector, { title = "Нужен прибор", text = "Проверка личности требует диагностический прибор.", kind = "warn" })
			return
		end
		local t0 = began[inspector]
		if not t0 or os.clock() - t0 < I.InspectHoldSeconds - 0.3 then
			return
		end
		if not Net.near(inspector, root.CFrame.Position, 8) then
			return
		end
		if onDouble then
			onDouble(inspector)
		else
			Net.event("Notification"):FireClient(inspector, { title = "Диагностика", text = displayName .. ": показатели в норме.", kind = "good" })
		end
	end)
end

-- ===== Headcount =========================================================

-- Counts bodies in the dorm sector: real participants plus accepted doubles.
function IdentityService.CountInDorm(): (number, number)
	local people, bodies = 0, 0
	for _, p in Players:GetPlayers() do
		if deps.inShift(p) and FacilityService.IsInNightSafeZone(p) then
			people += 1
			bodies += 1
		end
	end
	for _, d in doubles do
		local z = FacilityService.ZoneAt(d.body.root.CFrame.Position)
		if z and (z.id == "Dorm" or z.id == "Bunker") and not d.exposed then
			bodies += 1
		end
	end
	return people, bodies
end

-- ===== Lifecycle =========================================================

function IdentityService.BeginShift(players: { Player }, mapHandle: any, seed: number)
	map = mapHandle
	rng = SeededRandom.new(seed + 11)
	table.clear(identities)
	for _, d in doubles do
		d.body.model:Destroy()
	end
	table.clear(doubles)
	spawnedCount = 0
	active = true
	for _, p in players do
		identities[p.UserId] = { userId = p.UserId, player = p, originalInside = false, doubleInside = false, outsideSeconds = 0, lastScanAt = 0, denials = 0 }
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			IdentityService.AttachInspectPrompt(root, p.DisplayName, nil)
		end
	end
	if map and map.scanner then
		local prompt = Builder.prompt(map.scanner.PrimaryPart, "Отметиться", "Контроль входа", 1.2, Enum.KeyCode.E, 8)
		prompt:SetAttribute("UI", "Scanner")
		prompt.Triggered:Connect(onScanPrompt)
		setScannerText("ОЖИДАНИЕ", Builder.Palette.LightCold)
	end
	if map and map.scannerOverride then
		local prompt = Builder.prompt(map.scannerOverride, "Ручная разблокировка", "Внутренняя дверь", 1.5, Enum.KeyCode.E, 7)
		prompt:SetAttribute("UI", "Override")
		prompt.Triggered:Connect(onOverride)
	end
end

function IdentityService.EndShift()
	active = false
	for _, d in doubles do
		d.body.model:Destroy()
	end
	table.clear(doubles)
	table.clear(identities)
	map = nil
end

-- Called once a second by Start(): tracks inside/outside and rolls shadows.
function IdentityService.Tick(dt: number)
	if not active or not map then
		return
	end
	for _, id in identities do
		local p = id.player
		if p.Parent ~= Players then
			continue
		end
		local zone = FacilityService.PlayerZone(p)
		local inside = zone ~= nil and (zone.id == "Main" or zone.id == "Passage" or zone.id == "Dorm" or zone.id == "Bunker")
		id.originalInside = inside
		if inside then
			id.outsideSeconds = math.max(0, id.outsideSeconds - dt * 0.5)
		else
			id.outsideSeconds += dt
		end
	end
	-- Scanner power: unlock the inner door when the circuit is dead.
	local door = map.doors.airlockInner
	if door then
		local d = FacilityService.Door(door)
		if d then
			if not deps.scannerPowered() and d.locked then
				FacilityService.SetLocked(door, false)
				setScannerText("НЕТ ПИТАНИЯ", Builder.Palette.Graphite)
			elseif deps.scannerPowered() and not d.locked and not d.open and (os.clock() - d.openedAt) > 10 then
				FacilityService.SetLocked(door, true)
			end
		end
	end
	for i = #doubles, 1, -1 do
		local ok, err = pcall(stepDouble, doubles[i], os.clock())
		if not ok then
			warn("[Identity] double step: " .. tostring(err))
		end
	end
end

local rollAccumulator = 0
function IdentityService.RollShadows(dt: number)
	rollAccumulator += dt
	if rollAccumulator < I.CheckIntervalSeconds then
		return
	end
	rollAccumulator = 0
	if deps.stationHour() < I.MinStationHour and not deps.isNight() then
		return
	end
	for _, id in identities do
		if id.outsideSeconds >= I.OutsideSecondsForShadow and not id.doubleInside and spawnedCount < I.MaxDoublesPerShift then
			local chance = I.ShadowChance + deps.weatherSeverity() * 0.2
			if rng:nextNumber() < chance then
				id.outsideSeconds = 0
				IdentityService.SpawnDouble(id.player)
			end
		end
	end
end

function IdentityService.Init() end

function IdentityService.Start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			IdentityService.Tick(dt)
			IdentityService.RollShadows(dt)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		identities[p.UserId] = nil
	end)
end

return IdentityService
