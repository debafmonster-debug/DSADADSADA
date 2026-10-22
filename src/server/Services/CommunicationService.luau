--!nonstrict
-- Radio + team quick-signals. The radio is a real device: it needs its
-- circuit, a tuned frequency, an aligned antenna and tolerable weather.
-- Players only choose preset phrases; the dispatcher and the creature react
-- to phrase ids, never to free text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signals = require(ReplicatedStorage.Shared.Config.Signals)
local RadioPhrases = require(ReplicatedStorage.Shared.Config.RadioPhrases)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)

local C = GameConfig.Communication

local CommunicationService = {}
CommunicationService.Contacted = Signal.new() :: Signal.Signal<Player, string>
CommunicationService.Reaction = Signal.new() :: Signal.Signal<string, string, Player>
CommunicationService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local limiter = RateLimiter.new(4, 1)
local recipients: (Player) -> { Player } = function(_)
	return Players:GetPlayers()
end
local map = nil
local radio = { freq = 4000, dispatcherFreq = 4411, antennaAligned = false, lastSend = 0, log = {}, echoUsed = false }
local rng = SeededRandom.new(5)
local deps = {
	inShift = function(_: Player)
		return false
	end,
	radioPowered = function()
		return true
	end,
	isNight = function()
		return false
	end,
	weatherState = function()
		return "Calm"
	end,
	creatureAlert = function(_amount: number) end,
	creatureCalm = function(_seconds: number) end,
	playerNear = function(_p: Player, _pos: Vector3, _r: number)
		return true
	end,
}

function CommunicationService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function CommunicationService.SetRecipientResolver(fn: ((Player) -> { Player })?)
	recipients = fn or function(_)
		return Players:GetPlayers()
	end
end

function CommunicationService.DispatcherFrequency(): number
	return radio.dispatcherFreq
end

function CommunicationService.SetAntennaAligned(on: boolean)
	radio.antennaAligned = on
	CommunicationService.Broadcast()
end

-- Signal quality 0..1 from tuning error, antenna state and weather. Pure.
function CommunicationService.Quality(freq: number, dispatcherFreq: number, antenna: boolean, weather: string, powered: boolean): number
	if not powered then
		return 0
	end
	local err = math.abs(freq - dispatcherFreq)
	local tune = math.clamp(1 - err / C.RadioFreqTolerance, 0, 1)
	local q = tune * (if antenna then 1 else 0.55)
	local w = GameConfig.Weather.States[weather]
	if w then
		q *= 1 - w.wind * 0.45
	end
	return math.clamp(q, 0, 1)
end

function CommunicationService.Snapshot()
	local q = CommunicationService.Quality(radio.freq, radio.dispatcherFreq, radio.antennaAligned, deps.weatherState(), deps.radioPowered())
	local phrases = {}
	for _, p in RadioPhrases.List do
		table.insert(phrases, { id = p.id, text = p.text })
	end
	return { freq = radio.freq, quality = q, powered = deps.radioPowered(), antenna = radio.antennaAligned, log = radio.log, phrases = phrases, min = C.RadioMinFreq, max = C.RadioMaxFreq }
end

function CommunicationService.Broadcast()
	Net.event("RadioState"):FireAllClients(CommunicationService.Snapshot())
end

local function radioSound(key: string, pitch: number?)
	if not map or not map.radio then
		return
	end
	local def = Sounds[key]
	if not def or not def.id then
		return
	end
	local s = Builder.sound(map.radio.PrimaryPart, def, key)
	if pitch then
		s.PlaybackSpeed = pitch
	end
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local function appendLog(who: string, text: string, kind: string)
	table.insert(radio.log, { who = who, text = text, kind = kind, t = os.time() })
	while #radio.log > 14 do
		table.remove(radio.log, 1)
	end
	CommunicationService.Broadcast()
end

-- Dispatcher / "something else" answers a phrase after relay click + static.
local function respond(player: Player, phrase, quality: number)
	task.delay(1.2 + rng:nextNumber() * 1.5, function()
		radioSound("RadioClick")
		radioSound("RadioStatic", 1.4)
		task.wait(0.8)
		local text
		local night = deps.isNight()
		if quality < 0.5 then
			text = "…шум… повторите… «Восток»… …"
			appendLog("Эфир", text, "static")
			return
		end
		local reaction = phrase.reaction and RadioPhrases.Reactions[phrase.reaction]
		if night and phrase.nightReply then
			if reaction and reaction.echoCallsign then
				if not radio.echoUsed then
					radio.echoUsed = true
					text = string.format(phrase.nightReply, player.DisplayName)
					appendLog("Эфир", text, "echo")
					deps.creatureAlert(reaction.alertness)
					CommunicationService.Reaction:Fire(phrase.id, "echo", player)
					return
				end
				text = phrase.reply
			else
				text = phrase.nightReply
			end
		else
			text = phrase.reply or "Принято."
		end
		appendLog("Мирный-база", text, "dispatcher")
		if phrase.id == "hail" or phrase.id == "status_ok" then
			CommunicationService.Contacted:Fire(player, phrase.id)
		end
	end)
	local reaction = phrase.reaction and RadioPhrases.Reactions[phrase.reaction]
	if reaction then
		if reaction.calmChance and rng:nextNumber() < reaction.calmChance then
			deps.creatureCalm(reaction.seconds)
			CommunicationService.Reaction:Fire(phrase.id, "calm", player)
		elseif reaction.alertness and not reaction.echoCallsign then
			deps.creatureAlert(reaction.alertness)
			CommunicationService.Reaction:Fire(phrase.id, "alert", player)
		end
	end
end

-- Scripted inbound transmission (events, final scene).
function CommunicationService.Incoming(who: string, text: string, kind: string?)
	radioSound("RadioClick")
	radioSound("RadioStatic", 1.2)
	task.delay(0.9, function()
		appendLog(who, text, kind or "incoming")
	end)
end

function CommunicationService.BeginShift(mapHandle, seed: number)
	map = mapHandle
	rng = SeededRandom.new(seed + 23)
	radio.freq = 2000 + rng:nextInteger(0, 70) * 100
	radio.dispatcherFreq = 2500 + rng:nextInteger(0, 60) * 100 + rng:nextInteger(0, 9) * 10
	radio.antennaAligned = false
	radio.lastSend = 0
	radio.log = {}
	radio.echoUsed = false
	if map and map.radio then
		local prompt = Builder.prompt(map.radio.PrimaryPart, "Сесть за радиостанцию", "Радиостанция Р-140", 0, Enum.KeyCode.E, 8)
		prompt:SetAttribute("UI", "Radio")
		local dial = map.radio:FindFirstChild("Dial")
		if dial then
			dial:SetAttribute("Frequency", radio.freq)
		end
	end
	CommunicationService.Broadcast()
end

function CommunicationService.EndShift()
	map = nil
	radio.log = {}
	CommunicationService.Broadcast()
end

local function nearRadio(player: Player): boolean
	if not map or not map.radio then
		return false
	end
	return Net.near(player, map.radio.PrimaryPart.CFrame.Position, 10)
end

function CommunicationService.Init()
	-- Team quick signals (whitelisted ids, rate-limited).
	Net.event("SignalSend").OnServerEvent:Connect(function(player, id)
		if not Net.isString(id, 24) or not Signals.ById[id] or not limiter:allow(player) then
			return
		end
		local def = Signals.ById[id]
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local payload = { id = id, text = def.text, sender = player.DisplayName, senderId = player.UserId, position = hrp and hrp.CFrame.Position or nil, lifetime = C.SignalLifetime }
		for _, p in recipients(player) do
			Net.event("SignalBroadcast"):FireClient(p, payload)
		end
	end)
	Net.func("RadioQuery").OnServerInvoke = function(player)
		if not limiter:allow(player) then
			return Net.fail("rate")
		end
		return Net.ok(CommunicationService.Snapshot())
	end
	Net.func("RadioTune").OnServerInvoke = function(player, freq)
		if not limiter:allow(player) or not Net.isInt(freq, C.RadioMinFreq, C.RadioMaxFreq) then
			return Net.fail("bad freq")
		end
		if not deps.inShift(player) or not nearRadio(player) then
			return Net.fail("Подойдите к радиостанции")
		end
		if not deps.radioPowered() then
			return Net.fail("Нет питания: линия «РАДИОСВЯЗЬ»")
		end
		radio.freq = freq
		local dial = map.radio:FindFirstChild("Dial")
		if dial then
			dial:SetAttribute("Frequency", freq)
		end
		radioSound("RadioTune", 0.8 + (freq - C.RadioMinFreq) / (C.RadioMaxFreq - C.RadioMinFreq) * 0.6)
		CommunicationService.Broadcast()
		return Net.ok(CommunicationService.Snapshot())
	end
	Net.func("RadioSend").OnServerInvoke = function(player, phraseId)
		if not limiter:allow(player) or not Net.isString(phraseId, 24) then
			return Net.fail("bad args")
		end
		local phrase = RadioPhrases.ById[phraseId]
		if not phrase then
			return Net.fail("Неизвестная реплика")
		end
		if not deps.inShift(player) or not nearRadio(player) then
			return Net.fail("Подойдите к радиостанции")
		end
		if not deps.radioPowered() then
			return Net.fail("Нет питания")
		end
		if os.clock() - radio.lastSend < C.RadioSendCooldown then
			return Net.fail("Передатчик остывает")
		end
		radio.lastSend = os.clock()
		local quality = CommunicationService.Quality(radio.freq, radio.dispatcherFreq, radio.antennaAligned, deps.weatherState(), true)
		radioSound("RadioClick")
		CommunicationService.Noise:Fire(map.radio.PrimaryPart.CFrame.Position, "Radio", player)
		appendLog(player.DisplayName, phrase.text, "player")
		respond(player, phrase, quality)
		return Net.ok({ quality = quality })
	end
end

function CommunicationService.Start() end

return CommunicationService
