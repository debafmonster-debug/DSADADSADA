--!nonstrict
-- Flashlight: a narrow main beam plus a soft fill, a lens that frosts when
-- the body gets cold, dust/snow visible in the cone, and a battery owned by
-- the server (we only render what InventoryUpdated tells us).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local F = GameConfig.Flashlight
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FlashlightController = {}
FlashlightController.Changed = Signal.new()
FlashlightController.On = false
FlashlightController.Battery = F.BatterySeconds
FlashlightController.Frost = 0 -- 0..1 set by TemperatureFX
FlashlightController.Dim = 1 -- external dimming (events)

local holder: Part? = nil
local spot: SpotLight? = nil
local fill: PointLight? = nil
local dust: ParticleEmitter? = nil
local swayT = 0
local lastCamCF = CFrame.new()
local lag = CFrame.new()

local function ensureRig()
	if holder and holder.Parent then
		return
	end
	holder = Instance.new("Part")
	holder.Name = "FlashlightRig"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Anchored = true
	holder.CastShadow = false
	holder.Parent = camera
	spot = Instance.new("SpotLight")
	spot.Name = "Beam"
	spot.Angle = F.Angle
	spot.Range = F.Range
	spot.Brightness = F.Brightness
	spot.Color = Color3.fromRGB(255, 242, 214)
	spot.Face = Enum.NormalId.Front
	spot.Shadows = SettingsStore.Current.effectsQuality >= 2
	spot.Enabled = false
	spot.Parent = holder
	fill = Instance.new("PointLight")
	fill.Name = "Fill"
	fill.Range = F.FillRange
	fill.Brightness = F.FillBrightness
	fill.Color = Color3.fromRGB(255, 236, 205)
	fill.Shadows = false
	fill.Enabled = false
	fill.Parent = holder
	-- Dust and snow in the beam: a slow emitter pointed forward from the lens.
	local att = Instance.new("Attachment")
	att.Name = "Lens"
	att.Parent = holder
	dust = Instance.new("ParticleEmitter")
	dust.Name = "BeamDust"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 244, 220))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.08) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.75), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.5, 3)
	dust.Rate = 0
	dust.Speed = NumberRange.new(0.5, 2)
	dust.SpreadAngle = Vector2.new(14, 14)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.LightEmission = 0.6
	dust.LightInfluence = 0
	dust.Drag = 2
	dust.Parent = att
end

local function apply()
	if not spot or not fill or not dust then
		return
	end
	local on = FlashlightController.On and FlashlightController.Battery > 0
	local frostDim = 1 - FlashlightController.Frost * (1 - F.FrostDimMin)
	local lowBattery = math.clamp(FlashlightController.Battery / 30, 0.35, 1)
	local k = frostDim * lowBattery * FlashlightController.Dim
	spot.Enabled = on
	fill.Enabled = on
	spot.Brightness = F.Brightness * k
	fill.Brightness = F.FillBrightness * k
	spot.Angle = F.Angle + FlashlightController.Frost * 8 -- frost scatters the beam a little
	local q = SettingsStore.Current.effectsQuality
	dust.Rate = if on and q >= 1 then (if q >= 2 then 18 else 8) else 0
end

local function set(on: boolean)
	if on and FlashlightController.Battery <= 0 then
		Theme.playUISound("UIError")
		return
	end
	if FlashlightController.On == on then
		return
	end
	FlashlightController.On = on
	Theme.playUISound("FlashlightClick")
	Net.event("FlashlightState"):FireServer(on)
	apply()
	FlashlightController.Changed:Fire(on)
end

function FlashlightController.Toggle()
	if CameraController.InputLocked then
		return
	end
	set(not FlashlightController.On)
end

function FlashlightController.ForceOff()
	set(false)
end

function FlashlightController.SetFrost(f: number)
	FlashlightController.Frost = math.clamp(f, 0, 1)
	apply()
end

function FlashlightController.init()
	ensureRig()
	ContextActionService:BindAction("V9_Flashlight", function(_, state)
		if state == Enum.UserInputState.Begin then
			FlashlightController.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	Net.event("InventoryUpdated").OnClientEvent:Connect(function(inv)
		if typeof(inv) == "table" and typeof(inv.battery) == "number" then
			FlashlightController.Battery = inv.battery
			if inv.battery <= 0 and FlashlightController.On then
				set(false)
			end
			apply()
			FlashlightController.Changed:Fire(FlashlightController.On)
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(state)
		if state.phase == "Idle" or state.phase == "Boarding" then
			if FlashlightController.On then
				set(false)
			end
			FlashlightController.Battery = F.BatterySeconds
			apply()
		end
	end)
	SettingsStore.Changed:Connect(function()
		if spot then
			spot.Shadows = SettingsStore.Current.effectsQuality >= 2
		end
		apply()
	end)
	player.CharacterAdded:Connect(function()
		ensureRig()
		apply()
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not holder then
			return
		end
		-- Hand-held feel: the beam lags the view slightly and sways with movement.
		local cf = camera.CFrame
		local rel = lastCamCF:ToObjectSpace(cf)
		local _, yaw, _ = rel:ToEulerAnglesYXZ()
		local pitch = rel:ToEulerAnglesYXZ()
		lastCamCF = cf
		lag = lag:Lerp(CFrame.Angles(-pitch * 0.35, -yaw * 0.35, 0), math.clamp(dt * 10, 0, 1))
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local speed = if hum then hum.MoveDirection.Magnitude * hum.WalkSpeed else 0
		swayT += dt * (4 + speed * 0.4)
		local sway = CFrame.Angles(math.sin(swayT * 1.3) * 0.004 * (1 + speed * 0.1), math.sin(swayT) * 0.006 * (1 + speed * 0.1), 0)
		holder.CFrame = cf * CFrame.new(0.55, -0.45, -0.2) * lag * sway
		if FlashlightController.On then
			FlashlightController.Battery = math.max(0, FlashlightController.Battery - dt) -- cosmetic countdown; server is authoritative
		end
	end)
	apply()
end

return FlashlightController
