--!nonstrict
-- Station clock. Runs only during a shift; time advances faster at night so a
-- full evening + night fits a 12-15 minute session. Every gameplay rule that
-- mentions "22:00" reads this service, never a wall clock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)

local C = GameConfig.Clock

local ClockService = {}
ClockService.NightStarted = Signal.new()
ClockService.NightEnded = Signal.new()
ClockService.NightWarning = Signal.new()
ClockService.HourPassed = Signal.new() :: Signal.Signal<number>

local running = false
local hour = C.StartHour -- 0..24, wraps once past midnight (day index tracks wraps)
local day = 0
local isNight = false
local warned = false
local lastWholeHour = math.floor(C.StartHour)
local lastBroadcast = 0

function ClockService.Hour(): number
	return hour
end

function ClockService.Day(): number
	return day
end

function ClockService.IsNight(): boolean
	return isNight
end

function ClockService.IsRunning(): boolean
	return running
end

-- Station time as "HH:MM".
function ClockService.Format(h: number?): string
	local v = h or hour
	local hh = math.floor(v) % 24
	local mm = math.floor((v - math.floor(v)) * 60)
	return string.format("%02d:%02d", hh, mm)
end

-- Minutes of station time until `targetHour` (same day or next).
function ClockService.MinutesUntil(targetHour: number): number
	local diff = targetHour - hour
	if diff < 0 then
		diff += 24
	end
	return diff * 60
end

function ClockService.Snapshot()
	return { hour = hour, text = ClockService.Format(), night = isNight, day = day, scale = if isNight then C.NightScale else C.DayScale }
end

local function broadcast()
	Net.event("ClockState"):FireAllClients(ClockService.Snapshot())
end

local function computeNight(h: number): boolean
	-- Night spans midnight: [NightStart, 24) U [0, NightEnd)
	return h >= C.NightStart or h < C.NightEnd
end

-- Pure step used by the loop and by headless tests.
function ClockService.Advance(realSeconds: number)
	if not running then
		return
	end
	local scale = if isNight then C.NightScale else C.DayScale
	local prevHour = hour
	hour += realSeconds * scale / 3600
	if hour >= 24 then
		hour -= 24
		day += 1
		lastWholeHour = -1
	end
	local whole = math.floor(hour)
	if whole ~= lastWholeHour then
		lastWholeHour = whole
		ClockService.HourPassed:Fire(whole)
	end
	local nightNow = computeNight(hour)
	if nightNow ~= isNight then
		isNight = nightNow
		if isNight then
			ClockService.NightStarted:Fire()
		else
			ClockService.NightEnded:Fire()
		end
	end
	if not warned and not isNight and hour < C.NightStart and (C.NightStart - hour) * 60 <= C.NightWarningMinutes and prevHour <= hour then
		warned = true
		ClockService.NightWarning:Fire()
	end
end

function ClockService.StartShift(startHour: number?)
	hour = startHour or C.StartHour
	day = 0
	isNight = computeNight(hour)
	warned = false
	lastWholeHour = math.floor(hour)
	running = true
	broadcast()
end

function ClockService.StopShift()
	running = false
	hour = C.StartHour
	isNight = false
	broadcast()
end

function ClockService.Init() end

function ClockService.Start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = now - last
			last = now
			if running then
				ClockService.Advance(dt)
				if now - lastBroadcast >= 1 then
					lastBroadcast = now
					broadcast()
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(1, function()
			if p.Parent then
				Net.event("ClockState"):FireClient(p, ClockService.Snapshot())
			end
		end)
	end)
end

return ClockService
