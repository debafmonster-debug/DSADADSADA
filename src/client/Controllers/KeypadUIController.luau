--!nonstrict
-- Keypad for the warehouse code lock. Digits are entered locally and sent
-- as one string; the server counts attempts and enforces the lockout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)
local InteractionController = require(script.Parent.InteractionController)

local KeypadUIController = {}

local gui: ScreenGui? = nil
local entered = ""
local display: TextLabel

local function close()
	if gui then
		gui:Destroy()
		gui = nil
		CameraController.Unlock("keypad")
	end
end

local function refresh()
	local shown = entered .. string.rep("·", GameConfig.Warehouse.CodeLength - #entered)
	display.Text = shown
end

local function submit()
	if #entered ~= GameConfig.Warehouse.CodeLength then
		return
	end
	local code = entered
	entered = ""
	refresh()
	task.spawn(function()
		local ok, res = pcall(function()
			return Net.func("KeypadSubmit"):InvokeServer(code)
		end)
		if not ok then
			HUDController.Notify({ title = "Замок", text = tostring(res), kind = "danger" })
			return
		end
		if res.ok then
			Theme.playUISound("KeypadAccept")
			HUDController.Notify({ title = "Замок открыт", text = "Склад №2 доступен.", kind = "good" })
			close()
		else
			Theme.playUISound("KeypadDeny")
			if display then
				display.Text = "ОШИБКА"
				task.delay(1, refresh)
			end
			HUDController.Notify({ title = "Кодовый замок", text = res.reason or "", kind = "warn" })
		end
	end)
end

local function open()
	close()
	entered = ""
	gui = Theme.screen("V9_Keypad", 45)
	CameraController.Lock("keypad")
	local body = Theme.modal(gui, "Кодовый замок · склад №2", 300, 420, close)
	Theme.list(body, 6)
	display = Theme.label(body, "", 32, { Font = Theme.FontMono, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.Accent, Size = UDim2.new(1, 0, 0, 44) })
	refresh()
	Theme.label(body, "3 ошибки — блокировка на сутки", 11, { TextColor3 = Theme.Colors.Danger, TextXAlignment = Enum.TextXAlignment.Center })
	local grid = Theme.frame(body, { Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1 })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.3, 0, 0, 48)
	layout.CellPadding = UDim2.new(0.05, 0, 0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local order = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK" }
	for i, k in order do
		local b = Theme.button(grid, k, function()
			Theme.playUISound("KeypadKey")
			if k == "C" then
				entered = ""
			elseif k == "OK" then
				submit()
				return
			elseif #entered < GameConfig.Warehouse.CodeLength then
				entered ..= k
			end
			refresh()
		end, { TextSize = 18, Font = Theme.FontMono })
		b.LayoutOrder = i
	end
end

function KeypadUIController.init()
	InteractionController.OpenUI:Connect(function(ui)
		if ui == "Keypad" then
			open()
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase == "Idle" then
			close()
		end
	end)
end

return KeypadUIController
