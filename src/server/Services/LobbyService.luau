--!nonstrict
-- Lobby lifecycle: builds the transport base, wires board/locker anchors,
-- keeps the screens in sync with rooms, and spawns characters either in the
-- lobby or back from a shift. Also owns the per-character head flashlight
-- that teammates and the creature can see (the client renders its own beam).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Chapters = require(ReplicatedStorage.Shared.Config.Chapters)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local LobbyBuilder = require(script.Parent.Parent.Lobby.LobbyBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoomService = require(script.Parent.RoomService)
local EquipmentService = require(script.Parent.EquipmentService)
local RoundManager = require(script.Parent.RoundManager)

local LobbyService = {}

local anchors: LobbyBuilder.Anchors? = nil
local limiter = RateLimiter.new(6, 2)
local flashlightOn: { [Player]: boolean } = {}

function LobbyService.Anchors(): LobbyBuilder.Anchors?
	return anchors
end

local function refreshScreens()
	if not anchors then
		return
	end
	local rooms = RoomService.List(nil)
	local lines = { "ДОСКА СМЕН · " .. GameConfig.GameName }
	if #rooms == 0 then
		table.insert(lines, "Открытых комнат нет. Создайте свою.")
	end
	for _, r in rooms do
		table.insert(lines, string.format("%s  [%d/%d]  %s  %s", r.name, r.count, r.max, r.title, if r.state == "open" then "набор" else "в пути"))
	end
	anchors.shiftBoardScreen.Text = table.concat(lines, "\n")
	local b = { "БРИФИНГ · ГЛАВА I" }
	for _, id in Chapters.List[1].shifts do
		local def = Chapters.Shifts[id]
		table.insert(b, string.format("> %s — %s", def.title, def.kind))
	end
	table.insert(b, "")
	table.insert(b, "Регламент: сканер · крышка генератора · 22:00 · пересчёт")
	anchors.briefingScreen.Text = table.concat(b, "\n")
end

local function placeInLobby(player: Player)
	local char = player.Character
	if not char or not anchors then
		return
	end
	char:PivotTo(anchors.spawn.CFrame * CFrame.new(0, 3.5, 0))
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum.WalkSpeed = GameConfig.Character.WalkSpeed
	hum.JumpPower = 0
	hum.MaxHealth = GameConfig.Character.HealthMax
	hum.Health = hum.MaxHealth
	-- Server-visible flashlight on the head: enabled from the validated client toggle.
	local head = char:WaitForChild("Head", 10)
	if head and not head:FindFirstChild("Flashlight") then
		local spot = Instance.new("SpotLight")
		spot.Name = "Flashlight"
		spot.Angle = GameConfig.Flashlight.Angle
		spot.Range = GameConfig.Flashlight.Range * 0.8
		spot.Brightness = GameConfig.Flashlight.Brightness * 0.8
		spot.Color = Color3.fromRGB(255, 240, 215)
		spot.Face = Enum.NormalId.Front
		spot.Shadows = false
		spot.Enabled = flashlightOn[player] == true
		spot.Parent = head
	end
	if not RoundManager.InShift(player) then
		task.wait(0.1)
		placeInLobby(player)
	end
end

function LobbyService.Init()
	anchors = LobbyBuilder.build(workspace, CFrame.new(GameConfig.World.LobbyOrigin))
	RoomService.SetBoardPart(anchors.shiftBoard)
	EquipmentService.SetLockers(anchors.lockers)
	for _, s in anchors.root:GetDescendants() do
		if s:IsA("Sound") and s:GetAttribute("AutoPlay") then
			s.Looped = true
			s:Play()
		end
	end
	Net.func("TerminalQuery").OnServerInvoke = function(player, kind)
		if not limiter:allow(player) or not Net.isString(kind, 24) then
			return Net.fail("bad args")
		end
		local profile = PlayerDataService.Get(player)
		if not profile then
			return Net.fail("Данные ещё загружаются")
		end
		if kind == "shifts" then
			local out = {}
			for _, ch in Chapters.List do
				for _, id in ch.shifts do
					local def = Chapters.Shifts[id]
					table.insert(out, { id = id, title = def.title, chapterTitle = ch.title, kind = def.kind, danger = def.danger, tasks = def.tasks, available = PlayerDataService.IsMissionAvailable(player, id) })
				end
			end
			return Net.ok(out)
		elseif kind == "briefing" then
			if not Net.near(player, anchors.briefingConsole.CFrame.Position, 14) then
				return Net.fail("Подойдите к доске задач")
			end
			local out = {}
			for _, id in Chapters.List[1].shifts do
				local def = Chapters.Shifts[id]
				table.insert(out, { id = id, title = def.title, kind = def.kind, danger = def.danger, briefing = def.briefing, warnings = def.warnings, tasks = def.tasks })
			end
			return Net.ok({ shifts = out, chapters = Chapters.List })
		elseif kind == "registration" then
			if not Net.near(player, anchors.registration.CFrame.Position, 14) then
				return Net.fail("Подойдите к терминалу")
			end
			local toolDef = Tools.Defs[profile.selectedTool]
			return Net.ok({
				name = player.DisplayName,
				currency = profile.currency,
				documents = PlayerDataService.CountDocuments(profile),
				selectedTool = profile.selectedTool,
				selectedToolName = toolDef and toolDef.name or "—",
				transient = profile.transient == true,
				chapters = profile.chaptersUnlocked,
				history = profile.shiftHistory,
				stats = profile.stats,
			})
		end
		return Net.fail("unknown")
	end
	Net.event("FlashlightState").OnServerEvent:Connect(function(player, on)
		if not Net.isBool(on) then
			return
		end
		flashlightOn[player] = on
		local head = player.Character and player.Character:FindFirstChild("Head")
		local spot = head and head:FindFirstChild("Flashlight")
		if spot then
			spot.Enabled = on
		end
	end)
	RoomService.RoomsChanged:Connect(refreshScreens)
	RoundManager.ReturnToLobby:Connect(function(player)
		if player.Parent == Players then
			player:LoadCharacter()
		end
	end)
end

function LobbyService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			task.spawn(onCharacter, player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		flashlightOn[p] = nil
	end)
	refreshScreens()
	task.spawn(function()
		while true do
			task.wait(5)
			refreshScreens()
		end
	end)
end

return LobbyService
