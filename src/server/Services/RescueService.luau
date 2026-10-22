--!nonstrict
-- Downed / revive / self-rescue / spectator flow. A heavy hit downs a player
-- instead of killing them; allies (or a limited self-rescue) can bring them
-- back inside a window, otherwise they spectate a living teammate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local CreatureService = require(script.Parent.CreatureService)

local R = GameConfig.Rescue

type Downed = { since: number, deadline: number, prompt: ProximityPrompt?, selfRescueAt: number?, holdBegan: { [Player]: number }, reason: string }

local RescueService = {}
RescueService.PlayerDowned = Signal.new() :: Signal.Signal<Player>
RescueService.PlayerRevived = Signal.new() :: Signal.Signal<Player, Player?>
RescueService.PlayerEliminated = Signal.new() :: Signal.Signal<Player>

local downed: { [Player]: Downed } = {}
local eliminated: { [Player]: boolean } = {}
local selfCharges: { [Player]: number } = {}
local inShift: (Player) -> boolean = function(_: Player)
	return false
end
local toolOf: (Player) -> string? = function(_: Player)
	return nil
end
local limiter = RateLimiter.new(4, 1)

function RescueService.Configure(isInShift: (Player) -> boolean, toolResolver: (Player) -> string?)
	inShift = isInShift
	toolOf = toolResolver
end

local function flags(player: Player)
	local d = downed[player]
	Net.event("PlayerFlags"):FireClient(player, {
		downed = d ~= nil,
		downedSeconds = if d then math.max(0, d.deadline - os.clock()) else nil,
		downedReason = if d then d.reason else nil,
		selfRescueCharges = selfCharges[player] or 0,
		eliminated = eliminated[player] == true,
		selfRescuing = d ~= nil and d.selfRescueAt ~= nil,
	})
end

function RescueService.IsDowned(player: Player): boolean
	return downed[player] ~= nil
end

function RescueService.IsEliminated(player: Player): boolean
	return eliminated[player] == true
end

function RescueService.IsActive(player: Player): boolean
	return inShift(player) and not downed[player] and not eliminated[player]
end

local function pickSpectateTarget(forPlayer: Player): Player?
	for _, p in Players:GetPlayers() do
		if p ~= forPlayer and inShift(p) and not eliminated[p] and p.Character then
			return p
		end
	end
	return nil
end

local function eliminate(player: Player)
	local d = downed[player]
	if d and d.prompt then
		d.prompt:Destroy()
	end
	downed[player] = nil
	eliminated[player] = true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	flags(player)
	local target = pickSpectateTarget(player)
	Net.event("SpectateTarget"):FireClient(player, target)
	Net.event("Notification"):FireClient(player, { title = "Сотрудник потерян", text = "Вы наблюдаете за командой до конца смены.", kind = "danger" })
	RescueService.PlayerEliminated:Fire(player)
end

local function revive(player: Player, by: Player?)
	local d = downed[player]
	if not d then
		return
	end
	if d.prompt then
		d.prompt:Destroy()
	end
	downed[player] = nil
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = R.ReviveHealth
		hum.WalkSpeed = GameConfig.Character.WalkSpeed
	end
	if char then
		char:SetAttribute("Downed", false)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local s = Builder.sound(hrp, Sounds.Revive, "ReviveSfx")
			s:Play()
			task.delay(3, function()
				s:Destroy()
			end)
		end
	end
	flags(player)
	Net.event("Notification"):FireClient(player, { title = "Вы снова на ногах", text = if by then "Вас поднял " .. by.DisplayName else "Инъекция подействовала.", kind = "good" })
	RescueService.PlayerRevived:Fire(player, by)
end

function RescueService.Down(player: Player, reason: string?)
	if downed[player] or eliminated[player] or not inShift(player) then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hum or not hrp then
		return
	end
	hum.Health = 1
	hum.WalkSpeed = R.CrawlSpeed
	hum.JumpPower = 0
	char:SetAttribute("Downed", true)
	local now = os.clock()
	local d: Downed = { since = now, deadline = now + R.DownedSeconds, prompt = nil, selfRescueAt = nil, holdBegan = {}, reason = reason or "creature" }
	downed[player] = d
	local s = Builder.sound(hrp, Sounds.Downed, "DownedSfx")
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
	-- Ally revive prompt on the downed character.
	local prompt = Builder.prompt(hrp, "Помочь", player.DisplayName, R.ReviveHoldSeconds, Enum.KeyCode.E, 7)
	prompt:SetAttribute("UI", "Revive")
	prompt:SetAttribute("HoldBase", R.ReviveHoldSeconds)
	prompt:SetAttribute("ToolCap", "revive_fast")
	prompt:SetAttribute("HoldTool", R.ReviveHoldSecondsMedkit)
	d.prompt = prompt
	prompt.PromptButtonHoldBegan:Connect(function(helper)
		d.holdBegan[helper] = os.clock()
	end)
	prompt.Triggered:Connect(function(helper)
		if helper == player or not RescueService.IsActive(helper) then
			return
		end
		local hasMed = (function()
			local id = toolOf(helper)
			local def = id and Tools.Defs[id]
			return def ~= nil and (def.capabilities.revive_fast or 0) > 0
		end)()
		local required = if hasMed then R.ReviveHoldSecondsMedkit else R.ReviveHoldSeconds
		local began = d.holdBegan[helper]
		if not began or os.clock() - began < required - 0.2 then
			return
		end
		local hhrp = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hhrp or (hhrp.Position - hrp.Position).Magnitude > 10 then
			return
		end
		revive(player, helper)
	end)
	flags(player)
	Net.event("DownedState"):FireAllClients({ player = player, downed = true })
	Net.event("Notification"):FireClient(player, { title = if reason == "cold" then "Вы теряете сознание от холода" else "Вы выведены из строя", text = string.format("Дождитесь помощи (%d с). Товарищ с аптечкой поднимет быстрее.", R.DownedSeconds), kind = "danger" })
	RescueService.PlayerDowned:Fire(player)
end

function RescueService.GrantSelfCharge(player: Player)
	selfCharges[player] = (selfCharges[player] or 0) + 1
	flags(player)
end

function RescueService.Revive(player: Player, by: Player?)
	revive(player, by)
end

function RescueService.ApplyHit(player: Player, damage: number)
	if not inShift(player) or eliminated[player] then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if downed[player] then
		-- Hits while downed shorten the window instead of killing outright.
		local d = downed[player]
		d.deadline -= 15
		d.selfRescueAt = nil
		flags(player)
		return
	end
	if hum.Health - damage <= 1 then
		RescueService.Down(player)
	else
		hum:TakeDamage(damage)
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local s = Builder.sound(hrp, Sounds.Hurt, "HurtSfx")
			s:Play()
			task.delay(2, function()
				s:Destroy()
			end)
		end
	end
end

function RescueService.BeginShift(players: { Player })
	table.clear(downed)
	table.clear(eliminated)
	table.clear(selfCharges)
	for _, p in players do
		selfCharges[p] = 0
		flags(p)
	end
end

function RescueService.EndShift()
	for p, d in downed do
		if d.prompt then
			d.prompt:Destroy()
		end
		local char = p.Character
		if char then
			char:SetAttribute("Downed", false)
		end
	end
	table.clear(downed)
	table.clear(eliminated)
	table.clear(selfCharges)
end

function RescueService.AllOut(players: { Player }): boolean
	for _, p in players do
		if p.Parent and not eliminated[p] and not downed[p] then
			return false
		end
	end
	return true
end

function RescueService.Init()
	CreatureService.PlayerHit:Connect(function(player, dmg)
		RescueService.ApplyHit(player, dmg)
	end)
	CreatureService.SetTargetFilter(function(p)
		return RescueService.IsActive(p)
	end)
	-- Cold collapse: downed with a "cold" reason; warmth (medkit / heater) restores.
	local TemperatureService = require(script.Parent.TemperatureService)
	TemperatureService.Collapsed:Connect(function(player)
		RescueService.Down(player, "cold")
	end)
	TemperatureService.StageChanged:Connect(function(player, stage)
		local d = downed[player]
		if d and d.reason == "cold" and stage < 3 then
			revive(player, nil)
		end
	end)
	Net.func("RescueAction").OnServerInvoke = function(player, action)
		if not limiter:allow(player) then
			return Net.fail("rate")
		end
		if action ~= "self" then
			return Net.fail("bad action")
		end
		local d = downed[player]
		if not d then
			return Net.fail("not downed")
		end
		if (selfCharges[player] or 0) <= 0 then
			return Net.fail("Инъекций не осталось")
		end
		if d.selfRescueAt then
			return Net.fail("already")
		end
		selfCharges[player] -= 1
		d.selfRescueAt = os.clock() + R.SelfRescueHoldSeconds
		flags(player)
		return Net.ok({ seconds = R.SelfRescueHoldSeconds })
	end
	Players.PlayerRemoving:Connect(function(p)
		downed[p] = nil
		eliminated[p] = nil
		selfCharges[p] = nil
	end)
end

function RescueService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for p, d in downed do
				if not p.Parent then
					downed[p] = nil
					continue
				end
				if d.selfRescueAt and now >= d.selfRescueAt then
					revive(p, nil)
				elseif now >= d.deadline then
					eliminate(p)
				end
			end
		end
	end)
end

return RescueService
