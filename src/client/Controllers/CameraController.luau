--!nonstrict
-- First-person camera, movement (sprint/crouch/stamina) and procedural head
-- motion. Input locking is reference-counted so overlapping UIs never leave
-- the player stuck. The flashlight lives in FlashlightController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local SettingsStore = require(script.Parent.SettingsStore)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}
CameraController.StateChanged = Signal.new()
CameraController.Stamina = GameConfig.Character.StaminaMax
CameraController.Sprinting = false
CameraController.Crouching = false
CameraController.Downed = false
CameraController.InputLocked = false
CameraController.Shiver = 0 -- set by TemperatureFX (0..1)
CameraController.SpeedMult = 1 -- set by TemperatureFX when cold
CameraController.CinematicActive = false

local locks: { [string]: boolean } = {}
local sprintHeld = false
local bobT = 0

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function CameraController.Lock(key: string)
	locks[key] = true
	CameraController.InputLocked = true
end

function CameraController.Unlock(key: string)
	locks[key] = nil
	CameraController.InputLocked = next(locks) ~= nil
end

local function applySensitivity()
	UserInputService.MouseDeltaSensitivity = 0.4 + SettingsStore.Current.sensitivity * 1.6
end

local function updateSpeed()
	local hum = humanoid()
	if not hum or CameraController.Downed or CameraController.CinematicActive then
		return
	end
	local C = GameConfig.Character
	local base = if CameraController.Sprinting then C.SprintSpeed elseif CameraController.Crouching then C.CrouchSpeed else C.WalkSpeed
	hum.WalkSpeed = base * CameraController.SpeedMult
end
CameraController.UpdateSpeed = updateSpeed

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	camera.FieldOfView = 74
	CameraController.Sprinting = false
	CameraController.Crouching = false
	CameraController.Downed = false
	CameraController.Stamina = GameConfig.Character.StaminaMax
	updateSpeed()
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
	else
		updateSpeed()
	end
end

-- Cinematics take the camera: controls off, character frozen in place.
function CameraController.SetCinematic(on: boolean)
	CameraController.CinematicActive = on
	local hum = humanoid()
	if on then
		CameraController.Lock("cinematic")
		if hum then
			hum.WalkSpeed = 0
		end
		camera.CameraType = Enum.CameraType.Scriptable
	else
		CameraController.Unlock("cinematic")
		camera.CameraType = Enum.CameraType.Custom
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		updateSpeed()
	end
end

function CameraController.init()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	applySensitivity()
	SettingsStore.Changed:Connect(applySensitivity)

	ContextActionService:BindAction("V9_Sprint", handleSprint, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("V9_Crouch", handleCrouch, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)

	local C = GameConfig.Character
	RunService.RenderStepped:Connect(function(dt)
		local hum = humanoid()
		if not hum or CameraController.CinematicActive then
			return
		end
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
		-- Head motion: walk bob + cold shiver, both scaled by the camera-shake setting.
		local shake = SettingsStore.Current.cameraShake
		local speed = hum.MoveDirection.Magnitude * hum.WalkSpeed
		local rate = if CameraController.Sprinting then 11 else 7
		bobT += dt * rate * math.clamp(speed / C.WalkSpeed, 0, 1.6)
		local amp = (if CameraController.Sprinting then 0.16 else 0.07) * shake * math.clamp(speed / C.WalkSpeed, 0, 1)
		local bobY = math.sin(bobT * 2) * amp
		local bobX = math.cos(bobT) * amp * 0.6
		local t = os.clock()
		local shiver = CameraController.Shiver * shake * 0.06
		local shX = (math.sin(t * 37) + math.sin(t * 23)) * shiver
		local shY = math.sin(t * 41) * shiver
		local crouchY = if CameraController.Crouching then -1.4 else 0
		local downY = if CameraController.Downed then -2.4 else 0
		hum.CameraOffset = Vector3.new(bobX + shX, bobY + shY + crouchY + downY, 0)
	end)
end

return CameraController
