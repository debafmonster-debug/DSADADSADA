--!nonstrict
-- Body heat per player: outdoors it drains with the weather, indoors it
-- recovers only where the heating circuit actually works. Thresholds drive
-- client effects (shiver, disorientation) and, at the bottom, a cold collapse
-- handled by RescueService. Never an instant death.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)

local T = GameConfig.Temperature

local TemperatureService = {}
TemperatureService.Collapsed = Signal.new() :: Signal.Signal<Player>
TemperatureService.StageChanged = Signal.new() :: Signal.Signal<Player, number>

local heat: { [Player]: number } = {}
local stage: { [Player]: number } = {}
local active: { [Player]: boolean } = {}
local deps = {
	zoneOf = function(_: Player)
		return nil
	end,
	weatherCooling = function()
		return 1
	end,
	heatingPowered = function()
		return true
	end,
	exteriorDoorOpen = function(_: string)
		return false
	end,
	heaters = function()
		return {}
	end,
	position = function(_: Player)
		return nil
	end,
	isDowned = function(_: Player)
		return false
	end,
}

function TemperatureService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function TemperatureService.Heat(player: Player): number
	return heat[player] or T.Max
end

function TemperatureService.Stage(player: Player): number
	return stage[player] or 0
end

-- Display helper: 36.6 °C at full heat down to ~31 at collapse.
function TemperatureService.BodyTemp(player: Player): number
	local h = TemperatureService.Heat(player)
	return 31 + (h / T.Max) * 5.6
end

function TemperatureService.Begin(players: { Player })
	table.clear(heat)
	table.clear(stage)
	table.clear(active)
	for _, p in players do
		heat[p] = T.Start
		stage[p] = 0
		active[p] = true
		TemperatureService.Push(p)
	end
end

function TemperatureService.End()
	for p in active do
		heat[p] = T.Max
		stage[p] = 0
		TemperatureService.Push(p)
	end
	table.clear(active)
end

function TemperatureService.Warm(player: Player, amount: number)
	if heat[player] then
		heat[player] = math.min(T.Max, heat[player] + amount)
		TemperatureService.Push(player)
	end
end

function TemperatureService.Push(player: Player)
	Net.event("PlayerFlags"):FireClient(player, { heat = heat[player] or T.Max, bodyTemp = TemperatureService.BodyTemp(player), coldStage = stage[player] or 0 })
end

local function stageFor(h: number): number
	if h < T.CollapseBelow then
		return 3
	elseif h < T.DisorientBelow then
		return 2
	elseif h < T.ShiverBelow then
		return 1
	end
	return 0
end

-- Pure heat step for one player given their environment. Returns new heat.
function TemperatureService.Step(current: number, dt: number, env: { zoneKind: string?, cooling: number, heatingOn: boolean, doorOpen: boolean, nearHeater: boolean }): number
	local delta
	if env.zoneKind == nil then
		delta = -T.OutdoorLossPerSecond * env.cooling
	elseif env.zoneKind == "heated" then
		if env.heatingOn then
			delta = if env.doorOpen then T.IndoorUnheatedGainPerSecond else T.IndoorHeatedGainPerSecond
		else
			delta = if env.doorOpen then -T.OutdoorLossPerSecond * 0.35 else T.IndoorUnheatedGainPerSecond
		end
	elseif env.zoneKind == "indoor" then
		delta = if env.heatingOn then T.IndoorUnheatedGainPerSecond * 2 else T.IndoorUnheatedGainPerSecond
	else -- shelter
		delta = T.ShelterGainPerSecond
	end
	if env.nearHeater and env.heatingOn then
		delta = math.max(delta, 0) + T.HeaterGainPerSecond
	end
	return math.clamp(current + delta * dt, 0, T.Max)
end

local function tick(dt: number)
	local heaters = deps.heaters()
	local heatingOn = deps.heatingPowered()
	local cooling = deps.weatherCooling()
	for p in active do
		if p.Parent ~= Players then
			active[p] = nil
			continue
		end
		local pos = deps.position(p)
		if not pos then
			continue
		end
		local zone = deps.zoneOf(p)
		local nearHeater = false
		if zone and heatingOn then
			for _, h in heaters do
				if (h.CFrame.Position - pos).Magnitude <= (h:GetAttribute("Range") or T.HeaterRange) then
					nearHeater = true
					break
				end
			end
		end
		local before = heat[p]
		local after = TemperatureService.Step(before, dt, {
			zoneKind = zone and zone.kind,
			cooling = cooling,
			heatingOn = heatingOn,
			doorOpen = zone ~= nil and deps.exteriorDoorOpen(zone.id),
			nearHeater = nearHeater,
		})
		heat[p] = after
		local s = stageFor(after)
		if deps.isDowned(p) and s < 3 then
			-- a downed player recovers only through rescue / warmth; keep stage 3 until warm enough
			if after < T.RecoverAbove then
				s = 3
			end
		end
		if s ~= stage[p] then
			local prev = stage[p]
			stage[p] = s
			TemperatureService.StageChanged:Fire(p, s)
			if s == 3 and prev ~= 3 then
				TemperatureService.Collapsed:Fire(p)
			end
		end
		if math.abs(after - before) > 0.4 or s ~= 0 then
			TemperatureService.Push(p)
		end
	end
end

function TemperatureService.Init() end

function TemperatureService.Start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(T.TickSeconds)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		heat[p] = nil
		stage[p] = nil
		active[p] = nil
	end)
end

return TemperatureService
