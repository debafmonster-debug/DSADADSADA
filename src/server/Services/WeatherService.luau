--!nonstrict
-- Server-owned weather state. Chooses transitions on a timer, replicates the
-- target state and a transition time; clients tween fog/particles locally so
-- every player sees the same conditions without per-frame replication.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)

local W = GameConfig.Weather

local WeatherService = {}
WeatherService.Changed = Signal.new() :: Signal.Signal<string, string>

local state = W.StartState
local nextChangeAt = 0
local running = false
local rng = SeededRandom.new(os.time())
local forced: string? = nil

function WeatherService.Current(): string
	return state
end

function WeatherService.Def()
	return W.States[state]
end

function WeatherService.Snapshot()
	local d = W.States[state]
	return { state = state, visibility = d.visibility, wind = d.wind, snow = d.snow, label = d.label, transition = W.TransitionSeconds }
end

local function broadcast()
	Net.event("WeatherState"):FireAllClients(WeatherService.Snapshot())
end

-- Weather drifts one step along the severity order most of the time; jumps
-- straight to a storm are rare so players can read the sky.
function WeatherService.Pick(current: string, r: any): string
	local idx = table.find(W.Order, current) or 1
	local roll = r:nextNumber()
	local delta
	if roll < 0.45 then
		delta = 1
	elseif roll < 0.8 then
		delta = -1
	elseif roll < 0.92 then
		delta = 0
	else
		delta = 2
	end
	local n = math.clamp(idx + delta, 1, #W.Order)
	-- Whiteout is reserved for night; cap at Blizzard by day.
	return W.Order[n]
end

function WeatherService.Set(newState: string, silent: boolean?)
	if not W.States[newState] or newState == state then
		return
	end
	local prev = state
	state = newState
	WeatherService.Changed:Fire(state, prev)
	if not silent then
		broadcast()
	end
end

function WeatherService.Force(newState: string?)
	forced = newState
	if newState then
		WeatherService.Set(newState)
	end
end

function WeatherService.StartShift(seed: number, isNightFn: (() -> boolean)?)
	rng = SeededRandom.new(seed)
	forced = nil
	running = true
	state = W.StartState
	nextChangeAt = os.clock() + rng:nextInteger(W.ChangeIntervalSeconds[1], W.ChangeIntervalSeconds[2])
	WeatherService._isNight = isNightFn
	broadcast()
end

function WeatherService.StopShift()
	running = false
	state = W.StartState
	broadcast()
end

function WeatherService.Init() end

function WeatherService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			if not running or forced then
				continue
			end
			if os.clock() >= nextChangeAt then
				nextChangeAt = os.clock() + rng:nextInteger(W.ChangeIntervalSeconds[1], W.ChangeIntervalSeconds[2])
				local candidate = WeatherService.Pick(state, rng)
				local night = WeatherService._isNight and WeatherService._isNight()
				if candidate == "Whiteout" and not night then
					candidate = "Blizzard"
				end
				WeatherService.Set(candidate)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(1, function()
			if p.Parent then
				Net.event("WeatherState"):FireClient(p, WeatherService.Snapshot())
			end
		end)
	end)
end

return WeatherService
