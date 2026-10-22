--!nonstrict
-- Radio console screen: frequency dial with coarse/fine steps, signal
-- quality meter, preset phrases and the transmission log. The server owns
-- tuning, quality and replies; this screen only sends ids and numbers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)
local InteractionController = require(script.Parent.InteractionController)

local RadioUIController = {}

local gui: ScreenGui? = nil
local state = nil
local freqLabel, qualityFill, qualityLabel, logFrame, powerLabel

local function call(name: string, ...)
	local ok, res = pcall(function(...)
		return Net.func(name):InvokeServer(...)
	end, ...)
	if not ok then
		HUDController.Notify({ title = "Радио", text = tostring(res), kind = "danger" })
		return nil
	end
	if typeof(res) == "table" and res.ok == false then
		HUDController.Notify({ title = "Радио", text = res.reason or "", kind = "warn" })
		return nil
	end
	return res
end

local function close()
	if gui then
		gui:Destroy()
		gui = nil
		CameraController.Unlock("radio")
	end
end

local function render()
	if not gui or not state then
		return
	end
	freqLabel.Text = string.format("%d кГц", state.freq)
	local q = state.quality or 0
	qualityFill.Size = UDim2.new(math.clamp(q, 0, 1), 0, 1, 0)
	qualityFill.BackgroundColor3 = if q >= 0.5 then Theme.Colors.Good elseif q > 0.2 then Theme.Colors.Warm else Theme.Colors.Danger
	qualityLabel.Text = string.format("СИГНАЛ %d%%  ·  антенна: %s", math.floor(q * 100), if state.antenna then "выровнена" else "сбита")
	powerLabel.Text = if state.powered then "ПИТАНИЕ: ЕСТЬ" else "ПИТАНИЕ: НЕТ — линия «РАДИОСВЯЗЬ»"
	powerLabel.TextColor3 = if state.powered then Theme.Colors.Good else Theme.Colors.Danger
	for _, c in logFrame:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for _, entry in state.log do
		local color = if entry.kind == "player" then Theme.Colors.Text elseif entry.kind == "dispatcher" then Theme.Colors.Accent elseif entry.kind == "echo" then Theme.Colors.Danger else Theme.Colors.TextDim
		Theme.label(logFrame, string.format("[%s] %s", entry.who, entry.text), 12, { Font = Theme.FontMono, TextColor3 = color, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
end

local function open()
	close()
	local res = call("RadioQuery")
	if not res then
		return
	end
	state = res.data
	gui = Theme.screen("V9_Radio", 45)
	CameraController.Lock("radio")
	local body = Theme.modal(gui, "Радиостанция Р-140", 760, 520, close)
	local left = Theme.frame(body, { Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	local right = Theme.frame(body, { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 })
	Theme.list(left, 6)
	Theme.header(left, "Частота")
	freqLabel = Theme.label(left, "", 30, { Font = Theme.FontMono, TextColor3 = Theme.Colors.Warm, Size = UDim2.new(1, 0, 0, 36) })
	local row = Theme.frame(left, { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 })
	Theme.list(row, 6, true)
	for _, step in { -100, -10, 10, 100 } do
		Theme.button(row, (if step > 0 then "+" else "") .. tostring(step), function()
			local target = math.clamp(state.freq + step, state.min, state.max)
			local r = call("RadioTune", target)
			if r then
				state = r.data
				render()
			end
		end, { Size = UDim2.new(0.25, -5, 1, 0), TextSize = 13 })
	end
	qualityLabel = Theme.label(left, "", 12, { TextColor3 = Theme.Colors.TextDim })
	local track = Theme.frame(left, { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.Colors.PanelAlt })
	qualityFill = Theme.frame(track, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Colors.Good })
	powerLabel = Theme.label(left, "", 12)
	Theme.header(left, "Передать")
	local phrases = Theme.scroll(left, { Size = UDim2.new(1, 0, 1, -230) })
	Theme.list(phrases, 4)
	for _, p in state.phrases do
		local b = Theme.button(phrases, p.text, function()
			local r = call("RadioSend", p.id)
			if r then
				Theme.playUISound("RadioClick")
			end
		end, { TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, Size = UDim2.new(1, 0, 0, 30) })
		Theme.padding(b, 8)
	end
	Theme.header(right, "Журнал эфира")
	logFrame = Theme.scroll(right, { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30) })
	Theme.list(logFrame, 4)
	render()
end

function RadioUIController.init()
	InteractionController.OpenUI:Connect(function(ui)
		if ui == "Radio" then
			open()
		end
	end)
	Net.event("RadioState").OnClientEvent:Connect(function(s)
		state = s
		render()
		-- Replies are also shown as subtitles to whoever is at the console.
		if gui and s.log and #s.log > 0 then
			local last = s.log[#s.log]
			if last.kind ~= "player" then
				HUDController.Subtitle(last.text, 4, last.who)
			end
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase == "Idle" then
			close()
		end
	end)
end

return RadioUIController
