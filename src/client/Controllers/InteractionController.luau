--!nonstrict
-- Custom ProximityPrompt presentation (industrial style, mobile-friendly),
-- per-tool hold times and routing of lobby prompts to UI screens.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local InteractionController = {}
InteractionController.OpenUI = Signal.new() -- (uiName, prompt)

local active: { [ProximityPrompt]: BillboardGui } = {}
local holdConn: { [ProximityPrompt]: { RBXScriptConnection } } = {}

local function localTool(): string?
	return player:GetAttribute("ActiveTool")
end

local function hasCap(cap: string): boolean
	local id = localTool()
	local def = id and Tools.Defs[id]
	return def ~= nil and (def.capabilities[cap] or 0) > 0
end

local function keyText(prompt: ProximityPrompt): string
	if Theme.isMobile() then
		return "●"
	end
	if Theme.isGamepad() then
		return "X"
	end
	return UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
end

local function applyHold(prompt: ProximityPrompt)
	local base = prompt:GetAttribute("HoldBase")
	if base == nil then
		return
	end
	local cap = prompt:GetAttribute("ToolCap")
	if cap and hasCap(cap) then
		prompt.HoldDuration = prompt:GetAttribute("HoldTool") or base
	else
		prompt.HoldDuration = base
	end
end

local function build(prompt: ProximityPrompt)
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then
		return
	end
	-- Never show prompts attached to our own character (e.g. our revive prompt).
	if player.Character and part:IsDescendantOf(player.Character) then
		return
	end
	applyHold(prompt)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PromptUI"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 260, 0, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = prompt.MaxActivationDistance + 4
	gui.Parent = player.PlayerGui
	local frame = Theme.frame(gui, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.25 })
	Theme.stroke(frame, Theme.Colors.Border)
	Theme.corner(frame, 3)
	local key = Theme.frame(frame, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Colors.PanelAlt })
	Theme.stroke(key, Theme.Colors.Accent, 1.5)
	Theme.corner(key, 3)
	local keyLabel = Theme.label(key, keyText(prompt), 18, { Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1) })
	keyLabel.Name = "Key"
	Theme.label(frame, prompt.ObjectText, 13, { TextColor3 = Theme.Colors.TextDim, Position = UDim2.new(0, 64, 0, 8), Size = UDim2.new(1, -72, 0, 16) })
	local act = Theme.label(frame, prompt.ActionText, 16, { Font = Theme.FontBold, Position = UDim2.new(0, 64, 0, 26), Size = UDim2.new(1, -72, 0, 20) })
	-- Required-tool hint
	local cap = prompt:GetAttribute("ToolCap")
	if cap then
		local toolName = nil
		for _, id in Tools.Order do
			if (Tools.Defs[id].capabilities[cap] or 0) > 0 then
				toolName = Tools.Defs[id].name
				break
			end
		end
		if toolName then
			local has = hasCap(cap)
			local hint = Theme.label(frame, if has then "▲ " .. toolName else "○ быстрее с: " .. toolName, 11, { TextColor3 = if has then Theme.Colors.Good else Theme.Colors.TextDim, Position = UDim2.new(0, 64, 0, 46), Size = UDim2.new(1, -72, 0, 14) })
			hint.Name = "Hint"
		end
	end
	if prompt.ActionText == "Заблокировано" then
		act.TextColor3 = Theme.Colors.Danger
	end
	-- Hold progress bar
	local bar = Theme.frame(frame, { Size = UDim2.new(0, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = Theme.Colors.Accent })
	bar.Name = "Bar"
	local tween: Tween? = nil
	local conns = {}
	holdConn[prompt] = conns
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		tween = TweenService:Create(bar, TweenInfo.new(math.max(0.01, prompt.HoldDuration), Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 0, 3) })
		tween:Play()
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if tween then
			tween:Cancel()
		end
		bar.Size = UDim2.new(0, 0, 0, 3)
	end))
	-- Keep text in sync (door Open/Close, generator steps, etc.)
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		act.Text = prompt.ActionText
		act.TextColor3 = if prompt.ActionText == "Заблокировано" then Theme.Colors.Danger else Theme.Colors.Text
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal("HoldDuration"):Connect(function()
		applyHold(prompt)
	end))
	active[prompt] = gui
	-- Mobile: tapping the billboard triggers the prompt.
	if Theme.isMobile() then
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.Parent = frame
		btn.MouseButton1Down:Connect(function()
			prompt:InputHoldBegin()
		end)
		btn.MouseButton1Up:Connect(function()
			prompt:InputHoldEnd()
		end)
	end
end

local function destroy(prompt: ProximityPrompt)
	local gui = active[prompt]
	if gui then
		gui:Destroy()
		active[prompt] = nil
	end
	local conns = holdConn[prompt]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		holdConn[prompt] = nil
	end
end

function InteractionController.init()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			build(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(destroy)
	-- Only these prompt kinds open a client screen; everything else is a
	-- server-validated world interaction and needs no UI.
	local clientUI = { RoomBoard = true, Equipment = true, Briefing = true, Archive = true, Registration = true, Radio = true, Keypad = true }
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local ui = prompt:GetAttribute("UI")
		Theme.playUISound("UIClick")
		if ui and clientUI[ui] then
			InteractionController.OpenUI:Fire(ui, prompt)
		end
	end)
	player:GetAttributeChangedSignal("ActiveTool"):Connect(function()
		for prompt in active do
			applyHold(prompt)
		end
	end)
end

return InteractionController
