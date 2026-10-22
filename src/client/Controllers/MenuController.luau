--!nonstrict
-- Pause / settings menu and the team signal wheel. The main menu opens only
-- after the intro cinematic; "Продолжить" simply closes it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signals = require(ReplicatedStorage.Shared.Config.Signals)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local SettingsStore = require(script.Parent.SettingsStore)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer

local MenuController = {}

local menuGui: ScreenGui? = nil
local signalsGui: ScreenGui? = nil
local lastSignal = 0

local function closeMenu()
	if menuGui then
		menuGui:Destroy()
		menuGui = nil
		CameraController.Unlock("menu")
	end
end

local function settingsPanel(parent: Frame)
	local scroll = Theme.scroll(parent)
	Theme.list(scroll, 4)
	local S = SettingsStore
	Theme.header(scroll, "Звук")
	Theme.slider(scroll, "Окружение", S.Current.ambientVolume, function(v)
		S.set("ambientVolume", v)
	end)
	Theme.slider(scroll, "Эффекты", S.Current.sfxVolume, function(v)
		S.set("sfxVolume", v)
	end)
	Theme.slider(scroll, "Музыка", S.Current.musicVolume, function(v)
		S.set("musicVolume", v)
	end)
	Theme.slider(scroll, "Диалоги", S.Current.dialogueVolume, function(v)
		S.set("dialogueVolume", v)
	end)
	Theme.toggle(scroll, "Субтитры", S.Current.subtitles, function(v)
		S.set("subtitles", v)
	end)
	Theme.header(scroll, "Управление")
	Theme.slider(scroll, "Чувствительность", S.Current.sensitivity, function(v)
		S.set("sensitivity", math.max(0.05, v))
	end)
	Theme.slider(scroll, "Покачивание камеры", S.Current.cameraShake, function(v)
		S.set("cameraShake", v)
	end)
	Theme.slider(scroll, "Масштаб текста", (S.Current.textScale - 0.8) / 0.7, function(v)
		S.set("textScale", 0.8 + v * 0.7)
	end)
	Theme.header(scroll, "Графика")
	Theme.slider(scroll, "Качество света (тени фонаря)", S.Current.effectsQuality / 2, function(v)
		S.set("effectsQuality", math.floor(v * 2 + 0.5))
	end)
	Theme.slider(scroll, "Плотность частиц (снег, пар)", S.Current.particles / 2, function(v)
		S.set("particles", math.floor(v * 2 + 0.5))
	end)
	Theme.slider(scroll, "Постобработка", S.Current.postFx, function(v)
		S.set("postFx", v)
	end)
	Theme.toggle(scroll, "Иней на стекле и фонаре", S.Current.frost, function(v)
		S.set("frost", v)
	end)
	Theme.toggle(scroll, "Эффект дыхания", S.Current.breath, function(v)
		S.set("breath", v)
	end)
	Theme.label(scroll, "Видимость существ и туман одинаковы для всех настроек: графика не даёт преимущества.", 11, { TextColor3 = Theme.Colors.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
end

function MenuController.Open()
	if menuGui or CameraController.CinematicActive then
		return
	end
	menuGui = Theme.screen("V9_Menu", 60)
	CameraController.Lock("menu")
	local dim = Theme.frame(menuGui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35 })
	local panel = Theme.frame(dim, { Size = UDim2.new(0, 820, 0, 520), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Colors.Bg })
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(820, 520)
	sc.Parent = panel
	panel.Size = UDim2.new(0.94, 0, 0.9, 0)
	Theme.stroke(panel)
	Theme.corner(panel, 4)
	Theme.padding(panel, 16)
	local left = Theme.frame(panel, { Size = UDim2.new(0, 260, 1, 0), BackgroundTransparency = 1 })
	Theme.list(left, 8)
	Theme.label(left, GameConfig.GameName, 22, { Font = Theme.FontBold, TextColor3 = Theme.Colors.Accent, Size = UDim2.new(1, 0, 0, 56) })
	Theme.label(left, GameConfig.GameNameEn .. " · v" .. GameConfig.Version, 11, { TextColor3 = Theme.Colors.TextDim })
	Theme.button(left, "ПРОДОЛЖИТЬ", closeMenu)
	if HUDController.Phase ~= "Idle" then
		Theme.button(left, "ПОКИНУТЬ СМЕНУ", function()
			task.spawn(function()
				local ok, res = pcall(function()
					return Net.func("ReturnToLobby"):InvokeServer()
				end)
				if ok and res and not res.ok then
					HUDController.Notify({ title = "Нельзя", text = res.reason, kind = "warn" })
				end
			end)
			closeMenu()
		end, { TextColor3 = Theme.Colors.Danger })
	end
	Theme.label(left, "WASD — движение · Shift — бег · C — присесть\nF — фонарь · E — взаимодействие · Q — проверить участника\nT — сигнал команде · M — меню", 11, { TextColor3 = Theme.Colors.TextDim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	local right = Theme.frame(panel, { Position = UDim2.new(0, 280, 0, 0), Size = UDim2.new(1, -280, 1, 0), BackgroundTransparency = 1 })
	settingsPanel(right)
end

local function closeSignals()
	if signalsGui then
		signalsGui:Destroy()
		signalsGui = nil
		CameraController.Unlock("signals")
	end
end

local function sendSignal(id: string)
	if os.clock() - lastSignal < GameConfig.Communication.SignalCooldown then
		return
	end
	lastSignal = os.clock()
	Net.event("SignalSend"):FireServer(id)
	closeSignals()
end

function MenuController.OpenSignals()
	if signalsGui or HUDController.Phase == "Idle" or CameraController.CinematicActive then
		return
	end
	signalsGui = Theme.screen("V9_Signals", 55)
	CameraController.Lock("signals")
	local panel = Theme.frame(signalsGui, { Size = UDim2.new(0, 360, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.1 })
	Theme.stroke(panel)
	Theme.corner(panel, 4)
	Theme.padding(panel, 12)
	Theme.list(panel, 4)
	Theme.header(panel, "Сигнал команде")
	for i, s in Signals.List do
		Theme.button(panel, string.format("%d · %s", i % 10, s.text), function()
			sendSignal(s.id)
		end, { TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13 })
	end
	Theme.button(panel, "ЗАКРЫТЬ", closeSignals)
end

function MenuController.init()
	SettingsStore.Changed:Connect(function(cur)
		Theme.setTextScale(cur.textScale)
		Theme.sfxVolume = cur.sfxVolume
	end)
	ContextActionService:BindAction("V9_Menu", function(_, state)
		if state == Enum.UserInputState.Begin then
			if menuGui then
				closeMenu()
			else
				MenuController.Open()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
	ContextActionService:BindAction("V9_Signals", function(_, state)
		if state == Enum.UserInputState.Begin then
			if signalsGui then
				closeSignals()
			else
				MenuController.OpenSignals()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.T, Enum.KeyCode.DPadUp)
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero }
	ContextActionService:BindAction("V9_SignalPick", function(_, state, input)
		if state == Enum.UserInputState.Begin and signalsGui then
			local idx = table.find(keys, input.KeyCode)
			local s = idx and Signals.List[idx]
			if s then
				sendSignal(s.id)
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
	if Theme.isMobile() then
		local top = Theme.screen("V9_MobileTop", 20)
		local row = Theme.frame(top, { Position = UDim2.new(0.5, 0, 0, 8 + Theme.safeTop()), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 220, 0, 36), BackgroundTransparency = 1 })
		Theme.list(row, 8, true)
		Theme.button(row, "МЕНЮ", MenuController.Open, { Size = UDim2.new(0, 100, 1, 0) })
		Theme.button(row, "СИГНАЛ", MenuController.OpenSignals, { Size = UDim2.new(0, 100, 1, 0) })
	end
	player.CharacterAdded:Connect(closeSignals)
end

return MenuController
