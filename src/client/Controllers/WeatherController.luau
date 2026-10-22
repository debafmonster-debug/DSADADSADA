--!nonstrict
-- Weather presentation: fog/atmosphere tweened to the server state, a snow
-- volume that rides with the camera and leans into the wind, frost on window
-- glass, and dimmer post-processing indoors. The server decides the weather;
-- this only draws it, and never below the visibility the server set.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local SettingsStore = require(script.Parent.SettingsStore)
local WorldFXController = require(script.Parent.WorldFXController)
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WeatherController = {}
WeatherController.State = GameConfig.Weather.StartState
WeatherController.Visibility = 120

local snowPart: Part? = nil
local snowEmitter: ParticleEmitter? = nil
local frostParts: { BasePart } = {}
local windDir = Vector3.new(1, 0, 0.3)
local windAngleT = 0
local atmosphere: Atmosphere? = nil
local extraFog = 0 -- hallucination / cold add-on, 0..1

local function ensureSnow()
	if snowPart and snowPart.Parent then
		return
	end
	snowPart = Instance.new("Part")
	snowPart.Name = "SnowVolume"
	snowPart.Size = Vector3.new(70, 30, 70)
	snowPart.Transparency = 1
	snowPart.Anchored = true
	snowPart.CanCollide = false
	snowPart.CanQuery = false
	snowPart.CastShadow = false
	snowPart.Parent = camera
	local att = Instance.new("Attachment")
	att.Parent = snowPart
	snowEmitter = Instance.new("ParticleEmitter")
	snowEmitter.Name = "Snow"
	snowEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snowEmitter.Color = ColorSequence.new(Color3.fromRGB(230, 236, 246))
	snowEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0.11) })
	snowEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.35), NumberSequenceKeypoint.new(0.9, 0.5), NumberSequenceKeypoint.new(1, 1) })
	snowEmitter.Lifetime = NumberRange.new(3, 5)
	snowEmitter.Speed = NumberRange.new(2, 4)
	snowEmitter.Rate = 0
	snowEmitter.Shape = Enum.ParticleEmitterShape.Box
	snowEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snowEmitter.EmissionDirection = Enum.NormalId.Bottom
	snowEmitter.LightInfluence = 0.8
	snowEmitter.LightEmission = 0.1
	snowEmitter.Drag = 0.5
	snowEmitter.Parent = att
end

local function fogTargets(visibility: number, indoors: boolean)
	-- Indoors the fog stays far so corridors read as dark, not milky.
	local vis = if indoors then math.max(visibility, 140) else visibility
	local density = math.clamp(0.9 - vis / 240, 0.2, 0.86)
	if indoors then
		density = math.min(density, 0.32)
	end
	density = math.min(0.92, density + extraFog * 0.25)
	return density, vis * 0.25, vis * 1.6
end

local function applyWeather(w, immediate: boolean?)
	WeatherController.State = w.state
	WeatherController.Visibility = w.visibility
	WorldFXController.WindStrength = w.wind or 0.2
	WorldFXController.Snow = w.snow or 0.1
	AudioController.Weather = { wind = w.wind or 0.2, snow = w.snow or 0.1, state = w.state }
	if not atmosphere then
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Parent = Lighting
		end
	end
	local density, fogStart, fogEnd = fogTargets(w.visibility, AudioController.Indoors)
	local t = if immediate then 0.1 else (w.transition or 20)
	TweenService:Create(atmosphere, TweenInfo.new(t, Enum.EasingStyle.Sine), { Density = density, Haze = 1.2 + (w.snow or 0) * 3, Glare = 0.1 }):Play()
	TweenService:Create(Lighting, TweenInfo.new(t, Enum.EasingStyle.Sine), { FogStart = fogStart, FogEnd = fogEnd }):Play()
end

local lastIndoors = nil
local function tick(dt: number)
	ensureSnow()
	if not snowPart or not snowEmitter then
		return
	end
	local indoors = AudioController.Indoors
	snowPart.CFrame = camera.CFrame * CFrame.new(0, 10, -10)
	snowPart.CFrame = CFrame.new(snowPart.CFrame.Position)
	local p = SettingsStore.Current.particles
	local scale = if p >= 2 then 1 elseif p == 1 then 0.45 else 0
	local snow = WorldFXController.Snow
	local wind = WorldFXController.WindStrength
	windAngleT += dt * 0.07
	windDir = Vector3.new(math.cos(windAngleT), 0, math.sin(windAngleT) * 0.6).Unit
	WorldFXController.Wind = windDir
	snowEmitter.Rate = if indoors then 0 else (40 + snow * 520) * scale
	snowEmitter.Acceleration = windDir * (4 + wind * 26) + Vector3.new(0, -2 - wind * 2, 0)
	snowEmitter.Speed = NumberRange.new(2 + wind * 6, 4 + wind * 10)
	if indoors ~= lastIndoors then
		lastIndoors = indoors
		applyWeather({ state = WeatherController.State, visibility = WeatherController.Visibility, wind = wind, snow = snow, transition = 3 }, false)
	end
	-- Window frost: thicker in storms and at night; off when the player disables it.
	local frostOn = SettingsStore.Current.frost
	local target = if frostOn then math.clamp(0.9 - (0.25 + snow * 0.45 + wind * 0.2), 0.2, 0.9) else 1
	for i = #frostParts, 1, -1 do
		local f = frostParts[i]
		if not f.Parent then
			table.remove(frostParts, i)
		else
			f.Transparency += (target - f.Transparency) * math.clamp(dt * 0.3, 0, 1)
		end
	end
	-- Post-processing intensity follows the setting (never changes visibility rules).
	local cc = Lighting:FindFirstChild("ColorGrade")
	if cc and cc:IsA("ColorCorrectionEffect") then
		local k = SettingsStore.Current.postFx
		cc.Saturation = -0.22 * k
		cc.Contrast = 0.1 * k
	end
	local bloom = Lighting:FindFirstChild("Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.3 * SettingsStore.Current.postFx
	end
end

function WeatherController.SetExtraFog(v: number)
	extraFog = math.clamp(v, 0, 1)
	applyWeather({ state = WeatherController.State, visibility = WeatherController.Visibility, wind = WorldFXController.WindStrength, snow = WorldFXController.Snow, transition = 4 })
end

function WeatherController.init()
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Frost") then
			table.insert(frostParts, inst)
		end
	end
	workspace.DescendantAdded:Connect(function(inst)
		task.defer(function()
			if inst:IsA("BasePart") and inst:GetAttribute("Frost") then
				table.insert(frostParts, inst)
			end
		end)
	end)
	Net.event("WeatherState").OnClientEvent:Connect(function(w)
		applyWeather(w)
	end)
	applyWeather({ state = GameConfig.Weather.StartState, visibility = GameConfig.Weather.States[GameConfig.Weather.StartState].visibility, wind = 0.4, snow = 0.4, transition = 1 }, true)
	RunService.Heartbeat:Connect(tick)
	player.CharacterAdded:Connect(function()
		snowPart = nil
	end)
end

return WeatherController
