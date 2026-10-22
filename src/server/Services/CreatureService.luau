--!nonstrict
-- Warden AI: finite state machine with real perception (line of sight, FOV,
-- hearing radius), PathfindingService navigation, door handling, stuck
-- recovery and honest target loss. Never teleports or reads positions it
-- has no in-world reason to know.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local FacilityService = require(script.Parent.FacilityService)
local WardenModel = require(script.Parent.Parent.Creatures.WardenModel)

local W = GameConfig.Warden

export type State = "Idle" | "Patrol" | "Suspicious" | "Investigate" | "Search" | "Chase" | "Attack" | "Recover" | "ReturnToPatrol"

type Warden = {
	rig: WardenModel.Rig,
	state: State,
	stateSince: number,
	target: Player?,
	lastSeen: Vector3?,
	lastSeenAt: number,
	suspicion: number,
	suspicionPos: Vector3?,
	investigatePos: Vector3?,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathGoal: Vector3?,
	pathAt: number,
	patrolTarget: Vector3?,
	idleUntil: number,
	attackAt: number,
	lastPos: Vector3,
	stuckSince: number,
	stuckCount: number,
	phase: number,
	speedMult: number,
	hearMult: number,
	searchPoints: { Vector3 },
	alive: boolean,
	stepAt: number,
}

local CreatureService = {}
CreatureService.StateChanged = Signal.new() :: Signal.Signal<string, string>
CreatureService.PlayerHit = Signal.new() :: Signal.Signal<Player, number>

local warden: Warden? = nil
local loopThread: thread? = nil
local rng = SeededRandom.new(7)
local flashlightOn: { [Player]: boolean } = {}
local isTargetable: (Player) -> boolean = function(_: Player)
	return true
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function CreatureService.SetTargetFilter(fn: (Player) -> boolean)
	isTargetable = fn
end

local function setState(w: Warden, s: State)
	if w.state == s then
		return
	end
	local prev = w.state
	w.state = s
	w.stateSince = os.clock()
	w.rig.model:SetAttribute("State", s)
	local speed = if s == "Chase" then W.ChaseSpeed elseif s == "Search" or s == "Investigate" then W.SearchSpeed else W.WalkSpeed
	w.rig.humanoid.WalkSpeed = speed * w.speedMult
	if s == "Suspicious" then
		w.rig.sounds.Suspicious:Play()
	end
	CreatureService.StateChanged:Fire(s, prev)
	-- Clients only learn the state name (for music/tension), never the position.
	Net.event("CreatureState"):FireAllClients({ creature = "Warden", state = s })
end

local function playersAlive(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 and isTargetable(p) then
			table.insert(out, p)
		end
	end
	return out
end

-- Returns true when the player's head is visible from the Warden's head.
local function canSee(w: Warden, player: Player): (boolean, number)
	local char = player.Character :: Model
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = char:FindFirstChild("Head") :: BasePart? or hrp
	local eye = w.rig.head.Position
	local toTarget = head.Position - eye
	local dist = toTarget.Magnitude
	local map = FacilityService.Current()
	local viewDist = W.ViewDistance
	-- Darkness halves sight unless the player is lit by their own flashlight.
	if map then
		local sectorPowered = true
		local nearest, nearestD = nil, math.huge
		for _, h in map.nodes do
			local d = (h.cframe.Position - hrp.Position).Magnitude
			if d < nearestD then
				nearest, nearestD = h, d
			end
		end
		if nearest then
			sectorPowered = map.power[nearest.node.sector] ~= false
		end
		if not sectorPowered and not flashlightOn[player] then
			viewDist *= 0.5
		end
	end
	if flashlightOn[player] then
		-- A flashlight pointed at the Warden is visible from much further away.
		local look = hrp.CFrame.LookVector
		if look:Dot(-toTarget.Unit) > 0.85 then
			viewDist *= W.FlashlightNoticeMultiplier
		end
	end
	if dist > viewDist then
		return false, dist
	end
	local forward = w.rig.root.CFrame.LookVector
	local angle = math.deg(math.acos(math.clamp(forward:Dot(toTarget.Unit), -1, 1)))
	if angle > W.ViewAngle / 2 and dist > 6 then
		return false, dist
	end
	-- Glass and invisible helpers do not block sight; walk through them (max 4 hits).
	local filter = { w.rig.model, char }
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(eye, toTarget, rayParams)
		if not hit or not hit.Instance then
			return true, dist
		end
		if hit.Instance.Transparency < 0.4 then
			return false, dist
		end
		table.insert(filter, hit.Instance)
	end
	return false, dist
end

local function computePath(w: Warden, goal: Vector3): boolean
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.6,
		AgentHeight = 10,
		AgentCanJump = false,
		WaypointSpacing = 6,
		Costs = { Door = 1, LockedDoor = math.huge },
	})
	local ok = pcall(function()
		path:ComputeAsync(w.rig.root.Position, goal)
	end)
	w.pathAt = os.clock()
	if ok and path.Status == Enum.PathStatus.Success then
		w.waypoints = path:GetWaypoints()
		w.waypointIndex = 2
		w.pathGoal = goal
		return true
	end
	w.waypoints = {}
	w.waypointIndex = 1
	w.pathGoal = nil
	return false
end

local function moveAlongPath(w: Warden)
	local wp = w.waypoints[w.waypointIndex]
	if not wp then
		return
	end
	local pos = w.rig.root.Position
	local flat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z)
	if flat.Magnitude < 3.5 then
		w.waypointIndex += 1
		wp = w.waypoints[w.waypointIndex]
		if not wp then
			return
		end
	end
	w.rig.humanoid:MoveTo(wp.Position)
	-- Open doors directly ahead.
	for _, door in FacilityService.DoorsNear(pos, 8) do
		if not door.open and not door.locked then
			local toDoor = door.position - pos
			if toDoor.Unit:Dot(w.rig.root.CFrame.LookVector) > 0.3 then
				FacilityService.OpenDoor(door, "warden")
			end
		end
	end
end

local function pathDone(w: Warden): boolean
	return w.waypointIndex > #w.waypoints
end

local function pickPatrolTarget(w: Warden): Vector3?
	local map = FacilityService.Current()
	if not map or #map.patrolPoints == 0 then
		return nil
	end
	-- Prefer points at a medium distance so it wanders instead of oscillating.
	local pos = w.rig.root.Position
	local candidates = {}
	for _, p in map.patrolPoints do
		local d = (p - pos).Magnitude
		if d > 25 and d < 160 then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		candidates = map.patrolPoints
	end
	return rng:pick(candidates)
end

local function nearestPatrolPoints(origin: Vector3, n: number): { Vector3 }
	local map = FacilityService.Current()
	if not map then
		return {}
	end
	local pts = table.clone(map.patrolPoints)
	table.sort(pts, function(a, b)
		return (a - origin).Magnitude < (b - origin).Magnitude
	end)
	local out = {}
	for i = 1, math.min(n, #pts) do
		table.insert(out, pts[i])
	end
	return rng:shuffle(out)
end

local function handleStuck(w: Warden, now: number)
	local pos = w.rig.root.Position
	local moving = w.state ~= "Idle" and w.state ~= "Attack" and w.idleUntil < now
	if not moving then
		w.lastPos = pos
		w.stuckSince = now
		return
	end
	if (pos - w.lastPos).Magnitude > 1.5 then
		w.lastPos = pos
		w.stuckSince = now
		w.stuckCount = 0
		return
	end
	if now - w.stuckSince > W.StuckSeconds then
		w.stuckSince = now
		w.stuckCount += 1
		-- Recompute; after repeated failures abandon this goal and pick another.
		if w.stuckCount >= 2 then
			w.stuckCount = 0
			w.patrolTarget = nil
			w.waypoints = {}
			if w.state ~= "Chase" then
				setState(w, "ReturnToPatrol")
			end
		else
			local goal = w.pathGoal
			if goal then
				-- Small sidestep to escape door jambs, then repath.
				local side = w.rig.root.CFrame.RightVector * (if rng:chance(0.5) then 3 else -3)
				w.rig.humanoid:MoveTo(pos + side)
				task.delay(0.4, function()
					if w.alive then
						computePath(w, goal)
					end
				end)
			end
		end
	end
end

local function perceive(w: Warden, now: number)
	local best: Player? = nil
	local bestDist = math.huge
	for _, p in playersAlive() do
		local visible, dist = canSee(w, p)
		if visible and dist < bestDist then
			best, bestDist = p, dist
		end
	end
	if w.state == "Chase" then
		if best then
			w.target = best
			w.lastSeen = (best.Character :: Model):FindFirstChild("HumanoidRootPart") and ((best.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart).Position
			w.lastSeenAt = now
		elseif w.target then
			-- Keep tracking the current target only while it stays visible; otherwise it is lost.
			if now - w.lastSeenAt > W.LoseTargetSeconds then
				w.target = nil
				setState(w, "Search")
				w.searchPoints = nearestPatrolPoints(w.lastSeen or w.rig.root.Position, 3)
				if w.lastSeen then
					computePath(w, w.lastSeen)
				end
			end
		end
		return
	end
	if best then
		local gain = W.PerceptionInterval * (if bestDist < 12 then 3 elseif bestDist < 24 then 1.6 else 1)
		w.suspicion = math.min(W.SuspicionSeconds + 1, w.suspicion + gain)
		w.suspicionPos = ((best.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart).Position
		if w.suspicion >= W.SuspicionSeconds then
			w.target = best
			w.lastSeen = w.suspicionPos
			w.lastSeenAt = now
			w.suspicion = 0
			setState(w, "Chase")
		elseif w.state ~= "Suspicious" and w.state ~= "Investigate" then
			setState(w, "Suspicious")
			w.rig.humanoid:MoveTo(w.rig.root.Position)
		end
	else
		w.suspicion = math.max(0, w.suspicion - W.PerceptionInterval * 0.7)
		if w.state == "Suspicious" and w.suspicion <= 0 then
			if w.suspicionPos then
				w.investigatePos = w.suspicionPos
				setState(w, "Investigate")
				computePath(w, w.suspicionPos)
			else
				setState(w, "ReturnToPatrol")
			end
		end
	end
	-- Hearing: footsteps from sprinting players.
	for _, p in playersAlive() do
		local hrp = (p.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		local speed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
		if speed > 13.5 then
			CreatureService.OnNoise(hrp.Position, W.HearDistanceSprint, p)
		end
	end
end

function CreatureService.OnNoise(position: Vector3, radius: number, source: Player?)
	local w = warden
	if not w or not w.alive then
		return
	end
	local dist = (position - w.rig.root.Position).Magnitude
	if dist > radius * w.hearMult then
		return
	end
	if w.state == "Chase" or w.state == "Attack" then
		return
	end
	if dist < 9 and source and isTargetable(source) then
		-- Point-blank noise: it knows exactly where you are.
		w.target = source
		w.lastSeen = position
		w.lastSeenAt = os.clock()
		setState(w, "Chase")
		return
	end
	w.investigatePos = position
	if w.state == "Search" then
		table.insert(w.searchPoints, 1, position)
	else
		setState(w, "Investigate")
		computePath(w, position)
	end
end

local function tick(w: Warden, dt: number, now: number)
	local hum = w.rig.humanoid
	local pos = w.rig.root.Position
	if w.state == "Idle" then
		if now >= w.idleUntil then
			setState(w, "Patrol")
			w.patrolTarget = pickPatrolTarget(w)
			if w.patrolTarget then
				computePath(w, w.patrolTarget)
			end
		end
	elseif w.state == "Patrol" or w.state == "ReturnToPatrol" then
		if not w.patrolTarget or (#w.waypoints == 0 and now - w.pathAt > 1) then
			w.patrolTarget = pickPatrolTarget(w)
			if w.patrolTarget and not computePath(w, w.patrolTarget) then
				w.patrolTarget = nil
			end
		elseif pathDone(w) then
			w.patrolTarget = nil
			w.idleUntil = now + rng:nextNumber(W.PatrolIdleSeconds[1], W.PatrolIdleSeconds[2])
			setState(w, "Idle")
			if rng:chance(0.4) then
				w.rig.sounds.Creak:Play()
			end
		else
			moveAlongPath(w)
		end
	elseif w.state == "Suspicious" then
		-- Stand still and look toward the stimulus.
		if w.suspicionPos then
			local look = Vector3.new(w.suspicionPos.X, pos.Y, w.suspicionPos.Z)
			w.rig.root.CFrame = w.rig.root.CFrame:Lerp(CFrame.lookAt(pos, look), math.min(1, dt * 3))
		end
		if now - w.stateSince > 6 then
			setState(w, "ReturnToPatrol")
		end
	elseif w.state == "Investigate" then
		if pathDone(w) or #w.waypoints == 0 then
			if #w.waypoints == 0 and w.investigatePos and now - w.pathAt > 1 then
				if not computePath(w, w.investigatePos) then
					setState(w, "ReturnToPatrol")
				end
			else
				-- Arrived: look around for a moment, then resume patrol.
				if now - w.stateSince > 3 then
					setState(w, "Search")
					w.searchPoints = nearestPatrolPoints(pos, 2)
					w.stateSince = now
				end
			end
		else
			moveAlongPath(w)
		end
	elseif w.state == "Search" then
		if now - w.stateSince > W.SearchSeconds then
			setState(w, "Recover")
		elseif pathDone(w) or #w.waypoints == 0 then
			local nextPoint = table.remove(w.searchPoints, 1)
			if nextPoint then
				computePath(w, nextPoint)
			else
				setState(w, "Recover")
			end
		else
			moveAlongPath(w)
		end
	elseif w.state == "Chase" then
		local target = w.target
		local goal = w.lastSeen
		if target and target.Character then
			local hrp = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and now - w.lastSeenAt < 0.5 then
				goal = hrp.Position
			end
		end
		if goal then
			local dist = (goal - pos).Magnitude
			if dist <= W.AttackRange + 1 and target and now - w.lastSeenAt < 0.6 then
				if now >= w.attackAt then
					setState(w, "Attack")
				end
			else
				if not w.pathGoal or (w.pathGoal - goal).Magnitude > 4 or now - w.pathAt > W.PathRepathInterval then
					computePath(w, goal)
				end
				if #w.waypoints == 0 then
					hum:MoveTo(goal)
				else
					moveAlongPath(w)
				end
			end
		else
			setState(w, "Search")
		end
	elseif w.state == "Attack" then
		local target = w.target
		local hrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local look = Vector3.new(hrp.Position.X, pos.Y, hrp.Position.Z)
			w.rig.root.CFrame = CFrame.lookAt(pos, look)
			hum:MoveTo(pos)
		end
		if now - w.stateSince > 0.45 then
			if hrp and (hrp.Position - pos).Magnitude <= W.AttackRange + 2.5 and target then
				w.rig.sounds.Attack:Play()
				-- RescueService applies the damage so a hit can down instead of kill.
				CreatureService.PlayerHit:Fire(target, W.AttackDamage)
			end
			w.attackAt = now + W.AttackCooldown
			setState(w, "Chase")
		end
	elseif w.state == "Recover" then
		hum:MoveTo(pos)
		if now - w.stateSince > 2.5 then
			w.target = nil
			setState(w, "ReturnToPatrol")
		end
	end
	handleStuck(w, now)
end

local function animate(w: Warden, dt: number)
	local vel = w.rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	w.phase += dt * speed * 0.55
	local factor = math.clamp(speed / W.ChaseSpeed, 0, 1)
	WardenModel.pose(w.rig, w.phase, factor, w.state)
	-- Footsteps keyed to the gait so audio matches the legs.
	local stepPhase = w.phase % math.pi
	if speed > 1 and stepPhase < 0.3 and os.clock() - w.stepAt > 0.35 then
		w.stepAt = os.clock()
		local s = if w.state == "Chase" then w.rig.sounds.StepChase else w.rig.sounds.Step
		s:Play()
		-- Footsteps are noise other systems may react to (e.g. HUD subtitles).
		FacilityService.Noise:Fire(w.rig.root.Position, 0, nil)
	end
end

function CreatureService.Spawn(position: Vector3, difficulty: string)
	CreatureService.Despawn()
	local map = FacilityService.Current()
	local parent = if map then map.root else workspace
	local rig = WardenModel.build(parent, CFrame.new(position + Vector3.new(0, 9, 0)))
	local diff = GameConfig.Difficulty[difficulty] or GameConfig.Difficulty.Normal
	local w: Warden = {
		rig = rig,
		state = "Idle",
		stateSince = os.clock(),
		target = nil,
		lastSeen = nil,
		lastSeenAt = 0,
		suspicion = 0,
		suspicionPos = nil,
		investigatePos = nil,
		waypoints = {},
		waypointIndex = 1,
		pathGoal = nil,
		pathAt = 0,
		patrolTarget = nil,
		idleUntil = os.clock() + 2,
		attackAt = 0,
		lastPos = position,
		stuckSince = os.clock(),
		stuckCount = 0,
		phase = 0,
		speedMult = diff.wardenSpeedMult,
		hearMult = diff.hearMult,
		searchPoints = {},
		alive = true,
		stepAt = 0,
	}
	warden = w
	rig.humanoid.WalkSpeed = W.WalkSpeed * w.speedMult
	rig.model:SetAttribute("State", "Idle")
	local lastPerceive = 0
	local lastPose = 0
	loopThread = task.spawn(function()
		while w.alive do
			local dt = task.wait(0.05)
			if not w.rig.model.Parent then
				break
			end
			local now = os.clock()
			if now - lastPerceive >= W.PerceptionInterval then
				lastPerceive = now
				perceive(w, now)
			end
			tick(w, dt, now)
			if now - lastPose >= 0.05 then
				animate(w, now - lastPose)
				lastPose = now
			end
		end
	end)
	Net.event("CreatureState"):FireAllClients({ creature = "Warden", state = "Idle" })
end

function CreatureService.Despawn()
	local w = warden
	if w then
		w.alive = false
		if w.rig.model.Parent then
			w.rig.model:Destroy()
		end
		warden = nil
	end
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

function CreatureService.State(): State?
	return if warden then warden.state else nil
end

function CreatureService.Position(): Vector3?
	return if warden then warden.rig.root.Position else nil
end

function CreatureService.Init()
	FacilityService.Noise:Connect(function(position, radius, source)
		if radius > 0 then
			CreatureService.OnNoise(position, radius, source)
		end
	end)
	Net.event("FlashlightState").OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" then
			return
		end
		flashlightOn[player] = on
		-- Replicated beam so teammates (and the Warden's perception) see the light.
		local head = player.Character and player.Character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if light then
			light.Enabled = on
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		flashlightOn[p] = nil
		if warden and warden.target == p then
			warden.target = nil
		end
	end)
	local _ = RunService
end

function CreatureService.Start() end

return CreatureService
