--!nonstrict
-- Shift board: create / join / ready / start shifts. In local mode the shift
-- runs on this server via RoundManager; in teleport mode players are moved
-- to a reserved mission server with validated TeleportData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoundManager = require(script.Parent.RoundManager)

export type ShiftEntry = {
	id: string,
	host: Player,
	missionId: string,
	private: boolean,
	players: { Player },
	ready: { [Player]: boolean },
	state: "open" | "starting" | "running",
	createdAt: number,
}

local MatchmakingService = {}
MatchmakingService.ShiftsChanged = Signal.new() :: Signal.Signal<{ ShiftEntry }>

local shifts: { [string]: ShiftEntry } = {}
local limiter = RateLimiter.new(6, 2)
local boardPart: BasePart? = nil

function MatchmakingService.SetBoardPart(part: BasePart)
	boardPart = part
end

local function nearBoard(player: Player): boolean
	if not boardPart then
		return true
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - boardPart.Position).Magnitude <= 24
end

local function shiftOf(player: Player): ShiftEntry?
	for _, s in shifts do
		if table.find(s.players, player) then
			return s
		end
	end
	return nil
end

local function serialize(s: ShiftEntry)
	local m = Missions.Defs[s.missionId]
	local members = {}
	for _, p in s.players do
		table.insert(members, { userId = p.UserId, name = p.DisplayName, ready = s.ready[p] == true, tool = PlayerDataService.Get(p) and (PlayerDataService.Get(p) :: any).selectedTool or "?" })
	end
	return {
		id = s.id,
		hostId = s.host.UserId,
		hostName = s.host.DisplayName,
		missionId = s.missionId,
		title = if m then m.title else s.missionId,
		kind = if m then m.kind else "",
		danger = if m then m.danger else "",
		chapter = if m then m.chapter else 0,
		private = s.private,
		players = members,
		count = #s.players,
		max = GameConfig.MaxShiftPlayers,
		state = s.state,
	}
end

function MatchmakingService.List(forPlayer: Player?)
	local out = {}
	for _, s in shifts do
		if not s.private or (forPlayer and table.find(s.players, forPlayer)) then
			table.insert(out, serialize(s))
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local function broadcast()
	local list = {}
	for _, s in shifts do
		table.insert(list, s)
	end
	MatchmakingService.ShiftsChanged:Fire(list)
	for _, p in Players:GetPlayers() do
		Net.event("ShiftListUpdated"):FireClient(p, { shifts = MatchmakingService.List(p), mine = (function()
			local s = shiftOf(p)
			return if s then s.id else nil
		end)() })
	end
end

-- A participant may join a mission at most one chapter above their own unlock.
local function canParticipate(player: Player, missionId: string): boolean
	local m = Missions.Defs[missionId]
	local p = PlayerDataService.Get(player)
	if not m or not p then
		return false
	end
	local highest = 0
	for idx in p.chaptersUnlocked do
		highest = math.max(highest, idx)
	end
	return m.chapter <= highest + 1
end

function MatchmakingService.Create(player: Player, missionId: string, private: boolean): (ShiftEntry?, string?)
	if shiftOf(player) then
		return nil, "Вы уже в смене"
	end
	if not PlayerDataService.IsMissionAvailable(player, missionId) then
		return nil, "Смена недоступна: глава не открыта"
	end
	local s: ShiftEntry = {
		id = HttpService:GenerateGUID(false):sub(1, 8),
		host = player,
		missionId = missionId,
		private = private,
		players = { player },
		ready = {},
		state = "open",
		createdAt = os.clock(),
	}
	shifts[s.id] = s
	broadcast()
	return s, nil
end

function MatchmakingService.Join(player: Player, shiftId: string): (boolean, string?)
	local s = shifts[shiftId]
	if not s then
		return false, "Смена не найдена"
	end
	if s.state ~= "open" then
		return false, "Смена уже началась"
	end
	if shiftOf(player) then
		return false, "Вы уже в смене"
	end
	if #s.players >= GameConfig.MaxShiftPlayers then
		return false, "Команда укомплектована"
	end
	if s.private then
		return false, "Приватная смена: нужен код"
	end
	if not canParticipate(player, s.missionId) then
		return false, "Недостаточный уровень допуска для этой главы"
	end
	table.insert(s.players, player)
	broadcast()
	return true, nil
end

function MatchmakingService.JoinPrivate(player: Player, code: string): (boolean, string?)
	local s = shifts[code]
	if not s or not s.private then
		return false, "Код смены не найден"
	end
	if s.state ~= "open" then
		return false, "Смена уже началась"
	end
	if shiftOf(player) then
		return false, "Вы уже в смене"
	end
	if #s.players >= GameConfig.MaxShiftPlayers then
		return false, "Команда укомплектована"
	end
	if not canParticipate(player, s.missionId) then
		return false, "Недостаточный уровень допуска"
	end
	table.insert(s.players, player)
	broadcast()
	return true, nil
end

function MatchmakingService.Leave(player: Player)
	local s = shiftOf(player)
	if not s then
		return
	end
	local i = table.find(s.players, player)
	if i then
		table.remove(s.players, i)
	end
	s.ready[player] = nil
	if #s.players == 0 then
		shifts[s.id] = nil
	elseif s.host == player then
		s.host = s.players[1]
	end
	broadcast()
end

function MatchmakingService.SetReady(player: Player, ready: boolean): boolean
	local s = shiftOf(player)
	if not s or s.state ~= "open" then
		return false
	end
	s.ready[player] = ready
	broadcast()
	return true
end

function MatchmakingService.StartShift(player: Player): (boolean, string?)
	local s = shiftOf(player)
	if not s then
		return false, "Вы не в смене"
	end
	if s.host ~= player then
		return false, "Только создатель может начать смену"
	end
	if s.state ~= "open" then
		return false, "Смена уже запускается"
	end
	if #s.players < GameConfig.MinShiftPlayers or #s.players > GameConfig.MaxShiftPlayers then
		return false, "Недопустимый размер команды"
	end
	if not Missions.Defs[s.missionId] or not PlayerDataService.IsMissionAvailable(player, s.missionId) then
		return false, "Смена недоступна"
	end
	local present = {}
	for _, p in s.players do
		if p.Parent ~= Players or not p.Character then
			return false, p.DisplayName .. " не готов (нет персонажа)"
		end
		if not PlayerDataService.Get(p) then
			return false, p.DisplayName .. ": данные ещё загружаются"
		end
		if not s.ready[p] then
			return false, p.DisplayName .. " не подтвердил готовность"
		end
		table.insert(present, p)
	end
	if RoundManager.Current() and not GameConfig.UseTeleportForShifts then
		return false, "На этом сервере уже идёт смена"
	end
	s.state = "starting"
	broadcast()
	local seed = os.time() % 1000000 + #present
	if GameConfig.UseTeleportForShifts and GameConfig.MissionPlaceId > 0 then
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(GameConfig.MissionPlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			-- Only ids and seed cross the boundary; the mission server re-validates.
			opts:SetTeleportData({ missionId = s.missionId, seed = seed, shiftId = s.id, hostId = player.UserId })
			TeleportService:TeleportAsync(GameConfig.MissionPlaceId, present, opts)
		end)
		if not ok then
			s.state = "open"
			broadcast()
			return false, "Телепорт не удался: " .. tostring(err)
		end
		shifts[s.id] = nil
		broadcast()
		return true, nil
	end
	local ok, err = RoundManager.StartShift(present, s.missionId, seed, s.id)
	if not ok then
		s.state = "open"
		broadcast()
		return false, err
	end
	s.state = "running"
	broadcast()
	return true, nil
end

function MatchmakingService.Init()
	Net.func("ShiftList").OnServerInvoke = function(player)
		return { shifts = MatchmakingService.List(player), mine = (function()
			local s = shiftOf(player)
			return if s then s.id else nil
		end)() }
	end
	Net.func("ShiftCreate").OnServerInvoke = function(player, missionId, private)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		if not Net.isString(missionId, 48) or not Net.isBool(private) then
			return Net.fail("bad args")
		end
		local s, err = MatchmakingService.Create(player, missionId, private)
		return if s then Net.ok(serialize(s)) else Net.fail(err or "error")
	end
	Net.func("ShiftJoin").OnServerInvoke = function(player, shiftId)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		if not Net.isString(shiftId, 16) then
			return Net.fail("bad args")
		end
		local ok, err = MatchmakingService.Join(player, shiftId)
		if not ok and err == "Приватная смена: нужен код" then
			ok, err = MatchmakingService.JoinPrivate(player, shiftId)
		end
		return if ok then Net.ok() else Net.fail(err or "error")
	end
	Net.func("ShiftLeave").OnServerInvoke = function(player)
		if not limiter:allow(player) then
			return Net.fail("rate")
		end
		MatchmakingService.Leave(player)
		return Net.ok()
	end
	Net.func("ShiftReady").OnServerInvoke = function(player, ready)
		if not limiter:allow(player) or not Net.isBool(ready) then
			return Net.fail("bad args")
		end
		return if MatchmakingService.SetReady(player, ready) then Net.ok() else Net.fail("Нет открытой смены")
	end
	Net.func("ShiftStart").OnServerInvoke = function(player)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		local ok, err = MatchmakingService.StartShift(player)
		return if ok then Net.ok() else Net.fail(err or "error")
	end
	Players.PlayerRemoving:Connect(MatchmakingService.Leave)
	Players.PlayerAdded:Connect(function()
		task.delay(1, broadcast)
	end)
	RoundManager.ShiftEnded:Connect(function(shift)
		local s = shifts[shift.id]
		if s then
			shifts[shift.id] = nil
		end
		broadcast()
	end)
end

function MatchmakingService.Start() end

return MatchmakingService
