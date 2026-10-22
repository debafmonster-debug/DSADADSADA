--!nonstrict
-- First-person hands: orange parka sleeves and gloves rendered on the client,
-- the flashlight in the left hand and the active tool in the right. Reaches
-- forward while a prompt is held and bobs with movement. Pure presentation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local SettingsStore = require(script.Parent.SettingsStore)
local FlashlightController = require(script.Parent.FlashlightController)
local CameraController = require(script.Parent.CameraController)
local P = Builder.Palette

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ViewmodelController = {}

local rig: Model? = nil
local parts: { [string]: BasePart } = {}
local reach = 0
local reachTarget = 0
local t = 0
local toolColor: Color3? = nil
local gloveOff = 0 -- 1 while a glove is removed for fine work

local function mk(name, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.Fabric
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = rig
	parts[name] = p
	return p
end

local function build()
	if rig then
		rig:Destroy()
	end
	rig = Instance.new("Model")
	rig.Name = "Viewmodel"
	parts = {}
	mk("SleeveL", Vector3.new(0.55, 0.55, 1.5), P.StationOrangeFaded)
	mk("SleeveR", Vector3.new(0.55, 0.55, 1.5), P.StationOrangeFaded)
	mk("CuffL", Vector3.new(0.6, 0.6, 0.25), P.Graphite, Enum.Material.Fabric)
	mk("CuffR", Vector3.new(0.6, 0.6, 0.25), P.Graphite, Enum.Material.Fabric)
	mk("GloveL", Vector3.new(0.5, 0.42, 0.75), P.Bakelite, Enum.Material.Fabric)
	mk("GloveR", Vector3.new(0.5, 0.42, 0.75), P.Bakelite, Enum.Material.Fabric)
	mk("Flashlight", Vector3.new(0.28, 0.28, 1.1), P.Graphite, Enum.Material.Metal)
	local lens = mk("Lens", Vector3.new(0.3, 0.3, 0.06), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)
	lens.Transparency = 1
	mk("Tool", Vector3.new(0.45, 0.9, 0.3), P.Yellow, Enum.Material.SmoothPlastic)
	rig.Parent = camera
end

local function toolFor(): Color3?
	local id = player:GetAttribute("ActiveTool")
	local def = id and Tools.Defs[id]
	return def and def.color or nil
end

function ViewmodelController.SetGloveOff(on: boolean)
	gloveOff = if on then 1 else 0
end

function ViewmodelController.init()
	build()
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		build()
	end)
	player:GetAttributeChangedSignal("ActiveTool"):Connect(function()
		toolColor = toolFor()
	end)
	toolColor = toolFor()
	ProximityPromptService.PromptButtonHoldBegan:Connect(function()
		reachTarget = 1
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function()
		reachTarget = 0
	end)
	ProximityPromptService.PromptTriggered:Connect(function()
		reachTarget = 1
		task.delay(0.35, function()
			reachTarget = 0
		end)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not rig or not rig.Parent then
			return
		end
		local show = not CameraController.CinematicActive and not CameraController.Downed and player.Character ~= nil
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local speed = if hum then hum.MoveDirection.Magnitude * hum.WalkSpeed else 0
		t += dt * (3 + speed * 0.45)
		reach += (reachTarget - reach) * math.clamp(dt * 9, 0, 1)
		local shake = SettingsStore.Current.cameraShake
		local bob = CFrame.new(math.sin(t) * 0.02 * shake * math.clamp(speed / 11, 0, 1), math.abs(math.cos(t)) * 0.025 * shake * math.clamp(speed / 11, 0, 1), 0)
		local shiver = CameraController.Shiver * 0.02
		local sh = CFrame.new((math.sin(t * 29) + math.sin(t * 17)) * shiver, math.sin(t * 31) * shiver, 0)
		local base = camera.CFrame * bob * sh
		local flOn = FlashlightController.On and FlashlightController.Battery > 0
		-- Left hand: flashlight held low and slightly inward.
		local lh = base * CFrame.new(-0.62, -0.62 + reach * 0.05, -1.25 + reach * 0.1) * CFrame.Angles(0.15, 0.25, 0)
		parts.SleeveL.CFrame = lh * CFrame.new(0, 0.05, 0.9) * CFrame.Angles(-0.25, 0, 0)
		parts.CuffL.CFrame = lh * CFrame.new(0, 0.02, 0.22)
		parts.GloveL.CFrame = lh * CFrame.new(0, 0, -0.1)
		parts.Flashlight.CFrame = lh * CFrame.new(0, 0.08, -0.55)
		parts.Lens.CFrame = lh * CFrame.new(0, 0.08, -1.12)
		parts.Lens.Transparency = if flOn then 0.1 else 1
		-- Right hand: tool, reaching forward while interacting.
		local rh = base * CFrame.new(0.66, -0.66 + reach * 0.12, -1.2 - reach * 0.55) * CFrame.Angles(0.1 - reach * 0.4, -0.3 + reach * 0.15, 0)
		parts.SleeveR.CFrame = rh * CFrame.new(0, 0.05, 0.9) * CFrame.Angles(-0.25, 0, 0)
		parts.CuffR.CFrame = rh * CFrame.new(0, 0.02, 0.22)
		parts.GloveR.CFrame = rh * CFrame.new(0, 0, -0.1)
		parts.GloveR.Color = if gloveOff > 0 then Color3.fromRGB(214, 170, 140) else P.Bakelite
		parts.Tool.CFrame = rh * CFrame.new(0, 0.3, -0.35) * CFrame.Angles(-0.4, 0, 0)
		parts.Tool.Color = toolColor or P.Yellow
		parts.Tool.Transparency = if toolColor then 0 else 1
		for _, p in parts do
			if p ~= parts.Lens and p ~= parts.Tool then
				p.Transparency = if show then 0 else 1
			end
		end
		if not show then
			parts.Lens.Transparency = 1
			parts.Tool.Transparency = 1
		end
	end)
end

return ViewmodelController
