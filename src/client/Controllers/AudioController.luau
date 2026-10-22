--!nonstrict
-- Audio: sound groups, surface-aware footsteps, wind that follows weather
-- and shelter, creature-state music that stays sparse, and a dialogue group
-- for voice lines once they exist.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

local AudioController = {}
AudioController.Weather = { wind = 0.2, snow = 0.1, state = "Calm" }
AudioController.Indoors = false

local groups: { [string]: SoundGroup } = {}
local music: Sound? = nil
local musicKey: string? = nil
local stepT = 0
local windSound: Sound? = nil
local creatureState = "None"
local muffle = 0

local function group(name: string): SoundGroup
	local g = groups[name]
	if g then
		return g
	end
	g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	groups[name] = g
	return g
end

local function applyVolumes()
	local s = SettingsStore.Current
	group("Music").Volume = s.musicVolume
	group("SFX").Volume = s.sfxVolume
	group("Ambient").Volume = s.ambientVolume * (1 - muffle * 0.5)
	group("Voice").Volume = s.dialogueVolume
end

local function classify(sound: Sound)
	if sound:IsDescendantOf(SoundService) then
		return
	end
	local name = sound.Name
	if sound:GetAttribute("AutoPlay") or name == "Hum" or name == "Vent" or name == "Wind" or name == "GeneratorHum" or name == "ClockTick" then
		sound.SoundGroup = group("Ambient")
	elseif name:sub(1, 5) == "Voice" then
		sound.SoundGroup = group("Voice")
	else
		sound.SoundGroup = group("SFX")
	end
end

local function play(def, name: string?)
	if not def or not def.id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name or "Local"
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = def.pitch or 1
	s.SoundGroup = group(if def.category == "music" then "Music" elseif def.category == "ambient" then "Ambient" else "SFX")
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	return s
end
AudioController.Play = play

-- ===== Footsteps ===========================================================

local function floorKind(): string
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return "concrete"
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, workspace.CurrentCamera }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), params)
	if not hit then
		return "concrete"
	end
	local inst = hit.Instance
	local kind = inst:GetAttribute("Floor")
	if not kind and inst.Parent then
		kind = inst.Parent:GetAttribute("Floor")
	end
	if kind then
		return kind
	end
	local m = inst.Material
	if m == Enum.Material.Snow then
		return "snow"
	elseif m == Enum.Material.Ice or m == Enum.Material.Glass then
		return "ice"
	elseif m == Enum.Material.DiamondPlate then
		return "grate"
	elseif m == Enum.Material.Metal or m == Enum.Material.CorrodedMetal then
		return "metal"
	elseif m == Enum.Material.WoodPlanks or m == Enum.Material.Wood then
		return "wood"
	end
	return "concrete"
end

local footDefs = { metal = Sounds.FootMetal, concrete = Sounds.FootConcrete, grate = Sounds.FootGrate, snow = Sounds.FootSnow, ice = Sounds.FootSnow, wood = Sounds.FootWood }

local function footstep(speed: number)
	local kind = floorKind()
	local def = footDefs[kind] or Sounds.FootConcrete
	local s = play(def, "Foot")
	if s then
		local crouch = CameraController.Crouching
		s.Volume = def.volume * (if crouch then 0.4 else 1) * (if speed > 14 then 1.3 else 1)
		s.PlaybackSpeed = (def.pitch or 1) * (0.94 + math.random() * 0.12)
	end
end

-- ===== Wind & shelter =======================================================

local function updateWind(dt: number)
	if not windSound then
		windSound = Instance.new("Sound")
		windSound.Name = "LocalWind"
		windSound.SoundId = Sounds.Wind.id
		windSound.Looped = true
		windSound.PlaybackSpeed = Sounds.Wind.pitch or 1
		windSound.Volume = 0
		windSound.SoundGroup = group("Ambient")
		windSound.Parent = SoundService
		windSound:Play()
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local indoors = false
	if hrp then
		local lp = hrp.Position - GameConfig.World.StationOrigin
		indoors = Station.zoneAt(lp) ~= nil
		if not indoors then
			-- lobby interior check: close to lobby origin and inside the hull box
			local lo = hrp.Position - GameConfig.World.LobbyOrigin
			if math.abs(lo.X) < 63 and math.abs(lo.Z) < 44 and lo.Y < 14 and lo.Y > -2 then
				indoors = true
			end
		end
	end
	AudioController.Indoors = indoors
	local w = AudioController.Weather.wind
	local target = (0.15 + w * 0.6) * (if indoors then 0.25 else 1)
	windSound.Volume += (target - windSound.Volume) * math.clamp(dt * 1.5, 0, 1)
	windSound.PlaybackSpeed = (Sounds.Wind.pitch or 1) * (0.9 + w * 0.35)
end

-- ===== Music ===================================================================

local function setMusic(key: string?)
	if musicKey == key then
		return
	end
	musicKey = key
	local old = music
	if old then
		local tw = game:GetService("TweenService"):Create(old, TweenInfo.new(2.5), { Volume = 0 })
		tw:Play()
		tw.Completed:Once(function()
			old:Destroy()
		end)
		music = nil
	end
	local def = key and Sounds[key]
	if def and def.id then
		local s = Instance.new("Sound")
		s.Name = "Music"
		s.SoundId = def.id
		s.Looped = true
		s.PlaybackSpeed = def.pitch or 1
		s.Volume = 0
		s.SoundGroup = group("Music")
		s.Parent = SoundService
		s:Play()
		game:GetService("TweenService"):Create(s, TweenInfo.new(3), { Volume = def.volume }):Play()
		music = s
	end
end

local function chooseMusic(phase: string)
	if phase == "Idle" then
		setMusic("MusicLobby")
	elseif phase ~= "Results" and phase ~= "Boarding" and creatureState == "Chase" then
		setMusic("MusicChase")
	elseif phase ~= "Results" and phase ~= "Boarding" and (creatureState == "Stalk" or creatureState == "Observe") then
		setMusic("MusicStalk")
	else
		setMusic(nil) -- silence is the default inside the station
	end
end

function AudioController.SetMuffle(amount: number)
	muffle = math.clamp(amount, 0, 1)
	applyVolumes()
end

function AudioController.init()
	applyVolumes()
	SettingsStore.Changed:Connect(applyVolumes)
	for _, s in workspace:GetDescendants() do
		if s:IsA("Sound") then
			classify(s)
		end
	end
	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("Sound") then
			classify(inst)
		end
	end)
	local phase = "Idle"
	local HUDController = require(script.Parent.HUDController)
	HUDController.PhaseChanged:Connect(function(p)
		phase = p
		chooseMusic(phase)
		if p == "Results" then
			play(Sounds.MusicResult, "Stinger")
		end
	end)
	Net.event("CreatureState").OnClientEvent:Connect(function(c)
		creatureState = c.state or "None"
		chooseMusic(phase)
		if creatureState == "Chase" then
			play(Sounds.GuestNotice, "Notice")
		end
	end)
	Net.event("WeatherState").OnClientEvent:Connect(function(w)
		AudioController.Weather = { wind = w.wind or 0.2, snow = w.snow or 0.1, state = w.state }
	end)
	chooseMusic("Idle")
	RunService.Heartbeat:Connect(function(dt)
		updateWind(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or CameraController.CinematicActive then
			return
		end
		local speed = hum.MoveDirection.Magnitude * hum.WalkSpeed
		if speed > 0.5 and hum.FloorMaterial ~= Enum.Material.Air then
			stepT += dt * speed
			local stride = if CameraController.Crouching then 7 else 5.2
			if stepT >= stride then
				stepT = 0
				footstep(speed)
			end
		else
			stepT = math.min(stepT, 2)
		end
	end)
end

return AudioController
