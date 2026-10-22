--!nonstrict
-- Procedural Warden rig: tall humanoid in damaged industrial protective gear.
-- Built from parts with Motor6Ds so the AI can drive a simple gait. Designed
-- to be swapped for an authored mesh rig with the same part names later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)

local WardenModel = {}

export type Rig = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	head: BasePart,
	motors: { [string]: Motor6D },
	lens: BasePart,
	sounds: { [string]: Sound },
}

local SUIT = Color3.fromRGB(78, 82, 70) -- worn olive-grey protective fabric
local SUIT_DARK = Color3.fromRGB(48, 50, 46)
local RUST = Color3.fromRGB(120, 70, 40)
local TANK = Color3.fromRGB(96, 92, 84)

local function limb(parent: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

local function detail(parent: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local p = limb(parent.Parent :: Model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	return p
end

function WardenModel.build(parent: Instance, cframe: CFrame): Rig
	local model = Instance.new("Model")
	model.Name = "Warden"

	-- Proportions: ~9 studs tall (player is ~5) so it still fits a 9-stud door.
	local root = limb(model, "HumanoidRootPart", Vector3.new(2.6, 2, 1.4), SUIT)
	root.Transparency = 1
	root.CanCollide = false
	root.Massless = false
	root.CFrame = cframe

	local torso = limb(model, "Torso", Vector3.new(3.0, 3.8, 1.8), SUIT)
	torso.CanCollide = true -- the only colliding part; keeps the humanoid standing
	local head = limb(model, "Head", Vector3.new(1.7, 1.5, 1.9), SUIT_DARK, Enum.Material.Metal)
	local upperArmL = limb(model, "UpperArmL", Vector3.new(0.8, 2.4, 0.8), SUIT)
	local lowerArmL = limb(model, "LowerArmL", Vector3.new(0.7, 2.6, 0.7), SUIT_DARK)
	local upperArmR = limb(model, "UpperArmR", Vector3.new(0.8, 2.4, 0.8), SUIT)
	local lowerArmR = limb(model, "LowerArmR", Vector3.new(0.7, 2.6, 0.7), SUIT_DARK)
	local legL = limb(model, "LegL", Vector3.new(1.0, 3.6, 1.0), SUIT_DARK)
	local legR = limb(model, "LegR", Vector3.new(1.0, 3.6, 1.0), SUIT_DARK)

	local motors: { [string]: Motor6D } = {}
	motors.Root = motor("RootJoint", root, torso, CFrame.new(0, 1.2, 0), CFrame.new(0, 0, 0))
	motors.Neck = motor("Neck", torso, head, CFrame.new(0, 1.9, 0), CFrame.new(0, -0.8, 0))
	motors.ShoulderL = motor("ShoulderL", torso, upperArmL, CFrame.new(-1.9, 1.5, 0), CFrame.new(0, 1.1, 0))
	motors.ElbowL = motor("ElbowL", upperArmL, lowerArmL, CFrame.new(0, -1.2, 0), CFrame.new(0, 1.3, 0))
	motors.ShoulderR = motor("ShoulderR", torso, upperArmR, CFrame.new(1.9, 1.5, 0), CFrame.new(0, 1.1, 0))
	motors.ElbowR = motor("ElbowR", upperArmR, lowerArmR, CFrame.new(0, -1.2, 0), CFrame.new(0, 1.3, 0))
	motors.HipL = motor("HipL", torso, legL, CFrame.new(-0.8, -1.9, 0), CFrame.new(0, 1.8, 0))
	motors.HipR = motor("HipR", torso, legR, CFrame.new(0.8, -1.9, 0), CFrame.new(0, 1.8, 0))

	-- Gear details: chest plate, backpack tank, hoses, boots, gloves, visor, lens.
	detail(torso, "ChestPlate", Vector3.new(2.6, 2.0, 0.4), CFrame.new(0, 0.6, -1.0), TANK, Enum.Material.Metal)
	detail(torso, "ChestStrap", Vector3.new(3.2, 0.4, 2.0), CFrame.new(0, 1.2, 0), SUIT_DARK, Enum.Material.Rubber)
	detail(torso, "Tank", Vector3.new(1.0, 2.8, 1.0), CFrame.new(-0.6, 0.3, 1.3), TANK, Enum.Material.Metal)
	detail(torso, "Tank2", Vector3.new(1.0, 2.5, 1.0), CFrame.new(0.6, 0.1, 1.3), RUST, Enum.Material.CorrodedMetal)
	detail(torso, "Hose", Vector3.new(0.3, 2.2, 0.3), CFrame.new(-1.2, 0.9, 0.5) * CFrame.Angles(0.5, 0, 0.4), SUIT_DARK, Enum.Material.Rubber)
	detail(torso, "Hose2", Vector3.new(0.3, 1.9, 0.3), CFrame.new(1.2, 1.0, 0.4) * CFrame.Angles(0.5, 0, -0.5), SUIT_DARK, Enum.Material.Rubber)
	detail(torso, "Patch", Vector3.new(0.8, 0.7, 0.1), CFrame.new(0.9, -0.9, -0.95), RUST, Enum.Material.Fabric)
	detail(torso, "Tear", Vector3.new(0.4, 1.3, 0.1), CFrame.new(-1.0, -0.4, -0.95), Color3.fromRGB(20, 18, 18), Enum.Material.Fabric)
	detail(head, "Visor", Vector3.new(1.5, 0.6, 0.3), CFrame.new(0, 0.15, -0.9), Color3.fromRGB(12, 12, 14), Enum.Material.Glass)
	detail(head, "Filter", Vector3.new(0.7, 0.6, 0.5), CFrame.new(0, -0.45, -0.85), TANK, Enum.Material.Metal)
	detail(head, "FilterB", Vector3.new(0.5, 0.5, 0.4), CFrame.new(0.8, -0.35, -0.7), RUST, Enum.Material.CorrodedMetal)
	detail(head, "HelmetRim", Vector3.new(2.0, 0.25, 2.2), CFrame.new(0, 0.65, 0), SUIT_DARK, Enum.Material.Metal)
	local lens = detail(head, "Lens", Vector3.new(0.4, 0.2, 0.1), CFrame.new(-0.35, 0.15, -1.05), Color3.fromRGB(180, 30, 20), Enum.Material.Neon)
	local lensLight = Instance.new("PointLight")
	lensLight.Color = Color3.fromRGB(255, 50, 30)
	lensLight.Range = 6
	lensLight.Brightness = 0.6
	lensLight.Parent = lens
	detail(lowerArmL, "GloveL", Vector3.new(0.85, 0.9, 0.85), CFrame.new(0, -1.1, 0), SUIT_DARK, Enum.Material.Rubber)
	detail(lowerArmR, "GloveR", Vector3.new(0.85, 0.9, 0.85), CFrame.new(0, -1.1, 0), SUIT_DARK, Enum.Material.Rubber)
	detail(legL, "BootL", Vector3.new(1.2, 1.0, 1.5), CFrame.new(0, -1.4, -0.2), SUIT_DARK, Enum.Material.Rubber)
	detail(legR, "BootR", Vector3.new(1.2, 1.0, 1.5), CFrame.new(0, -1.4, -0.2), SUIT_DARK, Enum.Material.Rubber)
	detail(legL, "KneePad", Vector3.new(1.1, 0.8, 0.4), CFrame.new(0, 0.1, -0.55), TANK, Enum.Material.Metal)
	detail(legR, "KneePad", Vector3.new(1.1, 0.8, 0.4), CFrame.new(0, 0.1, -0.55), RUST, Enum.Material.CorrodedMetal)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 3.3 -- feet are 4.3 below the root centre, root half-height is 1
	humanoid.WalkSpeed = 7
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	local sounds: { [string]: Sound } = {}
	for name, def in { Step = Sounds.WardenStep, StepChase = Sounds.WardenStepChase, Suspicious = Sounds.WardenSuspicious, Attack = Sounds.WardenAttack, Creak = Sounds.WardenGearCreak } do
		sounds[name] = Builder.sound(root, def, name)
	end

	model.PrimaryPart = root
	model.Parent = parent
	return { model = model, root = root, humanoid = humanoid, head = head, motors = motors, lens = lens, sounds = sounds }
end

-- Gait driver: call every ~1/20 s. `phase` advances with distance travelled.
function WardenModel.pose(rig: Rig, phase: number, speedFactor: number, mode: string)
	local m = rig.motors
	local swing = math.sin(phase) * (0.45 + 0.35 * speedFactor)
	local lean = if mode == "Chase" then 0.35 elseif mode == "Search" then 0.12 else 0.05
	local bob = math.abs(math.cos(phase)) * 0.15 * speedFactor
	m.Root.C0 = CFrame.new(0, 1.2 + bob, 0) * CFrame.Angles(lean, 0, math.sin(phase) * 0.04)
	m.HipL.C0 = CFrame.new(-0.8, -1.9, 0) * CFrame.Angles(swing, 0, 0)
	m.HipR.C0 = CFrame.new(0.8, -1.9, 0) * CFrame.Angles(-swing, 0, 0)
	local armSwing = -swing * 0.7
	if mode == "Chase" then
		-- arms raised forward, reaching
		m.ShoulderL.C0 = CFrame.new(-1.9, 1.5, 0) * CFrame.Angles(-1.3 + armSwing * 0.3, 0, -0.2)
		m.ShoulderR.C0 = CFrame.new(1.9, 1.5, 0) * CFrame.Angles(-1.3 - armSwing * 0.3, 0, 0.2)
		m.ElbowL.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.4, 0, 0)
		m.ElbowR.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.4, 0, 0)
	elseif mode == "Attack" then
		m.ShoulderL.C0 = CFrame.new(-1.9, 1.5, 0) * CFrame.Angles(-2.4, 0, -0.5)
		m.ShoulderR.C0 = CFrame.new(1.9, 1.5, 0) * CFrame.Angles(-2.4, 0, 0.5)
		m.ElbowL.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.8, 0, 0)
		m.ElbowR.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.8, 0, 0)
	else
		m.ShoulderL.C0 = CFrame.new(-1.9, 1.5, 0) * CFrame.Angles(armSwing, 0, -0.08)
		m.ShoulderR.C0 = CFrame.new(1.9, 1.5, 0) * CFrame.Angles(-armSwing, 0, 0.08)
		m.ElbowL.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.25, 0, 0)
		m.ElbowR.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(-0.25, 0, 0)
	end
	local headTilt = if mode == "Suspicious" or mode == "Investigate" then math.sin(phase * 0.5) * 0.35 else 0
	m.Neck.C0 = CFrame.new(0, 1.9, 0) * CFrame.Angles(if mode == "Chase" then 0.2 else -0.05, headTilt, 0)
end

return WardenModel
