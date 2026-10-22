--!nonstrict
-- Tool selection in the lobby and tool hand-out during a shift.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EquipmentService = {}

local lockers: { [string]: BasePart } = {}
local activeTool: { [Player]: string } = {}
local limiter = RateLimiter.new(4, 1)

function EquipmentService.SetLockers(map: { [string]: BasePart })
	lockers = map
	for id, part in map do
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				EquipmentService.Select(player, id)
			end)
		end
	end
end

function EquipmentService.Select(player: Player, toolId: string): boolean
	if not limiter:allow(player) then
		return false
	end
	if not Tools.Defs[toolId] then
		return false
	end
	local locker = lockers[toolId]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if locker and (not hrp or (hrp.Position - locker.Position).Magnitude > 14) then
		return false
	end
	if activeTool[player] then
		return false -- cannot swap during a shift
	end
	PlayerDataService.Update(player, function(prof)
		prof.selectedTool = toolId
	end)
	Net.event("Notification"):FireClient(player, { title = "Инструмент выбран", text = Tools.Defs[toolId].name, kind = "good" })
	return true
end

function EquipmentService.SelectedTool(player: Player): string
	local p = PlayerDataService.Get(player)
	return if p then p.selectedTool else "Multimeter"
end

function EquipmentService.ActiveTool(player: Player): string?
	return activeTool[player]
end

local function buildTool(toolId: string): Tool
	local def = Tools.Defs[toolId]
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = def.name
	tool:SetAttribute("ToolId", toolId)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 0.5, 1.6)
	handle.Color = def.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(0.5, 0.2, 0.6)
	accent.Color = def.accent
	accent.Material = Enum.Material.Metal
	accent.CanCollide = false
	accent.Massless = true
	accent.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = accent
	weld.C0 = CFrame.new(0, 0.3, -0.3)
	weld.Parent = accent
	local screen = Instance.new("Part")
	screen.Name = "Screen"
	screen.Size = Vector3.new(0.6, 0.05, 0.5)
	screen.Color = Color3.fromRGB(120, 200, 160)
	screen.Material = Enum.Material.Neon
	screen.CanCollide = false
	screen.Massless = true
	screen.Parent = tool
	local weld2 = Instance.new("Weld")
	weld2.Part0 = handle
	weld2.Part1 = screen
	weld2.C0 = CFrame.new(0, 0.28, 0.4)
	weld2.Parent = screen
	local light = Instance.new("PointLight")
	light.Range = 3
	light.Brightness = 0.3
	light.Color = screen.Color
	light.Parent = screen
	Builder.sound(handle, Sounds[def.useSound] or Sounds.ToolBeep, "UseSound")
	tool.Grip = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(-0.3, 0, 0)
	return tool
end

function EquipmentService.Equip(player: Player)
	local toolId = EquipmentService.SelectedTool(player)
	activeTool[player] = toolId
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
		buildTool(toolId).Parent = backpack
	end
	player:SetAttribute("ActiveTool", toolId)
end

function EquipmentService.Unequip(player: Player)
	activeTool[player] = nil
	player:SetAttribute("ActiveTool", nil)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end
	local char = player.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			tool:Destroy()
		end
	end
end

function EquipmentService.Init()
	Net.func("SelectTool").OnServerInvoke = function(player, toolId)
		if not Net.isString(toolId, 32) then
			return Net.fail("bad tool")
		end
		return if EquipmentService.Select(player, toolId) then Net.ok(toolId) else Net.fail("Нельзя выбрать инструмент сейчас")
	end
	Players.PlayerRemoving:Connect(function(p)
		activeTool[p] = nil
	end)
end

function EquipmentService.Start() end

return EquipmentService
