--!nonstrict
-- Main menu on join, pause/settings menu, and the team-signal wheel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signals = require(ReplicatedStorage.Shared.Config.Signals)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)
local LobbyUIController = require(script.Parent.LobbyUIController)

local player = Players.LocalPlayer
local C = Theme.Colors

local MenuController = {}

local menuGui: ScreenGui? = nil
local signalGui: ScreenGui? = nil
local lastSignal = 0

local function slider(parent: Instance, label: string, key: string, min: number, max: number, step: number, fmt: ((number) -> string)?)
	local row = Theme.frame(parent, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	local l = Theme.label(row, label, 13, { Size = UDim2.new(0.5, 0, 0, 18) })
	local val = Theme.label(row, "", 13, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Accent })
	local track = Theme.frame(row, { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = C.PanelAlt })
	Theme.corner(track, 7)
	local fill = Theme.frame(track, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Accent })
	Theme.corner(fill, 7)
	local function render()
		local v = SettingsStore.Current[key]
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		val.Text = if fmt then fmt(v) else string.format("%d%%", math.floor((v - min) / (max - min) * 100 + 0.5))
	end
	local dragging = false
	local function setFromX(x: number)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = min + rel * (max - min)
		v = math.floor(v / step + 0.5) * step
		SettingsStore.set(key, v)
		render()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	-- Gamepad/keyboard friendly nudge buttons
	Theme.button(row, "−", function()
		SettingsStore.set(key, math.clamp(SettingsStore.Current[key] - step, min, max))
		render()
	end, { Size = UDim2.new(0, 26, 0, 18), Position = UDim2.new(1, -56, 0, 0), TextSize = 12 })
	Theme.button(row, "+", function()
		SettingsStore.set(key, math.clamp(SettingsStore.Current[key] + step, min, max))
		render()
	end, { Size = UDim2.new(0, 26, 0, 18), Position = UDim2.new(1, -26, 0, 0), TextSize = 12 })
	render()
	local _ = l
end

local function toggle(parent: Instance, label: string, key: string)
	local b
	b = Theme.button(parent, "", function()
		SettingsStore.set(key, not SettingsStore.Current[key])
		b.Text = (SettingsStore.Current[key] and "■ " or "□ ") .. label
	end, { TextXAlignment = Enum.TextXAlignment.Left })
	b.Text = (SettingsStore.Current[key] and "■ " or "□ ") .. label
end

local function settingsPanel(parent: Instance)
	local s = Theme.scroll(parent)
	Theme.list(s, 6)
	Theme.header(s, "Звук")
	slider(s, "Музыка", "musicVolume", 0, 1, 0.05)
	slider(s, "Эффекты", "sfxVolume", 0, 1, 0.05)
	slider(s, "Окружение", "ambientVolume", 0, 1, 0.05)
	Theme.header(s, "Управление и камера")
	slider(s, "Чувствительность", "sensitivity", 0.05, 1, 0.05)
	slider(s, "Интенсивность движения камеры", "cameraShake", 0, 1, 0.1)
	Theme.header(s, "Интерфейс")
	slider(s, "Размер текста", "textScale", 0.8, 1.5, 0.1, function(v)
		return string.format("%d%%", v * 100)
	end)
	toggle(s, "Субтитры", "subtitles")
	Theme.header(s, "Графика")
	slider(s, "Качество эффектов", "effectsQuality", 0, 2, 1, function(v)
		return ({ "низкое", "среднее", "высокое" })[v + 1]
	end)
	Theme.label(s, "Управление: WASD — движение, Shift — бег, C — присесть, F — фонарь, E — взаимодействие, T — сигналы, M — меню. Геймпад: L3 бег, B присесть, Y фонарь, X взаимодействие, DPad↑ сигналы.", 12, { TextColor3 = C.TextDim, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
end

function MenuController.closeMenu()
	if menuGui then
		menuGui:Destroy()
		menuGui = nil
		CameraController.InputLocked = false
	end
end

function MenuController.openMenu(isMain: boolean)
	if menuGui then
		MenuController.closeMenu()
		return
	end
	LobbyUIController.close()
	local g = Theme.screen("NS_Menu", 60)
	menuGui = g
	CameraController.InputLocked = true
	local dim = Theme.frame(g, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = if isMain then 0.15 else 0.5 })
	local panel = Theme.frame(dim, { Size = UDim2.new(0, 760, 0, 480), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Bg })
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(760, 480)
	sc.Parent = panel
	panel.Size = UDim2.new(0.94, 0, 0.9, 0)
	Theme.stroke(panel)
	Theme.corner(panel, 4)
	Theme.padding(panel, 18)
	local left = Theme.frame(panel, { Size = UDim2.new(0, 260, 1, 0), BackgroundTransparency = 1 })
	Theme.list(left, 8)
	Theme.label(left, GameConfig.GameName, 26, { Font = Theme.FontBold, TextColor3 = C.Accent, Size = UDim2.new(1, 0, 0, 64) })
	Theme.label(left, "COMPLEX-17 · ночная техническая смена · v" .. GameConfig.Version, 12, { TextColor3 = C.TextDim })
	if isMain then
		Theme.label(left, "Вы — технический сотрудник. Выполняйте работы, следите за объектом и выберитесь живым.", 13, { TextColor3 = C.TextDim, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		Theme.button(left, "НАЧАТЬ СМЕНУ", function()
			MenuController.closeMenu()
		end, { BackgroundColor3 = Color3.fromRGB(60, 50, 20) })
	else
		Theme.button(left, "ПРОДОЛЖИТЬ", function()
			MenuController.closeMenu()
		end)
		Theme.button(left, "ПОКИНУТЬ СМЕНУ (в лобби)", function()
			-- Only available from the results screen server-side; otherwise informs the player.
			local r = Net.func("ReturnToLobby"):InvokeServer()
			if r and r.ok then
				MenuController.closeMenu()
			else
				Theme.playUISound("UIError")
			end
		end)
	end
	Theme.label(left, "Игра работает строго от первого лица. Инструменты не являются оружием; основная защита — наблюдательность, скрытность и команда.", 12, { TextColor3 = C.TextDim, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local right = Theme.frame(panel, { Position = UDim2.new(0, 280, 0, 0), Size = UDim2.new(1, -280, 1, 0), BackgroundTransparency = 1 })
	settingsPanel(right)
end

local function sendSignal(id: string)
	if os.clock() - lastSignal < GameConfig.Communication.SignalCooldown then
		Theme.playUISound("UIError")
		return
	end
	lastSignal = os.clock()
	Net.event("SignalSend"):FireServer(id)
	Theme.playUISound("UIClick")
end

function MenuController.toggleSignals()
	if signalGui then
		signalGui:Destroy()
		signalGui = nil
		CameraController.InputLocked = false
		return
	end
	local g = Theme.screen("NS_Signals", 55)
	signalGui = g
	CameraController.InputLocked = true
	local panel = Theme.frame(g, { Size = UDim2.new(0, 420, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1 })
	Theme.stroke(panel, C.Accent)
	Theme.corner(panel, 4)
	Theme.padding(panel, 12)
	Theme.list(panel, 4)
	Theme.label(panel, "КОМАНДНЫЙ СИГНАЛ", 14, { Font = Theme.FontBold, TextColor3 = C.Accent })
	for i, s in Signals.List do
		Theme.button(panel, string.format("%d · %s", i % 10, s.text), function()
			sendSignal(s.id)
			MenuController.toggleSignals()
		end, { TextColor3 = s.color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, if Theme.isMobile() then 40 else 30), TextSize = 14 })
	end
	Theme.label(panel, "Esc / T — закрыть", 11, { TextColor3 = C.TextDim })
end

function MenuController.init()
	ContextActionService:BindAction("NS_Menu", function(_, state)
		if state == Enum.UserInputState.Begin then
			if signalGui then
				MenuController.toggleSignals()
			else
				MenuController.openMenu(false)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
	ContextActionService:BindAction("NS_Signals", function(_, state)
		if state == Enum.UserInputState.Begin then
			MenuController.toggleSignals()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.T, Enum.KeyCode.DPadUp)
	-- Number keys while the signal panel is open
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not signalGui then
			return
		end
		local idx = nil
		for i = 1, 10 do
			local key = Enum.KeyCode[if i == 10 then "Zero" else ({ "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" })[i]]
			if input.KeyCode == key then
				idx = i
			end
		end
		if idx and Signals.List[idx] then
			sendSignal(Signals.List[idx].id)
			MenuController.toggleSignals()
		end
	end)
	-- Mobile: persistent menu + signals buttons at the top
	if Theme.isMobile() then
		local g = Theme.screen("NS_MobileTop", 20)
		local f = Theme.frame(g, { Position = UDim2.new(1, -20, 0, 20), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 150, 0, 40), BackgroundTransparency = 1 })
		Theme.list(f, 6, true)
		Theme.button(f, "МЕНЮ", function()
			MenuController.openMenu(false)
		end, { Size = UDim2.new(0, 70, 0, 40), BackgroundColor3 = C.Bg })
		Theme.button(f, "СИГНАЛ", function()
			MenuController.toggleSignals()
		end, { Size = UDim2.new(0, 74, 0, 40), BackgroundColor3 = C.Bg })
	end
	SettingsStore.Changed:Connect(function(s)
		Theme.setTextScale(s.textScale)
		Theme.sfxVolume = s.sfxVolume
	end)
	-- Main menu once on join
	task.delay(0.5, function()
		MenuController.openMenu(true)
	end)
	local _ = player
end

return MenuController
