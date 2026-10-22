--!nonstrict
-- Personal tool (one per shift, chosen in the lobby) + consumable inventory.
-- The server owns every count: pickups are world parts with prompts, uses are
-- validated here, and no client message can create or forge an item.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EquipmentService = {}
EquipmentService.ItemUsed = Signal.new() :: Signal.Signal<Player, string>
EquipmentService.Noise = Signal.new() :: Signal.Signal<Vector3, string, Player?>

local activeTool: { [Player]: string } = {}
local inventory: { [Player]: { [string]: number } } = {}
local battery: { [Player]: number } = {}
local lockers: { [string]: BasePart } = {}
local limiter = RateLimiter.new(6, 2)
local pickupFolder: Folder? = nil
local deps = {
	inShift = function(_: Player)
		return false
	end,
	warm = function(_: Player, _: number) end,
	revive = function(_: Player, _: Player?) end,
	isDowned = function(_: Player)
		return false
	end,
}

function EquipmentService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

-- ===== Tool selection (lobby) ===========================================

function EquipmentService.SetLockers(map: { [string]: BasePart })
	lockers = map
end

function EquipmentService.SelectedTool(player: Player): string
	local p = PlayerDataService.Get(player)
	return if p then p.selectedTool else Tools.Order[1]
end

function EquipmentService.ActiveTool(player: Player): string?
	return activeTool[player]
end

function EquipmentService.HasCap(player: Player, cap: string): boolean
	local id = activeTool[player]
	local def = id and Tools.Defs[id]
	return def ~= nil and (def.capabilities[cap] or 0) > 0
end

function EquipmentService.Select(player: Player, toolId: string): (boolean, string?)
	if not Tools.Defs[toolId] then
		return false, "Неизвестный инструмент"
	end
	if activeTool[player] then
		return false, "Инструмент нельзя сменить во время смены"
	end
	local locker = lockers[toolId]
	if locker and not Net.near(player, locker.CFrame.Position, 14) then
		return false, "Подойдите к шкафчику"
	end
	PlayerDataService.Update(player, function(prof)
		prof.selectedTool = toolId
	end)
	return true, nil
end

-- ===== Inventory =========================================================

function EquipmentService.Count(player: Player, itemId: string): number
	local inv = inventory[player]
	return if inv then (inv[itemId] or 0) else 0
end

function EquipmentService.Has(player: Player, itemId: string): boolean
	return EquipmentService.Count(player, itemId) > 0
end

function EquipmentService.Snapshot(player: Player)
	local items = {}
	local inv = inventory[player] or {}
	for _, id in Tools.ItemOrder do
		if (inv[id] or 0) > 0 then
			table.insert(items, { id = id, name = Tools.Items[id].name, count = inv[id] })
		end
	end
	return { tool = activeTool[player], toolName = activeTool[player] and Tools.Defs[activeTool[player]].name or nil, items = items, battery = battery[player] or 0 }
end

local function push(player: Player)
	Net.event("InventoryUpdated"):FireClient(player, EquipmentService.Snapshot(player))
end

function EquipmentService.Give(player: Player, itemId: string, count: number?): boolean
	local def = Tools.Items[itemId]
	if not def then
		return false
	end
	inventory[player] = inventory[player] or {}
	local inv = inventory[player]
	local cur = inv[itemId] or 0
	if cur >= def.stack then
		return false
	end
	inv[itemId] = math.min(def.stack, cur + (count or 1))
	push(player)
	return true
end

function EquipmentService.Consume(player: Player, itemId: string, count: number?): boolean
	local inv = inventory[player]
	local n = count or 1
	if not inv or (inv[itemId] or 0) < n then
		return false
	end
	inv[itemId] -= n
	if inv[itemId] <= 0 then
		inv[itemId] = nil
	end
	push(player)
	return true
end

-- Flashlight battery is server-owned (seconds); the client only renders it.
function EquipmentService.Battery(player: Player): number
	return battery[player] or 0
end

function EquipmentService.DrainBattery(player: Player, seconds: number): number
	if battery[player] then
		battery[player] = math.max(0, battery[player] - seconds)
	end
	return battery[player] or 0
end

-- Use an item from the HUD. Only consumables with an immediate effect.
local function use(player: Player, itemId: string, targetUserId: number?): (boolean, string)
	if not deps.inShift(player) then
		return false, "Не в смене"
	end
	if not EquipmentService.Has(player, itemId) then
		return false, "Предмета нет"
	end
	if itemId == "Battery" then
		if (battery[player] or 0) > GameConfig.Flashlight.BatterySeconds * 0.5 then
			return false, "Аккумулятор ещё заряжен"
		end
		EquipmentService.Consume(player, "Battery")
		battery[player] = GameConfig.Flashlight.BatterySeconds
		push(player)
		return true, "Аккумулятор заменён"
	elseif itemId == "Medkit" then
		local target = player
		if targetUserId then
			target = Players:GetPlayerByUserId(targetUserId) or player
			if target ~= player and not Net.near(player, (target.Character and target.Character:FindFirstChild("HumanoidRootPart") or player.Character.HumanoidRootPart).CFrame.Position, 8) then
				return false, "Слишком далеко"
			end
		end
		EquipmentService.Consume(player, "Medkit")
		deps.warm(target, 45)
		if deps.isDowned(target) then
			deps.revive(target, player)
		else
			local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
			end
		end
		return true, if target == player then "Аптечка использована" else "Вы помогли " .. target.DisplayName
	end
	return false, "Этот предмет используется на месте (генератор, щит, бак)"
end

-- ===== Pickups ============================================================

function EquipmentService.PlacePickups(mapRoot: Instance, spots: { { itemId: string, cframe: CFrame } })
	EquipmentService.ClearPickups()
	local f = Builder.folder(mapRoot, "Pickups")
	pickupFolder = f
	for _, s in spots do
		local def = Tools.Items[s.itemId]
		if not def then
			continue
		end
		local part = Props.itemPickup(f, s.cframe, s.itemId, def.name)
		local prompt = Builder.prompt(part, "Взять", def.name, 0.6, Enum.KeyCode.E, 7)
		prompt:SetAttribute("UI", "Pickup")
		prompt.Triggered:Connect(function(player)
			if not deps.inShift(player) or not part.Parent then
				return
			end
			if not Net.near(player, part.CFrame.Position, 9) then
				return
			end
			if EquipmentService.Give(player, s.itemId) then
				local snd = Builder.sound(part, Sounds.Pickup, "Pickup")
				snd:Play()
				task.delay(1, function()
					part:Destroy()
				end)
				prompt.Enabled = false
				Net.event("Notification"):FireClient(player, { title = "Взято", text = def.name, kind = "info" })
			else
				Net.event("Notification"):FireClient(player, { title = "Нет места", text = def.name .. ": больше не унести", kind = "warn" })
			end
		end)
	end
end

function EquipmentService.ClearPickups()
	if pickupFolder then
		pickupFolder:Destroy()
		pickupFolder = nil
	end
end

-- ===== Equip / unequip ====================================================

local function buildTool(def: Tools.ToolDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("ToolId", def.id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 1.4, 0.5)
	handle.Color = def.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Transparency = 1 -- the client viewmodel draws the tool; this Tool only carries state
	handle.Parent = tool
	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(0.5, 0.5, 0.3)
	accent.Color = def.accent
	accent.Material = Enum.Material.Metal
	accent.CanCollide = false
	accent.Transparency = 1
	accent.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.3)
	accent.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = accent
	w.Parent = handle
	local snd = Builder.sound(handle, Sounds[def.useSound] or Sounds.ToolBeep, "UseSound")
	snd.RollOffMaxDistance = 20
	tool.Grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	return tool
end

function EquipmentService.Equip(player: Player)
	local toolId = EquipmentService.SelectedTool(player)
	local def = Tools.Defs[toolId]
	if not def then
		return
	end
	activeTool[player] = toolId
	inventory[player] = inventory[player] or {}
	battery[player] = GameConfig.Flashlight.BatterySeconds
	player:SetAttribute("ActiveTool", toolId)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in backpack:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
		buildTool(def).Parent = backpack
	end
	push(player)
end

function EquipmentService.Unequip(player: Player)
	activeTool[player] = nil
	inventory[player] = nil
	battery[player] = nil
	player:SetAttribute("ActiveTool", nil)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in backpack:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	local char = player.Character
	if char then
		for _, t in char:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	push(player)
end

function EquipmentService.Init()
	Net.func("SelectTool").OnServerInvoke = function(player, toolId)
		if not limiter:allow(player) or not Net.isString(toolId, 32) then
			return Net.fail("bad args")
		end
		local ok, err = EquipmentService.Select(player, toolId)
		return if ok then Net.ok(toolId) else Net.fail(err or "error")
	end
	Net.func("InventoryUse").OnServerInvoke = function(player, itemId, targetUserId)
		if not limiter:allow(player) or not Net.isString(itemId, 32) then
			return Net.fail("bad args")
		end
		if targetUserId ~= nil and not Net.isInt(targetUserId, 1) then
			return Net.fail("bad target")
		end
		local ok, msg = use(player, itemId, targetUserId)
		if ok then
			EquipmentService.ItemUsed:Fire(player, itemId)
		end
		return if ok then Net.ok(msg) else Net.fail(msg)
	end
	Players.PlayerRemoving:Connect(function(p)
		activeTool[p] = nil
		inventory[p] = nil
		battery[p] = nil
	end)
end

function EquipmentService.Start()
	-- Battery drain is measured here from the server-visible flashlight state.
	task.spawn(function()
		local acc = 0
		while true do
			task.wait(1)
			acc += 1
			for p, b in battery do
				local head = p.Character and p.Character:FindFirstChild("Head")
				local spot = head and head:FindFirstChild("Flashlight")
				if spot and spot.Enabled and b > 0 then
					battery[p] = math.max(0, b - 1)
					if battery[p] == 0 or acc % 10 == 0 then
						push(p)
					end
				end
			end
		end
	end)
end

return EquipmentService
