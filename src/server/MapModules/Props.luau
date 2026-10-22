--!nonstrict
-- Reusable industrial props. Every prop is a Model built from a handful of
-- parts so a room with 15 props stays well under 300 parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local P = Builder.Palette

local Props = {}

function Props.locker(parent: Instance, cf: CFrame, color: Color3?, tag: string?): Model
	local m = Builder.model(parent, "Locker")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 3.25, 0), Vector3.new(2.6, 6.5, 2), Enum.Material.Metal, color or P.SteelPainted)
	Builder.box(m, "Door", cf * CFrame.new(0, 3.25, -1.05), Vector3.new(2.3, 6.1, 0.15), Enum.Material.Metal, (color or P.SteelPainted):Lerp(Color3.new(1, 1, 1), 0.08))
	Builder.box(m, "Handle", cf * CFrame.new(0.8, 3.4, -1.2), Vector3.new(0.15, 0.8, 0.15), Enum.Material.Metal, P.Stainless)
	Builder.box(m, "Vent", cf * CFrame.new(0, 5.4, -1.14), Vector3.new(1.4, 0.6, 0.05), Enum.Material.DiamondPlate, P.WarningBlack)
	if tag then
		local plate = Builder.box(m, "Tag", cf * CFrame.new(0, 1.2, -1.16), Vector3.new(1.4, 0.5, 0.05), Enum.Material.SmoothPlastic, P.PanelWhite)
		Builder.label(plate, Enum.NormalId.Front, tag, { textColor = P.WarningBlack, textSize = 36, bold = true })
	end
	m.PrimaryPart = body
	return m
end

function Props.desk(parent: Instance, cf: CFrame, withScreen: boolean?): Model
	local m = Builder.model(parent, "Desk")
	local top = Builder.box(m, "Top", cf * CFrame.new(0, 2.9, 0), Vector3.new(6, 0.25, 2.8), Enum.Material.Metal, P.PanelBeige)
	Builder.box(m, "LegL", cf * CFrame.new(-2.7, 1.4, 0), Vector3.new(0.3, 2.8, 2.4), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "LegR", cf * CFrame.new(2.7, 1.4, 0), Vector3.new(0.3, 2.8, 2.4), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "Drawer", cf * CFrame.new(1.8, 2.1, 0), Vector3.new(1.6, 1.4, 2.4), Enum.Material.Metal, P.SteelPainted)
	if withScreen then
		local scr = Builder.box(m, "Monitor", cf * CFrame.new(-0.8, 4.0, 0.6), Vector3.new(2.2, 1.6, 0.2), Enum.Material.SmoothPlastic, P.WarningBlack)
		Builder.box(m, "Stand", cf * CFrame.new(-0.8, 3.3, 0.7), Vector3.new(0.4, 0.6, 0.4), Enum.Material.Metal, P.Stainless)
		local screen = Builder.box(scr, "Screen", cf * CFrame.new(-0.8, 4.0, 0.48), Vector3.new(2.0, 1.4, 0.05), Enum.Material.Neon, P.ScreenBlue)
		screen.Transparency = 0.2
		Builder.pointLight(screen, P.ScreenBlue, 6, 0.5)
		Builder.label(screen, Enum.NormalId.Front, "C-17 TERMINAL\n> status: standby", { textColor = Color3.fromRGB(220, 240, 255), textSize = 22, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, padding = 6 })
	end
	Builder.box(m, "Papers", cf * CFrame.new(1.4, 3.06, -0.4), Vector3.new(1.4, 0.06, 1.8), Enum.Material.SmoothPlastic, P.PanelWhite)
	m.PrimaryPart = top
	return m
end

function Props.chair(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Chair")
	local seat = Builder.box(m, "Seat", cf * CFrame.new(0, 1.7, 0), Vector3.new(1.8, 0.3, 1.8), Enum.Material.Fabric, P.RubberFloor)
	Builder.box(m, "Back", cf * CFrame.new(0, 2.9, 0.8), Vector3.new(1.8, 2.2, 0.25), Enum.Material.Fabric, P.RubberFloor)
	Builder.box(m, "Post", cf * CFrame.new(0, 0.9, 0), Vector3.new(0.3, 1.6, 0.3), Enum.Material.Metal, P.Stainless)
	Builder.box(m, "Base", cf * CFrame.new(0, 0.15, 0), Vector3.new(1.6, 0.2, 1.6), Enum.Material.Metal, P.SteelPainted)
	m.PrimaryPart = seat
	return m
end

function Props.bench(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Bench")
	local seat = Builder.box(m, "Seat", cf * CFrame.new(0, 1.6, 0), Vector3.new(6, 0.3, 1.8), Enum.Material.Metal, P.SteelPaintedLight)
	Builder.box(m, "LegL", cf * CFrame.new(-2.5, 0.8, 0), Vector3.new(0.3, 1.5, 1.6), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "LegR", cf * CFrame.new(2.5, 0.8, 0), Vector3.new(0.3, 1.5, 1.6), Enum.Material.Metal, P.SteelPainted)
	m.PrimaryPart = seat
	return m
end

function Props.crate(parent: Instance, cf: CFrame, size: number?, color: Color3?): Model
	local m = Builder.model(parent, "Crate")
	local s = size or 3
	local body = Builder.box(m, "Body", cf * CFrame.new(0, s / 2, 0), Vector3.new(s, s, s), Enum.Material.Metal, color or P.SteelPainted)
	Builder.box(m, "Band", cf * CFrame.new(0, s / 2, 0), Vector3.new(s + 0.1, 0.4, s + 0.1), Enum.Material.Metal, P.Galvanized)
	m.PrimaryPart = body
	return m
end

function Props.barrel(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = Builder.model(parent, "Barrel")
	local body = Builder.part({ name = "Body", size = Vector3.new(3.6, 2.4, 2.4), cframe = cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = color or P.Blue, parent = m })
	Builder.part({ name = "Ring", size = Vector3.new(0.3, 2.6, 2.6), cframe = cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Galvanized, parent = m, canCollide = false })
	m.PrimaryPart = body
	return m
end

function Props.cart(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "ServiceCart")
	local top = Builder.box(m, "Top", cf * CFrame.new(0, 2.6, 0), Vector3.new(3.4, 0.2, 2), Enum.Material.Metal, P.Stainless)
	Builder.box(m, "Shelf", cf * CFrame.new(0, 1.2, 0), Vector3.new(3.4, 0.2, 2), Enum.Material.Metal, P.Stainless)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -0.8, 0.8 } do
			Builder.box(m, "Post", cf * CFrame.new(x, 1.4, z), Vector3.new(0.2, 2.6, 0.2), Enum.Material.Metal, P.SteelPainted)
			Builder.box(m, "Wheel", cf * CFrame.new(x, 0.2, z), Vector3.new(0.4, 0.4, 0.4), Enum.Material.Rubber, P.WarningBlack)
		end
	end
	Builder.box(m, "Toolbox", cf * CFrame.new(0.4, 3.1, 0), Vector3.new(1.6, 0.8, 1), Enum.Material.Metal, P.Red)
	m.PrimaryPart = top
	return m
end

function Props.serverRack(parent: Instance, cf: CFrame, lit: boolean?): Model
	local m = Builder.model(parent, "ServerRack")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 4, 0), Vector3.new(3, 8, 3.2), Enum.Material.Metal, P.WarningBlack)
	for i = 0, 6 do
		local unit = Builder.box(m, "Unit", cf * CFrame.new(0, 0.9 + i * 1.05, -1.62), Vector3.new(2.6, 0.8, 0.1), Enum.Material.Metal, Color3.fromRGB(40, 42, 46))
		local led = Builder.box(unit, "Led", cf * CFrame.new(1.0, 0.9 + i * 1.05, -1.7), Vector3.new(0.3, 0.15, 0.05), Enum.Material.Neon, if lit ~= false then P.Green else P.Red)
		led:SetAttribute("RackLed", true)
	end
	if lit ~= false then
		Builder.pointLight(body, Color3.fromRGB(90, 200, 120), 5, 0.35)
	end
	m.PrimaryPart = body
	return m
end

function Props.breakerPanel(parent: Instance, cf: CFrame, switchCount: number, title: string): Model
	-- Wall-mounted breaker cabinet with `switchCount` individual switch parts.
	local m = Builder.model(parent, "BreakerPanel")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 5, 0), Vector3.new(4.5, 5.5, 0.8), Enum.Material.Metal, P.SteelPaintedLight)
	local plate = Builder.box(m, "Title", cf * CFrame.new(0, 7.4, -0.45), Vector3.new(4, 0.6, 0.05), Enum.Material.SmoothPlastic, P.PanelWhite)
	Builder.label(plate, Enum.NormalId.Front, title, { textColor = P.WarningBlack, textSize = 32, bold = true })
	local switches = Builder.folder(m, "Switches")
	local spacing = 3.6 / switchCount
	for i = 1, switchCount do
		local x = -1.8 + spacing * (i - 0.5)
		local sw = Builder.box(switches, "Switch" .. i, cf * CFrame.new(x, 4.6, -0.55), Vector3.new(spacing * 0.6, 1.4, 0.3), Enum.Material.SmoothPlastic, P.WarningBlack)
		sw:SetAttribute("Index", i)
		sw:SetAttribute("On", false)
		local lamp = Builder.box(sw, "Lamp", cf * CFrame.new(x, 5.6, -0.5), Vector3.new(0.3, 0.3, 0.1), Enum.Material.Neon, P.Red)
		lamp.Name = "Lamp"
		local numPlate = Builder.box(sw, "Num", cf * CFrame.new(x, 3.6, -0.46), Vector3.new(spacing * 0.6, 0.4, 0.05), Enum.Material.SmoothPlastic, P.PanelWhite)
		Builder.label(numPlate, Enum.NormalId.Front, "L" .. i, { textColor = P.WarningBlack, textSize = 28, bold = true })
	end
	local lever = Builder.box(m, "MainLever", cf * CFrame.new(0, 2.9, -0.65), Vector3.new(1.2, 0.5, 0.6), Enum.Material.Metal, P.Red)
	lever:SetAttribute("On", false)
	Builder.box(m, "Conduit", cf * CFrame.new(0, 9.5, 0), Vector3.new(0.6, 3.5, 0.6), Enum.Material.Metal, P.Galvanized)
	m.PrimaryPart = body
	return m
end

function Props.terminal(parent: Instance, cf: CFrame, text: string, screenColor: Color3?): Model
	local m = Builder.model(parent, "Terminal")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 2.2, 0), Vector3.new(3, 4.4, 2), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "Console", cf * CFrame.new(0, 4.5, -0.4) * CFrame.Angles(-0.5, 0, 0), Vector3.new(3, 0.3, 1.6), Enum.Material.Metal, P.SteelPaintedLight)
	local scr = Builder.box(m, "ScreenHousing", cf * CFrame.new(0, 6.2, 0.4) * CFrame.Angles(-0.15, 0, 0), Vector3.new(3, 2.4, 0.4), Enum.Material.Metal, P.WarningBlack)
	local screen = Builder.box(m, "Screen", cf * CFrame.new(0, 6.2, 0.17) * CFrame.Angles(-0.15, 0, 0), Vector3.new(2.7, 2.1, 0.05), Enum.Material.Neon, screenColor or P.ScreenBlue)
	screen.Transparency = 0.15
	Builder.pointLight(screen, screenColor or P.ScreenBlue, 7, 0.55)
	Builder.label(screen, Enum.NormalId.Front, text, { textColor = Color3.fromRGB(225, 240, 255), textSize = 22, font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 8 })
	scr.Name = "ScreenHousing"
	m.PrimaryPart = body
	return m
end

function Props.labTable(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "LabTable")
	local top = Builder.box(m, "Top", cf * CFrame.new(0, 3, 0), Vector3.new(8, 0.3, 3), Enum.Material.SmoothPlastic, P.LabWhite)
	Builder.box(m, "Base", cf * CFrame.new(0, 1.45, 0), Vector3.new(7.4, 2.8, 2.4), Enum.Material.Metal, P.PanelWhite)
	Builder.box(m, "Flask", cf * CFrame.new(-2, 3.6, 0), Vector3.new(0.6, 1, 0.6), Enum.Material.Glass, P.GlassTint).Transparency = 0.5
	Builder.box(m, "Analyzer", cf * CFrame.new(1.5, 3.7, -0.4), Vector3.new(2, 1.2, 1.4), Enum.Material.SmoothPlastic, P.PanelWhite)
	local led = Builder.box(m, "Led", cf * CFrame.new(2.3, 3.9, -1.12), Vector3.new(0.2, 0.2, 0.05), Enum.Material.Neon, P.Green)
	led.Name = "Led"
	m.PrimaryPart = top
	return m
end

function Props.glassWall(parent: Instance, cf: CFrame, width: number, height: number): Model
	local m = Builder.model(parent, "GlassPartition")
	local g = Builder.part({ name = "Glass", size = Vector3.new(width, height - 1, 0.3), cframe = cf * CFrame.new(0, height / 2 + 0.5, 0), material = Enum.Material.Glass, color = P.GlassTint, transparency = 0.55, reflectance = 0.1, parent = m })
	Builder.box(m, "Frame", cf * CFrame.new(0, 0.5, 0), Vector3.new(width, 1, 0.5), Enum.Material.Metal, P.SteelPainted)
	Builder.box(m, "FrameTop", cf * CFrame.new(0, height, 0), Vector3.new(width, 0.4, 0.5), Enum.Material.Metal, P.SteelPainted)
	m.PrimaryPart = g
	return m
end

function Props.sampleCabinet(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "SampleCabinet")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 3.5, 0), Vector3.new(4, 7, 2.2), Enum.Material.Metal, P.PanelWhite)
	local g = Builder.part({ name = "Glass", size = Vector3.new(3.4, 4, 0.1), cframe = cf * CFrame.new(0, 4.2, -1.1), material = Enum.Material.Glass, color = P.GlassTint, transparency = 0.5, parent = m, canCollide = false })
	Builder.pointLight(g, P.LightLab, 6, 0.6)
	for i = 0, 2 do
		Builder.box(m, "Shelf", cf * CFrame.new(0, 2.6 + i * 1.3, -0.4), Vector3.new(3.2, 0.1, 1.4), Enum.Material.Glass, P.GlassTint).Transparency = 0.3
		for j = -1, 1 do
			Builder.box(m, "Vial", cf * CFrame.new(j * 0.9, 3.1 + i * 1.3, -0.4), Vector3.new(0.35, 0.8, 0.35), Enum.Material.Glass, Color3.fromRGB(120, 200, 170)).Transparency = 0.35
		end
	end
	m.PrimaryPart = body
	return m
end

function Props.generator(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Generator")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 2.5, 0), Vector3.new(9, 5, 4.5), Enum.Material.Metal, P.Yellow:Lerp(P.WarningBlack, 0.35))
	Builder.box(m, "Base", cf * CFrame.new(0, 0.3, 0), Vector3.new(9.6, 0.6, 5), Enum.Material.DiamondPlate, P.WarningBlack)
	Builder.part({ name = "Drum", size = Vector3.new(4, 3, 3), cframe = cf * CFrame.new(-2, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.SteelPainted, parent = m })
	Builder.box(m, "Exhaust", cf * CFrame.new(3, 6.5, 0), Vector3.new(0.8, 3, 0.8), Enum.Material.Metal, P.Galvanized)
	Builder.box(m, "Grille", cf * CFrame.new(0, 2.5, -2.3), Vector3.new(6, 2.6, 0.1), Enum.Material.DiamondPlate, P.WarningBlack)
	m.PrimaryPart = body
	return m
end

function Props.valve(parent: Instance, cf: CFrame, labelText: string): Model
	local m = Builder.model(parent, "Valve")
	local pipe = Builder.part({ name = "PipeBody", size = Vector3.new(6, 1.6, 1.6), cframe = cf * CFrame.new(0, 4, 0), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Galvanized, parent = m })
	local wheel = Builder.part({ name = "Wheel", size = Vector3.new(0.4, 2.6, 2.6), cframe = cf * CFrame.new(0, 4, -1.4) * CFrame.Angles(0, math.pi / 2, 0), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Red, parent = m })
	wheel.Name = "Wheel"
	local gauge = Builder.box(m, "Gauge", cf * CFrame.new(2, 5.6, -0.5), Vector3.new(1.4, 1.4, 0.3), Enum.Material.SmoothPlastic, P.PanelWhite)
	Builder.label(gauge, Enum.NormalId.Front, "0.00", { textColor = P.WarningBlack, textSize = 34, font = Enum.Font.Code })
	local tag = Builder.box(m, "Tag", cf * CFrame.new(-2, 5.6, -0.5), Vector3.new(1.8, 0.6, 0.1), Enum.Material.SmoothPlastic, P.Yellow)
	Builder.label(tag, Enum.NormalId.Front, labelText, { textColor = P.WarningBlack, textSize = 28, bold = true })
	m.PrimaryPart = pipe
	return m
end

function Props.camera(parent: Instance, cf: CFrame, channel: string): Model
	local m = Builder.model(parent, "Camera")
	local mount = Builder.box(m, "Mount", cf * CFrame.new(0, 0, 0), Vector3.new(0.5, 0.5, 1.2), Enum.Material.Metal, P.SteelPainted)
	local body = Builder.box(m, "Body", cf * CFrame.new(0, -0.6, -0.8) * CFrame.Angles(-0.35, 0, 0), Vector3.new(0.9, 0.9, 2), Enum.Material.Metal, P.PanelWhite)
	local led = Builder.box(body, "Led", cf * CFrame.new(0, -0.95, -1.7), Vector3.new(0.15, 0.15, 0.1), Enum.Material.Neon, P.Red)
	led.Name = "Led"
	m:SetAttribute("Channel", channel)
	m.PrimaryPart = mount
	return m
end

function Props.doorPanel(parent: Instance, cf: CFrame, text: string): Model
	-- Wall-mounted access panel with 4 fuse slots (door repair task target).
	local m = Builder.model(parent, "DoorPanel")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 4.5, 0), Vector3.new(2.4, 3, 0.5), Enum.Material.Metal, P.SteelPaintedLight)
	local screen = Builder.box(m, "Screen", cf * CFrame.new(0, 5.4, -0.28), Vector3.new(2, 0.8, 0.05), Enum.Material.Neon, P.Red)
	Builder.label(screen, Enum.NormalId.Front, text, { textColor = Color3.new(1, 1, 1), textSize = 26, font = Enum.Font.Code })
	local slots = Builder.folder(m, "Slots")
	for i = 1, 4 do
		local s = Builder.box(slots, "Slot" .. i, cf * CFrame.new(-0.75 + (i - 1) * 0.5, 4, -0.28), Vector3.new(0.35, 0.9, 0.1), Enum.Material.SmoothPlastic, P.WarningBlack)
		s:SetAttribute("Index", i)
	end
	m.PrimaryPart = body
	return m
end

function Props.securityDoorFrame(parent: Instance, cf: CFrame, width: number, height: number): Model
	-- Decorative reinforced frame around isolation sector openings.
	local m = Builder.model(parent, "ReinforcedFrame")
	Builder.box(m, "Left", cf * CFrame.new(-width / 2 - 0.6, height / 2, 0), Vector3.new(1.2, height, 1.6), Enum.Material.Metal, P.Red:Lerp(P.WarningBlack, 0.5))
	Builder.box(m, "Right", cf * CFrame.new(width / 2 + 0.6, height / 2, 0), Vector3.new(1.2, height, 1.6), Enum.Material.Metal, P.Red:Lerp(P.WarningBlack, 0.5))
	Builder.box(m, "Top", cf * CFrame.new(0, height + 0.6, 0), Vector3.new(width + 2.4, 1.2, 1.6), Enum.Material.Metal, P.Red:Lerp(P.WarningBlack, 0.5))
	Builder.hazardStripes(m, cf * CFrame.new(0, 0.05, 0), width + 2, 1.2)
	return m
end

function Props.documentPickup(parent: Instance, cf: CFrame, documentId: string, title: string): Part
	local paper = Builder.part({
		name = "Document",
		size = Vector3.new(1.6, 0.08, 2.1),
		cframe = cf,
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(235, 232, 220),
		parent = parent,
		canCollide = false,
	})
	Builder.label(paper, Enum.NormalId.Top, title, { textColor = P.WarningBlack, textSize = 16, font = Enum.Font.Code, alignY = Enum.TextYAlignment.Top, padding = 4 })
	paper:SetAttribute("DocumentId", documentId)
	local glow = Builder.pointLight(paper, Color3.fromRGB(255, 240, 200), 5, 0.4)
	glow.Name = "Glow"
	return paper
end

function Props.vendingMachine(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Vending")
	local body = Builder.box(m, "Body", cf * CFrame.new(0, 3.75, 0), Vector3.new(4, 7.5, 3), Enum.Material.Metal, P.SteelPainted)
	local glass = Builder.part({ name = "Glass", size = Vector3.new(2.6, 4.5, 0.1), cframe = cf * CFrame.new(-0.4, 4.5, -1.52), material = Enum.Material.Glass, color = P.GlassTint, transparency = 0.45, parent = m, canCollide = false })
	Builder.pointLight(glass, P.LightWarm, 7, 0.7)
	local plate = Builder.box(m, "Header", cf * CFrame.new(0, 7, -1.52), Vector3.new(3.6, 0.8, 0.05), Enum.Material.Neon, P.LightWarm)
	Builder.label(plate, Enum.NormalId.Front, "СНАБЖЕНИЕ 17", { textColor = P.WarningBlack, textSize = 30, bold = true })
	Builder.box(m, "Keypad", cf * CFrame.new(1.4, 4.5, -1.52), Vector3.new(0.7, 1.6, 0.1), Enum.Material.SmoothPlastic, P.WarningBlack)
	m.PrimaryPart = body
	return m
end

function Props.warningSign(parent: Instance, cf: CFrame, text: string, color: Color3?): Part
	return Builder.signPlate(parent, cf, 4, 1.6, text, color or P.Yellow, P.WarningBlack, 34)
end

function Props.roomNumber(parent: Instance, cf: CFrame, text: string): Part
	return Builder.signPlate(parent, cf, 2.2, 0.9, text, P.PanelWhite, P.WarningBlack, 38)
end

function Props.pipeCluster(parent: Instance, cf: CFrame, length: number, count: number): Folder
	local f = Builder.folder(parent, "PipeCluster")
	for i = 0, count - 1 do
		local y = 8 + i * 0.9
		local a = cf:PointToWorldSpace(Vector3.new(-length / 2, y, 0))
		local b = cf:PointToWorldSpace(Vector3.new(length / 2, y, 0))
		local color = if i % 3 == 0 then P.Galvanized elseif i % 3 == 1 then P.Blue:Lerp(P.Galvanized, 0.5) else P.Red:Lerp(P.Galvanized, 0.6)
		Builder.pipeRun(f, { a, b }, 0.3 + (i % 2) * 0.15, color)
	end
	return f
end

function Props.debrisPile(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Debris")
	Builder.box(m, "Slab", cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0.4, 0.1), Vector3.new(4, 0.6, 2.5), Enum.Material.Concrete, P.ConcreteDark)
	Builder.box(m, "Slab2", cf * CFrame.new(1.5, 0.9, 0.6) * CFrame.Angles(0.2, -0.3, 0), Vector3.new(2.5, 0.5, 2), Enum.Material.Concrete, P.Concrete)
	Builder.box(m, "Rebar", cf * CFrame.new(-1, 1.2, 0) * CFrame.Angles(0, 0, 0.9), Vector3.new(0.15, 3, 0.15), Enum.Material.Metal, P.WarningBlack)
	return m
end

return Props
