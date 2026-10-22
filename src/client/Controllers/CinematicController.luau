--!nonstrict
-- Client cinematics: the winter-flat intro with the phone call and the
-- taxi, the boarding scene at the transport base, and the arrival fade.
-- The camera belongs to this controller while a scene runs; controls are
-- locked through CameraController and restored on every exit path.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Apartment = require(ReplicatedStorage.Shared.Scenes.Apartment)
local Airfield = require(ReplicatedStorage.Shared.Scenes.Airfield)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)
local MenuController = require(script.Parent.MenuController)
local FlashlightController = require(script.Parent.FlashlightController)
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CinematicController = {}
CinematicController.Active = nil

local fade: Frame? = nil
local sceneGui: ScreenGui? = nil
local currentSet: Instance? = nil
local skipRequested = false

local function ensureFade(): Frame
	if not fade or not fade.Parent then
		fade = Theme.fade(100)
	end
	return fade
end

local function black(seconds: number)
	local f = ensureFade()
	Theme.fadeTo(f, 0, seconds)
	task.wait(seconds)
end

local function clear(seconds: number)
	local f = ensureFade()
	Theme.fadeTo(f, 1, seconds)
	task.wait(seconds)
end

local function tweenCamera(cf: CFrame, seconds: number, style: Enum.EasingStyle?)
	local tw = TweenService:Create(camera, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cf })
	tw:Play()
	return tw
end

local function soundAt(part: BasePart, def, name: string?): Sound?
	if not def or not def.id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name or "SceneSound"
	s.SoundId = def.id
	s.Volume = def.volume
	s.Looped = def.looped == true
	s.PlaybackSpeed = def.pitch or 1
	s.RollOffMaxDistance = def.rollOff or 60
	s.Parent = part
	s:Play()
	return s
end

-- A visual stand-in of a character (own or teammate's), anchored and silent.
local function dummy(fromPlayer: Player, cf: CFrame): Model?
	local char = fromPlayer.Character
	if not char then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not clone then
		return nil
	end
	for _, inst in clone:GetDescendants() do
		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("Tool") or inst:IsA("ProximityPrompt") or inst:IsA("Light") or inst:IsA("Sound") or inst:IsA("BillboardGui") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = inst.Name == "HumanoidRootPart"
			inst.CanCollide = false
			inst.LocalTransparencyModifier = 0
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	clone.Name = "Dummy_" .. fromPlayer.Name
	clone:PivotTo(cf)
	clone.Parent = workspace
	return clone
end

local function motor(model: Model, name: string): Motor6D?
	local m = model:FindFirstChild(name, true)
	return if m and m:IsA("Motor6D") then m else nil
end

local function poseSit(model: Model)
	for _, n in { "LeftHip", "RightHip", "Left Hip", "Right Hip" } do
		local m = motor(model, n)
		if m then
			m.C0 = m.C0 * CFrame.Angles(math.rad(-85), 0, 0)
		end
	end
	for _, n in { "LeftKnee", "RightKnee" } do
		local m = motor(model, n)
		if m then
			m.C0 = m.C0 * CFrame.Angles(math.rad(80), 0, 0)
		end
	end
	local rs = motor(model, "RightShoulder") or motor(model, "Right Shoulder")
	if rs then
		rs.C0 = rs.C0 * CFrame.Angles(math.rad(-60), 0, math.rad(-10))
	end
	local re = motor(model, "RightElbow")
	if re then
		re.C0 = re.C0 * CFrame.Angles(math.rad(-70), 0, 0)
	end
end

local function poseStandPhone(model: Model)
	local rs = motor(model, "RightShoulder") or motor(model, "Right Shoulder")
	if rs then
		rs.C0 = rs.C0 * CFrame.Angles(math.rad(-120), 0, math.rad(-25))
	end
	local re = motor(model, "RightElbow")
	if re then
		re.C0 = re.C0 * CFrame.Angles(math.rad(-110), 0, 0)
	end
end

-- Walks an anchored dummy along waypoints with a simple leg swing.
local function walk(model: Model, points: { CFrame }, speed: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local lh, rh = motor(model, "LeftHip") or motor(model, "Left Hip"), motor(model, "RightHip") or motor(model, "Right Hip")
	local baseL, baseR = lh and lh.C0, rh and rh.C0
	local t = 0
	for _, target in points do
		local from = root.CFrame
		local dist = (target.Position - from.Position).Magnitude
		local dur = math.max(0.1, dist / speed)
		local look = CFrame.lookAt(from.Position, Vector3.new(target.Position.X, from.Position.Y, target.Position.Z))
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local a = (os.clock() - t0) / dur
			local pos = from.Position:Lerp(target.Position, a)
			root.CFrame = CFrame.new(pos) * (look - look.Position)
			t += RunService.Heartbeat:Wait() * 7
			if lh and baseL then
				lh.C0 = baseL * CFrame.Angles(math.sin(t) * 0.5, 0, 0)
			end
			if rh and baseR then
				rh.C0 = baseR * CFrame.Angles(-math.sin(t) * 0.5, 0, 0)
			end
		end
		root.CFrame = target
	end
	if lh and baseL then
		lh.C0 = baseL
	end
	if rh and baseR then
		rh.C0 = baseR
	end
end

local function swingDoor(door: Model, open: boolean, seconds: number)
	local leaf = door:FindFirstChild("Leaf")
	local hinge = door:FindFirstChild("Hinge")
	if not leaf or not hinge then
		return
	end
	local closed = hinge.CFrame * (door:GetAttribute("ClosedOffset") :: CFrame)
	local target = if open then hinge.CFrame * CFrame.Angles(0, math.rad(-100), 0) * (door:GetAttribute("ClosedOffset") :: CFrame) else closed
	TweenService:Create(leaf, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
end

local function cleanupSet()
	if currentSet then
		currentSet:Destroy()
		currentSet = nil
	end
	for _, inst in workspace:GetChildren() do
		if inst.Name:sub(1, 6) == "Dummy_" then
			inst:Destroy()
		end
	end
	if sceneGui then
		sceneGui:Destroy()
		sceneGui = nil
	end
end

-- ===== Intro ================================================================

local function choiceButtons(): boolean
	sceneGui = Theme.screen("V9_Cinematic", 90)
	local panel = Theme.frame(sceneGui, { Position = UDim2.new(0.5, 0, 1, -80), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 460, 0, 50), BackgroundTransparency = 1 })
	Theme.list(panel, 12, true)
	local result = nil
	Theme.button(panel, "ПРИНЯТЬ РАБОТУ", function()
		result = true
	end, { Size = UDim2.new(0, 220, 1, 0), TextColor3 = Theme.Colors.Accent })
	Theme.button(panel, "ОТКАЗАТЬСЯ", function()
		result = false
	end, { Size = UDim2.new(0, 220, 1, 0), TextColor3 = Theme.Colors.TextDim })
	while result == nil do
		task.wait(0.1)
	end
	panel:Destroy()
	return result
end

local function skipButton(label: string)
	if not sceneGui then
		sceneGui = Theme.screen("V9_Cinematic", 90)
	end
	skipRequested = false
	local b = Theme.button(sceneGui, label, function()
		skipRequested = true
	end, { Position = UDim2.new(1, -16, 0, 16 + Theme.safeTop()), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 200, 0, 32), TextSize = 13, BackgroundTransparency = 0.4 })
	return b
end

local function wait(seconds: number)
	local t0 = os.clock()
	while os.clock() - t0 < seconds and not skipRequested do
		task.wait(0.05)
	end
end

local function playIntro(payload)
	CinematicController.Active = "Intro"
	CameraController.SetCinematic(true)
	FlashlightController.ForceOff()
	local f = ensureFade()
	f.BackgroundTransparency = 0
	local set = Apartment.build(workspace, GameConfig.World.ApartmentOrigin)
	currentSet = set.root
	local me = dummy(player, set.sofaSeat)
	if me then
		poseSit(me)
	end
	local tvSound = soundAt(set.tvScreen, Sounds.TVStatic, "TV")
	soundAt(set.lampWarm, Sounds.Wind, "WindFar")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = set.cameraRoom
	local skip = if payload.skippable then skipButton("ПРОПУСТИТЬ ВСТУПЛЕНИЕ") else nil
	clear(2.2)
	tweenCamera(set.cameraRoom * CFrame.new(0.8, -0.2, -1.2), 9)
	HUDController.Subtitle("Зимний вечер. Телевизор что-то бормочет; чай ещё горячий.", 5)
	wait(6.5)
	-- The phone.
	local phoneSound
	if not skipRequested then
		local phonePart = set.root:FindFirstChild("Phone", true)
		for i = 1, 3 do
			if skipRequested then
				break
			end
			phoneSound = phonePart and soundAt(phonePart, Sounds.PhoneRing, "Ring")
			if i == 1 then
				tweenCamera(set.cameraPhone, 2.4)
			end
			wait(1.6)
		end
	end
	if me and not skipRequested then
		-- Stand up and step to the side table.
		for _, n in { "LeftHip", "RightHip", "Left Hip", "Right Hip", "LeftKnee", "RightKnee", "RightShoulder", "Right Shoulder", "RightElbow" } do
			local m = motor(me, n)
			if m then
				m.C0 = m.C0 -- keep; replaced by walk + phone pose below
			end
		end
		me:Destroy()
		me = dummy(player, set.sofaSeat * CFrame.new(0, 0.6, 1))
		if me then
			walk(me, { set.phone * CFrame.new(1.6, 3, 0) }, 6)
			poseStandPhone(me)
		end
	end
	if phoneSound then
		phoneSound:Stop()
	end
	if not skipRequested then
		HUDController.Lines(payload.lines or {})
		local total = 1
		for _, l in payload.lines or {} do
			total += l.seconds + (l.pauseAfter or 0)
		end
		wait(total)
	end
	if tvSound then
		tvSound.Volume = 0.05
	end
	local accept = true
	if not skipRequested then
		accept = choiceButtons()
	end
	if skip then
		skip:Destroy()
	end
	pcall(function()
		Net.func("IntroChoice"):InvokeServer(accept)
	end)
	if not accept then
		HUDController.Subtitle("Вы кладёте трубку.", 3)
		black(2)
		return -- the server kicks with a message
	end
	if not skipRequested then
		-- Coat, boots, door, street, taxi.
		HUDController.Subtitle("Вы кладёте трубку и начинаете собираться.", 3)
		tweenCamera(set.cameraDoor, 3)
		if me then
			walk(me, { set.doorInside * CFrame.new(0, 3, 0) }, 6)
		end
		swingDoor(set.door, true, 1.4)
		soundAt(set.door.PrimaryPart, Sounds.DoorSwing)
		wait(1.2)
		tweenCamera(set.cameraStreet, 2.5)
		local engine = soundAt(set.taxi.PrimaryPart, Sounds.CarEngine, "Engine")
		if me then
			walk(me, { set.doorOutside * CFrame.new(0, 3, 0), set.taxiExit * CFrame.new(0, 3, 0) }, 6)
			me:Destroy()
			me = nil
		end
		soundAt(set.taxi.PrimaryPart, Sounds.DoorSwing)
		wait(1.5)
		-- Camera stays on the door; the taxi pulls away out of frame.
		local start = set.taxi:GetPivot()
		local t0 = os.clock()
		while os.clock() - t0 < 6 and not skipRequested do
			local a = (os.clock() - t0) / 6
			set.taxi:PivotTo(start * CFrame.new(0, 0, 0) * CFrame.new(-a * a * 120, 0, 0))
			if engine then
				engine.Volume = 0.5 * (1 - a)
			end
			RunService.Heartbeat:Wait()
		end
		HUDController.Subtitle("Такси уезжает. Снег закрывает следы.", 4)
		wait(2)
	end
	black(2.5)
	cleanupSet()
	CameraController.SetCinematic(false)
	Net.event("CinematicDone"):FireServer("Intro")
	clear(2)
	CinematicController.Active = nil
	MenuController.Open()
end

-- ===== Boarding =============================================================

local function playBoarding(payload)
	CinematicController.Active = "Boarding"
	CameraController.SetCinematic(true)
	FlashlightController.ForceOff()
	black(0.8)
	local set = Airfield.build(workspace, GameConfig.World.AirfieldOrigin)
	currentSet = set.root
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = set.cameraStart
	AudioController.Weather = { wind = 0.6, snow = 0.5, state = "LightSnow" }
	local engine = soundAt(set.plane.PrimaryPart, Sounds.PlaneEngine, "Engine")
	if engine then
		engine.Volume = 0.25
	end
	clear(1.6)
	local hutDoor = set.root:FindFirstChild("AirlockHut"):FindFirstChildOfClass("Model")
	if hutDoor then
		swingDoor(hutDoor, true, 1.6)
		soundAt(hutDoor.PrimaryPart, Sounds.DoorHeavy)
	end
	HUDController.Subtitle("Шлюз открывается. Ветер.", 3)
	task.wait(1.4)
	-- Teammates walk out one by one towards the plane stairs.
	local dummies = {}
	for i, uid in payload.players or {} do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			local d = dummy(p, set.airlock * CFrame.new(-1 + (i % 2) * 2, 3, 2) * CFrame.Angles(0, math.pi, 0))
			if d then
				table.insert(dummies, d)
			end
		end
	end
	tweenCamera(set.cameraStart * CFrame.new(-6, 1, -6), 10)
	for i, d in dummies do
		task.spawn(function()
			task.wait((i - 1) * 1.6)
			walk(d, { set.airlock * CFrame.new(0, 3, -14), set.stairs * CFrame.new(0, 3, 0) }, 7)
			d:Destroy()
		end)
	end
	task.wait(3.5)
	tweenCamera(set.cameraPlane, 4.5)
	local total = math.max(12, #dummies * 1.6 + 7)
	task.wait(total - 5)
	HUDController.Subtitle("Дверь закрыта. Двигатели набирают обороты.", 3)
	local door = set.plane:FindFirstChild("Door")
	if door then
		TweenService:Create(door, TweenInfo.new(1.4), { CFrame = door:GetAttribute("ClosedCFrame") }):Play()
	end
	if engine then
		TweenService:Create(engine, TweenInfo.new(4), { Volume = 0.9, PlaybackSpeed = 0.7 }):Play()
	end
	task.wait(3)
	-- Takeoff run and lift.
	local start = set.plane:GetPivot()
	local t0 = os.clock()
	local runSeconds = 7
	while os.clock() - t0 < runSeconds do
		local a = (os.clock() - t0) / runSeconds
		set.plane:PivotTo(start * CFrame.new(0, a * a * 26, -a * a * 180) * CFrame.Angles(-a * 0.18, 0, 0))
		RunService.Heartbeat:Wait()
	end
	black(1.6)
	cleanupSet()
	if engine then
		engine:Destroy()
	end
	-- Hold black until the server says we have arrived (Cinematic "Arrive").
	CinematicController.Active = "BoardingHold"
	Net.event("CinematicDone"):FireServer("Boarding")
end

local function playArrive()
	-- Camera returns to the character; the server has already placed us at the apron.
	task.wait(0.3)
	CameraController.SetCinematic(false)
	CinematicController.Active = nil
	HUDController.Subtitle("Полярная ночь. Ветер. Огни станции впереди.", 5)
	clear(3)
end

function CinematicController.init()
	Net.event("Cinematic").OnClientEvent:Connect(function(payload)
		if not payload or not payload.kind then
			return
		end
		if payload.kind == "Intro" then
			task.spawn(function()
				local ok, err = pcall(playIntro, payload)
				if not ok then
					warn("[Cinematic] intro: " .. tostring(err))
					cleanupSet()
					CameraController.SetCinematic(false)
					clear(1)
					MenuController.Open()
				end
			end)
		elseif payload.kind == "Boarding" then
			task.spawn(function()
				local ok, err = pcall(playBoarding, payload)
				if not ok then
					warn("[Cinematic] boarding: " .. tostring(err))
					cleanupSet()
				end
			end)
		elseif payload.kind == "Arrive" then
			task.spawn(playArrive)
		end
	end)
	-- Safety: if a shift ends while a scene is mid-way, restore control.
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase == "Idle" and CinematicController.Active == "BoardingHold" then
			cleanupSet()
			CameraController.SetCinematic(false)
			CinematicController.Active = nil
			clear(1)
		end
	end)
end

return CinematicController
