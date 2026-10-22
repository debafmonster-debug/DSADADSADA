--!nonstrict
-- Adaptive music states, sound groups for volume settings, local footsteps.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SettingsStore = require(script.Parent.SettingsStore)
local HUDController = require(script.Parent.HUDController)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local music: { [string]: Sound } = {}
local currentTrack: string? = nil
local creatureState = "Idle"
local phase = "Idle"

local function group(name: string): SoundGroup
	if groups[name] then
		return groups[name]
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	groups[name] = g
	return g
end

local function makeMusic(name: string): Sound
	local def = Sounds[name]
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.id
	s.Volume = 0
	s.Looped = def.looped == true
	s.PlaybackSpeed = def.pitch or 1
	s.SoundGroup = group("Music")
	s.Parent = SoundService
	s:SetAttribute("TargetVolume", def.volume)
	return s
end

local function setTrack(name: string?)
	if currentTrack == name then
		return
	end
	if currentTrack and music[currentTrack] then
		local old = music[currentTrack]
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			if currentTrack ~= old.Name then
				old:Stop()
			end
		end)
	end
	currentTrack = name
	if name then
		local s = music[name] or makeMusic(name)
		music[name] = s
		if not s.IsPlaying then
			s:Play()
		end
		TweenService:Create(s, TweenInfo.new(2), { Volume = s:GetAttribute("TargetVolume") }):Play()
	end
end

local function chooseTrack()
	if phase == "Idle" then
		setTrack("MusicLobby")
	elseif phase == "Results" then
		setTrack(nil)
	elseif phase == "Evacuation" and creatureState ~= "Chase" and creatureState ~= "Attack" then
		setTrack("MusicEvac")
	elseif creatureState == "Chase" or creatureState == "Attack" then
		setTrack("MusicChase")
	elseif creatureState == "Suspicious" or creatureState == "Investigate" or creatureState == "Search" then
		setTrack("MusicSuspicion")
	else
		setTrack("MusicExplore")
	end
end

local function applyVolumes()
	group("Music").Volume = SettingsStore.Current.musicVolume
	group("SFX").Volume = SettingsStore.Current.sfxVolume
	group("Ambient").Volume = SettingsStore.Current.ambientVolume
end

local function classify(sound: Sound)
	if sound.SoundGroup then
		return
	end
	if sound:GetAttribute("AutoPlay") or sound.Name == "Hum" or sound.Name == "Vent" or sound.Name == "AlarmSound" then
		sound.SoundGroup = group("Ambient")
	else
		sound.SoundGroup = group("SFX")
	end
end

local stepT = 0
local function footsteps(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return
	end
	local speed = hum.MoveDirection.Magnitude * hum.WalkSpeed
	if speed < 1 or hum.FloorMaterial == Enum.Material.Air then
		return
	end
	stepT += dt * speed
	local interval = if CameraController.Crouching then 7 else 5.2
	if stepT >= interval then
		stepT = 0
		local metal = hum.FloorMaterial == Enum.Material.Metal or hum.FloorMaterial == Enum.Material.DiamondPlate
		local def = if metal then Sounds.FootMetal else Sounds.FootConcrete
		local s = Instance.new("Sound")
		s.SoundId = def.id
		s.Volume = def.volume * (if CameraController.Crouching then 0.4 elseif CameraController.Sprinting then 1.3 else 1)
		s.PlaybackSpeed = (def.pitch or 1) * (0.95 + math.random() * 0.1)
		s.SoundGroup = group("SFX")
		s.Parent = hrp
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end

function AudioController.init()
	group("Music")
	group("SFX")
	group("Ambient")
	applyVolumes()
	SettingsStore.Changed:Connect(applyVolumes)
	for _, d in workspace:GetDescendants() do
		if d:IsA("Sound") then
			classify(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			classify(d)
		end
	end)
	Net.event("CreatureState").OnClientEvent:Connect(function(s)
		creatureState = s.state
		chooseTrack()
	end)
	HUDController.PhaseChanged:Connect(function(p)
		phase = p
		if p == "Idle" or p == "Prep" then
			creatureState = "Idle"
		end
		if p == "Results" then
			local s = Instance.new("Sound")
			s.SoundId = Sounds.MusicResult.id
			s.Volume = Sounds.MusicResult.volume
			s.SoundGroup = group("Music")
			s.Parent = SoundService
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
		chooseTrack()
	end)
	chooseTrack()
	game:GetService("RunService").Heartbeat:Connect(footsteps)
end

return AudioController
