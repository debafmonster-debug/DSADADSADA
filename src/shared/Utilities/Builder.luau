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

return Builder
