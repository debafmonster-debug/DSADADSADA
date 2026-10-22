--!nonstrict
-- Geometry toolkit used by the lobby and every map module. All environment
-- geometry in the vertical slice is code-built so modules can be regenerated
-- from a seed; builders are deterministic given the same inputs.
local Builder = {}

export type PartOpts = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material?,
	color: Color3?,
	parent: Instance?,
	transparency: number?,
	reflectance: number?,
	canCollide: boolean?,
	castShadow: boolean?,
	shape: Enum.PartType?,
}

Builder.Palette = {
	Concrete = Color3.fromRGB(118, 120, 122),
	ConcreteDark = Color3.fromRGB(86, 88, 90),
	ConcreteFloor = Color3.fromRGB(96, 98, 100),
	SteelPainted = Color3.fromRGB(72, 80, 88),
	SteelPaintedLight = Color3.fromRGB(128, 136, 144),
	Stainless = Color3.fromRGB(176, 180, 184),
	Galvanized = Color3.fromRGB(140, 142, 140),
	PanelBeige = Color3.fromRGB(176, 170, 150),
	PanelWhite = Color3.fromRGB(205, 208, 210),
	RubberFloor = Color3.fromRGB(52, 54, 56),
	Yellow = Color3.fromRGB(230, 190, 40),
	Red = Color3.fromRGB(190, 40, 36),
	Orange = Color3.fromRGB(228, 120, 30),
	Green = Color3.fromRGB(60, 170, 90),
	Blue = Color3.fromRGB(50, 110, 190),
	Cable = Color3.fromRGB(28, 28, 30),
	GlassTint = Color3.fromRGB(170, 200, 215),
	LabWhite = Color3.fromRGB(222, 226, 228),
	WarningBlack = Color3.fromRGB(20, 20, 22),
	LightCold = Color3.fromRGB(205, 220, 255),
	LightWarm = Color3.fromRGB(255, 214, 160),
	LightEmergency = Color3.fromRGB(255, 60, 40),
	LightLab = Color3.fromRGB(190, 255, 230),
	ScreenBlue = Color3.fromRGB(70, 150, 220),
	-- «Восток-9» palette: faded orange hulls, cold snow, graphite metal,
	-- dirty-white interiors, old green equipment, three light temperatures.
	StationOrange = Color3.fromRGB(196, 104, 42),
	StationOrangeDark = Color3.fromRGB(142, 76, 34),
	StationOrangeFaded = Color3.fromRGB(176, 112, 70),
	RoofGrey = Color3.fromRGB(96, 100, 104),
	Snow = Color3.fromRGB(214, 222, 232),
	SnowShadow = Color3.fromRGB(168, 182, 200),
	Ice = Color3.fromRGB(190, 214, 230),
	Graphite = Color3.fromRGB(58, 60, 64),
	GraphiteLight = Color3.fromRGB(92, 96, 102),
	DirtyWhite = Color3.fromRGB(196, 192, 180),
	DirtyWhiteDark = Color3.fromRGB(166, 160, 148),
	OldGreen = Color3.fromRGB(96, 118, 96),
	OldGreenDark = Color3.fromRGB(66, 84, 68),
	Wood = Color3.fromRGB(120, 92, 62),
	WoodDark = Color3.fromRGB(84, 62, 42),
	Fabric = Color3.fromRGB(88, 96, 104),
	FabricWarm = Color3.fromRGB(128, 96, 72),
	Blanket = Color3.fromRGB(96, 108, 92),
	Paper = Color3.fromRGB(214, 206, 180),
	Mug = Color3.fromRGB(210, 214, 220),
	Bakelite = Color3.fromRGB(42, 38, 36),
	LightFluor = Color3.fromRGB(222, 236, 244),
	LightWarmOld = Color3.fromRGB(255, 196, 120),
	LightEmergencyWarm = Color3.fromRGB(255, 150, 60),
	LightFlood = Color3.fromRGB(230, 240, 255),
	EyeGlow = Color3.fromRGB(150, 220, 255),
}

function Builder.part(o: PartOpts): Part
	local p = Instance.new("Part")
	p.Name = o.name or "Part"
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cframe
	p.Material = o.material or Enum.Material.Concrete
	p.Color = o.color or Builder.Palette.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		p.Shape = o.shape
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	if o.reflectance then
		p.Reflectance = o.reflectance
	end
	if o.canCollide ~= nil then
		p.CanCollide = o.canCollide
	end
	if o.castShadow ~= nil then
		p.CastShadow = o.castShadow
	end
	p.Parent = o.parent
	return p
end

function Builder.box(parent: Instance, name: string, cframe: CFrame, size: Vector3, material: Enum.Material?, color: Color3?): Part
	return Builder.part({ name = name, cframe = cframe, size = size, material = material, color = color, parent = parent })
end

function Builder.model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Builder.folder(parent: Instance?, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Text on a face of a part (signage, screens, markings).
export type LabelOpts = {
	textColor: Color3?,
	background: Color3?,
	backgroundTransparency: number?,
	textSize: number?,
	font: Enum.Font?,
	bold: boolean?,
	pixelsPerStud: number?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	padding: number?,
	brightness: number?,
}

function Builder.label(part: BasePart, face: Enum.NormalId, text: string, opts: LabelOpts?): TextLabel
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.pixelsPerStud or 40
	gui.LightInfluence = 0.6
	gui.Brightness = o.brightness or 1
	gui.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = o.background or Color3.new(0, 0, 0)
	lbl.BackgroundTransparency = o.backgroundTransparency or 1
	lbl.BorderSizePixel = 0
	lbl.Text = text
	lbl.TextColor3 = o.textColor or Color3.fromRGB(230, 230, 230)
	lbl.TextSize = o.textSize or 48
	lbl.TextWrapped = true
	lbl.Font = o.font or (if o.bold then Enum.Font.GothamBold else Enum.Font.Gotham)
	lbl.TextXAlignment = o.alignX or Enum.TextXAlignment.Center
	lbl.TextYAlignment = o.alignY or Enum.TextYAlignment.Center
	lbl.Parent = gui
	if o.padding then
		local pad = Instance.new("UIPadding")
		local u = UDim.new(0, o.padding)
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = u, u, u, u
		pad.Parent = lbl
	end
	return lbl
end

-- Thin plate with text on its front (-Z) face.
function Builder.signPlate(parent: Instance, cframe: CFrame, width: number, height: number, text: string, bg: Color3, fg: Color3, textSize: number?): Part
	local plate = Builder.part({
		name = "Sign",
		size = Vector3.new(width, height, 0.2),
		cframe = cframe,
		material = Enum.Material.SmoothPlastic,
		color = bg,
		parent = parent,
		canCollide = false,
	})
	Builder.label(plate, Enum.NormalId.Front, text, { textColor = fg, textSize = textSize or 40, bold = true })
	return plate
end

function Builder.pointLight(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

-- Ceiling fixture: neon slab + point light. Lights are the main perf cost, so
-- fixtures default to no shadows; important rooms may enable them.
function Builder.ceilingLamp(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, range: number, brightness: number, shadows: boolean?): Part
	local housing = Builder.part({
		name = "LampHousing",
		size = size + Vector3.new(0.6, 0.2, 0.6),
		cframe = cframe * CFrame.new(0, 0.1, 0),
		material = Enum.Material.Metal,
		color = Builder.Palette.SteelPaintedLight,
		parent = parent,
		canCollide = false,
	})
	local lamp = Builder.part({
		name = "Lamp",
		size = size,
		cframe = cframe,
		material = Enum.Material.Neon,
		color = color,
		parent = housing,
		canCollide = false,
		castShadow = false,
	})
	Builder.pointLight(lamp, color, range, brightness, shadows)
	lamp:SetAttribute("LampColor", color)
	lamp:SetAttribute("LampBrightness", brightness)
	housing:SetAttribute("IsLampFixture", true)
	return lamp
end

function Builder.emergencyLamp(parent: Instance, cframe: CFrame): Part
	local lamp = Builder.part({
		name = "EmergencyLamp",
		size = Vector3.new(1.2, 0.5, 0.5),
		cframe = cframe,
		material = Enum.Material.Neon,
		color = Builder.Palette.LightEmergency,
		parent = parent,
		canCollide = false,
		castShadow = false,
	})
	local l = Builder.pointLight(lamp, Builder.Palette.LightEmergency, 14, 1.2)
	l.Enabled = false
	lamp.Transparency = 0.6
	lamp:SetAttribute("IsEmergency", true)
	return lamp
end

-- Wall from a to b (XZ plane) with optional centered opening.
export type Opening = { width: number, height: number, offset: number? }

function Builder.wall(parent: Instance, a: Vector3, b: Vector3, height: number, thickness: number, opening: Opening?, material: Enum.Material?, color: Color3?, name: string?): { Part }
	local parts = {}
	local dir = (b - a)
	local len = dir.Magnitude
	if len < 0.01 then
		return parts
	end
	local unit = dir.Unit
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, mid + unit)
	local function seg(center: number, segLen: number, yBase: number, segH: number, label: string)
		local p = Builder.part({
			name = name or label,
			size = Vector3.new(thickness, segH, segLen),
			cframe = look * CFrame.new(0, yBase + segH / 2, -(center - len / 2)),
			material = material or Enum.Material.Concrete,
			color = color or Builder.Palette.Concrete,
			parent = parent,
		})
		table.insert(parts, p)
	end
	if not opening then
		seg(len / 2, len, 0, height, "Wall")
		return parts
	end
	local oc = len / 2 + (opening.offset or 0)
	local leftLen = oc - opening.width / 2
	local rightLen = len - (oc + opening.width / 2)
	if leftLen > 0.05 then
		seg(leftLen / 2, leftLen, 0, height, "WallLeft")
	end
	if rightLen > 0.05 then
		seg(len - rightLen / 2, rightLen, 0, height, "WallRight")
	end
	if height - opening.height > 0.05 then
		seg(oc, opening.width, opening.height, height - opening.height, "WallLintel")
	end
	return parts
end

export type ShellOpts = {
	floorMaterial: Enum.Material?,
	floorColor: Color3?,
	wallMaterial: Enum.Material?,
	wallColor: Color3?,
	ceiling: boolean?,
	ceilingColor: Color3?,
	ceilingMaterial: Enum.Material?,
	doors: { [string]: Opening? }?, -- N E S W
	thickness: number?,
	trim: boolean?,
}

-- Rectangular room shell. `origin` is the floor-level center. North = -Z.
function Builder.shell(parent: Instance, origin: CFrame, sizeX: number, sizeZ: number, height: number, opts: ShellOpts?): Folder
	local o = opts or {}
	local t = o.thickness or 1
	local f = Builder.folder(parent, "Shell")
	Builder.part({
		name = "Floor",
		size = Vector3.new(sizeX, 1, sizeZ),
		cframe = origin * CFrame.new(0, -0.5, 0),
		material = o.floorMaterial or Enum.Material.Concrete,
		color = o.floorColor or Builder.Palette.ConcreteFloor,
		parent = f,
	})
	if o.ceiling ~= false then
		Builder.part({
			name = "Ceiling",
			size = Vector3.new(sizeX, 1, sizeZ),
			cframe = origin * CFrame.new(0, height + 0.5, 0),
			material = o.ceilingMaterial or Enum.Material.Concrete,
			color = o.ceilingColor or Builder.Palette.ConcreteDark,
			parent = f,
		})
	end
	local hx, hz = sizeX / 2, sizeZ / 2
	local doors = o.doors or {}
	local corners = {
		N = { origin:PointToWorldSpace(Vector3.new(-hx, 0, -hz + t / 2)), origin:PointToWorldSpace(Vector3.new(hx, 0, -hz + t / 2)) },
		S = { origin:PointToWorldSpace(Vector3.new(hx, 0, hz - t / 2)), origin:PointToWorldSpace(Vector3.new(-hx, 0, hz - t / 2)) },
		E = { origin:PointToWorldSpace(Vector3.new(hx - t / 2, 0, -hz)), origin:PointToWorldSpace(Vector3.new(hx - t / 2, 0, hz)) },
		W = { origin:PointToWorldSpace(Vector3.new(-hx + t / 2, 0, hz)), origin:PointToWorldSpace(Vector3.new(-hx + t / 2, 0, -hz)) },
	}
	for side, ab in corners do
		local walls = Builder.wall(f, ab[1], ab[2], height, t, doors[side], o.wallMaterial, o.wallColor)
		for _, w in walls do
			w.Name = "Wall" .. side
		end
	end
	if o.trim ~= false then
		-- Floor skirting line adds visual grounding cheaply. Walls are listed
		-- clockwise so the wall frame's +X always points into the room.
		for _, ab in corners do
			local a, b = ab[1], ab[2]
			local mid = (a + b) / 2
			local look = CFrame.lookAt(mid, mid + (b - a).Unit)
			local len = (b - a).Magnitude
			Builder.part({
				name = "Skirting",
				size = Vector3.new(0.3, 0.6, len),
				cframe = look * CFrame.new(t / 2 + 0.15, 0.3, 0),
				material = Enum.Material.Metal,
				color = Builder.Palette.SteelPainted,
				parent = f,
				canCollide = false,
			})
		end
	end
	return f
end

-- Pipe run through a list of world points.
function Builder.pipeRun(parent: Instance, points: { Vector3 }, radius: number, color: Color3?, material: Enum.Material?): Folder
	local f = Builder.folder(parent, "Pipe")
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		if len < 0.01 then
			continue
		end
		-- Cylinder axis is X; rotate so it runs along a->b.
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		Builder.part({
			name = "PipeSeg",
			size = Vector3.new(len + radius * 2, radius * 2, radius * 2),
			cframe = cf,
			shape = Enum.PartType.Cylinder,
			material = material or Enum.Material.Metal,
			color = color or Builder.Palette.Galvanized,
			parent = f,
			canCollide = false,
		})
		if i > 1 then
			Builder.part({
				name = "PipeJoint",
				size = Vector3.new(radius * 2.4, radius * 2.4, radius * 2.4),
				cframe = CFrame.new(a),
				shape = Enum.PartType.Ball,
				material = material or Enum.Material.Metal,
				color = color or Builder.Palette.Galvanized,
				parent = f,
				canCollide = false,
			})
		end
	end
	return f
end

function Builder.cableTray(parent: Instance, a: Vector3, b: Vector3, width: number): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local tray = Builder.part({
		name = "CableTray",
		size = Vector3.new(width, 0.25, len),
		cframe = cf,
		material = Enum.Material.DiamondPlate,
		color = Builder.Palette.Galvanized,
		parent = parent,
		canCollide = false,
	})
	Builder.part({
		name = "Cables",
		size = Vector3.new(width * 0.7, 0.3, len),
		cframe = cf * CFrame.new(0, 0.25, 0),
		material = Enum.Material.Rubber,
		color = Builder.Palette.Cable,
		parent = tray,
		canCollide = false,
	})
	return tray
end

function Builder.ventDuct(parent: Instance, a: Vector3, b: Vector3, size: number): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local duct = Builder.part({
		name = "Duct",
		size = Vector3.new(size, size, len),
		cframe = cf,
		material = Enum.Material.Metal,
		color = Builder.Palette.Galvanized,
		parent = parent,
		canCollide = false,
	})
	return duct
end

function Builder.ventGrille(parent: Instance, cframe: CFrame, w: number, h: number): Part
	local g = Builder.part({
		name = "VentGrille",
		size = Vector3.new(w, h, 0.2),
		cframe = cframe,
		material = Enum.Material.DiamondPlate,
		color = Builder.Palette.SteelPainted,
		parent = parent,
		canCollide = false,
	})
	return g
end

function Builder.hazardStripes(parent: Instance, cframe: CFrame, length: number, width: number): Part
	local p = Builder.part({
		name = "HazardStripe",
		size = Vector3.new(length, 0.05, width),
		cframe = cframe,
		material = Enum.Material.SmoothPlastic,
		color = Builder.Palette.Yellow,
		parent = parent,
		canCollide = false,
	})
	local count = math.max(1, math.floor(length / 2))
	for i = 0, count - 1 do
		if i % 2 == 0 then
			Builder.part({
				name = "StripeBlack",
				size = Vector3.new(1, 0.06, width),
				cframe = cframe * CFrame.new(-length / 2 + i * 2 + 1, 0, 0),
				material = Enum.Material.SmoothPlastic,
				color = Builder.Palette.WarningBlack,
				parent = p,
				canCollide = false,
			})
		end
	end
	return p
end

function Builder.beam(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, color: Color3?): Part
	local len = (b - a).Magnitude
	return Builder.part({
		name = "Beam",
		size = Vector3.new(w, h, len),
		cframe = CFrame.lookAt((a + b) / 2, b),
		material = Enum.Material.Metal,
		color = color or Builder.Palette.SteelPainted,
		parent = parent,
		canCollide = false,
	})
end

function Builder.column(parent: Instance, position: Vector3, size: number, height: number, color: Color3?): Part
	return Builder.part({
		name = "Column",
		size = Vector3.new(size, height, size),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		material = Enum.Material.Concrete,
		color = color or Builder.Palette.ConcreteDark,
		parent = parent,
	})
end

function Builder.prompt(part: BasePart, actionText: string, objectText: string, holdDuration: number?, key: Enum.KeyCode?, maxDistance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = holdDuration or 0
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.MaxActivationDistance = maxDistance or 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = part
	return p
end

function Builder.sound(parent: Instance, def: { id: string, volume: number, looped: boolean?, pitch: number?, rollOff: number? }, name: string?): Sound
	local s = Instance.new("Sound")
	s.Name = name or "Sound"
	s.SoundId = def.id
	s.Volume = def.volume
	s.Looped = def.looped == true
	s.PlaybackSpeed = def.pitch or 1
	s.RollOffMaxDistance = def.rollOff or 40
	s.RollOffMinDistance = 4
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent = parent
	return s
end

function Builder.invisible(parent: Instance, name: string, cframe: CFrame, size: Vector3): Part
	local p = Builder.part({
		name = name,
		size = size,
		cframe = cframe,
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- ===== Station-specific fixtures =====================================

-- Marks a light-emitting part so PowerGridService can drive it. Lamps carry
-- their circuit, nominal color/brightness and an optional stagger index so
-- a dying circuit goes dark fixture by fixture instead of all at once.
function Builder.registerLamp(lamp: BasePart, circuit: string, color: Color3, brightness: number)
	lamp:SetAttribute("Lamp", true)
	lamp:SetAttribute("Circuit", circuit)
	lamp:SetAttribute("LampColor", color)
	lamp:SetAttribute("LampBrightness", brightness)
	lamp:SetAttribute("LampMaterial", lamp.Material.Name)
end

-- Fluorescent tube fixture (old station lighting). Housing + tube + light.
function Builder.fluorLamp(parent: Instance, cframe: CFrame, length: number, circuit: string, color: Color3?, brightness: number?, shadows: boolean?): Part
	local c = color or Builder.Palette.LightFluor
	local b = brightness or 1.1
	local housing = Builder.part({
		name = "FluorHousing",
		size = Vector3.new(length + 0.6, 0.35, 1.2),
		cframe = cframe * CFrame.new(0, 0.2, 0),
		material = Enum.Material.Metal,
		color = Builder.Palette.DirtyWhiteDark,
		parent = parent,
		canCollide = false,
	})
	local tube = Builder.part({
		name = "Lamp",
		size = Vector3.new(length, 0.22, 0.4),
		cframe = cframe,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
		color = c,
		parent = housing,
		canCollide = false,
		castShadow = false,
	})
	local light = Builder.pointLight(tube, c, 18 + length, b, shadows)
	light.Name = "Light"
	Builder.registerLamp(tube, circuit, c, b)
	return tube
end

-- Bare bulb in a wire cage (utility rooms, bunker, shed).
function Builder.cageLamp(parent: Instance, cframe: CFrame, circuit: string, color: Color3?, brightness: number?, range: number?): Part
	local c = color or Builder.Palette.LightWarmOld
	local b = brightness or 0.9
	local base = Builder.part({
		name = "CageBase",
		size = Vector3.new(0.8, 0.3, 0.8),
		cframe = cframe * CFrame.new(0, 0.3, 0),
		material = Enum.Material.Metal,
		color = Builder.Palette.Graphite,
		parent = parent,
		canCollide = false,
	})
	local bulb = Builder.part({
		name = "Lamp",
		size = Vector3.new(0.5, 0.6, 0.5),
		cframe = cframe,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		color = c,
		parent = base,
		canCollide = false,
		castShadow = false,
	})
	for i = 0, 3 do
		Builder.part({
			name = "CageWire",
			size = Vector3.new(0.06, 0.9, 0.06),
			cframe = cframe * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0.32, -0.05, 0),
			material = Enum.Material.Metal,
			color = Builder.Palette.Graphite,
			parent = base,
			canCollide = false,
			castShadow = false,
		})
	end
	local light = Builder.pointLight(bulb, c, range or 16, b, false)
	light.Name = "Light"
	Builder.registerLamp(bulb, circuit, c, b)
	return bulb
end

-- Emergency lamp tied to a circuit: lit only when that circuit is DOWN.
function Builder.emergencyLampFor(parent: Instance, cframe: CFrame, circuit: string): Part
	local lamp = Builder.emergencyLamp(parent, cframe)
	lamp:SetAttribute("Circuit", circuit)
	lamp.Color = Builder.Palette.LightEmergency
	return lamp
end

-- Outdoor floodlight on a pole aimed at a point.
function Builder.floodlight(parent: Instance, position: Vector3, height: number, aimAt: Vector3, circuit: string): Part
	local m = Builder.model(parent, "Floodlight")
	Builder.part({ name = "Pole", size = Vector3.new(0.9, height, 0.9), cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m })
	Builder.part({ name = "Base", size = Vector3.new(2.4, 1, 2.4), cframe = CFrame.new(position + Vector3.new(0, 0.5, 0)), material = Enum.Material.Concrete, color = Builder.Palette.ConcreteDark, parent = m })
	local headPos = position + Vector3.new(0, height, 0)
	local cf = CFrame.lookAt(headPos, aimAt)
	Builder.part({ name = "Head", size = Vector3.new(2.2, 1.4, 1.2), cframe = cf, material = Enum.Material.Metal, color = Builder.Palette.GraphiteLight, parent = m, canCollide = false })
	local lens = Builder.part({ name = "Lamp", size = Vector3.new(1.8, 1.0, 0.2), cframe = cf * CFrame.new(0, 0, -0.6), material = Enum.Material.Neon, color = Builder.Palette.LightFlood, parent = m, canCollide = false, castShadow = false })
	local spot = Instance.new("SpotLight")
	spot.Name = "Light"
	spot.Angle = 95
	spot.Range = 60
	spot.Brightness = 2.2
	spot.Color = Builder.Palette.LightFlood
	spot.Face = Enum.NormalId.Front
	spot.Shadows = true
	spot.Parent = lens
	Builder.registerLamp(lens, circuit, Builder.Palette.LightFlood, 2.2)
	return lens
end

-- Window: frame + tinted glass + a frost layer the client fades with weather.
function Builder.window(parent: Instance, cframe: CFrame, w: number, h: number, frameColor: Color3?): Part
	local m = Builder.model(parent, "Window")
	local fc = frameColor or Builder.Palette.Graphite
	local t = 0.25
	Builder.part({ name = "FrameTop", size = Vector3.new(w + 0.5, t, 0.6), cframe = cframe * CFrame.new(0, h / 2 + t / 2, 0), material = Enum.Material.Metal, color = fc, parent = m })
	Builder.part({ name = "FrameBottom", size = Vector3.new(w + 0.5, t, 0.6), cframe = cframe * CFrame.new(0, -h / 2 - t / 2, 0), material = Enum.Material.Metal, color = fc, parent = m })
	Builder.part({ name = "FrameL", size = Vector3.new(t, h, 0.6), cframe = cframe * CFrame.new(-w / 2 - t / 2, 0, 0), material = Enum.Material.Metal, color = fc, parent = m })
	Builder.part({ name = "FrameR", size = Vector3.new(t, h, 0.6), cframe = cframe * CFrame.new(w / 2 + t / 2, 0, 0), material = Enum.Material.Metal, color = fc, parent = m })
	local glass = Builder.part({ name = "Glass", size = Vector3.new(w, h, 0.12), cframe = cframe, material = Enum.Material.Glass, color = Builder.Palette.GlassTint, parent = m, transparency = 0.45, reflectance = 0.08, castShadow = false })
	glass.CanCollide = true
	local frost = Builder.part({ name = "Frost", size = Vector3.new(w, h, 0.06), cframe = cframe * CFrame.new(0, 0, 0.12), material = Enum.Material.Ice, color = Builder.Palette.Ice, parent = m, transparency = 0.82, canCollide = false, castShadow = false })
	frost:SetAttribute("Frost", true)
	return glass
end

-- Hinged door. The leaf rotates around `Hinge` (left edge). Prompt lives on
-- the leaf; FacilityService animates and validates it. `heavy` makes an
-- airlock-style insulated door with a wheel handle and slower swing.
export type DoorOpts = { heavy: boolean?, color: Color3?, name: string?, window: boolean?, label: string?, locked: boolean? }

function Builder.door(parent: Instance, cframe: CFrame, w: number, h: number, opts: DoorOpts?): Model
	local o = opts or {}
	local m = Builder.model(parent, o.name or "Door")
	local thick = if o.heavy then 0.8 else 0.3
	local color = o.color or (if o.heavy then Builder.Palette.StationOrangeDark else Builder.Palette.DirtyWhiteDark)
	local hinge = Builder.part({ name = "Hinge", size = Vector3.new(0.3, h, 0.3), cframe = cframe * CFrame.new(-w / 2, h / 2, 0), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m, canCollide = false })
	local leaf = Builder.part({ name = "Leaf", size = Vector3.new(w - 0.1, h - 0.1, thick), cframe = cframe * CFrame.new(0, h / 2, 0), material = if o.heavy then Enum.Material.Metal else Enum.Material.SmoothPlastic, color = color, parent = m })
	leaf.CanCollide = true
	local mod = Instance.new("PathfindingModifier")
	mod.Label = if o.locked then "LockedDoor" else "Door"
	mod.PassThrough = true
	mod.Parent = leaf
	-- Frame
	Builder.part({ name = "FrameL", size = Vector3.new(0.3, h + 0.3, thick + 0.4), cframe = cframe * CFrame.new(-w / 2 - 0.15, h / 2, 0), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m })
	Builder.part({ name = "FrameR", size = Vector3.new(0.3, h + 0.3, thick + 0.4), cframe = cframe * CFrame.new(w / 2 + 0.15, h / 2, 0), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m })
	Builder.part({ name = "FrameT", size = Vector3.new(w + 0.6, 0.3, thick + 0.4), cframe = cframe * CFrame.new(0, h + 0.15, 0), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m })
	if o.heavy then
		local wheel = Builder.part({ name = "Wheel", size = Vector3.new(1.6, 1.6, 0.25), cframe = cframe * CFrame.new(w * 0.2, h * 0.5, thick / 2 + 0.2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = Builder.Palette.Stainless, parent = m, canCollide = false })
		wheel.CFrame = cframe * CFrame.new(w * 0.2, h * 0.5, thick / 2 + 0.2) * CFrame.Angles(0, math.pi / 2, 0)
		local wheel2 = wheel:Clone()
		wheel2.CFrame = cframe * CFrame.new(w * 0.2, h * 0.5, -thick / 2 - 0.2) * CFrame.Angles(0, math.pi / 2, 0)
		wheel2.Parent = m
		for i = 0, 2 do
			Builder.part({ name = "Rib", size = Vector3.new(w - 0.4, 0.15, 0.1), cframe = cframe * CFrame.new(0, h * (0.25 + i * 0.25), thick / 2 + 0.05), material = Enum.Material.Metal, color = Builder.Palette.Graphite, parent = m, canCollide = false })
		end
		Builder.hazardStripes(m, cframe * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, 0), w + 1, 1.2)
	else
		Builder.part({ name = "Handle", size = Vector3.new(0.9, 0.15, 0.15), cframe = cframe * CFrame.new(w * 0.32, h * 0.47, thick / 2 + 0.12), material = Enum.Material.Metal, color = Builder.Palette.Stainless, parent = m, canCollide = false })
		Builder.part({ name = "Handle2", size = Vector3.new(0.9, 0.15, 0.15), cframe = cframe * CFrame.new(w * 0.32, h * 0.47, -thick / 2 - 0.12), material = Enum.Material.Metal, color = Builder.Palette.Stainless, parent = m, canCollide = false })
		if o.window then
			Builder.part({ name = "Porthole", size = Vector3.new(1.2, 1.6, thick + 0.05), cframe = cframe * CFrame.new(-w * 0.1, h * 0.7, 0), material = Enum.Material.Glass, color = Builder.Palette.GlassTint, parent = m, transparency = 0.5, canCollide = false })
		end
	end
	if o.label then
		Builder.label(leaf, Enum.NormalId.Front, o.label, { textColor = Builder.Palette.WarningBlack, textSize = 28, bold = true, pixelsPerStud = 30 })
	end
	m:SetAttribute("Open", false)
	m:SetAttribute("Locked", o.locked == true)
	m:SetAttribute("Heavy", o.heavy == true)
	m:SetAttribute("Width", w)
	m:SetAttribute("Height", h)
	m.PrimaryPart = leaf
	-- Leaf rotates around the hinge; store its closed CFrame relative to the hinge.
	m:SetAttribute("ClosedOffset", hinge.CFrame:ToObjectSpace(leaf.CFrame))
	return m
end

-- Oil radiator / heater block.
function Builder.heater(parent: Instance, cframe: CFrame, circuit: string, range: number): Part
	local m = Builder.model(parent, "Heater")
	local body = Builder.part({ name = "Body", size = Vector3.new(3.2, 2.2, 0.6), cframe = cframe * CFrame.new(0, 1.3, 0), material = Enum.Material.Metal, color = Builder.Palette.DirtyWhiteDark, parent = m })
	for i = 0, 6 do
		Builder.part({ name = "Fin", size = Vector3.new(0.3, 2.0, 0.8), cframe = cframe * CFrame.new(-1.35 + i * 0.45, 1.3, 0), material = Enum.Material.Metal, color = Builder.Palette.DirtyWhite, parent = m, canCollide = false })
	end
	local glow = Builder.part({ name = "Lamp", size = Vector3.new(0.3, 0.3, 0.1), cframe = cframe * CFrame.new(1.3, 2.2, 0.35), material = Enum.Material.Neon, color = Builder.Palette.Orange, parent = m, canCollide = false, castShadow = false })
	Builder.pointLight(glow, Builder.Palette.Orange, 6, 0.4).Name = "Light"
	Builder.registerLamp(glow, circuit, Builder.Palette.Orange, 0.4)
	body:SetAttribute("Heater", true)
	body:SetAttribute("Circuit", circuit)
	body:SetAttribute("Range", range)
	return body
end

-- Attachment-only FX anchor the client fills with particle emitters (snow,
-- dust, steam) according to its quality settings. Server never emits.
function Builder.fxAnchor(parent: Instance, name: string, cframe: CFrame, kind: string, size: Vector3?, attrs: { [string]: any }?): Part
	local p = Builder.invisible(parent, name, cframe, size or Vector3.new(1, 1, 1))
	p:SetAttribute("FX", kind)
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	return p
end

return Builder
