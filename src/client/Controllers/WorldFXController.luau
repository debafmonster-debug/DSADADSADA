--!nonstrict
-- World presentation that costs nothing on the server: blinking beacons,
-- spinning anemometers/props, windsocks, gauge needles, and particle
-- emitters created on FX anchors according to the particle setting.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local SettingsStore = require(script.Parent.SettingsStore)

local WorldFXController = {}
WorldFXController.Wind = Vector3.new(1, 0, 0.3)
WorldFXController.WindStrength = 0.3
WorldFXController.Snow = 0.2

local blinkers: { [BasePart]: number } = {}
local spinners: { BasePart: boolean } = {}
local socks: { [BasePart]: CFrame } = {}
local emitters: { [BasePart]: ParticleEmitter } = {}
local camera = workspace.CurrentCamera

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function makeEmitter(anchor: BasePart, kind: string): ParticleEmitter?
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local e = Instance.new("ParticleEmitter")
	e.Name = "FX_" .. kind
	e.LightInfluence = 1
	if kind == "Steam" then
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(230, 234, 240))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(1, 2)
		e.Rate = anchor:GetAttribute("Rate") or 2
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.SpreadAngle = Vector2.new(15, 15)
	elseif kind == "Drip" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(200, 220, 240))
		e.Size = NumberSequence.new(0.08)
		e.Lifetime = NumberRange.new(0.5, 0.7)
		e.Speed = NumberRange.new(0)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Rate = 0.6
	elseif kind == "SnowIn" then
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(235, 240, 250))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0.1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1.5, 3)
		e.Speed = NumberRange.new(2, 5)
		e.Acceleration = Vector3.new(0, -4, 0)
		e.Rate = 0 -- driven by exterior door state / weather in update()
		e.SpreadAngle = Vector2.new(40, 40)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	else
		-- SnowField is drawn by WeatherController around the camera; unknown kinds get nothing.
		att:Destroy()
		return nil
	end
	e.Parent = att
	return e
end

local function register(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local blink = inst:GetAttribute("Blink")
	if blink then
		blinkers[inst] = blink
	end
	if inst:GetAttribute("Spin") then
		spinners[inst] = true
	end
	if inst:GetAttribute("Windsock") then
		socks[inst] = inst.CFrame
	end
	local fx = inst:GetAttribute("FX")
	if fx and not emitters[inst] then
		local e = makeEmitter(inst, fx)
		if e then
			emitters[inst] = e
		end
	end
end

local function unregister(inst: Instance)
	blinkers[inst] = nil
	spinners[inst] = nil
	socks[inst] = nil
	emitters[inst] = nil
end

local function particleScale(): number
	local p = SettingsStore.Current.particles
	return if p >= 2 then 1 elseif p == 1 then 0.5 else 0
end

local function update(dt: number)
	local t = os.clock()
	for part, period in blinkers do
		if part.Parent then
			local on = (t % period) < period * 0.5
			part.Transparency = if on then 0 else 0.7
			local light = part:FindFirstChildWhichIsA("Light")
			if light then
				light.Enabled = on
			end
		else
			blinkers[part] = nil
		end
	end
	local spin = dt * (3 + WorldFXController.WindStrength * 14)
	for part in spinners do
		if part.Parent then
			part.CFrame = part.CFrame * CFrame.Angles(0, spin, 0) * (if part.Name == "Prop" then CFrame.Angles(0, 0, dt * 40) * CFrame.Angles(0, -spin, 0) else CFrame.new())
		else
			spinners[part] = nil
		end
	end
	for part, base in socks do
		if part.Parent then
			local droop = (1 - WorldFXController.WindStrength) * 0.9
			part.CFrame = base * CFrame.Angles(0, 0, -droop + math.sin(t * 2.3) * 0.08 * WorldFXController.WindStrength)
		else
			socks[part] = nil
		end
	end
	local scale = particleScale()
	for anchor, e in emitters do
		if not anchor.Parent then
			emitters[anchor] = nil
			continue
		end
		local kind = anchor:GetAttribute("FX")
		if kind == "SnowIn" then
			-- Snow blows in only through an open exterior door nearby.
			local open = false
			for _, d in workspace:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("Exterior") and d:GetAttribute("Open") and (d:GetPivot().Position - anchor.Position).Magnitude < 12 then
					open = true
					break
				end
			end
			e.Rate = if open then 30 * scale * (0.3 + WorldFXController.Snow) else 0
			e.Acceleration = WorldFXController.Wind * 6 * WorldFXController.WindStrength + Vector3.new(0, -4, 0)
		elseif kind == "Steam" then
			e.Rate = (anchor:GetAttribute("Rate") or 2) * scale
		end
	end
end

function WorldFXController.init()
	for _, inst in workspace:GetDescendants() do
		register(inst)
	end
	workspace.DescendantAdded:Connect(function(inst)
		-- Attributes may be set after parenting; defer one frame.
		task.defer(register, inst)
	end)
	workspace.DescendantRemoving:Connect(unregister)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 20 then
			update(acc)
			acc = 0
		end
	end)
	-- Gauge needles follow their Value attribute (set by the server).
	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") and inst.Name == "Gauge" then
			inst:GetAttributeChangedSignal("Value"):Connect(function()
				local center = inst:GetAttribute("Center")
				local needle = inst:FindFirstChild("Needle")
				if center and needle then
					local v = inst:GetAttribute("Value") or 0
					needle.CFrame = center * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, 0, math.rad(120) - v * math.rad(240)) * CFrame.new(0, 0.2, 0)
				end
			end)
		end
	end)
	-- Keep a reference so CollectionService stays importable for tags later.
	WorldFXController._cs = CollectionService
	WorldFXController._camera = camera
	WorldFXController._builder = Builder
end

return WorldFXController
