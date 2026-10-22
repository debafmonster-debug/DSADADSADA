--!nonstrict
-- «Гость» AI. Server-authoritative state machine driven by sight (raycast
-- cone, no wall-hacks), hearing (NoiseDirector only) and a slow alertness
-- value. Moves on real paths, opens unlocked doors, never teleports near a
-- player. Position is never replicated through remotes — only the state name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local GuestModel = require(script.Parent.Parent.Creatures.GuestModel)
local NoiseDirector = require(script.Parent.NoiseDirector)
local FacilityService = require(script.Parent.FacilityService)

local G = GameConfig.Guest

export type State = "Idle" | "Patrol" | "InvestigateNoise" | "SearchArea" | "Observe" | "Stalk" | "Chase" | "LostTarget" | "ReturnToPatrol" | "ScriptedStoryEvent" | "Retreat"

local CreatureService = {}
CreatureService.StateChanged = Signal.new() :: Signal.Signal<string, string>
CreatureService.PlayerHit = Signal.new() :: Signal.Signal<Player, number>
CreatureService.Interacted = Signal.new() :: Signal.Signal<string, Instance?>

type Guest = {
	rig: GuestModel.Rig,
	state: State,
	stateAt: number,
	target: Player?,
	lastSeenPos: Vector3?,
	lastSeenAt: number,
	goal: Vector3?,
	waypoints: { PathWaypoint },
	wpIndex: number,
	pathAt: number,
	pathFails: number,
	stuckSince: number?,
	lastPos: Vector3,
	phase: number,
	idleUntil: number,
	alertness: number,
	calmUntil: number,
	searchPoints: { Vector3 },
	observeUntil: number,
	lastAttack: number,
	scripted: { kind: string, data: any, step: number, at: number }?,
	allowIndoor: boolean,
	hunting: boolean,
	lastStep: number,
	speedMult: number,
	hearMult: number,
}

local guest: Guest? = nil
local rng = SeededRandom.new(7)
local targetFilter: (Player) -> boolean = function(_)
	return true
end
local lastBroadcast = ""
local map = nil -- StationBuilder.Handle

function CreatureService.SetTargetFilter(fn: (Player) -> boolean)
	targetFilter = fn
end

function CreatureService.State(): string?
	return if guest then guest.state else nil
end

function CreatureService.Alertness(): number
	return if guest then guest.alertness else 0
end

function CreatureService.Position(): Vector3?
	return if guest then guest.rig.root.CFrame.Position else nil
end

function CreatureService.IsActive(): boolean
	return guest ~= nil
end

local function broadcast()
	if not guest then
		return
	end
	local band = if guest.alertness > 0.66 then "high" elseif guest.alertness > 0.33 then "mid" else "low"
	local key = guest.state .. band
	if key == lastBroadcast then
		return
	end
	lastBroadcast = key
	Net.event("CreatureState"):FireAllClients({ creature = "Guest", state = guest.state, alert = band })
end

local function setState(s: State)
	if not guest or guest.state == s then
		return
	end
	local prev = guest.state
	guest.state = s
	guest.stateAt = os.clock()
	guest.rig.model:SetAttribute("State", s)
	CreatureService.StateChanged:Fire(s, prev)
	local eyes = if s == "Chase" then 1 elseif s == "Stalk" or s == "Observe" then 0.6 elseif s == "InvestigateNoise" or s == "SearchArea" then 0.4 else 0.2
	GuestModel.setEyes(guest.rig, eyes)
	if s == "Stalk" or s == "Chase" then
		guest.rig.sounds.Notice:Play()
	end
	broadcast()
end

-- ===== Perception ========================================================

local function playerRoot(p: Player): BasePart?
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

local function flashlightOn(p: Player): boolean
	local c = p.Character
	local head = c and c:FindFirstChild("Head")
	local fl = head and head:FindFirstChild("Flashlight")
	return fl ~= nil and (fl :: SpotLight).Enabled
end

local function lineOfSight(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local origin = from
	local dir = to - from
	for _ = 1, 4 do
		local ok, hit = pcall(function()
			return workspace:Raycast(origin, dir, params)
		end)
		if not ok or not hit then
			return true
		end
		local inst = hit.Instance
		if inst.Transparency >= 0.4 or not inst.CanCollide then
			origin = hit.Position + dir.Unit * 0.5
			dir = to - origin
			if dir.Magnitude < 0.5 then
				return true
			end
		else
			return false
		end
	end
	return false
end

local function canSee(g: Guest, p: Player): (boolean, number)
	local hrp = playerRoot(p)
	if not hrp then
		return false, math.huge
	end
	local eye = g.rig.head.CFrame.Position
	local to = hrp.CFrame.Position
	local dist = (to - eye).Magnitude
	local maxDist = G.ViewDistance
	local zone = FacilityService.ZoneAt(to)
	if zone and not CreatureService._lightsOn(zone.id) then
		maxDist = G.ViewDistanceDark
	end
	if flashlightOn(p) then
		maxDist *= G.FlashlightNoticeMultiplier
	end
	if dist > maxDist then
		return false, dist
	end
	local look = g.rig.root.CFrame.LookVector
	local dir = (to - eye).Unit
	local ang = math.deg(math.acos(math.clamp(look:Dot(dir), -1, 1)))
	if ang > G.ViewAngle / 2 and dist > 8 then
		return false, dist
	end
	local ignore = { g.rig.model, p.Character }
	return lineOfSight(eye, to + Vector3.new(0, 1, 0), ignore), dist
end

CreatureService._lightsOn = function(_zoneId: string): boolean
	return true
end

function CreatureService.SetLightResolver(fn: (string) -> boolean)
	CreatureService._lightsOn = fn
end

-- ===== Movement ==========================================================

local function computePath(g: Guest, goal: Vector3): boolean
	local ok, result = pcall(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.6,
			AgentHeight = 11,
			AgentCanJump = false,
			WaypointSpacing = 6,
			Costs = { Door = 1, LockedDoor = math.huge, Snow = 1, Ice = 1.2 },
		})
		path:ComputeAsync(g.rig.root.CFrame.Position, goal)
		return path
	end)
	g.pathAt = os.clock()
	if not ok or result.Status ~= Enum.PathStatus.Success then
		g.pathFails += 1
		g.waypoints = {}
		g.wpIndex = 1
		return false
	end
	g.pathFails = 0
	g.waypoints = result:GetWaypoints()
	g.wpIndex = 2
	return true
end

local function openDoorsAhead(g: Guest)
	local pos = g.rig.root.CFrame.Position
	for _, d in FacilityService.DoorsNear(pos, 6) do
		if not d.open then
			if d.locked then
				continue
			end
			FacilityService.SetDoor(d, true, nil, "guest")
			CreatureService.Interacted:Fire("door", d.model)
		end
	end
end

local function moveTowards(g: Guest, goal: Vector3, speed: number)
	g.rig.humanoid.WalkSpeed = speed * g.speedMult
	local now = os.clock()
	if g.goal ~= goal or now - g.pathAt > (if g.state == "Chase" then G.RepathInterval else 2.5) then
		g.goal = goal
		computePath(g, goal)
	end
	local wp = g.waypoints[g.wpIndex]
	if wp then
		local target = wp.Position
		if (Vector3.new(target.X, 0, target.Z) - Vector3.new(g.rig.root.CFrame.Position.X, 0, g.rig.root.CFrame.Position.Z)).Magnitude < 3 then
			g.wpIndex += 1
			wp = g.waypoints[g.wpIndex]
		end
		if wp then
			g.rig.humanoid:MoveTo(wp.Position)
		end
	else
		-- No path (or exhausted): walk straight; fine outdoors on open snow.
		g.rig.humanoid:MoveTo(goal)
	end
	openDoorsAhead(g)
end

local function arrived(g: Guest, goal: Vector3, tol: number?): boolean
	local p = g.rig.root.CFrame.Position
	return (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude <= (tol or 4)
end

local function farthestNodeFromPlayers(nodes: { Vector3 }): Vector3?
	local best, bestD = nil, -1
	for _, n in nodes do
		local d = math.huge
		for _, p in Players:GetPlayers() do
			local hrp = playerRoot(p)
			if hrp then
				d = math.min(d, (hrp.CFrame.Position - n).Magnitude)
			end
		end
		if d > bestD then
			best, bestD = n, d
		end
	end
	return best
end

local function pickPatrolNode(g: Guest): Vector3?
	if not map then
		return nil
	end
	local pool = {}
	for _, n in map.patrolOutdoor do
		table.insert(pool, { pos = n, zone = "Outdoor" })
	end
	if g.allowIndoor then
		for _, n in map.patrolIndoor do
			local z = FacilityService.ZoneAt(n)
			table.insert(pool, { pos = n, zone = z and z.id or "Outdoor" })
		end
	end
	if #pool == 0 then
		return nil
	end
	-- Weighted by sector heat: the team's noisy habits shape the patrol.
	local hot, heat = NoiseDirector.HottestZone()
	local weights, total = {}, 0
	local here = g.rig.root.CFrame.Position
	for i, n in pool do
		local w = 1
		if hot and n.zone == hot then
			w += heat * 4
		end
		if (n.pos - here).Magnitude < 10 then
			w *= 0.1
		end
		weights[i] = w
		total += w
	end
	local r = rng:nextNumber() * total
	for i, n in pool do
		r -= weights[i]
		if r <= 0 then
			return n.pos
		end
	end
	return pool[#pool].pos
end

-- ===== State logic =======================================================

local function visibleTarget(g: Guest): (Player?, number)
	local best, bestD = nil, math.huge
	for _, p in Players:GetPlayers() do
		if not targetFilter(p) then
			continue
		end
		local seen, dist = canSee(g, p)
		if seen and dist < bestD then
			best, bestD = p, dist
		end
	end
	return best, bestD
end

local function playerLookingAt(p: Player, pos: Vector3): boolean
	local hrp = playerRoot(p)
	if not hrp then
		return false
	end
	local dir = (pos - hrp.CFrame.Position)
	if dir.Magnitude < 1 then
		return true
	end
	return hrp.CFrame.LookVector:Dot(dir.Unit) > 0.5
end

local function perceive(g: Guest)
	local now = os.clock()
	-- Hearing
	local hearMult = g.hearMult * (1 + g.alertness * 0.5)
	local ev, strength = NoiseDirector.Loudest(g.rig.head.CFrame.Position, hearMult, 0.08)
	if ev and g.state ~= "Chase" and g.state ~= "ScriptedStoryEvent" and now > g.calmUntil then
		local zone = FacilityService.ZoneAt(ev.pos)
		local indoor = zone ~= nil
		if (not indoor or g.allowIndoor) and strength > 0.3 then
			if g.state ~= "InvestigateNoise" or (g.goal and (g.goal - ev.pos).Magnitude > 8) then
				g.goal = ev.pos
				g.alertness = math.min(1, g.alertness + strength * 0.2)
				setState("InvestigateNoise")
			end
		elseif strength > 0.12 and (g.state == "Patrol" or g.state == "Idle") then
			g.idleUntil = now + 2.5
			g.rig.model:SetAttribute("Listening", true)
			g.listenAt = ev.pos
		end
	end
	-- Sight
	local target, dist = visibleTarget(g)
	if target then
		g.lastSeenPos = playerRoot(target).CFrame.Position
		g.lastSeenAt = now
		if g.state == "Chase" then
			g.target = target
		elseif g.state == "ScriptedStoryEvent" then
			-- scripted scenes ignore players unless they come very close
			if dist < 8 then
				g.scripted = nil
				g.target = target
				setState(if g.hunting then "Chase" else "Retreat")
			end
		elseif g.hunting and dist < 40 then
			g.target = target
			setState("Chase")
		elseif g.state == "Stalk" then
			g.target = target
			if dist <= G.StalkDistance and (g.alertness > 0.5 or g.hunting) then
				setState("Chase")
			elseif dist < 14 and playerLookingAt(target, g.rig.root.CFrame.Position) then
				-- Spotted up close by daylight rules: slip away around a corner.
				setState("Retreat")
			end
		elseif g.state ~= "Retreat" then
			g.target = target
			if dist > G.ObserveDistance[1] and now - g.stateAt > 1 and g.state ~= "Observe" and rng:nextNumber() < 0.5 then
				g.observeUntil = now + rng:nextInteger(G.ObserveSeconds[1], G.ObserveSeconds[2])
				setState("Observe")
			else
				setState("Stalk")
			end
		end
	elseif g.state == "Chase" and now - g.lastSeenAt > G.LoseTargetSeconds then
		setState("LostTarget")
	elseif g.state == "Stalk" and now - g.lastSeenAt > G.LoseTargetSeconds * 1.5 then
		setState("SearchArea")
	end
end

local function think(g: Guest, dt: number)
	local now = os.clock()
	local s = g.state
	-- Alertness decays slowly; calm windows (radio) suppress it faster.
	g.alertness = math.max(0, g.alertness - dt * (if now < g.calmUntil then 0.03 else 0.008))
	if s == "Idle" then
		if now >= g.idleUntil then
			g.rig.model:SetAttribute("Listening", false)
			setState("Patrol")
			g.goal = pickPatrolNode(g)
		end
	elseif s == "Patrol" then
		if now < g.idleUntil then
			return -- listening pause
		end
		g.rig.model:SetAttribute("Listening", false)
		if not g.goal then
			g.goal = pickPatrolNode(g)
		end
		if g.goal then
			if arrived(g, g.goal, 5) then
				g.goal = nil
				g.idleUntil = now + rng:nextNumber(G.PatrolIdleSeconds[1], G.PatrolIdleSeconds[2])
				setState("Idle")
			else
				moveTowards(g, g.goal, G.WalkSpeed)
			end
		end
	elseif s == "InvestigateNoise" then
		if g.goal then
			if arrived(g, g.goal, 5) then
				g.searchPoints = {}
				for _ = 1, 3 do
					table.insert(g.searchPoints, g.goal + Vector3.new(rng:nextNumber(-12, 12), 0, rng:nextNumber(-12, 12)))
				end
				setState("SearchArea")
			else
				moveTowards(g, g.goal, G.StalkSpeed)
			end
		else
			setState("ReturnToPatrol")
		end
	elseif s == "SearchArea" then
		if now - g.stateAt > G.SearchSeconds or #g.searchPoints == 0 and not g.goal then
			setState("ReturnToPatrol")
			return
		end
		if not g.goal or arrived(g, g.goal, 4) then
			g.goal = table.remove(g.searchPoints, 1)
			if not g.goal then
				setState("ReturnToPatrol")
				return
			end
		end
		moveTowards(g, g.goal, G.WalkSpeed)
	elseif s == "Observe" then
		-- Stand still, track the target with the head; leave when the window ends.
		g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
		if now >= g.observeUntil then
			setState(if g.alertness > 0.4 or g.hunting then "Stalk" else "ReturnToPatrol")
		end
	elseif s == "Stalk" then
		local t = g.target and playerRoot(g.target)
		if not t then
			setState("SearchArea")
			return
		end
		local tp = t.CFrame.Position
		local d = (tp - g.rig.root.CFrame.Position).Magnitude
		if d > G.StalkDistance + 4 then
			moveTowards(g, tp, G.StalkSpeed)
		else
			g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
		end
	elseif s == "Chase" then
		local t = g.target and playerRoot(g.target)
		if not t or not targetFilter(g.target) then
			setState("LostTarget")
			return
		end
		local tp = t.CFrame.Position
		local d = (tp - g.rig.root.CFrame.Position).Magnitude
		if d <= G.AttackRange then
			if now - g.lastAttack >= G.AttackCooldown then
				g.lastAttack = now
				g.rig.sounds.Attack:Play()
				g.rig.model:SetAttribute("Attacking", true)
				task.delay(0.5, function()
					if guest == g then
						g.rig.model:SetAttribute("Attacking", false)
					end
				end)
				CreatureService.PlayerHit:Fire(g.target, G.AttackDamage)
				-- A downed player is left alone; the Guest loses interest.
				if not targetFilter(g.target) then
					g.target = nil
					setState("LostTarget")
				end
			end
			g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
		else
			moveTowards(g, tp, G.ChaseSpeed)
		end
	elseif s == "LostTarget" then
		if g.lastSeenPos then
			g.goal = g.lastSeenPos
			g.searchPoints = {}
			for _ = 1, 3 do
				table.insert(g.searchPoints, g.lastSeenPos + Vector3.new(rng:nextNumber(-10, 10), 0, rng:nextNumber(-10, 10)))
			end
			setState("SearchArea")
		else
			setState("ReturnToPatrol")
		end
	elseif s == "ReturnToPatrol" then
		g.target = nil
		g.goal = pickPatrolNode(g)
		setState("Patrol")
	elseif s == "Retreat" then
		if not g.goal or arrived(g, g.goal, 6) then
			if not g.goal then
				g.goal = farthestNodeFromPlayers(map and map.patrolOutdoor or {})
			else
				g.goal = nil
				setState("ReturnToPatrol")
				return
			end
		end
		if g.goal then
			moveTowards(g, g.goal, G.StalkSpeed * 1.2)
		end
	elseif s == "ScriptedStoryEvent" then
		CreatureService._runScripted(g, now)
	end
end

-- Stuck recovery: repath, then choose another goal; as a last resort move to
-- the patrol node farthest from every player (never next to one).
local function checkStuck(g: Guest, dt: number)
	local pos = g.rig.root.CFrame.Position
	local moving = g.state == "Patrol" or g.state == "InvestigateNoise" or g.state == "SearchArea" or g.state == "Chase" or g.state == "Stalk" or g.state == "Retreat"
	if moving and g.goal and (pos - g.lastPos).Magnitude < 0.3 * dt * 10 then
		g.stuckSince = g.stuckSince or os.clock()
		local stuck = os.clock() - g.stuckSince
		if stuck > G.StuckSeconds and stuck < G.StuckSeconds + 0.5 then
			g.pathAt = 0
			g.rig.humanoid:MoveTo(pos + Vector3.new(rng:nextNumber(-4, 4), 0, rng:nextNumber(-4, 4)))
		elseif stuck > G.StuckSeconds * 2.5 then
			g.goal = nil
			g.stuckSince = nil
			if g.state ~= "Chase" then
				setState("ReturnToPatrol")
			end
		elseif stuck > 12 then
			local node = farthestNodeFromPlayers(map and map.patrolOutdoor or {})
			if node then
				local nearest = math.huge
				for _, p in Players:GetPlayers() do
					local hrp = playerRoot(p)
					if hrp then
						nearest = math.min(nearest, (hrp.CFrame.Position - node).Magnitude)
					end
				end
				if nearest >= G.SafeTeleportMinPlayerDistance then
					g.rig.model:PivotTo(CFrame.new(node + Vector3.new(0, 8, 0)))
				end
			end
			g.stuckSince = nil
		end
	else
		g.stuckSince = nil
	end
	g.lastPos = pos
end

local function animate(g: Guest, dt: number)
	local speed = g.rig.root.AssemblyLinearVelocity.Magnitude
	g.phase += dt * math.clamp(speed / 6, 0, 3) * 4.2
	local mode = g.state
	if g.state == "InvestigateNoise" or g.state == "SearchArea" or g.state == "Patrol" or g.state == "ReturnToPatrol" or g.state == "Retreat" then
		mode = if speed > 0.5 then "Walk" else "Idle"
	elseif g.state == "Idle" and g.rig.model:GetAttribute("Listening") then
		mode = "Listen"
	end
	if g.rig.model:GetAttribute("Attacking") then
		mode = "Attack"
	end
	local headYaw, headPitch = 0, 0
	local focus = nil
	if g.target and (g.state == "Observe" or g.state == "Stalk" or g.state == "Chase") then
		local hrp = playerRoot(g.target)
		focus = hrp and hrp.CFrame.Position
	elseif g.listenAt and mode == "Listen" then
		focus = g.listenAt
	end
	if focus then
		local rel = g.rig.torso.CFrame:PointToObjectSpace(focus)
		headYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.2, 1.2)
		headPitch = math.clamp(math.atan2(rel.Y - 2, (Vector3.new(rel.X, 0, rel.Z)).Magnitude), -0.5, 0.5)
	end
	GuestModel.pose(g.rig, g.phase, 1, mode, headYaw, headPitch)
	-- Footsteps from the gait phase.
	local stepPhase = math.floor(g.phase / math.pi)
	if stepPhase ~= g.lastStep and speed > 0.5 then
		g.lastStep = stepPhase
		local snd = if g.state == "Chase" then g.rig.sounds.StepChase else g.rig.sounds.Step
		snd.PlaybackSpeed = (snd == g.rig.sounds.Step and 0.5 or 0.65) + rng:nextNumber(-0.05, 0.05)
		snd:Play()
	end
	if rng:nextNumber() < dt * 0.05 and g.state ~= "Chase" then
		g.rig.sounds.Breath:Play()
	end
end

-- ===== Scripted story events =============================================

CreatureService._runScripted = function(g: Guest, now: number)
	local sc = g.scripted
	if not sc then
		setState("ReturnToPatrol")
		return
	end
	if sc.kind == "Knock" then
		-- Walk to a door, knock three times with pauses, leave.
		local door = sc.data.door
		local leafPos = door.Leaf.CFrame.Position + door.Leaf.CFrame.LookVector * (sc.data.outsideSign or 1) * 3
		if sc.step == 0 then
			if arrived(g, leafPos, 4) then
				sc.step = 1
				sc.at = now
			else
				moveTowards(g, leafPos, G.WalkSpeed)
			end
		elseif sc.step <= 3 then
			g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
			if now - sc.at > (if sc.step == 1 then 1.5 else 2.2 + rng:nextNumber() * 2) then
				g.rig.sounds.Touch:Play()
				CreatureService.Interacted:Fire("knock", door)
				sc.step += 1
				sc.at = now
			end
		else
			if now - sc.at > 6 then
				g.scripted = nil
				setState("Retreat")
			end
		end
	elseif sc.kind == "Window" then
		local pos = sc.data.pos
		if sc.step == 0 then
			if arrived(g, pos, 3) then
				sc.step = 1
				sc.at = now
			else
				moveTowards(g, pos, G.WalkSpeed)
			end
		else
			g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
			if now - sc.at > (sc.data.seconds or 10) then
				g.scripted = nil
				setState("Retreat")
			end
		end
	elseif sc.kind == "Sabotage" then
		local pos = sc.data.pos
		if sc.step == 0 then
			if arrived(g, pos, 5) then
				sc.step = 1
				sc.at = now
			else
				moveTowards(g, pos, G.StalkSpeed)
			end
		else
			g.rig.humanoid:MoveTo(g.rig.root.CFrame.Position)
			if now - sc.at > 4 then
				g.rig.sounds.Touch:Play()
				CreatureService.Interacted:Fire("sabotage", nil)
				g.scripted = nil
				setState("Retreat")
			end
		end
	else
		g.scripted = nil
		setState("ReturnToPatrol")
	end
end

function CreatureService.PlayScripted(kind: string, data: any): boolean
	if not guest or guest.state == "Chase" then
		return false
	end
	guest.scripted = { kind = kind, data = data, step = 0, at = os.clock() }
	guest.goal = nil
	setState("ScriptedStoryEvent")
	return true
end

-- ===== External influence ===============================================

function CreatureService.AddAlertness(amount: number)
	if guest then
		guest.alertness = math.clamp(guest.alertness + amount, 0, 1)
		broadcast()
	end
end

function CreatureService.Calm(seconds: number)
	if guest then
		guest.calmUntil = os.clock() + seconds
		guest.alertness = math.max(0, guest.alertness - 0.2)
	end
end

function CreatureService.SetHunting(on: boolean)
	if guest then
		guest.hunting = on
	end
end

function CreatureService.SetIndoorAllowed(on: boolean)
	if guest then
		guest.allowIndoor = on
	end
end

function CreatureService.OnViolation(player: Player)
	if not guest then
		return
	end
	local hrp = playerRoot(player)
	guest.alertness = math.min(1, guest.alertness + 0.4)
	guest.hunting = true
	if hrp and guest.state ~= "Chase" then
		guest.goal = hrp.CFrame.Position
		setState("InvestigateNoise")
	end
end

-- ===== Lifecycle =========================================================

function CreatureService.Spawn(position: Vector3, mapHandle: any, seed: number?): GuestModel.Rig
	CreatureService.Despawn()
	map = mapHandle
	rng = SeededRandom.new(seed or os.time())
	local parent = (mapHandle and mapHandle.root) or workspace
	local rig = GuestModel.build(parent, CFrame.new(position + Vector3.new(0, 8, 0)))
	guest = {
		rig = rig,
		state = "Idle",
		stateAt = os.clock(),
		target = nil,
		lastSeenPos = nil,
		lastSeenAt = 0,
		goal = nil,
		waypoints = {},
		wpIndex = 1,
		pathAt = 0,
		pathFails = 0,
		stuckSince = nil,
		lastPos = position,
		phase = 0,
		idleUntil = os.clock() + 2,
		alertness = 0.1,
		calmUntil = 0,
		searchPoints = {},
		observeUntil = 0,
		lastAttack = 0,
		scripted = nil,
		allowIndoor = false,
		hunting = false,
		lastStep = 0,
		speedMult = 1,
		hearMult = 1,
	}
	GuestModel.setEyes(rig, 0.2)
	lastBroadcast = ""
	broadcast()
	local g = guest
	task.spawn(function()
		local lastPerceive, lastThink = 0, os.clock()
		while guest == g and g.rig.model.Parent do
			local dt = task.wait(0.05)
			local now = os.clock()
			if now - lastPerceive >= G.PerceptionInterval then
				lastPerceive = now
				local ok, err = pcall(perceive, g)
				if not ok then
					warn("[Guest] perceive: " .. tostring(err))
				end
			end
			local ok, err = pcall(function()
				think(g, now - lastThink)
				checkStuck(g, now - lastThink)
				animate(g, dt)
			end)
			lastThink = now
			if not ok then
				warn("[Guest] think: " .. tostring(err))
			end
		end
	end)
	return rig
end

function CreatureService.Despawn()
	if guest then
		local g = guest
		guest = nil
		g.rig.model:Destroy()
		Net.event("CreatureState"):FireAllClients({ creature = "Guest", state = "None", alert = "low" })
		lastBroadcast = ""
	end
	map = nil
end

-- Exposed for tests: pure state helpers.
CreatureService._setStateForTest = function(s)
	setState(s)
end

function CreatureService.Init() end
function CreatureService.Start() end

return CreatureService
