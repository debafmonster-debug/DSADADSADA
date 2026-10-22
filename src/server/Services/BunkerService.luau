--!nonstrict
-- Hidden bunker under the dorm. The hatch unlocks only while participants
-- stand in two opposite corners of the room at the same time (one corner is
-- enough in a solo shift); the heavy door below is operated by its lever.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local FacilityService = require(script.Parent.FacilityService)

local B = GameConfig.Bunker

local BunkerService = {}
BunkerService.HatchOpened = Signal.new()
BunkerService.DoorChanged = Signal.new() :: Signal.Signal<boolean>
BunkerService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local map = nil
local hatchOpen = false
local hatchOpenedAt = 0
local cornersHeld = { false, false }
local deps = {
	inShift = function(_: Player)
		return false
	end,
	teamSize = function()
		return 1
	end,
}

function BunkerService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function BunkerService.IsHatchOpen(): boolean
	return hatchOpen
end

-- Pure rule used by the loop and tests.
function BunkerService.Condition(positions: { Vector3 }, corners: { Vector3 }, teamSize: number): (boolean, { boolean })
	local held = { false, false }
	for i, c in corners do
		for _, p in positions do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude <= B.CornerRadius and math.abs(p.Y - c.Y) < 6 then
				held[i] = true
			end
		end
	end
	if teamSize <= 1 then
		return held[1] or held[2], held
	end
	return held[1] and held[2], held
end

local function playAt(part: BasePart, key: string)
	local s = Builder.sound(part, Sounds[key], key)
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local function openHatch()
	if hatchOpen or not map or not map.hatch then
		return
	end
	hatchOpen = true
	hatchOpenedAt = os.clock()
	local plate = map.hatch:FindFirstChild("Plate")
	local rug = map.hatch:FindFirstChild("Rug")
	if rug then
		rug:Destroy()
	end
	if plate then
		playAt(plate, "HatchOpen")
		local open = plate.CFrame * CFrame.new(0, 0, -1.8) * CFrame.Angles(math.rad(-95), 0, 0) * CFrame.new(0, 0, 1.8)
		TweenService:Create(plate, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = open }):Play()
		task.delay(1.4, function()
			plate.CanCollide = false
		end)
	end
	map.hatch:SetAttribute("Open", true)
	BunkerService.Noise:Fire(map.point("Hatch"), "Hatch", nil)
	BunkerService.HatchOpened:Fire()
	Net.event("Notification"):FireAllClients({ title = "Механизм сработал", text = "Люк в спальном секторе открыт.", kind = "story" })
end

local function closeHatch()
	if not hatchOpen or not map or not map.hatch then
		return
	end
	hatchOpen = false
	local plate = map.hatch:FindFirstChild("Plate")
	if plate then
		local closed = CFrame.new(map.point("Hatch") + Vector3.new(0, 0.18, 0))
		TweenService:Create(plate, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = closed }):Play()
		plate.CanCollide = true
		playAt(plate, "HatchOpen")
	end
	map.hatch:SetAttribute("Open", false)
end

local function onLever(player: Player)
	if not map or not map.bunkerLever or not deps.inShift(player) then
		return
	end
	if not Net.near(player, map.bunkerLever.PrimaryPart.CFrame.Position, 8) then
		return
	end
	local door = map.doors.bunker
	local d = door and FacilityService.Door(door)
	if not d then
		return
	end
	playAt(map.bunkerLever.PrimaryPart, "Lever")
	FacilityService.SetLocked(door, false)
	if d.open then
		FacilityService.CloseDoor(door, "lever")
		FacilityService.SetLocked(door, true)
	else
		FacilityService.OpenDoor(door, "lever")
	end
	BunkerService.DoorChanged:Fire(d.open)
	local arm = map.bunkerLever.PrimaryPart
	arm.CFrame = arm.CFrame * CFrame.Angles(if d.open then -1.0 else 1.0, 0, 0)
end

function BunkerService.BeginShift(mapHandle)
	map = mapHandle
	hatchOpen = false
	cornersHeld = { false, false }
	if map.bunkerLever then
		local prompt = Builder.prompt(map.bunkerLever.PrimaryPart, "Рычаг двери", "Убежище", 1.0, Enum.KeyCode.E, 7)
		prompt:SetAttribute("UI", "Lever")
		prompt.Triggered:Connect(onLever)
	end
	-- The bunker door starts closed and locked; only the lever moves it.
	if map.doors.bunker then
		FacilityService.SetLocked(map.doors.bunker, true)
	end
end

function BunkerService.EndShift()
	map = nil
	hatchOpen = false
end

function BunkerService.Tick()
	if not map then
		return
	end
	local positions = {}
	for _, p in Players:GetPlayers() do
		if deps.inShift(p) then
			local pos = FacilityService.PlayerPosition(p)
			if pos then
				table.insert(positions, pos)
			end
		end
	end
	local ok, held = BunkerService.Condition(positions, map.corners, deps.teamSize())
	for i = 1, 2 do
		if held[i] ~= cornersHeld[i] then
			cornersHeld[i] = held[i]
			local mark = map.root:FindFirstChild("CornerMark" .. i, true)
			if mark then
				mark.Color = if held[i] then Builder.Palette.Yellow else Builder.Palette.GraphiteLight
			end
		end
	end
	if ok and not hatchOpen then
		openHatch()
	elseif hatchOpen and os.clock() - hatchOpenedAt > B.HatchOpenSeconds then
		-- Auto-close only when nobody is in the shaft.
		local blocked = false
		local hp = map.point("Hatch")
		for _, pos in positions do
			if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(hp.X, 0, hp.Z)).Magnitude < 4 and pos.Y < hp.Y + 4 and pos.Y > hp.Y - 18 then
				blocked = true
			end
		end
		if not blocked then
			closeHatch()
		end
	end
end

function BunkerService.Init() end

function BunkerService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(BunkerService.Tick)
			if not ok then
				warn("[Bunker] " .. tostring(err))
			end
		end
	end)
end

return BunkerService
