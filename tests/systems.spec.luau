--!nocheck
-- Pure gameplay rules exercised headless: station clock, weather drift,
-- power grid (overload, trip, fault repair with inventory), temperature,
-- noise director memory, identity scanner rule, warehouse lockout, bunker
-- corner condition, radio quality.
local H = require("./harness")
local task = require("@lune/task")
local S = H.load()
local V3 = S.env.Vector3

local GameConfig = S.require(S.path("ReplicatedStorage.Shared.Config.GameConfig"))
local Station = S.require(S.path("ReplicatedStorage.Shared.Config.Station"))

print("ClockService")
local Clock = S.require(S.path("ServerScriptService.Vostok9.Services.ClockService"))
H.test("clock advances, warns, enters night and ends it", function()
	local warned, night, dawn = 0, 0, 0
	Clock.NightWarning:Connect(function()
		warned += 1
	end)
	Clock.NightStarted:Connect(function()
		night += 1
	end)
	Clock.NightEnded:Connect(function()
		dawn += 1
	end)
	Clock.StartShift()
	H.eq(Clock.Format(), "18:45")
	H.eq(Clock.IsNight(), false)
	-- 18:45 -> 22:00 is 195 game minutes = 11700 game seconds at DayScale 24 => 487.5 real s
	Clock.Advance(470)
	task.wait()
	assert(not Clock.IsNight(), "not night yet at " .. Clock.Format())
	H.eq(warned, 1, "night warning fired once")
	Clock.Advance(30)
	task.wait()
	assert(Clock.IsNight(), "night at " .. Clock.Format())
	H.eq(night, 1)
	-- 22:00 -> 06:00 = 8h = 28800 game s at NightScale 80 => 360 real s
	Clock.Advance(370)
	task.wait()
	assert(not Clock.IsNight(), "dawn at " .. Clock.Format())
	H.eq(dawn, 1)
	H.eq(Clock.Day(), 1)
	Clock.StopShift()
end)
H.test("MinutesUntil wraps past midnight", function()
	Clock.StartShift(23)
	local m = Clock.MinutesUntil(6)
	assert(m > 400 and m < 430, "minutes until dawn " .. m)
	Clock.StopShift()
end)

print("WeatherService")
local Weather = S.require(S.path("ServerScriptService.Vostok9.Services.WeatherService"))
local SeededRandom = S.require(S.path("ReplicatedStorage.Shared.Utilities.SeededRandom"))
H.test("weather drifts between known states only", function()
	local r = SeededRandom.new(5)
	local s = "Calm"
	for _ = 1, 200 do
		s = Weather.Pick(s, r)
		assert(GameConfig.Weather.States[s], "unknown state " .. tostring(s))
	end
end)

print("PowerGridService")
local Power = S.require(S.path("ServerScriptService.Vostok9.Services.PowerGridService"))
local inv = { Fuse = 1, SpareRelay = 1 }
local fakePlayer = { UserId = 7, DisplayName = "Tester", Name = "Tester" }
Power.Configure({
	has = function(_, item)
		return (inv[item] or 0) > 0
	end,
	consume = function(_, item)
		if (inv[item] or 0) > 0 then
			inv[item] -= 1
			return true
		end
		return false
	end,
})
H.test("default load fits capacity; lab pushes it over and the breaker trips", function()
	Power.StartShift(1)
	assert(Power.TotalLoad() <= GameConfig.Power.Capacity, "default load " .. Power.TotalLoad())
	assert(Power.IsPowered("Heating") and Power.IsPowered("LightsMain"), "default circuits powered")
	H.eq(Power.IsPowered("Lab"), false)
	Power.SetSwitch("Lab", true)
	assert(Power.TotalLoad() > GameConfig.Power.Capacity, "overloaded")
	-- Simulate the overload timer.
	Power.Generator().overloadSince = os.clock() - GameConfig.Power.OverloadTripSeconds - 1
	Power.Tick(1, 0.1)
	H.eq(Power.Generator().tripped, true)
	H.eq(Power.IsPowered("Heating"), false)
	-- Reset refuses only when the generator is down; with too much load it warns.
	local ok, msg = Power.ResetBreaker(nil)
	H.eq(ok, true)
	assert(msg ~= nil, "warning expected while overloaded")
	Power.SetSwitch("Lab", false)
	Power.SetSwitch("Floodlights", false)
	assert(Power.TotalLoad() <= GameConfig.Power.Capacity)
	H.eq(Power.IsPowered("Heating"), true)
end)
H.test("fault -> repair sequence is order-enforced and consumes the spare", function()
	Power.StartShift(2)
	Power.InjectFault("Relay")
	local g = Power.Generator()
	H.eq(g.fault, "Relay")
	H.eq(g.degraded, true)
	local ok = Power.Action(fakePlayer, "diagnose")
	H.eq(ok, false, "diagnose requires the panel open")
	ok = Power.Action(fakePlayer, "replace")
	H.eq(ok, false, "replace requires diagnosis")
	H.eq(Power.Action(fakePlayer, "openPanel"), true)
	H.eq(Power.Action(fakePlayer, "diagnose"), true)
	H.eq(Power.Generator().diagnosed, true)
	inv.SpareRelay = 0
	ok = Power.Action(fakePlayer, "replace")
	H.eq(ok, false, "no spare part")
	inv.SpareRelay = 1
	H.eq(Power.Action(fakePlayer, "replace"), true)
	H.eq(inv.SpareRelay, 0)
	H.eq(Power.Generator().fault, nil)
	Power.StopGenerator("fault")
	ok = Power.Action(fakePlayer, "start")
	H.eq(ok, false, "start requires the connection check")
	H.eq(Power.Action(fakePlayer, "check"), true)
	H.eq(Power.Action(fakePlayer, "start"), true)
	H.eq(Power.Generator().running, true)
	H.eq(Power.Generator().capacity, GameConfig.Power.Capacity)
	H.eq(Power.Action(fakePlayer, "closePanel"), true)
end)
H.test("fuel runs out and refuel needs a canister", function()
	Power.StartShift(3)
	Power.Tick(1, 1000)
	H.eq(Power.Generator().running, false)
	H.eq(Power.Generator().stopReason, "fuel")
	local ok = Power.Action(fakePlayer, "refuel")
	H.eq(ok, false)
	inv.FuelCanister = 1
	H.eq(Power.Action(fakePlayer, "refuel"), true)
	assert(Power.Generator().fuel > 0)
	H.eq(Power.Action(fakePlayer, "start"), true)
end)
H.test("blown fuse keeps a circuit dark until replaced; sabotage needs an open cover", function()
	Power.StartShift(4)
	Power.SetFuse("Floodlights", false)
	H.eq(Power.IsPowered("Floodlights"), false)
	Power.SetFuse("Floodlights", true)
	H.eq(Power.IsPowered("Floodlights"), true)
	H.eq(Power.Sabotage(), false)
	Power.SetCover(true)
	H.eq(Power.Sabotage(), true)
	assert(Power.Generator().fault ~= nil)
	Power.StopShift()
end)

print("TemperatureService")
local Temp = S.require(S.path("ServerScriptService.Vostok9.Services.TemperatureService"))
H.test("heat drains outdoors, recovers only with working heating, never below zero", function()
	local T = GameConfig.Temperature
	local h = Temp.Step(100, 10, { zoneKind = nil, cooling = 2, heatingOn = true, doorOpen = false, nearHeater = false })
	assert(h < 100 - 15, "outdoor loss " .. h)
	local h2 = Temp.Step(50, 10, { zoneKind = "heated", cooling = 1, heatingOn = true, doorOpen = false, nearHeater = false })
	assert(h2 > 70, "heated recovery " .. h2)
	local h3 = Temp.Step(50, 10, { zoneKind = "heated", cooling = 1, heatingOn = false, doorOpen = true, nearHeater = false })
	assert(h3 < 50, "unheated with open door cools " .. h3)
	local h4 = Temp.Step(50, 10, { zoneKind = "heated", cooling = 1, heatingOn = true, doorOpen = false, nearHeater = true })
	assert(h4 > h2, "heater warms faster")
	H.eq(Temp.Step(1, 100, { zoneKind = nil, cooling = 3, heatingOn = false, doorOpen = false, nearHeater = false }), 0)
	-- A full outdoor walk at Blizzard cooling should take minutes, not seconds, to reach collapse.
	local heat, seconds = T.Start, 0
	while heat > T.CollapseBelow do
		heat = Temp.Step(heat, 1, { zoneKind = nil, cooling = 2.0, heatingOn = false, doorOpen = false, nearHeater = false })
		seconds += 1
	end
	assert(seconds >= 35 and seconds <= 90, "collapse after " .. seconds .. " s in a blizzard")
end)

print("NoiseDirector")
local Noise = S.require(S.path("ServerScriptService.Vostok9.Services.NoiseDirector"))
H.test("events are remembered, decay and heat up sectors", function()
	Noise.Configure(function(pos)
		local z = Station.zoneAt(pos)
		return z and z.id or nil
	end, {})
	Noise.SetEnabled(true)
	local ev = Noise.Report(V3.new(0, 7, 0), "Sprint", nil)
	assert(ev and ev.zone == "Main", "zone resolved: " .. tostring(ev and ev.zone))
	local best, strength = Noise.Loudest(V3.new(10, 7, 0), 1)
	assert(best == ev and strength > 0.2, "audible nearby " .. tostring(strength))
	local far = Noise.Loudest(V3.new(200, 0, 0), 1)
	H.eq(far, nil, "inaudible far away")
	local hot, heat = Noise.HottestZone()
	H.eq(hot, "Main")
	assert(heat > 0)
	ev.at = os.clock() - GameConfig.Noise.MemorySeconds - 1
	Noise.Tick(1)
	local gone = Noise.Loudest(V3.new(10, 7, 0), 1)
	H.eq(gone, nil, "forgotten after memory window")
	Noise.SetEnabled(false)
	H.eq(Noise.Heat("Main"), 0)
end)

print("IdentityService")
local Identity = S.require(S.path("ServerScriptService.Vostok9.Services.IdentityService"))
H.test("two instances of one identity never pass the scanner together", function()
	Identity.Configure({
		scannerPowered = function()
			return true
		end,
		inShift = function()
			return true
		end,
	})
	local p = { UserId = 42, DisplayName = "Калинин", Name = "Kalinin", Character = nil, Parent = nil }
	Identity.BeginShift({ p }, nil, 1)
	local id = Identity.Identity(p)
	assert(id, "identity created")
	local dbl = { identity = id }
	-- Original outside: the double gets in.
	id.originalInside = false
	local ok = Identity.Scan(dbl)
	H.eq(ok, true)
	H.eq(id.doubleInside, true)
	-- Now the original is denied.
	local ok2, reason = Identity.Scan(p)
	H.eq(ok2, false)
	assert(string.find(reason, "УЖЕ ВНУТРИ"), reason)
	-- Double removed, original inside: a second double is denied.
	id.doubleInside = false
	id.originalInside = true
	local ok3 = Identity.Scan(dbl)
	H.eq(ok3, false)
	-- Without scanner power nothing is verified (fail-open).
	Identity.Configure({ scannerPowered = function()
		return false
	end })
	local ok4, r4 = Identity.Scan(dbl)
	H.eq(ok4, true)
	assert(string.find(r4, "НЕТ ПИТАНИЯ"))
	Identity.EndShift()
end)

print("WarehouseService")
local Warehouse = S.require(S.path("ServerScriptService.Vostok9.Services.WarehouseService"))
H.test("three wrong codes lock the keypad for a station day", function()
	local day = 0
	Warehouse.Configure({ inShift = function()
		return true
	end, stationDay = function()
		return day
	end })
	Warehouse.BeginShift(nil, 99)
	local code = Warehouse.Code()
	H.eq(#code, GameConfig.Warehouse.CodeLength)
	local wrong = if code == "0000" then "1111" else "0000"
	local ok, state = Warehouse.Submit(nil, wrong)
	H.eq(ok, false)
	H.eq(state, "wrong")
	Warehouse.Submit(nil, wrong)
	ok, state = Warehouse.Submit(nil, wrong)
	H.eq(state, "lockout")
	ok, state = Warehouse.Submit(nil, code)
	H.eq(ok, false, "correct code refused during lockout")
	H.eq(state, "lockout")
	day = 1
	ok, state = Warehouse.Submit(nil, code)
	H.eq(ok, true)
	H.eq(state, "accepted")
	H.eq(Warehouse.IsUnlocked(), true)
	Warehouse.EndShift()
end)

print("BunkerService")
local Bunker = S.require(S.path("ServerScriptService.Vostok9.Services.BunkerService"))
H.test("hatch needs both diagonal corners (one in a solo shift)", function()
	local a, b = V3.new(0, 6, 0), V3.new(40, 6, 24)
	local ok = Bunker.Condition({ V3.new(1, 6, 1) }, { a, b }, 2)
	H.eq(ok, false)
	ok = Bunker.Condition({ V3.new(1, 6, 1), V3.new(39, 6, 23) }, { a, b }, 2)
	H.eq(ok, true)
	ok = Bunker.Condition({ V3.new(1, 6, 1), V3.new(30, 6, 23) }, { a, b }, 2)
	H.eq(ok, false)
	ok = Bunker.Condition({ V3.new(39, 6, 23) }, { a, b }, 1)
	H.eq(ok, true)
	ok = Bunker.Condition({ V3.new(1, -10, 1), V3.new(39, 6, 23) }, { a, b }, 2)
	H.eq(ok, false, "wrong floor does not count")
end)

print("CommunicationService")
local Comm = S.require(S.path("ServerScriptService.Vostok9.Services.CommunicationService"))
H.test("radio quality needs tuning, antenna and weather", function()
	H.eq(Comm.Quality(4411, 4411, true, "Calm", false), 0)
	local tuned = Comm.Quality(4411, 4411, true, "Calm", true)
	assert(tuned > 0.85, "tuned " .. tuned)
	local off = Comm.Quality(4411 + 100, 4411, true, "Calm", true)
	H.eq(off, 0)
	local noAntenna = Comm.Quality(4411, 4411, false, "Calm", true)
	assert(noAntenna < tuned and noAntenna > 0.4)
	local storm = Comm.Quality(4411, 4411, true, "Blizzard", true)
	assert(storm < tuned and storm > 0.4, "storm " .. storm)
end)

H.finish()
