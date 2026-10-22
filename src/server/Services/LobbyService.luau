--!nonstrict
-- Lobby: builds the location, keeps physical screens in sync, answers
-- registration/briefing terminal queries and returns players after shifts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local LobbyBuilder = require(script.Parent.Parent.Lobby.LobbyBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local EquipmentService = require(script.Parent.EquipmentService)
local RoundManager = require(script.Parent.RoundManager)

local LobbyService = {}

local anchors: LobbyBuilder.Anchors? = nil
local limiter = RateLimiter.new(5, 1)

local function isNear(player: Player, part: BasePart?, dist: number): boolean
	if not part then
		return true
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= dist
end

local function availableMissions(player: Player)
	local out = {}
	local p = PlayerDataService.Get(player)
	for _, ch in Missions.Chapters do
		for _, mid in ch.missions do
			local m = Missions.Defs[mid]
			table.insert(out, {
				id = mid,
				title = m.title,
				kind = m.kind,
				danger = m.danger,
				chapter = m.chapter,
				chapterTitle = ch.title,
				available = p ~= nil and p.chaptersUnlocked[m.chapter] == true,
				mainTask = m.mainTask.label,
				optionalTask = if m.optionalTask then m.optionalTask.label else nil,
				briefing = m.briefing,
				warnings = m.warnings,
				evacuation = m.evacuation,
			})
		end
	end
	return out
end

local function updateBoard()
	local a = anchors
	if not a then
		return
	end
	local list = MatchmakingService.List(nil)
	local lines = { "ДОСКА СМЕН · COMPLEX-17", string.rep("─", 34) }
	if #list == 0 then
		table.insert(lines, "Открытых смен нет.")
		table.insert(lines, "Создайте смену на консоли.")
	else
		for _, s in list do
			table.insert(lines, string.format("%s  [%d/%d]  %s", s.title, s.count, s.max, if s.state == "open" then "НАБОР" elseif s.state == "starting" then "ЗАПУСК" else "В РАБОТЕ"))
			table.insert(lines, string.format("   %s · опасность: %s", s.kind, s.danger))
		end
	end
	local running = RoundManager.Current()
	if running then
		table.insert(lines, "")
		table.insert(lines, string.format("ТЕКУЩАЯ СМЕНА: %s · фаза %s", running.mission.title, running.phase))
	end
	a.shiftBoardScreen.Text = table.concat(lines, "\n")
	local team = { "КОМАНДА" }
	for _, s in list do
		for _, m in s.players do
			table.insert(team, string.format("%s %s", if m.ready then "■" else "□", m.name))
		end
	end
	if #team == 1 then
		table.insert(team, "—")
	end
	a.readyBoard.Text = table.concat(team, "\n")
end

local function updateBriefingScreen()
	local a = anchors
	if not a then
		return
	end
	local list = MatchmakingService.List(nil)
	local s = list[1]
	if not s then
		a.briefingScreen.Text = "БРИФИНГ\n\nВыберите смену на доске смен, чтобы получить задание."
		return
	end
	local m = Missions.Defs[s.missionId]
	local lines = { "БРИФИНГ · " .. m.title, "" }
	for _, b in m.briefing do
		table.insert(lines, "• " .. b)
	end
	table.insert(lines, "")
	table.insert(lines, "ПРЕДУПРЕЖДЕНИЯ:")
	for _, w in m.warnings do
		table.insert(lines, "! " .. w)
	end
	table.insert(lines, "")
	table.insert(lines, "Эвакуация: " .. m.evacuation)
	a.briefingScreen.Text = table.concat(lines, "\n")
end

function LobbyService.Anchors(): LobbyBuilder.Anchors?
	return anchors
end

function LobbyService.SpawnInLobby(player: Player)
	local a = anchors
	local char = player.Character
	if a and char then
		char:PivotTo(a.spawn.CFrame * CFrame.new(0, 3.5, 0))
	end
end

function LobbyService.Init()
	anchors = LobbyBuilder.build(workspace, CFrame.new(GameConfig.Grid.LobbyOrigin))
	local a = anchors :: LobbyBuilder.Anchors
	MatchmakingService.SetBoardPart(a.shiftBoard)
	EquipmentService.SetLockers(a.lockers)
	-- Lobby sounds flagged AutoPlay
	for _, d in a.root:GetDescendants() do
		if d:IsA("Sound") and d:GetAttribute("AutoPlay") then
			d:Play()
		end
	end

	Net.func("TerminalQuery").OnServerInvoke = function(player, kind)
		if not limiter:allow(player) or not Net.isString(kind, 24) then
			return Net.fail("rate")
		end
		if kind == "registration" then
			if not isNear(player, a.registration, 16) then
				return Net.fail("Подойдите к терминалу")
			end
			local p = PlayerDataService.Get(player)
			if not p then
				return Net.fail("Данные загружаются")
			end
			local highest = 1
			for idx in p.chaptersUnlocked do
				highest = math.max(highest, idx)
			end
			local history = {}
			for _, h in p.shiftHistory do
				local m = Missions.Defs[h.missionId]
				table.insert(history, { title = if m then m.title else h.missionId, success = h.success, reward = h.reward, time = h.time })
			end
			local next_ = nil
			for _, m in availableMissions(player) do
				if m.available then
					next_ = m
				end
			end
			return Net.ok({
				name = player.DisplayName,
				accessLevel = string.format("%02d", highest),
				currency = p.currency,
				stats = p.stats,
				documents = PlayerDataService.CountDocuments(p),
				selectedTool = Tools.Defs[p.selectedTool].name,
				chapters = (function()
					local out = {}
					for _, ch in Missions.Chapters do
						table.insert(out, { index = ch.index, title = ch.title, unlocked = p.chaptersUnlocked[ch.index] == true, available = #ch.missions > 0 })
					end
					return out
				end)(),
				nextShift = next_,
				history = history,
				transient = p.transient == true,
			})
		elseif kind == "missions" then
			if not isNear(player, a.shiftBoard, 24) then
				return Net.fail("Подойдите к доске смен")
			end
			return Net.ok(availableMissions(player))
		elseif kind == "briefing" then
			if not isNear(player, a.briefingConsole, 20) then
				return Net.fail("Подойдите к пульту брифинга")
			end
			local mine = nil
			for _, s in MatchmakingService.List(player) do
				for _, m in s.players do
					if m.userId == player.UserId then
						mine = s
					end
				end
			end
			local missionId = if mine then mine.missionId else nil
			local m = missionId and Missions.Defs[missionId]
			if not m then
				return Net.ok(nil)
			end
			return Net.ok({
				title = m.title,
				kind = m.kind,
				danger = m.danger,
				briefing = m.briefing,
				warnings = m.warnings,
				mainTask = m.mainTask.label,
				optionalTask = if m.optionalTask then m.optionalTask.label else nil,
				evacuation = m.evacuation,
				tools = (function()
					local out = {}
					for _, id in Tools.Order do
						table.insert(out, Tools.Defs[id].name)
					end
					return out
				end)(),
			})
		end
		return Net.fail("unknown query")
	end

	MatchmakingService.ShiftsChanged:Connect(function()
		updateBoard()
		updateBriefingScreen()
	end)
	RoundManager.ShiftEnded:Connect(updateBoard)
	RoundManager.ReturnToLobby:Connect(function(player)
		-- Fresh character back in the lobby after a shift.
		task.defer(function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
	updateBoard()
end

function LobbyService.Start()
	local function onCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.WalkSpeed = GameConfig.Character.WalkSpeed
			hum.JumpPower = 0
			hum.UseJumpPower = true
			hum.MaxHealth = GameConfig.Character.HealthMax
			hum.Health = GameConfig.Character.HealthMax
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
		end
		local head = char:FindFirstChild("Head") :: BasePart?
		if head and not head:FindFirstChild("Flashlight") then
			local light = Instance.new("SpotLight")
			light.Name = "Flashlight"
			light.Angle = GameConfig.Flashlight.Angle
			light.Range = GameConfig.Flashlight.Range
			light.Brightness = GameConfig.Flashlight.Brightness
			light.Color = Color3.fromRGB(255, 244, 220)
			light.Face = Enum.NormalId.Front
			light.Enabled = false
			light.Parent = head
		end
		if not RoundManager.InShift(player) then
			task.wait(0.1)
			LobbyService.SpawnInLobby(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(function(char)
			onCharacter(p, char)
		end)
		if p.Character then
			task.spawn(onCharacter, p, p.Character)
		end
	end
	task.spawn(function()
		while true do
			task.wait(5)
			updateBoard()
		end
	end)
end

return LobbyService
