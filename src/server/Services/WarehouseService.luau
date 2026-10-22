--!nonstrict
-- Warehouse container: a four-digit code lock. The code is generated per
-- shift and written into the supply journal document. Three wrong attempts
-- lock the keypad for one station day — a real server state, not a label.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local FacilityService = require(script.Parent.FacilityService)

local W = GameConfig.Warehouse

local WarehouseService = {}
WarehouseService.Unlocked = Signal.new() :: Signal.Signal<Player>
WarehouseService.LockedOut = Signal.new() :: Signal.Signal<Player>
WarehouseService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local code = "0000"
local attempts = 0
local lockedUntilDay: number? = nil
local unlocked = false
local map = nil
local limiter = RateLimiter.new(5, 1)
local deps = {
	inShift = function(_: Player)
		return false
	end,
	stationDay = function()
		return 0
	end,
}

function WarehouseService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

function WarehouseService.Code(): string
	return code
end

function WarehouseService.IsUnlocked(): boolean
	return unlocked
end

function WarehouseService.IsLockedOut(): boolean
	return lockedUntilDay ~= nil and deps.stationDay() < lockedUntilDay
end

function WarehouseService.Attempts(): number
	return attempts
end

local function setKeypadText(text: string, color: Color3?)
	if not map or not map.keypad then
		return
	end
	local screen = map.keypad:FindFirstChild("Screen")
	local gui = screen and screen:FindFirstChildOfClass("SurfaceGui")
	local lbl = gui and gui:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.Text = text
	end
	if screen and color then
		screen.Color = color
	end
end

local function sound(key: string)
	if not map or not map.keypad then
		return
	end
	local s = Builder.sound(map.keypad.PrimaryPart, Sounds[key], key)
	s:Play()
	task.delay(2, function()
		s:Destroy()
	end)
end

-- Pure rule, also used by tests: returns accepted, state string.
function WarehouseService.Submit(_player: Player?, entered: string): (boolean, string)
	if unlocked then
		return true, "open"
	end
	if WarehouseService.IsLockedOut() then
		return false, "lockout"
	end
	if entered == code then
		unlocked = true
		attempts = 0
		return true, "accepted"
	end
	attempts += 1
	if attempts >= W.MaxAttempts then
		lockedUntilDay = deps.stationDay() + 1
		attempts = 0
		return false, "lockout"
	end
	return false, "wrong"
end

local function applyUnlock(player: Player?)
	if not map then
		return
	end
	for _, key in { "warehouseL", "warehouseR" } do
		local d = map.doors[key]
		if d then
			d:SetAttribute("KeypadLocked", false)
			FacilityService.SetLocked(d, false)
		end
	end
	setKeypadText("ОТКРЫТО", Builder.Palette.Green)
	sound("KeypadAccept")
	if player then
		WarehouseService.Unlocked:Fire(player)
	end
end

function WarehouseService.BeginShift(mapHandle, seed: number)
	map = mapHandle
	local rng = SeededRandom.new(seed + 7)
	code = ""
	for _ = 1, W.CodeLength do
		code ..= tostring(rng:nextInteger(0, 9))
	end
	attempts = 0
	lockedUntilDay = nil
	unlocked = false
	setKeypadText("- - - -", Builder.Palette.LightCold)
	if map and map.keypad then
		local prompt = Builder.prompt(map.keypad.PrimaryPart, "Ввести код", "Кодовый замок", 0, Enum.KeyCode.E, 8)
		prompt:SetAttribute("UI", "Keypad")
	end
end

function WarehouseService.EndShift()
	map = nil
	unlocked = false
end

function WarehouseService.Init()
	Net.func("KeypadSubmit").OnServerInvoke = function(player, entered)
		if not limiter:allow(player) then
			return Net.fail("Подождите")
		end
		if not deps.inShift(player) or not map or not map.keypad then
			return Net.fail("Недоступно")
		end
		if not Net.isString(entered, 8) or not string.match(entered, "^%d+$") or #entered ~= W.CodeLength then
			return Net.fail("Код: " .. W.CodeLength .. " цифры")
		end
		if not Net.near(player, map.keypad.PrimaryPart.CFrame.Position, 10) then
			return Net.fail("Подойдите к замку")
		end
		WarehouseService.Noise:Fire(map.keypad.PrimaryPart.CFrame.Position, "Keypad", player)
		local ok, state = WarehouseService.Submit(player, entered)
		if ok then
			if state == "accepted" then
				applyUnlock(player)
			end
			return Net.ok({ state = state })
		end
		if state == "lockout" then
			setKeypadText("БЛОКИРОВКА", Builder.Palette.Red)
			sound("KeypadDeny")
			WarehouseService.LockedOut:Fire(player)
			return Net.fail("Замок заблокирован до следующего дня")
		end
		setKeypadText("ОШИБКА " .. attempts .. "/" .. W.MaxAttempts, Builder.Palette.Red)
		sound("KeypadDeny")
		task.delay(2, function()
			if not unlocked and not WarehouseService.IsLockedOut() then
				setKeypadText("- - - -", Builder.Palette.LightCold)
			end
		end)
		return Net.fail(string.format("Неверный код (%d/%d)", attempts, W.MaxAttempts))
	end
end

function WarehouseService.Start() end

return WarehouseService
