--!nonstrict
-- Lobby screens: room board (create / find / join by code / ready / start),
-- equipment picker, briefing, archive and the registration profile. All
-- actions go through RemoteFunctions and surface server errors verbatim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)
local InteractionController = require(script.Parent.InteractionController)

local player = Players.LocalPlayer

local LobbyUIController = {}

local gui: ScreenGui? = nil
local currentScreen: string? = nil
local roomsCache = { rooms = {}, mine = nil }
local shiftsCache = nil

local function call(name: string, ...)
	local ok, res = pcall(function(...)
		return Net.func(name):InvokeServer(...)
	end, ...)
	if not ok then
		HUDController.Notify({ title = "Ошибка связи", text = tostring(res), kind = "danger" })
		return nil
	end
	if typeof(res) == "table" and res.ok == false then
		HUDController.Notify({ title = "Отказ", text = res.reason or "", kind = "warn" })
		return nil
	end
	return res
end

local function close()
	if gui then
		gui:Destroy()
		gui = nil
	end
	currentScreen = nil
	CameraController.Unlock("lobbyui")
end
LobbyUIController.Close = close

local function open(title: string, w: number, h: number): Frame
	close()
	gui = Theme.screen("V9_Lobby", 40)
	CameraController.Lock("lobbyui")
	local body = Theme.modal(gui, title, w, h, close)
	return body
end

-- ===== Room board ============================================================

local function shiftList()
	if not shiftsCache then
		local res = call("TerminalQuery", "shifts")
		shiftsCache = res and res.data or {}
	end
	return shiftsCache
end

local function renderBoard(body: Frame)
	for _, c in body:GetChildren() do
		if not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	local left = Theme.frame(body, { Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	local right = Theme.frame(body, { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	local mine = nil
	for _, r in roomsCache.rooms do
		if r.id == roomsCache.mine then
			mine = r
		end
	end
	-- Left: my room or the open-room list.
	local ls = Theme.scroll(left)
	Theme.list(ls, 6)
	if mine then
		Theme.header(ls, "Моя комната: " .. mine.name)
		Theme.label(ls, string.format("%s · %s · %d/%d · %s", mine.title, mine.kind, mine.count, mine.max, if mine.private then "приватная" else "открытая"), 12, { TextColor3 = Theme.Colors.TextDim })
		if mine.code then
			Theme.label(ls, "Код приглашения: " .. mine.code, 14, { Font = Theme.FontMono, TextColor3 = Theme.Colors.Accent })
		end
		Theme.header(ls, "Состав")
		local meReady = false
		for _, m in mine.players do
			local tool = Tools.Defs[m.tool]
			Theme.label(ls, string.format("%s %s — %s%s", if m.ready then "■" else "□", m.name, tool and tool.name or "?", if m.userId == mine.hostId then " (создатель)" else ""), 13)
			if m.userId == player.UserId then
				meReady = m.ready
			end
		end
		Theme.button(ls, if meReady then "ОТМЕНИТЬ ГОТОВНОСТЬ" else "Я ГОТОВ", function()
			call("RoomReady", not meReady)
		end)
		if mine.hostId == player.UserId then
			Theme.button(ls, "НАЧАТЬ ЭКСПЕДИЦИЮ", function()
				if call("RoomStart") then
					close()
				end
			end, { BackgroundColor3 = Theme.Colors.PanelAlt, TextColor3 = Theme.Colors.Good })
		end
		Theme.button(ls, "ПОКИНУТЬ КОМНАТУ", function()
			call("RoomLeave")
		end)
	else
		Theme.header(ls, "Открытые комнаты")
		if #roomsCache.rooms == 0 then
			Theme.label(ls, "Пока никого. Создайте комнату или введите код друга.", 13, { TextColor3 = Theme.Colors.TextDim })
		end
		for _, r in roomsCache.rooms do
			local card = Theme.frame(ls, { Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = Theme.Colors.PanelAlt })
			Theme.corner(card, 3)
			Theme.padding(card, 8)
			Theme.label(card, r.name, 14, { Font = Theme.FontBold })
			Theme.label(card, string.format("%s · %d/%d · %s · %s", r.title, r.count, r.max, r.hostName, if r.state == "open" then "набор" else "в пути"), 12, { Position = UDim2.new(0, 0, 0, 20), TextColor3 = Theme.Colors.TextDim })
			Theme.button(card, "ВОЙТИ", function()
				call("RoomJoin", r.id)
			end, { Position = UDim2.new(1, -90, 0, 32), Size = UDim2.new(0, 90, 0, 26), TextSize = 13 })
		end
		Theme.header(ls, "Присоединиться к другу")
		local codeBox = Instance.new("TextBox")
		codeBox.PlaceholderText = "КОД КОМНАТЫ"
		codeBox.Text = ""
		codeBox.Size = UDim2.new(1, 0, 0, 34)
		codeBox.BackgroundColor3 = Theme.Colors.PanelAlt
		codeBox.TextColor3 = Theme.Colors.Text
		codeBox.Font = Theme.FontMono
		codeBox.TextSize = 16
		codeBox.ClearTextOnFocus = false
		codeBox.Parent = ls
		Theme.corner(codeBox, 3)
		Theme.button(ls, "ВОЙТИ ПО КОДУ", function()
			if #codeBox.Text >= 4 then
				call("RoomJoin", string.upper(codeBox.Text))
			end
		end)
		Theme.button(ls, "БЫСТРАЯ ИГРА", function()
			for _, r in roomsCache.rooms do
				if r.state == "open" and r.count < r.max then
					call("RoomJoin", r.id)
					return
				end
			end
			-- Nobody to join: open a public room for the first chapter shift.
			local shifts = shiftList()
			local first = shifts[1]
			if first then
				call("RoomCreate", player.DisplayName, 4, false, first.id)
			end
		end)
	end
	-- Right: create a room.
	local rs = Theme.scroll(right)
	Theme.list(rs, 6)
	Theme.header(rs, "Создать комнату")
	local nameBox = Instance.new("TextBox")
	nameBox.PlaceholderText = "Название комнаты"
	nameBox.Text = "Смена " .. player.DisplayName
	nameBox.Size = UDim2.new(1, 0, 0, 34)
	nameBox.BackgroundColor3 = Theme.Colors.PanelAlt
	nameBox.TextColor3 = Theme.Colors.Text
	nameBox.Font = Theme.Font
	nameBox.TextSize = 14
	nameBox.ClearTextOnFocus = false
	nameBox.Parent = rs
	Theme.corner(nameBox, 3)
	local maxPlayers = GameConfig.MaxShiftPlayers
	local private = false
	local maxLabel
	local function maxText()
		return "Участников: " .. tostring(maxPlayers) .. "   [−] [+]"
	end
	local row = Theme.frame(rs, { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })
	maxLabel = Theme.label(row, maxText(), 13, { Size = UDim2.new(1, -70, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	Theme.button(row, "−", function()
		maxPlayers = math.max(1, maxPlayers - 1)
		maxLabel.Text = maxText()
	end, { Position = UDim2.new(1, -66, 0, 2), Size = UDim2.new(0, 30, 0, 26) })
	Theme.button(row, "+", function()
		maxPlayers = math.min(4, maxPlayers + 1)
		maxLabel.Text = maxText()
	end, { Position = UDim2.new(1, -32, 0, 2), Size = UDim2.new(0, 30, 0, 26) })
	Theme.toggle(rs, "Приватная (вход по коду)", false, function(v)
		private = v
	end)
	Theme.header(rs, "Смена")
	local selected = nil
	local buttons = {}
	local function refreshSel()
		for id, b in buttons do
			b.TextColor3 = if id == selected then Theme.Colors.Accent else Theme.Colors.Text
		end
	end
	for _, s in shiftList() do
		local b = Theme.button(rs, string.format("%s%s — %s (%s)", if s.available then "" else "🔒 ", s.title, s.kind, s.danger), function()
			if s.available then
				selected = s.id
				refreshSel()
			end
		end, { TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13 })
		Theme.padding(b, 8)
		buttons[s.id] = b
		if not selected and s.available then
			selected = s.id
		end
	end
	refreshSel()
	Theme.button(rs, "СОЗДАТЬ", function()
		if not selected then
			return
		end
		local res = call("RoomCreate", nameBox.Text, maxPlayers, private, selected)
		if res then
			Theme.playUISound("UIConfirm")
		end
	end, { TextColor3 = Theme.Colors.Good })
end

local function openBoard()
	local body = open("Доска смен · комнаты экспедиций", 860, 540)
	currentScreen = "RoomBoard"
	local res = call("RoomList")
	if res then
		roomsCache = res
	end
	renderBoard(body)
end

-- ===== Equipment ==============================================================

local function openEquipment(prompt)
	local body = open("Экипировочная · выбор инструмента", 620, 440)
	currentScreen = "Equipment"
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 8)
	Theme.label(scroll, "Один инструмент на смену. Фонарь выдаётся каждому. Аккумуляторы, предохранители и аптечки — на станции.", 13, { TextColor3 = Theme.Colors.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	local focus = prompt and prompt:GetAttribute("ToolId")
	for _, id in Tools.Order do
		local def = Tools.Defs[id]
		local card = Theme.frame(scroll, { Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = Theme.Colors.PanelAlt })
		Theme.corner(card, 3)
		Theme.padding(card, 10)
		if id == focus then
			Theme.stroke(card, Theme.Colors.Accent)
		end
		local sw = Theme.frame(card, { Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = def.color })
		Theme.corner(sw, 2)
		Theme.label(card, def.name, 15, { Position = UDim2.new(0, 22, 0, -2), Font = Theme.FontBold })
		Theme.label(card, def.description, 12, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -110, 0, 44), TextColor3 = Theme.Colors.TextDim })
		Theme.button(card, "ВЫБРАТЬ", function()
			if call("SelectTool", id) then
				HUDController.Notify({ title = "Инструмент выбран", text = def.name, kind = "good" })
				close()
			end
		end, { Position = UDim2.new(1, -100, 1, -30), Size = UDim2.new(0, 100, 0, 28), TextSize = 13 })
	end
end

-- ===== Briefing ================================================================

local function openBriefing()
	local body = open("Брифинговая · доска задач", 720, 520)
	currentScreen = "Briefing"
	local res = call("TerminalQuery", "briefing")
	if not res then
		return
	end
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 8)
	for _, s in res.data.shifts do
		Theme.header(scroll, s.title .. " · " .. s.kind .. " · " .. s.danger)
		for _, line in s.briefing do
			Theme.label(scroll, line, 13, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		end
		for _, t in s.tasks do
			Theme.label(scroll, (if t.optional then "◇ " else "○ ") .. t.label, 13)
		end
		for _, w in s.warnings do
			Theme.label(scroll, "! " .. w, 12, { TextColor3 = Theme.Colors.Warm, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		end
	end
	Theme.header(scroll, "Главы")
	for _, ch in res.data.chapters do
		Theme.label(scroll, string.format("%s — %s%s", ch.title, ch.summary, if #ch.shifts == 0 then " (в разработке)" else ""), 12, { TextColor3 = Theme.Colors.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
end

-- ===== Archive =================================================================

local function openArchive()
	local body = open("Архив экспедиций", 760, 540)
	currentScreen = "Archive"
	local a = call("GetArchive")
	if not a then
		return
	end
	local tabs = Theme.frame(body, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	Theme.list(tabs, 6, true)
	local content = Theme.frame(body, { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1 })
	local function show(kind: string)
		for _, c in content:GetChildren() do
			c:Destroy()
		end
		local scroll = Theme.scroll(content)
		Theme.list(scroll, 6)
		if kind == "docs" then
			Theme.label(scroll, string.format("Найдено документов: %d", a.documentCount), 13, { TextColor3 = Theme.Colors.TextDim })
			for _, d in a.documents do
				local card = Theme.frame(scroll, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Colors.PanelAlt })
				Theme.corner(card, 3)
				Theme.padding(card, 8)
				Theme.list(card, 2)
				Theme.label(card, (if d.found then "■ " else "□ ") .. d.kind .. " · " .. d.title, 14, { Font = Theme.FontBold, TextColor3 = if d.found then Theme.Colors.Text else Theme.Colors.TextDim })
				Theme.label(card, d.body, 12, { Font = Theme.FontMono, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextColor3 = if d.found then Theme.Colors.Text else Theme.Colors.TextDim })
			end
		elseif kind == "chapters" then
			for _, ch in a.chapters do
				Theme.label(scroll, string.format("%s %s", if ch.unlocked then "■" else "□", ch.title), 14, { Font = Theme.FontBold })
				Theme.label(scroll, ch.summary .. (if not ch.available then "  (в разработке)" else ""), 12, { TextColor3 = Theme.Colors.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			end
		elseif kind == "lore" then
			for _, l in a.creatures do
				Theme.label(scroll, l.title, 14, { Font = Theme.FontBold, TextColor3 = if l.unlocked then Theme.Colors.Accent else Theme.Colors.TextDim })
				Theme.label(scroll, l.text, 12, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			end
		else
			Theme.label(scroll, string.format("Смен: %d · успешных: %d · спасений: %d · ночей: %d", a.stats.shifts, a.stats.successes, a.stats.rescues, a.stats.nightsSurvived or 0), 13)
			for _, h in a.history do
				Theme.label(scroll, string.format("%s  %s  +%d", if h.success then "■" else "✕", h.missionId, h.reward), 12, { Font = Theme.FontMono, TextColor3 = Theme.Colors.TextDim })
			end
		end
	end
	for _, t in { { "ДОКУМЕНТЫ", "docs" }, { "ГЛАВЫ", "chapters" }, { "СВЕДЕНИЯ", "lore" }, { "ИСТОРИЯ", "history" } } do
		Theme.button(tabs, t[1], function()
			show(t[2])
		end, { Size = UDim2.new(0, 150, 0, 30), TextSize = 13 })
	end
	show("docs")
end

-- ===== Registration ===========================================================

local function openRegistration()
	local body = open("Регистрация · профиль сотрудника", 560, 420)
	currentScreen = "Registration"
	local res = call("TerminalQuery", "registration")
	if not res then
		return
	end
	local d = res.data
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 6)
	Theme.label(scroll, d.name, 18, { Font = Theme.FontBold })
	if d.transient then
		Theme.label(scroll, "Хранилище данных недоступно: прогресс этой сессии не сохранится.", 12, { TextColor3 = Theme.Colors.Danger, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
	Theme.label(scroll, string.format("Валюта: %d · Документов: %d · Инструмент: %s", d.currency, d.documents, d.selectedToolName), 13)
	Theme.label(scroll, string.format("Смен: %d · Успешных: %d · Спасений: %d · Ночей пережито: %d", d.stats.shifts, d.stats.successes, d.stats.rescues, d.stats.nightsSurvived or 0), 13)
	Theme.header(scroll, "Открытые главы")
	for idx in d.chapters do
		Theme.label(scroll, "Глава " .. tostring(idx), 13)
	end
	Theme.header(scroll, "Последние смены")
	for _, h in d.history do
		Theme.label(scroll, string.format("%s  %s  +%d", if h.success then "■" else "✕", h.missionId, h.reward), 12, { Font = Theme.FontMono, TextColor3 = Theme.Colors.TextDim })
	end
end

function LobbyUIController.init()
	InteractionController.OpenUI:Connect(function(ui, prompt)
		if ui == "RoomBoard" then
			openBoard()
		elseif ui == "Equipment" then
			openEquipment(prompt)
		elseif ui == "Briefing" then
			openBriefing()
		elseif ui == "Archive" then
			openArchive()
		elseif ui == "Registration" then
			openRegistration()
		end
	end)
	Net.event("RoomListUpdated").OnClientEvent:Connect(function(payload)
		roomsCache = payload
		if currentScreen == "RoomBoard" and gui then
			local body = gui:FindFirstChild("Body", true)
			if body then
				renderBoard(body)
			end
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(state)
		if state.phase ~= "Idle" then
			close()
		end
	end)
end

return LobbyUIController
