--!nonstrict
-- Cold presentation: breath puffs, a frost vignette that grows with the cold
-- stage, lens frost on the flashlight, camera shiver, slower hands and a
-- muffled mix at stage 2. All driven by PlayerFlags.coldStage from the server.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)
local FlashlightController = require(script.Parent.FlashlightController)
local AudioController = require(script.Parent.AudioController)
local WeatherController = require(script.Parent.WeatherController)

local camera = workspace.CurrentCamera

local TemperatureFXController = {}

local stage = 0
local heat = 100
local vignette: Frame? = nil
local edges: { Frame } = {}
local breathPart: Part? = nil
local breath: ParticleEmitter? = nil
local breathT = 0

local function build()
	local gui = Theme.screen("V9_ColdFX", 5, true)
	vignette = Theme.frame(gui, { BackgroundTransparency = 1 })
	-- Four soft edges fading inward: cheap frost without textures.
	for _, side in { "L", "R", "T", "B" } do
		local f = Theme.frame(vignette, { BackgroundColor3 = Color3.fromRGB(205, 222, 236), BackgroundTransparency = 1 })
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		if side == "L" then
			f.Size = UDim2.new(0.22, 0, 1, 0)
			g.Rotation = 0
		elseif side == "R" then
			f.Size = UDim2.new(0.22, 0, 1, 0)
			f.Position = UDim2.new(0.78, 0, 0, 0)
			g.Rotation = 180
		elseif side == "T" then
			f.Size = UDim2.new(1, 0, 0.2, 0)
			g.Rotation = 90
		else
			f.Size = UDim2.new(1, 0, 0.2, 0)
			f.Position = UDim2.new(0, 0, 0.8, 0)
			g.Rotation = -90
		end
		g.Parent = f
		table.insert(edges, f)
	end
end

local function ensureBreath()
	if breathPart and breathPart.Parent then
		return
	end
	breathPart = Instance.new("Part")
	breathPart.Name = "Breath"
	breathPart.Size = Vector3.new(0.2, 0.2, 0.2)
	breathPart.Transparency = 1
	breathPart.Anchored = true
	breathPart.CanCollide = false
	breathPart.CanQuery = false
	breathPart.Parent = camera
	local att = Instance.new("Attachment")
	att.Parent = breathPart
	breath = Instance.new("ParticleEmitter")
	breath.Texture = "rbxasset://textures/particles/smoke_main.dds"
	breath.Color = ColorSequence.new(Color3.fromRGB(225, 232, 240))
	breath.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.7) })
	breath.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	breath.Lifetime = NumberRange.new(0.8, 1.4)
	breath.Speed = NumberRange.new(1.2, 2)
	breath.Rate = 0
	breath.EmissionDirection = Enum.NormalId.Front
	breath.SpreadAngle = Vector2.new(10, 10)
	breath.LightInfluence = 1
	breath.Parent = att
end

local function apply()
	local k = if stage >= 3 then 1 elseif stage == 2 then 0.7 elseif stage == 1 then 0.35 else 0
	local frostAllowed = SettingsStore.Current.frost
	for _, f in edges do
		f.BackgroundTransparency = if frostAllowed then 1 - k * 0.8 else 1
	end
	FlashlightController.SetFrost(if frostAllowed then math.clamp((GameConfig.Flashlight.FrostDimBelowHeat - heat) / GameConfig.Flashlight.FrostDimBelowHeat, 0, 1) else 0)
	CameraController.Shiver = if stage >= 2 then 1 elseif stage == 1 then 0.45 else 0
	CameraController.SpeedMult = if stage >= 2 then 0.82 elseif stage == 1 then 0.93 else 1
	CameraController.UpdateSpeed()
	AudioController.SetMuffle(if stage >= 2 then 0.8 else 0)
	WeatherController.SetExtraFog(if stage >= 2 then 0.5 else 0)
end

function TemperatureFXController.init()
	build()
	ensureBreath()
	Net.event("PlayerFlags").OnClientEvent:Connect(function(f)
		local changed = false
		if f.coldStage ~= nil and f.coldStage ~= stage then
			stage = f.coldStage
			changed = true
		end
		if f.heat ~= nil then
			heat = f.heat
			changed = true
		end
		if changed then
			apply()
		end
	end)
	SettingsStore.Changed:Connect(apply)
	RunService.RenderStepped:Connect(function(dt)
		ensureBreath()
		if not breathPart or not breath then
			return
		end
		breathPart.CFrame = camera.CFrame * CFrame.new(0, -0.35, -0.6)
		local outdoors = not AudioController.Indoors
		local p = SettingsStore.Current.particles
		if not SettingsStore.Current.breath or p == 0 or CameraController.CinematicActive then
			breath.Rate = 0
			return
		end
		-- Breathing rhythm: faster when cold, visible mainly outdoors.
		local period = if stage >= 2 then 2.2 elseif stage == 1 then 3 else 4
		breathT += dt
		local phase = (breathT % period) / period
		local exhale = phase > 0.45 and phase < 0.75
		breath.Rate = if exhale and (outdoors or stage >= 1) then (if outdoors then 10 else 4) else 0
		breath.Acceleration = WeatherController and Vector3.new(0, 0.4, 0) or Vector3.zero
	end)
end

return TemperatureFXController
