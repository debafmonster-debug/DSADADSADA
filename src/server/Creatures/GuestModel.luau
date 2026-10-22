--!nonstrict
-- «Гость»: procedural rig for the unknown life form. Tall, thin, wrapped in
-- iced fabric over a dark organic core; two small cold eyes. The part/motor
-- naming is a contract so an authored mesh rig can replace it later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local P = Builder.Palette

local GuestModel = {}

export type Rig = {
	model: Model,
	root: BasePart,
	torso: BasePart,
	head: BasePart,
	humanoid: Humanoid,
	motors: { [string]: Motor6D },
	eyes: { BasePart },
	eyeLight: PointLight,
	sounds: { [string]: Sound },
}

local CORE = Color3.fromRGB(26, 28, 34)
local ICE = Color3.fromRGB(150, 176, 196)
local CLOTH = Color3.fromRGB(58, 62, 70)

local function part(parent, name, size, cf, material, color, collide, transparency)
	local p = Builder.part({ name = name, size = size, cframe = cf, material = material, color = color, parent = parent, canCollide = collide == true, transparency = transparency })
	p.Anchored = false
	return p
end

local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1 or CFrame.new()
	m.Parent = p0
	return m
end

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p0
end

function GuestModel.build(parent: Instance, cframe: CFrame): Rig
	local model = Instance.new("Model")
	model.Name = "Guest"
	local root = part(model, "HumanoidRootPart", Vector3.new(2.4, 2.4, 1.6), cframe, Enum.Material.SmoothPlastic, CORE, false, 1)
	root.CanCollide = false
	local torso = part(model, "Torso", Vector3.new(2.6, 5.2, 1.6), cframe, Enum.Material.Slate, CORE, true)
	local pelvis = part(model, "Pelvis", Vector3.new(2.2, 1.4, 1.4), cframe, Enum.Material.Slate, CORE, false)
	local head = part(model, "Head", Vector3.new(1.3, 2.0, 1.5), cframe, Enum.Material.Slate, CORE, false)
	-- Frozen wrap: angled fabric plates over the torso and a torn hood.
	for i = 0, 3 do
		local plate = part(model, "Wrap", Vector3.new(2.9, 1.3, 0.35), cframe, Enum.Material.Fabric, CLOTH, false)
		plate.CFrame = torso.CFrame * CFrame.new(0, 2.0 - i * 1.2, 0.85 + (i % 2) * 0.1) * CFrame.Angles((i % 2) * 0.15 - 0.07, 0, 0)
		weld(torso, plate)
		local ice = part(model, "IceShard", Vector3.new(0.6, 0.9, 0.2), cframe, Enum.Material.Ice, ICE, false, 0.35)
		ice.CFrame = torso.CFrame * CFrame.new(-1.1 + i * 0.7, 1.6 - i * 0.9, 1.0) * CFrame.Angles(0, 0, 0.4 - i * 0.2)
		weld(torso, ice)
	end
	local hood = part(model, "Hood", Vector3.new(1.7, 1.2, 1.9), cframe, Enum.Material.Fabric, CLOTH, false)
	hood.CFrame = head.CFrame * CFrame.new(0, 0.7, -0.2)
	weld(head, hood)
	-- Eyes: small cold points, their light is tiny on purpose.
	local eyes = {}
	for i, x in { -0.3, 0.3 } do
		local e = part(model, "Eye" .. i, Vector3.new(0.18, 0.12, 0.1), cframe, Enum.Material.Neon, P.EyeGlow, false)
		e.CFrame = head.CFrame * CFrame.new(x, 0.25, -0.78)
		e.CastShadow = false
		weld(head, e)
		table.insert(eyes, e)
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Name = "EyeLight"
	eyeLight.Color = P.EyeGlow
	eyeLight.Range = 5
	eyeLight.Brightness = 0.35
	eyeLight.Shadows = false
	eyeLight.Parent = eyes[1]
	-- Limbs: two-segment arms and legs, slightly too long.
	local function limb(prefix, upperSize, lowerSize)
		local upper = part(model, prefix .. "Upper", upperSize, cframe, Enum.Material.Slate, CORE, false)
		local lower = part(model, prefix .. "Lower", lowerSize, cframe, Enum.Material.Slate, CORE, false)
		local wrap = part(model, prefix .. "Wrap", Vector3.new(upperSize.X + 0.25, upperSize.Y * 0.6, upperSize.Z + 0.25), cframe, Enum.Material.Fabric, CLOTH, false)
		weld(upper, wrap)
		wrap.CFrame = upper.CFrame * CFrame.new(0, upperSize.Y * 0.1, 0)
		return upper, lower
	end
	local armUL, armLL = limb("ArmL", Vector3.new(0.7, 3.4, 0.7), Vector3.new(0.55, 3.6, 0.55))
	local armUR, armLR = limb("ArmR", Vector3.new(0.7, 3.4, 0.7), Vector3.new(0.55, 3.6, 0.55))
	local legUL, legLL = limb("LegL", Vector3.new(0.9, 3.4, 0.9), Vector3.new(0.75, 3.4, 0.75))
	local legUR, legLR = limb("LegR", Vector3.new(0.9, 3.4, 0.9), Vector3.new(0.75, 3.4, 0.75))
	local motors = {}
	motors.Root = motor("Root", root, torso, CFrame.new(0, 1.0, 0))
	motors.Waist = motor("Waist", torso, pelvis, CFrame.new(0, -3.2, 0))
	motors.Neck = motor("Neck", torso, head, CFrame.new(0, 3.4, 0), CFrame.new(0, -0.8, 0))
	motors.ShoulderL = motor("ShoulderL", torso, armUL, CFrame.new(-1.65, 2.2, 0), CFrame.new(0, 1.6, 0))
	motors.ShoulderR = motor("ShoulderR", torso, armUR, CFrame.new(1.65, 2.2, 0), CFrame.new(0, 1.6, 0))
	motors.ElbowL = motor("ElbowL", armUL, armLL, CFrame.new(0, -1.7, 0), CFrame.new(0, 1.8, 0))
	motors.ElbowR = motor("ElbowR", armUR, armLR, CFrame.new(0, -1.7, 0), CFrame.new(0, 1.8, 0))
	motors.HipL = motor("HipL", pelvis, legUL, CFrame.new(-0.6, -0.6, 0), CFrame.new(0, 1.7, 0))
	motors.HipR = motor("HipR", pelvis, legUR, CFrame.new(0.6, -0.6, 0), CFrame.new(0, 1.7, 0))
	motors.KneeL = motor("KneeL", legUL, legLL, CFrame.new(0, -1.7, 0), CFrame.new(0, 1.7, 0))
	motors.KneeR = motor("KneeR", legUR, legLR, CFrame.new(0, -1.7, 0), CFrame.new(0, 1.7, 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 7.4
	hum.MaxHealth = 1e6
	hum.Health = 1e6
	hum.BreakJointsOnDeath = false
	hum.AutoRotate = true
	hum.NameDisplayDistance = 0
	hum.HealthDisplayDistance = 0
	hum.WalkSpeed = 6
	hum.Parent = model
	model.PrimaryPart = root
	local sounds = {}
	for key, def in { Step = Sounds.GuestStep, StepChase = Sounds.GuestStepChase, Breath = Sounds.GuestBreath, Touch = Sounds.GuestTouch, Notice = Sounds.GuestNotice, Attack = Sounds.GuestAttack } do
		sounds[key] = Builder.sound(torso, def, key)
	end
	model:SetAttribute("Creature", "Guest")
	model:SetAttribute("State", "Idle")
	model.Parent = parent
	return { model = model, root = root, torso = torso, head = head, humanoid = hum, motors = motors, eyes = eyes, eyeLight = eyeLight, sounds = sounds }
end

-- Procedural gait. `phase` advances with distance travelled; `mode` selects
-- the posture. Only C0 of the motors is rewritten so it stays cheap.
function GuestModel.pose(rig: Rig, phase: number, _speedFactor: number, mode: string, headYaw: number?, headPitch: number?)
	local m = rig.motors
	local s = math.sin(phase)
	local c = math.cos(phase)
	local lean, crouch, armSwing, stride = 0.04, 0, 0.35, 0.55
	if mode == "Stalk" then
		lean, crouch, armSwing, stride = 0.22, 0.6, 0.15, 0.4
	elseif mode == "Chase" then
		lean, crouch, armSwing, stride = 0.3, 0.2, 0.7, 0.95
	elseif mode == "Observe" or mode == "Idle" or mode == "Listen" then
		lean, armSwing, stride = 0.0, 0.05, 0.0
	elseif mode == "Attack" then
		lean, armSwing, stride = 0.35, 0.0, 0.2
	end
	local breathe = math.sin(os.clock() * 1.1) * 0.03
	m.Root.C0 = CFrame.new(0, 1.0 - crouch - math.abs(s) * 0.12 * stride, 0) * CFrame.Angles(-lean + breathe, 0, s * 0.04 * stride)
	m.Waist.C0 = CFrame.new(0, -3.2, 0) * CFrame.Angles(lean * 0.4, s * 0.08 * stride, 0)
	local hy = headYaw or 0
	local hp = headPitch or 0
	local tilt = if mode == "Listen" then 0.35 else 0
	m.Neck.C0 = CFrame.new(0, 3.4, 0) * CFrame.Angles(0.15 + hp - lean * 0.5, hy, tilt + breathe)
	local sw = s * armSwing * stride
	if mode == "Attack" then
		m.ShoulderL.C0 = CFrame.new(-1.65, 2.2, 0) * CFrame.Angles(-2.4, 0, -0.4)
		m.ShoulderR.C0 = CFrame.new(1.65, 2.2, 0) * CFrame.Angles(-2.4, 0, 0.4)
		m.ElbowL.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-0.4, 0, 0)
		m.ElbowR.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-0.4, 0, 0)
	else
		m.ShoulderL.C0 = CFrame.new(-1.65, 2.2, 0) * CFrame.Angles(sw - 0.1, 0, -0.12 + crouch * 0.2)
		m.ShoulderR.C0 = CFrame.new(1.65, 2.2, 0) * CFrame.Angles(-sw - 0.1, 0, 0.12 - crouch * 0.2)
		m.ElbowL.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-0.25 - math.max(0, sw) * 0.8, 0, 0)
		m.ElbowR.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-0.25 - math.max(0, -sw) * 0.8, 0, 0)
	end
	local ls = s * stride * 0.9
	m.HipL.C0 = CFrame.new(-0.6, -0.6, 0) * CFrame.Angles(ls + crouch * 0.6, 0, 0.05)
	m.HipR.C0 = CFrame.new(0.6, -0.6, 0) * CFrame.Angles(-ls + crouch * 0.6, 0, -0.05)
	m.KneeL.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-math.max(0, -c * stride) * 1.1 - crouch * 0.9, 0, 0)
	m.KneeR.C0 = CFrame.new(0, -1.7, 0) * CFrame.Angles(-math.max(0, c * stride) * 1.1 - crouch * 0.9, 0, 0)
end

-- Eye glow follows state; never bright enough to light a room.
function GuestModel.setEyes(rig: Rig, intensity: number)
	local i = math.clamp(intensity, 0, 1)
	for _, e in rig.eyes do
		e.Transparency = 1 - (0.35 + i * 0.65)
	end
	rig.eyeLight.Brightness = 0.15 + i * 0.6
	rig.eyeLight.Range = 3 + i * 4
end

return GuestModel
