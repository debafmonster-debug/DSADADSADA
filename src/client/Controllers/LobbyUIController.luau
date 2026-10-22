--!nonstrict
-- Lobby screens: shift board, equipment, briefing, archive, registration.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local InteractionController = require(script.Parent.InteractionController)
local HUDController = require(script.Parent.HUDController)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local C = Theme.Colors

local LobbyUIController = {}

local gui: ScreenGui? = nil
local shiftList = { shifts = {}, mine = nil }
local missionsCache = nil
local boardRefresh: (() -> ())? = nil

local function open(title: string, w: number, h: number): Frame
	LobbyUIController.close()
	local g = Theme.screen("NS_Lobby", 40)
	gui = g
	local body = Theme.modal(g, title, w, h, function()
		gui = nil
		boardRefresh = nil
		CameraController.InputLocked = false
	end)
	CameraController.InputLocked = true
	return body
end

function LobbyUIController.close()
	if gui then
		gui:Destroy()
		gui = nil
	end
	boardRefresh = nil
	CameraController.InputLocked = false
end

local function call(name: string, ...)
	local ok, res = pcall(function(...)
		return Net.func(name):InvokeServer(...)
	end, ...)
	if not ok then
		HUDController.Notify({ title = "Ошибка связи", text = tostring(res), kind = "danger" })
		return nil
	end
	if typeof(res) == "table" and res.ok == false then
		HUDController.Notify({ title = "Отказано", text = tostring(res.reason), kind = "warn" })
		return nil
	end
	return res
end

------------------------------------------------------------------------------
local function shiftBoard()
	local body = open("Доска смен", 820, 520)
	local left = Theme.frame(body, { Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	local right = Theme.frame(body, { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	local leftScroll = Theme.scroll(left)
	Theme.list(leftScroll, 6)
	local rightScroll = Theme.scroll(right)
	Theme.list(rightScroll, 6)

	local function render()
		for _, ch in leftScroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for _, ch in rightScroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local mine = nil
		for _, s in shiftList.shifts do
			if s.id == shiftList.mine then
				mine = s
			end
		end
		if mine then
			Theme.header(leftScroll, "Ваша смена")
			Theme.label(leftScroll, mine.title, 16, { Font = Theme.FontBold })
			Theme.label(leftScroll, string.format("%s · %s", mine.kind, mine.danger), 13, { TextColor3 = C.TextDim })
			Theme.label(leftScroll, string.format("Создатель: %s · %s · код: <b>%s</b>", mine.hostName, if mine.private then "приватная" else "публичная", mine.id), 13, { TextColor3 = C.TextDim })
			Theme.header(leftScroll, "Команда " .. mine.count .. "/" .. mine.max)
			local me = nil
			for _, m in mine.players do
				if m.userId == player.UserId then
					me = m
				end
				local toolName = Tools.Defs[m.tool] and Tools.Defs[m.tool].name or m.tool
				Theme.label(leftScroll, string.format("%s %s  <font color='#969ea6'>%s</font>", if m.ready then "■" else "□", m.name, toolName), 14, { TextColor3 = if m.ready then C.Good else C.Text })
			end
			Theme.button(leftScroll, if me and me.ready then "ОТМЕНИТЬ ГОТОВНОСТЬ" else "Я ГОТОВ", function()
				call("ShiftReady", not (me and me.ready))
			end)
			if mine.hostId == player.UserId then
				Theme.button(leftScroll, "НАЧАТЬ СМЕНУ", function()
					if call("ShiftStart") then
						LobbyUIController.close()
					end
				end, { BackgroundColor3 = Color3.fromRGB(60, 50, 20) })
			end
			Theme.button(leftScroll, "ПОКИНУТЬ СМЕНУ", function()
				call("ShiftLeave")
			end)
		else
			Theme.header(leftScroll, "Открытые смены")
			local any = false
			for _, s in shiftList.shifts do
				any = true
				local card = Theme.frame(leftScroll, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Panel })
				Theme.stroke(card)
				Theme.corner(card)
				Theme.padding(card, 8)
				Theme.list(card, 3)
				Theme.label(card, s.title, 14, { Font = Theme.FontBold })
				Theme.label(card, string.format("%s · %s · %d/%d · %s", s.kind, s.danger, s.count, s.max, s.state), 12, { TextColor3 = C.TextDim })
				if s.state == "open" then
					Theme.button(card, "ПРИСОЕДИНИТЬСЯ", function()
						call("ShiftJoin", s.id)
					end)
				end
			end
			if not any then
				Theme.label(leftScroll, "Открытых смен нет. Создайте свою или введите код приватной смены.", 13, { TextColor3 = C.TextDim, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
			end
			local codeBox = Instance.new("TextBox")
			codeBox.PlaceholderText = "Код приватной смены"
			codeBox.Text = ""
			codeBox.Size = UDim2.new(1, 0, 0, 34)
			codeBox.BackgroundColor3 = C.Panel
			codeBox.TextColor3 = C.Text
			codeBox.Font = Theme.FontMono
			codeBox.TextSize = 14
			codeBox.ClearTextOnFocus = false
			Theme.stroke(codeBox)
			Theme.corner(codeBox)
			codeBox.Parent = leftScroll
			Theme.button(leftScroll, "ВОЙТИ ПО КОДУ", function()
				if #codeBox.Text > 0 then
					call("ShiftJoin", codeBox.Text)
				end
			end)
		end
		-- Right: missions
		Theme.header(rightScroll, "Создать смену")
		if not missionsCache then
			missionsCache = call("TerminalQuery", "missions")
			missionsCache = missionsCache and missionsCache.data
		end
		local privateFlag = { value = false }
		local privBtn
		privBtn = Theme.button(rightScroll, "□ Приватная смена (для друзей)", function()
			privateFlag.value = not privateFlag.value
			privBtn.Text = (privateFlag.value and "■" or "□") .. " Приватная смена (для друзей)"
		end)
		for _, m in missionsCache or {} do
			local card = Theme.frame(rightScroll, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Panel })
			Theme.stroke(card, if m.available then C.Border else Color3.fromRGB(50, 40, 40))
			Theme.corner(card)
			Theme.padding(card, 8)
			Theme.list(card, 3)
			Theme.label(card, m.title, 14, { Font = Theme.FontBold, TextColor3 = if m.available then C.Text else C.TextDim })
			Theme.label(card, m.chapterTitle, 12, { TextColor3 = C.TextDim })
			Theme.label(card, string.format("%s · опасность: %s", m.kind, m.danger), 12, { TextColor3 = C.TextDim })
			Theme.label(card, "Цель: " .. m.mainTask, 12, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
			if m.available and not mine then
				Theme.button(card, "СОЗДАТЬ", function()
					call("ShiftCreate", m.id, privateFlag.value)
				end)
			elseif not m.available then
				Theme.label(card, "Недоступно: глава не открыта", 12, { TextColor3 = C.Danger })
			end
		end
	end
	boardRefresh = render
	render()
	local list = call("ShiftList")
	if list then
		shiftList = list
		render()
	end
end

------------------------------------------------------------------------------
local function equipment(prompt: ProximityPrompt)
	local toolId = prompt:GetAttribute("ToolId")
	local def = Tools.Defs[toolId]
	if not def then
		return
	end
	local body = open("Экипировка · " .. def.name, 480, 300)
	Theme.list(body, 8)
	local sw = Theme.frame(body, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = def.color })
	sw.Name = "Swatch"
	Theme.label(body, def.description, 15, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local caps = {}
	for cap in def.capabilities do
		table.insert(caps, cap)
	end
	table.sort(caps)
	Theme.label(body, "Возможности: " .. table.concat(caps, ", "), 12, { TextColor3 = C.TextDim })
	Theme.label(body, "Один инструмент на смену. Инструменты не являются оружием.", 12, { TextColor3 = C.TextDim })
	Theme.button(body, "ВЗЯТЬ " .. string.upper(def.name), function()
		if call("SelectTool", toolId) then
			LobbyUIController.close()
		end
	end, { BackgroundColor3 = Color3.fromRGB(40, 50, 30) })
end

------------------------------------------------------------------------------
local function briefing()
	local res = call("TerminalQuery", "briefing")
	local b = res and res.data
	local body = open("Брифинг", 640, 460)
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 6)
	if not b then
		Theme.label(scroll, "Вы не состоите в смене. Создайте или выберите смену на доске смен, затем вернитесь к пульту брифинга.", 15, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		return
	end
	Theme.label(scroll, b.title, 18, { Font = Theme.FontBold })
	Theme.label(scroll, string.format("Тип: %s · Опасность: %s", b.kind, b.danger), 13, { TextColor3 = C.TextDim })
	Theme.header(scroll, "Необходимые работы")
	Theme.label(scroll, "• " .. b.mainTask, 14)
	if b.optionalTask then
		Theme.label(scroll, "• (дополнительно) " .. b.optionalTask, 14, { TextColor3 = C.TextDim })
	end
	Theme.header(scroll, "Сводка")
	for _, l in b.briefing do
		Theme.label(scroll, l, 14, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(scroll, "Известные неисправности и предупреждения")
	for _, l in b.warnings do
		Theme.label(scroll, "! " .. l, 14, { TextColor3 = C.Accent, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(scroll, "Доступные инструменты")
	Theme.label(scroll, table.concat(b.tools, " · "), 13, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Theme.header(scroll, "Условия эвакуации")
	Theme.label(scroll, b.evacuation .. ". Шлюз открывается после активации терминала и завершения основной задачи.", 14, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
end

------------------------------------------------------------------------------
local function archive()
	local data = call("GetArchive")
	local body = open("Персональный архив", 860, 540)
	if not data then
		return
	end
	local tabs = Theme.frame(body, { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 })
	Theme.list(tabs, 6, true)
	local content = Theme.frame(body, { Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1 })
	local function clear()
		for _, ch in content:GetChildren() do
			ch:Destroy()
		end
	end
	local function docsTab()
		clear()
		local list = Theme.scroll(content, { Size = UDim2.new(0.42, -6, 1, 0) })
		Theme.list(list, 4)
		local reader = Theme.scroll(content, { Position = UDim2.new(0.42, 6, 0, 0), Size = UDim2.new(0.58, -6, 1, 0) })
		Theme.list(reader, 6)
		Theme.label(reader, "Выберите документ.", 14, { TextColor3 = C.TextDim })
		Theme.label(list, string.format("Найдено: %d / %d", data.documentCount, #data.documents), 13, { TextColor3 = C.TextDim })
		for _, d in data.documents do
			Theme.button(list, (d.found and "■ " or "□ ") .. d.title .. "  <font color='#969ea6'>гл." .. d.chapter .. "</font>", function()
				for _, ch in reader:GetChildren() do
					if ch:IsA("GuiObject") then
						ch:Destroy()
					end
				end
				if d.found then
					Theme.label(reader, d.title, 16, { Font = Theme.FontBold })
					Theme.label(reader, d.kind .. " · " .. d.author, 12, { TextColor3 = C.TextDim })
					Theme.label(reader, d.body, 14, { Font = Theme.FontMono, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
				else
					Theme.label(reader, "Документ не найден. Ищите в секторах комплекса во время смен.", 14, { TextColor3 = C.TextDim })
				end
			end, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), TextSize = 13, RichText = true, TextColor3 = if d.found then C.Text else C.TextDim })
		end
	end
	local function chaptersTab()
		clear()
		local s = Theme.scroll(content)
		Theme.list(s, 6)
		for _, ch in data.chapters do
			local card = Theme.frame(s, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Panel })
			Theme.stroke(card, if ch.unlocked then C.Accent else C.Border)
			Theme.corner(card)
			Theme.padding(card, 8)
			Theme.list(card, 3)
			Theme.label(card, ch.title, 15, { Font = Theme.FontBold, TextColor3 = if ch.unlocked then C.Text else C.TextDim })
			Theme.label(card, ch.summary, 13, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
			Theme.label(card, if ch.unlocked then "ОТКРЫТА" elseif not ch.available then "В РАЗРАБОТКЕ" else string.format("Требуется документов: %d%s", ch.requires.documents, if ch.requires.chapter then " и завершение главы " .. ch.requires.chapter else ""), 12, { TextColor3 = if ch.unlocked then C.Good else C.TextDim })
		end
	end
	local function creaturesTab()
		clear()
		local s = Theme.scroll(content)
		Theme.list(s, 6)
		for _, k in data.creatures do
			Theme.label(s, k.title, 15, { Font = Theme.FontBold, TextColor3 = if k.unlocked then C.Text else C.TextDim })
			Theme.label(s, k.text, 13, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		end
	end
	local function historyTab()
		clear()
		local s = Theme.scroll(content)
		Theme.list(s, 4)
		Theme.label(s, string.format("Смен: %d · Успешных: %d · Документов: %d", data.stats.shifts, data.stats.successes, data.stats.documentsFound), 13, { TextColor3 = C.TextDim })
		if #data.history == 0 then
			Theme.label(s, "История смен пуста.", 14, { TextColor3 = C.TextDim })
		end
		for _, h in data.history do
			Theme.label(s, string.format("%s  %s  +%d  seed %d  %s", if h.success then "■" else "✕", h.title, h.reward, h.seed, os.date("%d.%m %H:%M", h.time)), 13, { TextColor3 = if h.success then C.Good else C.Danger })
		end
	end
	for _, t in { { "ДОКУМЕНТЫ", docsTab }, { "ГЛАВЫ", chaptersTab }, { "СУЩЕСТВА", creaturesTab }, { "ИСТОРИЯ", historyTab } } do
		Theme.button(tabs, t[1], t[2], { Size = UDim2.new(0, 150, 0, 32), TextSize = 13 })
	end
	docsTab()
end

------------------------------------------------------------------------------
local function registration()
	local res = call("TerminalQuery", "registration")
	local d = res and res.data
	local body = open("Регистрация персонала", 560, 460)
	local s = Theme.scroll(body)
	Theme.list(s, 6)
	if not d then
		return
	end
	Theme.label(s, d.name, 20, { Font = Theme.FontBold })
	Theme.label(s, string.format("Уровень допуска: <b>%s</b> · Кредиты: <b>%d</b> · Документов: <b>%d</b>", d.accessLevel, d.currency, d.documents), 14)
	Theme.label(s, "Инструмент: " .. d.selectedTool, 13, { TextColor3 = C.TextDim })
	if d.transient then
		Theme.label(s, "! Хранилище данных недоступно: прогресс этой сессии не будет сохранён.", 12, { TextColor3 = C.Danger })
	end
	Theme.header(s, "Сюжетные главы")
	for _, ch in d.chapters do
		Theme.label(s, string.format("%s %s%s", if ch.unlocked then "■" else "□", ch.title, if not ch.available then " (в разработке)" else ""), 14, { TextColor3 = if ch.unlocked then C.Text else C.TextDim })
	end
	Theme.header(s, "Следующая смена")
	if d.nextShift then
		Theme.label(s, d.nextShift.title .. " — " .. d.nextShift.mainTask, 14, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(s, "История смен")
	if #d.history == 0 then
		Theme.label(s, "Смен ещё не было.", 13, { TextColor3 = C.TextDim })
	end
	for _, h in d.history do
		Theme.label(s, string.format("%s %s  +%d", if h.success then "■" else "✕", h.title, h.reward), 13, { TextColor3 = if h.success then C.Good else C.Danger })
	end
	Theme.header(s, "Статистика")
	Theme.label(s, string.format("Смен: %d · Успешных: %d · Спасений: %d", d.stats.shifts, d.stats.successes, d.stats.rescues), 13)
end

function LobbyUIController.init()
	InteractionController.OpenUI:Connect(function(ui, prompt)
		if ui == "ShiftBoard" then
			shiftBoard()
		elseif ui == "Equipment" then
			equipment(prompt)
		elseif ui == "Briefing" then
			briefing()
		elseif ui == "Archive" then
			archive()
		elseif ui == "Registration" then
			registration()
		end
	end)
	Net.event("ShiftListUpdated").OnClientEvent:Connect(function(list)
		shiftList = list
		if boardRefresh then
			boardRefresh()
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase and st.phase ~= "Idle" then
			LobbyUIController.close()
		end
	end)
	local _ = GameConfig
end

return LobbyUIController
