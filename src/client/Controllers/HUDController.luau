--!nonstrict
-- In-game HUD. Minimal by design: station clock and stage, task list, body
-- temperature / stamina / battery, inventory, a four-light power strip,
-- subtitles, notifications, headcount and evacuation banners, and the
-- briefing / results / document modals. Everything it shows comes from
-- server events; the only local values are stamina and the cosmetic battery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)
local FlashlightController = require(script.Parent.FlashlightController)

local HUDController = {}
HUDController.PhaseChanged = Signal.new()
HUDController.Phase = "Idle"
HUDController.Flags = { heat = 100, bodyTemp = 36.6, coldStage = 0, downed = false }

local gui: ScreenGui
local objective, tasksList, clockLabel, stageLabel, titleLabel, teamList
local statusPanel, tempFill, tempLabel, stamFill, batFill, batLabel, toolLabel, itemsFrame
local notifications, subtitle, subtitleSpeaker, banner, bannerText, evacLabel, powerStrip, powerLights
local downedOverlay, downedText
local modalGui: ScreenGui? = nil
local taskRows: { [string]: Frame } = {}
local inventory = { items = {}, battery = 0, tool = nil }
local subtitleQueue = {}
local subtitleBusy = false

-- ===== helpers ==========================================================

local function closeModal()
	if modalGui then
		modalGui:Destroy()
		modalGui = nil
		CameraController.Unlock("modal")
	end
end

local function openModal(title: string, w: number, h: number): Frame
	closeModal()
	modalGui = Theme.screen("V9_Modal", 50)
	CameraController.Lock("modal")
	local body = Theme.modal(modalGui, title, w, h, function()
		closeModal()
	end)
	return body
end

function HUDController.Notify(n: { title: string, text: string?, kind: string? })
	local color = Theme.Colors.Info
	if n.kind == "danger" then
		color = Theme.Colors.Danger
	elseif n.kind == "warn" then
		color = Theme.Colors.Warm
	elseif n.kind == "good" then
		color = Theme.Colors.Good
	elseif n.kind == "story" then
		color = Theme.Colors.Terminal
	end
	local card = Theme.frame(notifications, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.15 })
	Theme.stroke(card, color)
	Theme.corner(card, 3)
	Theme.padding(card, 8)
	Theme.list(card, 2)
	Theme.label(card, n.title, 14, { Font = Theme.FontBold, TextColor3 = color, Size = UDim2.new(1, 0, 0, 18) })
	if n.text and n.text ~= "" then
		Theme.label(card, n.text, 13, { TextColor3 = Theme.Colors.Text, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
	local children = notifications:GetChildren()
	local count = 0
	for _, c in children do
		if c:IsA("Frame") then
			count += 1
		end
	end
	if count > 6 then
		for _, c in children do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(if n.kind == "story" then 10 else 6, function()
		if card.Parent then
			Theme.tween(card, { BackgroundTransparency = 1 }, 0.4)
			task.wait(0.4)
			card:Destroy()
		end
	end)
	if n.kind == "danger" then
		Theme.playUISound("UIError")
	elseif n.kind == "good" then
		Theme.playUISound("UIConfirm")
	end
end

local function showSubtitle(speaker: string?, text: string, seconds: number)
	subtitleSpeaker.Text = if speaker then string.upper(speaker) else ""
	subtitle.Text = text
	subtitle.Visible = true
	subtitleSpeaker.Visible = speaker ~= nil
	task.wait(seconds)
	subtitle.Visible = false
	subtitleSpeaker.Visible = false
end

local function pumpSubtitles()
	if subtitleBusy then
		return
	end
	subtitleBusy = true
	task.spawn(function()
		while #subtitleQueue > 0 do
			local line = table.remove(subtitleQueue, 1)
			if SettingsStore.Current.subtitles then
				showSubtitle(line.speaker, line.text, line.seconds)
			else
				task.wait(line.seconds)
			end
			if line.pauseAfter then
				task.wait(line.pauseAfter)
			end
		end
		subtitleBusy = false
	end)
end

function HUDController.Subtitle(text: string, seconds: number?, speaker: string?)
	table.insert(subtitleQueue, { speaker = speaker, text = text, seconds = seconds or 3 })
	pumpSubtitles()
end

function HUDController.Lines(lines)
	for _, l in lines do
		table.insert(subtitleQueue, { speaker = l.speaker, text = l.text, seconds = l.seconds, pauseAfter = l.pauseAfter })
	end
	pumpSubtitles()
end

local function setBanner(text: string?, color: Color3?)
	if text then
		bannerText.Text = text
		bannerText.TextColor3 = color or Theme.Colors.Accent
		banner.Visible = true
	else
		banner.Visible = false
	end
end

-- ===== build ============================================================

local function buildTaskRow(t)
	local row = Theme.frame(tasksList, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	local mark = Theme.label(row, "○", 14, { Size = UDim2.new(0, 16, 0, 18), TextColor3 = Theme.Colors.TextDim })
	mark.Name = "Mark"
	local lbl = Theme.label(row, t.label, 13, { Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -18, 0, 18) })
	lbl.Name = "Label"
	local hint = Theme.label(row, t.hint or "", 11, { Position = UDim2.new(0, 18, 0, 17), Size = UDim2.new(1, -18, 0, 14), TextColor3 = Theme.Colors.TextDim })
	hint.Name = "Hint"
	local track = Theme.frame(row, { Position = UDim2.new(0, 18, 1, -3), Size = UDim2.new(1, -18, 0, 2), BackgroundColor3 = Theme.Colors.PanelAlt })
	local fill = Theme.frame(track, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Colors.Accent })
	fill.Name = "Fill"
	row.Name = t.id
	return row
end

local function applyTask(t)
	local row = taskRows[t.id]
	if not row then
		row = buildTaskRow(t)
		taskRows[t.id] = row
	end
	local mark = row:FindFirstChild("Mark")
	local lbl = row:FindFirstChild("Label")
	local hint = row:FindFirstChild("Hint")
	local fill = row:FindFirstChild("Fill", true)
	if t.status == "complete" then
		mark.Text = "■"
		mark.TextColor3 = Theme.Colors.Good
		lbl.TextColor3 = Theme.Colors.TextDim
		hint.Text = ""
	else
		mark.Text = if t.optional then "◇" else "○"
		mark.TextColor3 = if t.optional then Theme.Colors.TextDim else Theme.Colors.Accent
		lbl.TextColor3 = Theme.Colors.Text
		hint.Text = t.hint or ""
	end
	lbl.Text = t.label .. (if t.optional then "  (доп.)" else "")
	fill.Size = UDim2.new(math.clamp(t.progress or 0, 0, 1), 0, 1, 0)
	row.LayoutOrder = if t.status == "complete" then 100 else (if t.optional then 50 else 0)
end

local function rebuildItems()
	for _, c in itemsFrame:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for i, it in inventory.items do
		local usable = it.id == "Battery" or it.id == "Medkit"
		local text = string.format("%s ×%d", it.name, it.count)
		if usable then
			local b = Theme.button(itemsFrame, text .. "  [" .. tostring(i) .. "]", function()
				task.spawn(function()
					local ok, res = pcall(function()
						return Net.func("InventoryUse"):InvokeServer(it.id)
					end)
					if ok and res and res.ok then
						HUDController.Notify({ title = "Использовано", text = res.data, kind = "good" })
					elseif ok and res then
						HUDController.Notify({ title = "Нельзя", text = res.reason, kind = "warn" })
					end
				end)
			end, { Size = UDim2.new(1, 0, 0, 22), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
			Theme.padding(b, 6)
			b.LayoutOrder = i
		else
			local l = Theme.label(itemsFrame, "▪ " .. text, 12, { Size = UDim2.new(1, 0, 0, 16), TextColor3 = Theme.Colors.TextDim })
			l.LayoutOrder = i
		end
	end
end

local function build()
	gui = Theme.screen("V9_HUD", 10)
	gui.Enabled = false
	-- Objective panel (top-left): title, station clock, stage, tasks, team.
	objective = Theme.frame(gui, { Position = UDim2.new(0, 16, 0, 16 + Theme.safeTop()), Size = UDim2.new(0, 330, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.3 })
	Theme.stroke(objective)
	Theme.corner(objective, 3)
	Theme.padding(objective, 10)
	Theme.list(objective, 4)
	local head = Theme.frame(objective, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 0 })
	clockLabel = Theme.label(head, "--:--", 34, { Font = Theme.FontMono, Size = UDim2.new(0, 120, 0, 40), TextColor3 = Theme.Colors.Accent })
	titleLabel = Theme.label(head, "", 13, { Position = UDim2.new(0, 124, 0, 2), Size = UDim2.new(1, -124, 0, 16), Font = Theme.FontBold })
	stageLabel = Theme.label(head, "", 12, { Position = UDim2.new(0, 124, 0, 20), Size = UDim2.new(1, -124, 0, 16), TextColor3 = Theme.Colors.TextDim })
	tasksList = Theme.frame(objective, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 })
	Theme.list(tasksList, 2)
	teamList = Theme.label(objective, "", 11, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = Theme.Colors.TextDim, LayoutOrder = 2 })
	-- Status panel (bottom-left).
	statusPanel = Theme.frame(gui, { Position = UDim2.new(0, 16, 1, -16), AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(0, 250, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.3 })
	Theme.stroke(statusPanel)
	Theme.corner(statusPanel, 3)
	Theme.padding(statusPanel, 10)
	local bars = Theme.frame(statusPanel, { Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1 })
	tempFill, tempLabel = Theme.bar(bars, "ТЕМПЕРАТУРА ТЕЛА  36.6 °C", Theme.Colors.Accent, 0, 230)
	stamFill = Theme.bar(bars, "ВЫНОСЛИВОСТЬ", Theme.Colors.Good, 28, 230)
	batFill, batLabel = Theme.bar(bars, "ФОНАРЬ [F]", Theme.Colors.Warm, 56, 230)
	toolLabel = Theme.label(statusPanel, "", 12, { Position = UDim2.new(0, 0, 0, 90), Size = UDim2.new(1, 0, 0, 16), Font = Theme.FontBold })
	itemsFrame = Theme.frame(statusPanel, { Position = UDim2.new(0, 0, 0, 108), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	Theme.list(itemsFrame, 2)
	-- Power strip (bottom-right): four small indicator lights.
	powerStrip = Theme.frame(gui, { Position = UDim2.new(1, -16, 1, -16), AnchorPoint = Vector2.new(1, 1), Size = UDim2.new(0, 230, 0, 30), BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.3 })
	Theme.stroke(powerStrip)
	Theme.corner(powerStrip, 3)
	Theme.list(powerStrip, 6, true)
	Theme.padding(powerStrip, 6)
	powerLights = {}
	for _, def in { { "ГЕН", "gen" }, { "ОТОП", "Heating" }, { "СВЯЗЬ", "Radio" }, { "СКАН", "Scanner" }, { "СВЕТ", "LightsMain" } } do
		local cell = Theme.frame(powerStrip, { Size = UDim2.new(0, 40, 1, 0), BackgroundTransparency = 1 })
		local dot = Theme.frame(cell, { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 0, 0.5, -4), BackgroundColor3 = Theme.Colors.TextDim })
		Theme.corner(dot, 4)
		Theme.label(cell, def[1], 10, { Position = UDim2.new(0, 11, 0, 0), Size = UDim2.new(1, -11, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = Theme.Colors.TextDim })
		powerLights[def[2]] = dot
	end
	-- Notifications (top-right).
	notifications = Theme.frame(gui, { Position = UDim2.new(1, -16, 0, 16 + Theme.safeTop()), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 320, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	Theme.list(notifications, 6)
	-- Subtitles (bottom-center).
	subtitleSpeaker = Theme.label(gui, "", 12, { Position = UDim2.new(0.5, 0, 1, -170), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 700, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.Accent, Font = Theme.FontBold, Visible = false })
	subtitle = Theme.label(gui, "", 18, { Position = UDim2.new(0.5, 0, 1, -120), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 760, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Visible = false, TextStrokeTransparency = 0.4 })
	-- Banner (top-center): night rule, headcount, evacuation.
	banner = Theme.frame(gui, { Position = UDim2.new(0.5, 0, 0, 16 + Theme.safeTop()), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 460, 0, 34), BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.25, Visible = false })
	Theme.stroke(banner, Theme.Colors.Border)
	Theme.corner(banner, 3)
	bannerText = Theme.label(banner, "", 15, { Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Font = Theme.FontBold })
	evacLabel = Theme.label(gui, "", 13, { Position = UDim2.new(0.5, 0, 0, 56 + Theme.safeTop()), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 460, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.TextDim, Visible = false })
	-- Downed overlay.
	downedOverlay = Theme.frame(gui, { BackgroundColor3 = Color3.fromRGB(40, 8, 8), BackgroundTransparency = 0.55, Visible = false })
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0) })
	grad.Rotation = 90
	grad.Parent = downedOverlay
	downedText = Theme.label(downedOverlay, "", 20, { Position = UDim2.new(0.5, 0, 0.6, 0), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 600, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold })
	local selfBtn = Theme.button(downedOverlay, "ПОПЫТАТЬСЯ ВСТАТЬ", function()
		task.spawn(function()
			local ok, res = pcall(function()
				return Net.func("RescueAction"):InvokeServer("self")
			end)
			if ok and res and not res.ok then
				HUDController.Notify({ title = "Не получается", text = res.reason, kind = "warn" })
			end
		end)
	end, { Position = UDim2.new(0.5, 0, 0.6, 70), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 260, 0, 36) })
	selfBtn.Name = "SelfRescue"
	-- Mobile controls.
	if Theme.isMobile() then
		local col = Theme.frame(gui, { Position = UDim2.new(1, -16, 1, -60), AnchorPoint = Vector2.new(1, 1), Size = UDim2.new(0, 110, 0, 150), BackgroundTransparency = 1 })
		Theme.list(col, 6)
		local run = Theme.button(col, "БЕГ", nil, { Size = UDim2.new(1, 0, 0, 44) })
		run.MouseButton1Down:Connect(function()
			CameraController.ToggleSprint(true)
		end)
		run.MouseButton1Up:Connect(function()
			CameraController.ToggleSprint(false)
		end)
		Theme.button(col, "ПРИСЕСТЬ", function()
			CameraController.ToggleCrouch()
		end, { Size = UDim2.new(1, 0, 0, 44) })
		Theme.button(col, "ФОНАРЬ", function()
			FlashlightController.Toggle()
		end, { Size = UDim2.new(1, 0, 0, 44) })
	end
end

-- ===== state application ====================================================

local function applyFlags(f)
	for k, v in f do
		HUDController.Flags[k] = v
	end
	local F = HUDController.Flags
	if f.heat ~= nil then
		tempFill.Size = UDim2.new(math.clamp(F.heat / GameConfig.Temperature.Max, 0, 1), 0, 1, 0)
		tempLabel.Text = string.format("ТЕМПЕРАТУРА ТЕЛА  %.1f °C", F.bodyTemp or 36.6)
		local color = if (F.coldStage or 0) >= 2 then Theme.Colors.Danger elseif (F.coldStage or 0) == 1 then Theme.Colors.Warm else Theme.Colors.Accent
		tempFill.BackgroundColor3 = color
	end
	if f.downed ~= nil then
		downedOverlay.Visible = F.downed and not F.eliminated
		CameraController.SetDowned(F.downed == true)
		if F.downed then
			FlashlightController.ForceOff()
		end
	end
	if F.eliminated then
		downedOverlay.Visible = false
	end
	if F.downed then
		local reason = if F.downedReason == "cold" then "Вы замерзаете. Нужно тепло или аптечка." else "Вы выведены из строя. Ждите помощи."
		downedText.Text = string.format("%s\n%d с", reason, math.floor(F.downedSeconds or 0))
		local btn = downedOverlay:FindFirstChild("SelfRescue")
		if btn then
			btn.Visible = (F.selfRescueCharges or 0) > 0 and not F.selfRescuing
		end
	end
end

function HUDController.ApplyRoundState(state)
	local prev = HUDController.Phase
	HUDController.Phase = state.phase
	gui.Enabled = state.phase ~= "Idle" and state.phase ~= "Boarding"
	if prev ~= state.phase then
		HUDController.PhaseChanged:Fire(state.phase, prev)
	end
	if state.phase == "Idle" then
		for id, row in taskRows do
			row:Destroy()
			taskRows[id] = nil
		end
		setBanner(nil)
		downedOverlay.Visible = false
		closeModal()
		return
	end
	titleLabel.Text = state.title or ""
	local stageNames = { Arrival = "Прибытие", Exploration = "Вечерняя смена", Incident = "Инцидент", Escalation = "Обстановка ухудшается", NightPrep = "Подготовка к ночи", Night = "Ночь · регламент", Dawn = "Рассвет · эвакуация", Results = "Итоги", Boarding = "Посадка" }
	stageLabel.Text = stageNames[state.stage] or state.stage or ""
	if state.tasks then
		for _, t in state.tasks do
			applyTask(t)
		end
	end
	if state.clock then
		clockLabel.Text = state.clock.text
		clockLabel.TextColor3 = if state.clock.night then Theme.Colors.Danger else Theme.Colors.Accent
	end
	if state.players and #state.players > 1 then
		local lines = {}
		for _, p in state.players do
			local status = if p.eliminated then "потерян" elseif p.downed then "НУЖНА ПОМОЩЬ" elseif p.evacuated then "на борту" elseif not p.present then "вне связи" else string.format("%d%%", p.heat or 100)
			table.insert(lines, p.name .. " — " .. status)
		end
		teamList.Text = table.concat(lines, "\n")
	else
		teamList.Text = ""
	end
	if state.phase == "Evacuation" and state.evacCountdown then
		setBanner(string.format("БОРТ НА ПЛОЩАДКЕ · %d с", state.evacCountdown), Theme.Colors.Good)
		evacLabel.Text = "Идите к огням площадки (северо-запад от К-1)"
		evacLabel.Visible = true
	elseif state.stage == "Night" then
		setBanner("22:00 — НЕ ПОКИДАЙТЕ СПАЛЬНЫЙ СЕКТОР", Theme.Colors.Danger)
		evacLabel.Visible = false
	elseif state.stage == "NightPrep" then
		setBanner("СКОРО 22:00 · ГЕНЕРАТОР · КРЫШКА · ЛЮДИ", Theme.Colors.Warm)
		evacLabel.Visible = false
	else
		setBanner(nil)
		evacLabel.Visible = false
	end
end

function HUDController.ShowBriefing(b)
	local body = openModal("Брифинг · " .. (b.title or ""), 640, 460)
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 8)
	Theme.label(scroll, string.format("%s · опасность: %s", b.kind or "", b.danger or ""), 13, { TextColor3 = Theme.Colors.TextDim })
	Theme.header(scroll, "Обстановка")
	for _, line in b.briefing or {} do
		Theme.label(scroll, line, 14, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
	Theme.header(scroll, "Задачи")
	for _, t in b.tasks or {} do
		Theme.label(scroll, (if t.optional then "◇ " else "○ ") .. t.label, 14)
	end
	Theme.header(scroll, "Регламент")
	for _, w in b.warnings or {} do
		Theme.label(scroll, "! " .. w, 13, { TextColor3 = Theme.Colors.Warm, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
	Theme.button(scroll, "ПРИНЯТО", closeModal)
	if b.seconds then
		task.delay(b.seconds, function()
			if modalGui and modalGui.Parent then
				closeModal()
			end
		end)
	end
end

function HUDController.ShowResults(r)
	local body = openModal(if r.success then "Смена завершена" else "Смена провалена", 560, 440)
	Theme.list(body, 6)
	Theme.label(body, r.reason or "", 15, { Font = Theme.FontBold, TextColor3 = if r.success then Theme.Colors.Good else Theme.Colors.Danger })
	Theme.label(body, string.format("%s · %d мин · документов: %d · ночь: %s", r.title or "", math.floor((r.duration or 0) / 60), r.documents or 0, if r.nightSurvived then "пережита" else "—"), 12, { TextColor3 = Theme.Colors.TextDim })
	Theme.header(body, "Начисления")
	for _, line in r.lines or {} do
		Theme.label(body, string.format("%s  %s%d", line.label, if line.value >= 0 then "+" else "", line.value), 14)
	end
	Theme.label(body, "ИТОГО: " .. tostring(r.reward or 0), 18, { Font = Theme.FontBold, TextColor3 = Theme.Colors.Accent })
	Theme.button(body, "ВЕРНУТЬСЯ НА БАЗУ", function()
		task.spawn(function()
			pcall(function()
				Net.func("ReturnToLobby"):InvokeServer()
			end)
		end)
		closeModal()
	end)
	Theme.playUISound(if r.success then "UIConfirm" else "UIError")
end

function HUDController.ShowDocument(d)
	local body = openModal(d.kind .. " · " .. d.title, 620, 480)
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 6)
	Theme.label(scroll, "Автор: " .. (d.author or "—") .. (if d.isNew then "   · НОВЫЙ ДОКУМЕНТ" else ""), 12, { TextColor3 = if d.isNew then Theme.Colors.Good else Theme.Colors.TextDim })
	Theme.label(scroll, d.body or "", 15, { Font = Theme.FontMono, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	Theme.button(scroll, "ЗАКРЫТЬ", closeModal)
	Theme.playUISound("UIConfirm")
end

function HUDController.init()
	build()
	Net.event("RoundState").OnClientEvent:Connect(HUDController.ApplyRoundState)
	Net.event("TaskUpdated").OnClientEvent:Connect(function(t)
		applyTask(t)
	end)
	Net.event("Notification").OnClientEvent:Connect(HUDController.Notify)
	Net.event("Briefing").OnClientEvent:Connect(HUDController.ShowBriefing)
	Net.event("Results").OnClientEvent:Connect(HUDController.ShowResults)
	Net.event("DocumentFound").OnClientEvent:Connect(HUDController.ShowDocument)
	Net.event("Subtitle").OnClientEvent:Connect(function(payload)
		if payload and payload.lines then
			HUDController.Lines(payload.lines)
		end
	end)
	Net.event("StoryEvent").OnClientEvent:Connect(function(payload)
		if payload and payload.text then
			HUDController.Subtitle(payload.text, 4)
		end
	end)
	Net.event("ClockState").OnClientEvent:Connect(function(c)
		clockLabel.Text = c.text
		clockLabel.TextColor3 = if c.night then Theme.Colors.Danger else Theme.Colors.Accent
	end)
	Net.event("PowerState").OnClientEvent:Connect(function(ps)
		if not ps then
			return
		end
		local g = ps.generator
		powerLights.gen.BackgroundColor3 = if g.running and not g.tripped then (if g.degraded or g.fault then Theme.Colors.Warm else Theme.Colors.Good) else Theme.Colors.Danger
		for _, c in ps.circuits do
			local dot = powerLights[c.id]
			if dot then
				dot.BackgroundColor3 = if c.powered then Theme.Colors.Good elseif c.on then Theme.Colors.Warm else Theme.Colors.TextDim
			end
		end
	end)
	Net.event("PlayerFlags").OnClientEvent:Connect(applyFlags)
	Net.event("InventoryUpdated").OnClientEvent:Connect(function(inv)
		inventory = inv
		toolLabel.Text = if inv.toolName then "Инструмент: " .. inv.toolName else ""
		rebuildItems()
	end)
	Net.event("HeadcountResult").OnClientEvent:Connect(function(h)
		local text = string.format("ПЕРЕСЧЁТ (%s): в секторе %d, по журналу %d", h.by or "", h.bodies or 0, h.roster or 0)
		HUDController.Notify({ title = "Пересчёт участников", text = text, kind = if (h.bodies or 0) ~= (h.roster or 0) then "danger" else "info" })
	end)
	Net.event("ScannerEvent").OnClientEvent:Connect(function(e)
		HUDController.Notify({ title = "Контроль входа · " .. (e.name or ""), text = e.reason or "", kind = if e.ok then "info" else "danger" })
	end)
	Net.event("SignalBroadcast").OnClientEvent:Connect(function(s)
		HUDController.Notify({ title = s.sender, text = s.text, kind = "info" })
	end)
	Net.event("Cinematic").OnClientEvent:Connect(function(c)
		if c.kind == "Boarding" then
			gui.Enabled = false
		end
	end)
	-- Local polling for stamina and the cosmetic battery bar.
	task.spawn(function()
		while true do
			task.wait(0.15)
			if gui.Enabled then
				stamFill.Size = UDim2.new(CameraController.Stamina / GameConfig.Character.StaminaMax, 0, 1, 0)
				local b = FlashlightController.Battery / GameConfig.Flashlight.BatterySeconds
				batFill.Size = UDim2.new(math.clamp(b, 0, 1), 0, 1, 0)
				batLabel.Text = string.format("ФОНАРЬ [F]  %s", if FlashlightController.On then "вкл" else "выкл")
				batFill.BackgroundColor3 = if b < 0.2 then Theme.Colors.Danger else Theme.Colors.Warm
			end
		end
	end)
end

return HUDController
