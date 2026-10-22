--!nonstrict
-- First-person camera, movement (sprint/crouch/stamina), flashlight and
-- subtle procedural head motion. Everything is local and respects settings.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local SettingsStore = require(script.Parent.SettingsStore)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}
CameraController.StateChanged = Signal.new()
CameraController.FlashlightChanged = Signal.new()
CameraController.Stamina = GameConfig.Character.StaminaMax
CameraController.Flashlight = false
CameraController.Battery = GameConfig.Flashlight.BatterySeconds
CameraController.Sprinting = false
CameraController.Crouching = false
CameraController.Downed = false
CameraController.InputLocked = false

local sprintHeld = false
local bobT = 0
local spot: SpotLight? = nil
local lastBattery = GameConfig.Flashlight.BatterySeconds

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applySensitivity()
	UserInputService.MouseDeltaSensitivity = 0.4 + SettingsStore.Current.sensitivity * 1.6
end

local function updateSpeed()
	local hum = humanoid()
	if not hum then
		return
	end
	if CameraController.Downed then
		return -- server controls crawl speed
	end
	local C = GameConfig.Character
	if CameraController.Sprinting then
		hum.WalkSpeed = C.SprintSpeed
	elseif CameraController.Crouching then
		hum.WalkSpeed = C.CrouchSpeed
	else
		hum.WalkSpeed = C.WalkSpeed
	end
end

local function setFlashlight(on: boolean)
	if on and CameraController.Battery <= 0 then
		on = false
	end
	if CameraController.Flashlight == on then
		return
	end
	CameraController.Flashlight = on
	if spot then
		spot.Enabled = on
	end
	Net.event("FlashlightState"):FireServer(on)
	CameraController.FlashlightChanged:Fire(on)
end

local function ensureSpot()
	if spot and spot.Parent then
		return
	end
	local s = Instance.new("SpotLight")
	s.Name = "LocalFlashlight"
	s.Angle = GameConfig.Flashlight.Angle
	s.Range = GameConfig.Flashlight.Range
	s.Brightness = GameConfig.Flashlight.Brightness
	s.Color = Color3.fromRGB(255, 244, 220)
	s.Shadows = SettingsStore.Current.effectsQuality >= 2
	s.Face = Enum.NormalId.Front
	s.Enabled = CameraController.Flashlight
	-- Attach to an invisible part that follows the camera so the beam aims where you look.
	local holder = Instance.new("Part")
	holder.Name = "FlashlightHolder"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.Anchored = true
	holder.CastShadow = false
	holder.Parent = camera
	s.Parent = holder
	spot = s
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	camera.FieldOfView = 76
	CameraController.Sprinting = false
	CameraController.Crouching = false
	CameraController.Downed = false
	CameraController.Stamina = GameConfig.Character.StaminaMax
	updateSpeed()
	ensureSpot()
end

local function handleSprint(_, state)
	sprintHeld = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end

local function handleCrouch(_, state)
	if state == Enum.UserInputState.Begin and not CameraController.InputLocked then
		CameraController.Crouching = not CameraController.Crouching
		if CameraController.Crouching then
			CameraController.Sprinting = false
		end
		updateSpeed()
		CameraController.StateChanged:Fire()
	end
	return Enum.ContextActionResult.Pass
end

local function handleFlashlight(_, state)
	if state == Enum.UserInputState.Begin and not CameraController.InputLocked then
		setFlashlight(not CameraController.Flashlight)
	end
	return Enum.ContextActionResult.Sink
end

function CameraController.ToggleFlashlight()
	setFlashlight(not CameraController.Flashlight)
end

function CameraController.ToggleSprint(on: boolean)
	sprintHeld = on
end

function CameraController.ToggleCrouch()
	handleCrouch(nil, Enum.UserInputState.Begin)
end

function CameraController.SetDowned(d: boolean)
	CameraController.Downed = d
	if d then
		CameraController.Sprinting = false
		setFlashlight(false)
	else
		updateSpeed()
	end
end

function CameraController.init()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	applySensitivity()
	SettingsStore.Changed:Connect(function()
		applySensitivity()
		if spot then
			spot.Shadows = SettingsStore.Current.effectsQuality >= 2
		end
	end)

	ContextActionService:BindAction("NS_Sprint", handleSprint, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("NS_Crouch", handleCrouch, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("NS_Flashlight", handleFlashlight, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

	local C = GameConfig.Character
	local F = GameConfig.Flashlight
	RunService.RenderStepped:Connect(function(dt)
		local hum = humanoid()
		if not hum then
			return
		end
		-- Sprint & stamina
		local moving = hum.MoveDirection.Magnitude > 0.1
		local wantSprint = sprintHeld and moving and not CameraController.Crouching and not CameraController.Downed and not CameraController.InputLocked
		if wantSprint and CameraController.Stamina > 0.2 then
			CameraController.Stamina = math.max(0, CameraController.Stamina - dt)
			if not CameraController.Sprinting then
				CameraController.Sprinting = true
				updateSpeed()
				CameraController.StateChanged:Fire()
			end
		else
			if CameraController.Sprinting then
				CameraController.Sprinting = false
				updateSpeed()
				CameraController.StateChanged:Fire()
			end
			CameraController.Stamina = math.min(C.StaminaMax, CameraController.Stamina + dt * C.StaminaRegenPerSecond * (if moving then 0.6 else 1))
		end
		-- Flashlight battery
		if CameraController.Flashlight then
			CameraController.Battery = math.max(0, CameraController.Battery - dt)
			if CameraController.Battery <= 0 then
				setFlashlight(false)
			end
		else
			CameraController.Battery = math.min(F.BatterySeconds, CameraController.Battery + dt * F.RechargeIdlePerSecond)
		end
		if math.abs(CameraController.Battery - lastBattery) > 1 then
			lastBattery = CameraController.Battery
			CameraController.StateChanged:Fire()
		end
		-- Head motion: small, scaled by the camera-shake setting, off when crouched-still.
		local shake = SettingsStore.Current.cameraShake
		local speed = hum.MoveDirection.Magnitude * hum.WalkSpeed
		local rate = if CameraController.Sprinting then 11 else 7
		bobT += dt * rate * math.clamp(speed / C.WalkSpeed, 0, 1.6)
		local amp = (if CameraController.Sprinting then 0.16 else 0.07) * shake * math.clamp(speed / C.WalkSpeed, 0, 1)
		local bobY = math.sin(bobT * 2) * amp
		local bobX = math.cos(bobT) * amp * 0.6
		local crouchY = if CameraController.Crouching then -1.4 else 0
		local downY = if CameraController.Downed then -2.4 else 0
		hum.CameraOffset = Vector3.new(bobX, bobY + crouchY + downY, 0)
		-- Flashlight follows the camera.
		if spot and spot.Parent then
			(spot.Parent :: Part).CFrame = camera.CFrame * CFrame.new(0.4, -0.3, 0)
		end
	end)
end

return CameraController
