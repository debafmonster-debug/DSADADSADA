--!nonstrict
-- Programmatic UI toolkit with the game's industrial theme. All screens are
-- built from these helpers so the look stays consistent and scales to
-- phones, tablets, PC and gamepad.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = {}

-- Cold, restrained palette: near-black panels, pale ice accent, one warm
-- orange reserved for the station hull colour, red only for danger.
Theme.Colors = {
	Bg = Color3.fromRGB(10, 12, 16),
	Panel = Color3.fromRGB(16, 19, 24),
	PanelAlt = Color3.fromRGB(24, 28, 35),
	Border = Color3.fromRGB(62, 72, 84),
	Text = Color3.fromRGB(220, 226, 232),
	TextDim = Color3.fromRGB(138, 150, 164),
	Accent = Color3.fromRGB(150, 198, 228),
	Warm = Color3.fromRGB(214, 140, 72),
	Danger = Color3.fromRGB(214, 62, 52),
	Good = Color3.fromRGB(112, 196, 150),
	Info = Color3.fromRGB(110, 160, 210),
	Terminal = Color3.fromRGB(150, 210, 190),
}
Theme.Font = Enum.Font.Gotham
Theme.FontBold = Enum.Font.GothamBold
Theme.FontMono = Enum.Font.Code

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local textScale = 1

function Theme.isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Theme.isGamepad(): boolean
	return UserInputService.GamepadEnabled and UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1
end

function Theme.setTextScale(s: number)
	textScale = s
	for _, gui in playerGui:GetChildren() do
		local scale = gui:FindFirstChild("Scale") :: UIScale?
		if scale then
			scale.Scale = Theme.baseScale() * textScale
		end
	end
end

function Theme.baseScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local s = math.clamp(vp.Y / 900, 0.7, 1.25)
	if Theme.isMobile() then
		s = math.clamp(vp.Y / 700, 0.75, 1.1)
	end
	return s
end

function Theme.screen(name: string, order: number, ignoreInset: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset ~= false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = Theme.baseScale() * textScale
	scale.Parent = gui
	gui.Parent = playerGui
	return gui
end

function Theme.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Colors.Panel
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	if props then
		for k, v in props do
			f[k] = v
		end
	end
	f.Parent = parent
	return f
end

function Theme.stroke(inst: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.Border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function Theme.corner(inst: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 3)
	c.Parent = inst
end

function Theme.padding(inst: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = u, u, u, u
	p.Parent = inst
end

function Theme.list(parent: Instance, gap: number?, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end

function Theme.label(parent: Instance, text: string, size: number?, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Theme.Colors.Text
	l.TextSize = size or 16
	l.Font = Theme.Font
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Size = UDim2.new(1, 0, 0, (size or 16) + 6)
	l.RichText = true
	if props then
		for k, v in props do
			l[k] = v
		end
	end
	l.Parent = parent
	return l
end

function Theme.header(parent: Instance, text: string, size: number?): TextLabel
	local l = Theme.label(parent, string.upper(text), size or 20, { Font = Theme.FontBold, TextColor3 = Theme.Colors.Accent })
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Theme.Colors.Border
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = parent
	return l
end

function Theme.button(parent: Instance, text: string, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Colors.PanelAlt
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = Theme.Colors.Text
	b.TextSize = 16
	b.Font = Theme.FontBold
	b.Size = UDim2.new(1, 0, 0, if Theme.isMobile() then 44 else 36)
	b.TextWrapped = true
	if props then
		for k, v in props do
			b[k] = v
		end
	end
	Theme.stroke(b)
	Theme.corner(b)
	b.MouseEnter:Connect(function()
		if b.Active then
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Colors.Border }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = (props and props.BackgroundColor3) or Theme.Colors.PanelAlt }):Play()
	end)
	if onClick then
		b.Activated:Connect(function()
			if b.Active then
				onClick()
			end
		end)
	end
	b.Parent = parent
	return b
end

function Theme.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = Theme.Colors.Border
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	if props then
		for k, v in props do
			s[k] = v
		end
	end
	s.Parent = parent
	return s
end

-- Centered modal panel with title and close button. Returns body frame.
function Theme.modal(gui: ScreenGui, title: string, width: number, height: number, onClose: (() -> ())?): (Frame, Frame)
	local dim = Theme.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Name = "Dim" })
	local panel = Theme.frame(dim, {
		Name = "Panel",
		Size = UDim2.new(0, width, 0, height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Bg,
	})
	-- Constrain to the viewport on small screens.
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(width, height)
	sc.Parent = panel
	panel.Size = UDim2.new(0.94, 0, 0.9, 0)
	Theme.stroke(panel, Theme.Colors.Border, 1)
	Theme.corner(panel, 4)
	local top = Theme.frame(panel, { Name = "Top", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Colors.Panel })
	local accent = Theme.frame(top, { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Theme.Colors.Accent })
	accent.Name = "Accent"
	local t = Theme.label(top, string.upper(title), 18, { Font = Theme.FontBold, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -80, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
	t.Name = "Title"
	local close = Theme.button(top, "✕", function()
		dim:Destroy()
		if onClose then
			onClose()
		end
	end, { Size = UDim2.new(0, 36, 0, 30), Position = UDim2.new(1, -42, 0, 5), BackgroundColor3 = Theme.Colors.Panel })
	close.Name = "Close"
	local body = Theme.frame(panel, { Name = "Body", Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1 })
	Theme.padding(body, 14)
	return body, dim
end

function Theme.playUISound(name: string)
	local Sounds = require(game:GetService("ReplicatedStorage").Shared.Config.SoundLibrary)
	local def = Sounds[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume * (Theme.sfxVolume or 1)
	s.PlaybackSpeed = def.pitch or 1
	s.Parent = playerGui
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end
Theme.sfxVolume = 1

-- Full-screen black fade used by cinematics and transitions. Returns the frame.
function Theme.fade(order: number?): Frame
	local gui = Theme.screen("V9_Fade", order or 100, true)
	local f = Theme.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Name = "Fade" })
	f.Active = false
	return f
end

function Theme.fadeTo(frame: Frame, transparency: number, seconds: number)
	local tw = TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = transparency })
	tw:Play()
	return tw
end

-- Horizontal slider with −/+ nudges; `onChange(value)` receives 0..1 values.
function Theme.slider(parent: Instance, labelText: string, value: number, onChange: (number) -> ()): Frame
	local row = Theme.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) })
	Theme.label(row, labelText, 13, { TextColor3 = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 16) })
	local track = Theme.frame(row, { Position = UDim2.new(0, 30, 0, 24), Size = UDim2.new(1, -60, 0, 8), BackgroundColor3 = Theme.Colors.PanelAlt })
	Theme.corner(track, 4)
	local fill = Theme.frame(track, { Size = UDim2.new(math.clamp(value, 0, 1), 0, 1, 0), BackgroundColor3 = Theme.Colors.Accent })
	Theme.corner(fill, 4)
	local knob = Theme.frame(track, { Size = UDim2.new(0, 14, 0, 18), Position = UDim2.new(math.clamp(value, 0, 1), -7, 0.5, -9), BackgroundColor3 = Theme.Colors.Text })
	Theme.corner(knob, 3)
	local current = value
	local function set(v: number)
		current = math.clamp(v, 0, 1)
		fill.Size = UDim2.new(current, 0, 1, 0)
		knob.Position = UDim2.new(current, -7, 0.5, -9)
		onChange(current)
	end
	local dragging = false
	local function fromInput(x: number)
		local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		set(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	Theme.button(row, "−", function()
		set(current - 0.1)
	end, { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 0, 0, 16), TextSize = 14 })
	Theme.button(row, "+", function()
		set(current + 0.1)
	end, { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -24, 0, 16), TextSize = 14 })
	return row
end

function Theme.toggle(parent: Instance, labelText: string, value: boolean, onChange: (boolean) -> ()): TextButton
	local b
	local function text()
		return (if value then "■ " else "□ ") .. labelText
	end
	b = Theme.button(parent, text(), function()
		value = not value
		b.Text = text()
		onChange(value)
	end, { TextXAlignment = Enum.TextXAlignment.Left })
	Theme.padding(b, 8)
	return b
end

-- Thin progress bar: returns the fill frame to resize.
function Theme.bar(parent: Instance, labelText: string, color: Color3, y: number, width: number?): (Frame, TextLabel)
	local l = Theme.label(parent, labelText, 11, { TextColor3 = Theme.Colors.TextDim, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(0, width or 200, 0, 14) })
	local track = Theme.frame(parent, { Position = UDim2.new(0, 0, 0, y + 15), Size = UDim2.new(0, width or 200, 0, 6), BackgroundColor3 = Theme.Colors.PanelAlt })
	local fill = Theme.frame(track, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color })
	return fill, l
end

function Theme.safeTop(): number
	local inset = GuiService:GetGuiInset()
	return inset.Y
end

function Theme.tween(inst: Instance, props: { [string]: any }, t: number?)
	TweenService:Create(inst, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

return Theme
