--!nonstrict
-- Rooms (lobbies): create / find / join by code / ready / start. In local
-- mode the shift runs on this server through RoundManager. Cross-server mode
-- (TeleportService + MemoryStore listing) is wired behind GameConfig flags and
-- stays off until a mission place is published.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Chapters = require(ReplicatedStorage.Shared.Config.Chapters)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoundManager = require(script.Parent.RoundManager)

export type Room = {
	id: string,
	code: string,
	name: string,
	host: Player,
	shiftId: string,
	maxPlayers: number,
	private: boolean,
	players: { Player },
	ready: { [Player]: boolean },
	state: "open" | "starting" | "running",
	createdAt: number,
}

local RoomService = {}
RoomService.RoomsChanged = Signal.new() :: Signal.Signal<{ Room }>

local rooms: { [string]: Room } = {}
local limiter = RateLimiter.new(6, 2)
local boardPart: BasePart? = nil
local memoryStore = nil

function RoomService.SetBoardPart(part: BasePart)
	boardPart = part
end

local function nearBoard(player: Player): boolean
	if not boardPart then
		return true
	end
	return Net.near(player, boardPart.CFrame.Position, 26)
end

local function roomOf(player: Player): Room?
	for _, r in rooms do
		if table.find(r.players, player) then
			return r
		end
	end
	return nil
end

local function sanitizeName(raw: string): string
	local s = string.gsub(raw, "[%c]", "")
	s = string.sub(s, 1, 24)
	if #s < 2 then
		s = "Смена"
	end
	return s
end

local function serialize(r: Room, forPlayer: Player?)
	local def = Chapters.Shifts[r.shiftId]
	local members = {}
	for _, p in r.players do
		local prof = PlayerDataService.Get(p)
		table.insert(members, { userId = p.UserId, name = p.DisplayName, ready = r.ready[p] == true, tool = prof and prof.selectedTool or "?" })
	end
	local mine = forPlayer ~= nil and table.find(r.players, forPlayer) ~= nil
	return {
		id = r.id,
		code = if mine then r.code else nil,
		name = r.name,
		hostId = r.host.UserId,
		hostName = r.host.DisplayName,
		shiftId = r.shiftId,
		title = if def then def.title else r.shiftId,
		kind = if def then def.kind else "",
		danger = if def then def.danger else "",
		chapter = if def then def.chapter else 0,
		private = r.private,
		players = members,
		count = #r.players,
		max = r.maxPlayers,
		state = r.state,
	}
end

function RoomService.List(forPlayer: Player?)
	local out = {}
	for _, r in rooms do
		if not r.private or (forPlayer and table.find(r.players, forPlayer)) then
			table.insert(out, serialize(r, forPlayer))
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local function payloadFor(p: Player)
	local r = roomOf(p)
	return { rooms = RoomService.List(p), mine = if r then r.id else nil }
end

local function broadcast()
	local list = {}
	for _, r in rooms do
		table.insert(list, r)
	end
	RoomService.RoomsChanged:Fire(list)
	for _, p in Players:GetPlayers() do
		Net.event("RoomListUpdated"):FireClient(p, payloadFor(p))
	end
end

-- Chapter gating: a guest may join one chapter above their own unlock.
local function canParticipate(player: Player, shiftId: string): boolean
	local def = Chapters.Shifts[shiftId]
	local p = PlayerDataService.Get(player)
	if not def or not p then
		return false
	end
	local highest = 0
	for idx in p.chaptersUnlocked do
		highest = math.max(highest, idx)
	end
	return def.chapter <= highest + 1
end

local function newCode(): string
	local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local code = ""
	for _ = 1, 6 do
		local i = math.random(1, #alphabet)
		code ..= string.sub(alphabet, i, i)
	end
	return code
end

function RoomService.Create(player: Player, name: string, maxPlayers: number, private: boolean, shiftId: string): (Room?, string?)
	if roomOf(player) then
		return nil, "Вы уже в комнате"
	end
	if not PlayerDataService.IsMissionAvailable(player, shiftId) then
		return nil, "Смена недоступна: глава не открыта"
	end
	local r: Room = {
		id = HttpService:GenerateGUID(false):sub(1, 8),
		code = newCode(),
		name = sanitizeName(name),
		host = player,
		shiftId = shiftId,
		maxPlayers = math.clamp(maxPlayers, GameConfig.MinShiftPlayers, GameConfig.MaxShiftPlayers),
		private = private,
		players = { player },
		ready = {},
		state = "open",
		createdAt = os.clock(),
	}
	rooms[r.id] = r
	broadcast()
	RoomService.Publish(r)
	return r, nil
end

function RoomService.Join(player: Player, idOrCode: string): (boolean, string?)
	local r = rooms[idOrCode]
	if not r then
		for _, rr in rooms do
			if rr.code == string.upper(idOrCode) then
				r = rr
				break
			end
		end
	end
	if not r then
		return false, "Комната не найдена"
	end
	if r.state ~= "open" then
		return false, "Смена уже началась"
	end
	if roomOf(player) then
		return false, "Вы уже в комнате"
	end
	if #r.players >= r.maxPlayers then
		return false, "Команда укомплектована"
	end
	if r.private and r.code ~= string.upper(idOrCode) then
		return false, "Приватная комната: нужен код"
	end
	if not canParticipate(player, r.shiftId) then
		return false, "Недостаточный уровень допуска для этой главы"
	end
	table.insert(r.players, player)
	broadcast()
	RoomService.Publish(r)
	return true, nil
end

function RoomService.Leave(player: Player)
	local r = roomOf(player)
	if not r then
		return
	end
	local i = table.find(r.players, player)
	if i then
		table.remove(r.players, i)
	end
	r.ready[player] = nil
	if #r.players == 0 then
		rooms[r.id] = nil
		RoomService.Unpublish(r)
	else
		if r.host == player then
			r.host = r.players[1]
		end
		RoomService.Publish(r)
	end
	broadcast()
end

function RoomService.SetReady(player: Player, ready: boolean): boolean
	local r = roomOf(player)
	if not r or r.state ~= "open" then
		return false
	end
	r.ready[player] = ready
	broadcast()
	return true
end

function RoomService.StartShift(player: Player): (boolean, string?)
	local r = roomOf(player)
	if not r then
		return false, "Вы не в комнате"
	end
	if r.host ~= player then
		return false, "Только создатель может начать смену"
	end
	if r.state ~= "open" then
		return false, "Смена уже запускается"
	end
	if #r.players < GameConfig.MinShiftPlayers or #r.players > r.maxPlayers then
		return false, "Недопустимый размер команды"
	end
	if not Chapters.Shifts[r.shiftId] or not PlayerDataService.IsMissionAvailable(player, r.shiftId) then
		return false, "Смена недоступна"
	end
	local present = {}
	for _, p in r.players do
		if p.Parent ~= Players or not p.Character then
			return false, p.DisplayName .. " не готов (нет персонажа)"
		end
		if not PlayerDataService.Get(p) then
			return false, p.DisplayName .. ": данные ещё загружаются"
		end
		if not r.ready[p] then
			return false, p.DisplayName .. " не подтвердил готовность"
		end
		table.insert(present, p)
	end
	if RoundManager.Current() and not GameConfig.UseTeleportForShifts then
		return false, "На этом сервере уже идёт смена"
	end
	r.state = "starting"
	broadcast()
	local seed = os.time() % 1000000 + #present
	if GameConfig.UseTeleportForShifts and GameConfig.MissionPlaceId > 0 then
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(GameConfig.MissionPlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			-- Only ids and the seed cross the boundary; the mission server re-validates.
			opts:SetTeleportData({ shiftId = r.shiftId, seed = seed, roomId = r.id, hostId = player.UserId })
			TeleportService:TeleportAsync(GameConfig.MissionPlaceId, present, opts)
		end)
		if not ok then
			r.state = "open"
			broadcast()
			return false, "Телепорт не удался: " .. tostring(err)
		end
		rooms[r.id] = nil
		RoomService.Unpublish(r)
		broadcast()
		return true, nil
	end
	local ok, err = RoundManager.StartShift(present, r.shiftId, seed, r.id)
	if not ok then
		r.state = "open"
		broadcast()
		return false, err
	end
	r.state = "running"
	broadcast()
	RoomService.Unpublish(r)
	return true, nil
end

-- ===== Cross-server listing (optional) =====================================

local function store()
	if memoryStore ~= nil then
		return memoryStore or nil
	end
	if not GameConfig.UseMemoryStoreRooms then
		memoryStore = false
		return nil
	end
	local ok, ms = pcall(function()
		return game:GetService("MemoryStoreService"):GetSortedMap("Vostok9Rooms")
	end)
	memoryStore = if ok then ms else false
	return memoryStore or nil
end

function RoomService.Publish(r: Room)
	local map = store()
	if not map or r.private then
		return
	end
	task.spawn(function()
		pcall(function()
			map:SetAsync(r.id, { name = r.name, count = #r.players, max = r.maxPlayers, shiftId = r.shiftId, jobId = game.JobId, state = r.state }, 60)
		end)
	end)
end

function RoomService.Unpublish(r: Room)
	local map = store()
	if not map then
		return
	end
	task.spawn(function()
		pcall(function()
			map:RemoveAsync(r.id)
		end)
	end)
end

-- ===== Remotes ===============================================================

function RoomService.Init()
	Net.func("RoomList").OnServerInvoke = function(player)
		return payloadFor(player)
	end
	Net.func("RoomCreate").OnServerInvoke = function(player, name, maxPlayers, private, shiftId)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		if not Net.isString(name, 40) or not Net.isInt(maxPlayers, 1, 4) or not Net.isBool(private) or not Net.isString(shiftId, 48) then
			return Net.fail("bad args")
		end
		local r, err = RoomService.Create(player, name, maxPlayers, private, shiftId)
		return if r then Net.ok(serialize(r, player)) else Net.fail(err or "error")
	end
	Net.func("RoomJoin").OnServerInvoke = function(player, idOrCode)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		if not Net.isString(idOrCode, 16) then
			return Net.fail("bad args")
		end
		local ok, err = RoomService.Join(player, idOrCode)
		return if ok then Net.ok() else Net.fail(err or "error")
	end
	Net.func("RoomLeave").OnServerInvoke = function(player)
		if not limiter:allow(player) then
			return Net.fail("rate")
		end
		RoomService.Leave(player)
		return Net.ok()
	end
	Net.func("RoomReady").OnServerInvoke = function(player, ready)
		if not limiter:allow(player) or not Net.isBool(ready) then
			return Net.fail("bad args")
		end
		return if RoomService.SetReady(player, ready) then Net.ok() else Net.fail("Нет открытой комнаты")
	end
	Net.func("RoomStart").OnServerInvoke = function(player)
		if not limiter:allow(player) or not nearBoard(player) then
			return Net.fail("Подойдите к доске смен")
		end
		local ok, err = RoomService.StartShift(player)
		return if ok then Net.ok() else Net.fail(err or "error")
	end
	Players.PlayerRemoving:Connect(RoomService.Leave)
	Players.PlayerAdded:Connect(function()
		task.delay(1, broadcast)
	end)
	RoundManager.ShiftEnded:Connect(function(shift)
		local r = rooms[shift.id]
		if r then
			rooms[shift.id] = nil
		end
		broadcast()
	end)
end

function RoomService.Start() end

return RoomService
