--!nonstrict
-- In-shift HUD: objective & tasks, player status, notifications, subtitles,
-- team signals, downed overlay, briefing, results and document reader.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Signals = require(ReplicatedStorage.Shared.Config.Signals)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local SettingsStore = require(script.Parent.SettingsStore)

local player = Players.LocalPlayer
local C = Theme.Colors

local HUDController = {}
HUDController.PhaseChanged = Signal.new()
HUDController.Phase = "Idle"

local gui: ScreenGui
local objectiveLabel: TextLabel
local taskList: Frame
local statusFrame: Frame
local healthBar: Frame
local staminaBar: Frame
local batteryBar: Frame
local toolLabel: TextLabel
local notifStack: Frame
local subtitle: TextLabel
local alarmBanner: Frame
local evacLabel: TextLabel
local downedOverlay: Frame
local downedTimer: TextLabel
local selfRescueBtn: TextButton
local phaseLabel: TextLabel
local teamFrame: Frame
local mobileFrame: Frame
local modalGui: ScreenGui
local currentState = nil

local function bar(parent: Instance, name: string, color: Color3, y: number): Frame
	local lbl = Theme.label(parent, name, 11, { TextColor3 = C.TextDim, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 12) })
	lbl.Name = name .. "Label"
	local bg = Theme.frame(parent, { Position = UDim2.new(0, 0, 0, y + 13), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.PanelAlt })
	local fill = Theme.frame(bg, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color })
	fill.Name = "Fill"
	return fill
end

local function buildStatus()
	statusFrame = Theme.frame(gui, { Name = "Status", Position = UDim2.new(0, 20, 1, -20), AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(0, 220, 0, 110), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.35 })
	Theme.stroke(statusFrame)
	Theme.corner(statusFrame)
	Theme.padding(statusFrame, 10)
	healthBar = bar(statusFrame, "СОСТОЯНИЕ", C.Good, 0)
	staminaBar = bar(statusFrame, "ВЫНОСЛИВОСТЬ", C.Info, 26)
	batteryBar = bar(statusFrame, "ФОНАРЬ [F]", C.Accent, 52)
	toolLabel = Theme.label(statusFrame, "", 12, { Position = UDim2.new(0, 0, 0, 78), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.Text })
end

local function buildObjective()
	local panel = Theme.frame(gui, { Name = "Objective", Position = UDim2.new(0, 20, 0, 20), Size = UDim2.new(0, 340, 0, 40), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.35, AutomaticSize = Enum.AutomaticSize.Y })
	Theme.stroke(panel)
	Theme.corner(panel)
	Theme.padding(panel, 10)
	Theme.list(panel, 4)
	phaseLabel = Theme.label(panel, "", 11, { TextColor3 = C.Accent, Font = Theme.FontBold, LayoutOrder = 0 })
	objectiveLabel = Theme.label(panel, "", 16, { Font = Theme.FontBold, LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	taskList = Theme.frame(panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
	Theme.list(taskList, 3)
	evacLabel = Theme.label(panel, "", 14, { TextColor3 = C.Good, Font = Theme.FontBold, LayoutOrder = 3 })
	teamFrame = Theme.frame(panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4 })
	Theme.list(teamFrame, 2)
end

local function buildNotifications()
	notifStack = Theme.frame(gui, { Name = "Notifications", Position = UDim2.new(1, -20, 0, 20), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 320, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y })
	Theme.list(notifStack, 6)
	subtitle = Theme.label(gui, "", 16, { Position = UDim2.new(0.5, 0, 1, -150), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 600, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), Font = Theme.FontBold })
	alarmBanner = Theme.frame(gui, { Name = "Alarm", Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 360, 0, 30), BackgroundColor3 = C.Danger, BackgroundTransparency = 0.2, Visible = false })
	Theme.corner(alarmBanner)
	Theme.label(alarmBanner, "⚠ АВАРИЙНЫЙ РЕЖИМ · НАРУШЕНИЕ ИЗОЛЯЦИИ", 14, { Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1) })
end

local function buildDowned()
	downedOverlay = Theme.frame(gui, { Name = "Downed", BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.55, Visible = false, ZIndex = 5 })
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) })
	grad.Rotation = 90
	grad.Parent = downedOverlay
	local box = Theme.frame(downedOverlay, { Position = UDim2.new(0.5, 0, 0.72, 0), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 360, 0, 120), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.2, ZIndex = 6 })
	Theme.stroke(box, C.Danger, 2)
	Theme.corner(box)
	Theme.padding(box, 12)
	Theme.label(box, "ВЫ ВЫВЕДЕНЫ ИЗ СТРОЯ", 18, { Font = Theme.FontBold, TextColor3 = C.Danger, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	downedTimer = Theme.label(box, "", 14, { Position = UDim2.new(0, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
	selfRescueBtn = Theme.button(box, "ИНЪЕКЦИЯ (самоспасение)", function()
		local r = Net.func("RescueAction"):InvokeServer("self")
		if r and r.ok then
			selfRescueBtn.Active = false
			selfRescueBtn.Text = "ИНЪЕКЦИЯ ДЕЙСТВУЕТ..."
		elseif r then
			HUDController.Notify({ title = "Инъекция", text = tostring(r.reason), kind = "warn" })
		end
	end, { Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 36), ZIndex = 7 })
end

local function buildMobile()
	if not Theme.isMobile() then
		return
	end
	mobileFrame = Theme.frame(gui, { Name = "Mobile", Position = UDim2.new(1, -20, 1, -20), AnchorPoint = Vector2.new(1, 1), Size = UDim2.new(0, 70, 0, 230), BackgroundTransparency = 1 })
	Theme.list(mobileFrame, 8)
	local function mb(text, fn, hold)
		local b = Theme.button(mobileFrame, text, nil, { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.Bg })
		if hold then
			b.MouseButton1Down:Connect(function()
				fn(true)
			end)
			b.MouseButton1Up:Connect(function()
				fn(false)
			end)
		else
			b.Activated:Connect(fn)
		end
		return b
	end
	mb("БЕГ", function(on)
		CameraController.ToggleSprint(on)
	end, true)
	mb("ПРИСЕСТЬ", function()
		CameraController.ToggleCrouch()
	end)
	mb("ФОНАРЬ", function()
		CameraController.ToggleFlashlight()
	end)
end

function HUDController.Notify(n: { title: string, text: string, kind: string? })
	local color = if n.kind == "danger" then C.Danger elseif n.kind == "warn" then C.Accent elseif n.kind == "good" then C.Good elseif n.kind == "terminal" then C.Terminal elseif n.kind == "story" then Color3.fromRGB(190, 160, 255) else C.Info
	local card = Theme.frame(notifStack, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Bg, BackgroundTransparency = 0.2 })
	Theme.stroke(card, color)
	Theme.corner(card)
	Theme.padding(card, 10)
	local accent = Theme.frame(card, { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(0, -10, 0, 0), BackgroundColor3 = color })
	accent.Name = "Accent"
	Theme.label(card, n.title, 13, { Font = Theme.FontBold, TextColor3 = color })
	Theme.label(card, n.text, 13, { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = if n.kind == "terminal" then Theme.FontMono else Theme.Font })
	if n.kind == "danger" then
		Theme.playUISound("UIError")
	elseif n.kind == "good" or n.kind == "story" then
		Theme.playUISound("UIConfirm")
	end
	task.delay(if n.kind == "terminal" then 12 else 6, function()
		Theme.tween(card, { BackgroundTransparency = 1 }, 0.4)
		task.wait(0.4)
		card:Destroy()
	end)
	if #notifStack:GetChildren() > 7 then
		for _, ch in notifStack:GetChildren() do
			if ch:IsA("Frame") then
				ch:Destroy()
				break
			end
		end
	end
end

local subtitleThread: thread? = nil
function HUDController.Subtitle(text: string, seconds: number?)
	if not SettingsStore.Current.subtitles then
		return
	end
	subtitle.Text = text
	if subtitleThread then
		task.cancel(subtitleThread)
	end
	subtitleThread = task.delay(seconds or 3, function()
		subtitle.Text = ""
	end)
end

function HUDController.Signal(s)
	local def = Signals.ById[s.id]
	local color = if def then def.color else C.Info
	HUDController.Notify({ title = s.sender, text = "«" .. s.text .. "»", kind = "info" })
	HUDController.Subtitle(string.format("%s: %s", s.sender, s.text), 4)
	-- World marker at the sender's position (what the sender knows: where they are).
	if s.position and s.senderId ~= player.UserId then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = s.position + Vector3.new(0, 3, 0)
		part.Parent = workspace.CurrentCamera
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 180, 0, 40)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 400
		bb.Parent = part
		local f = Theme.frame(bb, { BackgroundColor3 = C.Bg, BackgroundTransparency = 0.3 })
		Theme.stroke(f, color, 1.5)
		Theme.corner(f)
		Theme.label(f, s.sender .. ": " .. s.text, 13, { TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Font = Theme.FontBold, TextColor3 = color })
		task.delay(s.lifetime or 6, function()
			part:Destroy()
		end)
	end
end

local function renderTasks(tasks)
	for _, ch in taskList:GetChildren() do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	table.sort(tasks, function(a, b)
		return (a.isMain and 0 or 1) < (b.isMain and 0 or 1)
	end)
	for i, t in tasks do
		local row = Theme.frame(taskList, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i })
		local done = t.status == "complete"
		local color = if done then C.Good elseif t.isMain then C.Text else C.TextDim
		Theme.label(row, string.format("%s %s%s", if done then "■" else "□", if t.isMain then "" else "(доп.) ", t.label), 13, { TextColor3 = color, Size = UDim2.new(1, 0, 0, 16) })
		if not done then
			local bg = Theme.frame(row, { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.PanelAlt })
			Theme.frame(bg, { Size = UDim2.new(math.clamp(t.progress or 0, 0, 1), 0, 1, 0), BackgroundColor3 = C.Accent })
			if t.hint and t.hint ~= "" then
				Theme.label(row, t.hint, 11, { TextColor3 = C.TextDim, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
			end
		end
	end
end

local function renderTeam(players)
	for _, ch in teamFrame:GetChildren() do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
	if not players or #players <= 1 then
		return
	end
	for i, p in players do
		local status = if p.eliminated then "✕" elseif p.downed then "▼" elseif p.evacuated then "✓" else "●"
		local color = if p.eliminated then C.TextDim elseif p.downed then C.Danger elseif p.evacuated then C.Good else C.Text
		Theme.label(teamFrame, status .. " " .. p.name, 12, { TextColor3 = color, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 14) })
	end
end

function HUDController.ApplyRoundState(state)
	currentState = state
	local phase = state.phase or "Idle"
	if phase ~= HUDController.Phase then
		HUDController.Phase = phase
		HUDController.PhaseChanged:Fire(phase)
	end
	local inShift = phase ~= "Idle"
	gui.Enabled = true
	statusFrame.Visible = inShift
	local objectivePanel = gui:FindFirstChild("Objective") :: Frame
	objectivePanel.Visible = inShift
	if mobileFrame then
		mobileFrame.Visible = inShift
	end
	if not inShift then
		alarmBanner.Visible = false
		downedOverlay.Visible = false
		return
	end
	local phaseNames = { Prep = "ПРИБЫТИЕ", Briefing = "БРИФИНГ", Active = "СМЕНА", Evacuation = "ЭВАКУАЦИЯ", Results = "ОТЧЁТ" }
	local minutes = math.floor((state.elapsed or 0) / 60)
	local seconds = math.floor((state.elapsed or 0) % 60)
	phaseLabel.Text = string.format("%s · %s · %02d:%02d · seed %s", phaseNames[phase] or phase, state.title or "", minutes, seconds, tostring(state.seed))
	objectiveLabel.Text = state.objective or ""
	renderTasks(state.tasks or {})
	renderTeam(state.players)
	alarmBanner.Visible = state.incident == true and phase ~= "Results"
	if state.evacCountdown then
		evacLabel.Text = string.format("Шлюз откроется через %d с", math.ceil(state.evacCountdown))
	elseif state.shutterOpen then
		evacLabel.Text = "ШЛЮЗ ОТКРЫТ — на площадку E-1"
	else
		evacLabel.Text = ""
	end
end

function HUDController.ShowBriefing(b)
	if modalGui then
		modalGui:Destroy()
	end
	modalGui = Theme.screen("NS_Modal", 50)
	local body, dim = Theme.modal(modalGui, "Брифинг · " .. b.title, 640, 460)
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 6)
	Theme.label(scroll, string.format("<b>Тип:</b> %s   <b>Опасность:</b> %s", b.kind, b.danger), 14, { TextColor3 = C.TextDim })
	Theme.header(scroll, "Цель смены")
	Theme.label(scroll, "• " .. b.mainTask, 15, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	if b.optionalTask then
		Theme.label(scroll, "• (доп.) " .. b.optionalTask, 15, { TextColor3 = C.TextDim, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(scroll, "Сводка диспетчера")
	for _, line in b.briefing do
		Theme.label(scroll, line, 14, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(scroll, "Предупреждения")
	for _, line in b.warnings do
		Theme.label(scroll, "! " .. line, 14, { TextColor3 = C.Accent, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	end
	Theme.header(scroll, "Эвакуация")
	Theme.label(scroll, b.evacuation, 14)
	local countdown = Theme.label(body, "", 13, { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Right })
	task.spawn(function()
		local t = (b.seconds or 10) + GameConfig.Round.PrepSeconds
		while t > 0 and dim.Parent do
			countdown.Text = string.format("Начало через %d с", t)
			task.wait(1)
			t -= 1
		end
		if dim.Parent then
			dim:Destroy()
		end
	end)
end

function HUDController.ShowResults(r)
	if modalGui then
		modalGui:Destroy()
	end
	modalGui = Theme.screen("NS_Modal", 50)
	local body = Theme.modal(modalGui, if r.success then "Смена завершена" else "Смена провалена", 520, 420)
	local scroll = Theme.scroll(body, { Size = UDim2.new(1, 0, 1, -50) })
	Theme.list(scroll, 6)
	Theme.label(scroll, r.title, 16, { Font = Theme.FontBold })
	Theme.label(scroll, r.reason, 14, { TextColor3 = if r.success then C.Good else C.Danger })
	Theme.label(scroll, string.format("Длительность: %02d:%02d · Seed: %d", math.floor(r.duration / 60), math.floor(r.duration % 60), r.seed), 13, { TextColor3 = C.TextDim })
	Theme.header(scroll, "Отчёт")
	Theme.label(scroll, (r.mainDone and "■" or "□") .. " Основная цель", 14)
	Theme.label(scroll, (r.optionalDone and "■" or "□") .. " Дополнительная задача", 14)
	Theme.label(scroll, (r.evacuated and "■" or "□") .. " Эвакуация", 14)
	Theme.label(scroll, string.format("Найдено документов: %d", r.documents or 0), 14)
	Theme.header(scroll, "Вознаграждение")
	for _, line in r.lines do
		Theme.label(scroll, string.format("%s  <b>%+d</b>", line.label, line.value), 14, { TextColor3 = if line.value < 0 then C.Danger else C.Text })
	end
	Theme.label(scroll, string.format("ИТОГО: <b>%d</b> кредитов", r.reward), 18, { TextColor3 = C.Accent })
	Theme.button(body, "ВЕРНУТЬСЯ В ЛОББИ", function()
		Net.func("ReturnToLobby"):InvokeServer()
		if modalGui then
			modalGui:Destroy()
			modalGui = nil
		end
	end, { Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.PanelAlt })
	Theme.playUISound(if r.success then "UIConfirm" else "UIError")
end

function HUDController.ShowDocument(d)
	if modalGui then
		modalGui:Destroy()
	end
	modalGui = Theme.screen("NS_Modal", 50)
	local body = Theme.modal(modalGui, d.title, 560, 440, function()
		modalGui = nil
	end)
	local scroll = Theme.scroll(body)
	Theme.list(scroll, 6)
	Theme.label(scroll, string.format("%s · %s%s", d.kind, d.author, if d.isNew then "   <font color='#5ad282'>НОВЫЙ ДОКУМЕНТ → АРХИВ</font>" else ""), 13, { TextColor3 = C.TextDim })
	Theme.label(scroll, d.body, 15, { Font = Theme.FontMono, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	CameraController.InputLocked = true
	modalGui.Destroying:Connect(function()
		CameraController.InputLocked = false
	end)
end

function HUDController.init()
	gui = Theme.screen("NS_HUD", 10)
	buildObjective()
	buildStatus()
	buildNotifications()
	buildDowned()
	buildMobile()
	HUDController.ApplyRoundState({ phase = "Idle" })

	Net.event("RoundState").OnClientEvent:Connect(HUDController.ApplyRoundState)
	Net.event("TaskUpdated").OnClientEvent:Connect(function(t)
		if currentState and currentState.tasks then
			local replaced = false
			for i, old in currentState.tasks do
				if old.id == t.id then
					currentState.tasks[i] = t
					replaced = true
				end
			end
			if not replaced then
				table.insert(currentState.tasks, t)
			end
			renderTasks(currentState.tasks)
		end
	end)
	Net.event("Notification").OnClientEvent:Connect(HUDController.Notify)
	Net.event("Briefing").OnClientEvent:Connect(HUDController.ShowBriefing)
	Net.event("Results").OnClientEvent:Connect(HUDController.ShowResults)
	Net.event("DocumentFound").OnClientEvent:Connect(HUDController.ShowDocument)
	Net.event("SignalBroadcast").OnClientEvent:Connect(HUDController.Signal)
	Net.event("FacilityState").OnClientEvent:Connect(function(st)
		if st.alarm then
			HUDController.Subtitle("[сирена] Аварийный режим объекта", 4)
		end
	end)
	Net.event("CreatureState").OnClientEvent:Connect(function(s)
		if s.state == "Suspicious" then
			HUDController.Subtitle("[скрип снаряжения неподалёку]", 2.5)
		elseif s.state == "Chase" then
			HUDController.Subtitle("[тяжёлые быстрые шаги]", 3)
		end
	end)
	Net.event("PlayerFlags").OnClientEvent:Connect(function(f)
		downedOverlay.Visible = f.downed == true
		CameraController.SetDowned(f.downed == true)
		if f.downed then
			selfRescueBtn.Active = (f.selfRescueCharges or 0) > 0 and not f.selfRescuing
			selfRescueBtn.Text = if f.selfRescuing then "ИНЪЕКЦИЯ ДЕЙСТВУЕТ..." else string.format("ИНЪЕКЦИЯ (%d)", f.selfRescueCharges or 0)
			local deadline = f.downedUntil
			task.spawn(function()
				while downedOverlay.Visible and deadline do
					local left = math.max(0, deadline - os.clock())
					downedTimer.Text = string.format("Окно спасения: %d с · ползите к укрытию", math.ceil(left))
					task.wait(0.5)
				end
			end)
		end
	end)

	-- Status bars
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and statusFrame.Visible then
				healthBar.Size = UDim2.new(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 0, 1, 0)
				staminaBar.Size = UDim2.new(CameraController.Stamina / GameConfig.Character.StaminaMax, 0, 1, 0)
				batteryBar.Size = UDim2.new(CameraController.Battery / GameConfig.Flashlight.BatterySeconds, 0, 1, 0)
				batteryBar.BackgroundColor3 = if CameraController.Flashlight then C.Accent else C.TextDim
				local toolId = player:GetAttribute("ActiveTool")
				toolLabel.Text = if toolId and Tools.Defs[toolId] then "Инструмент: " .. Tools.Defs[toolId].name else "Инструмент: —"
			end
		end
	end)
end

return HUDController
