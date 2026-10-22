--!nonstrict
-- Furniture and equipment props shared by the station, the lobby and the
-- client-built cinematic sets. Every prop returns a Model (unless noted),
-- takes a floor-level CFrame and keeps part counts small. Interactive props
-- expose named child parts that services look up (documented per function).
local Builder = require(script.Parent.Builder)
local P = Builder.Palette

local Props = {}

local function box(parent, name, cf, size, mat, color, collide)
	local p = Builder.part({ name = name, cframe = cf, size = size, material = mat, color = color, parent = parent })
	if collide ~= nil then
		p.CanCollide = collide
	end
	return p
end

-- ===== Furniture ======================================================

function Props.table(parent: Instance, cf: CFrame, w: number?, d: number?, color: Color3?): Model
	local m = Builder.model(parent, "Table")
	local W, D = w or 6, d or 3
	box(m, "Top", cf * CFrame.new(0, 2.6, 0), Vector3.new(W, 0.25, D), Enum.Material.WoodPlanks, color or P.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, "Leg", cf * CFrame.new(sx * (W / 2 - 0.3), 1.25, sz * (D / 2 - 0.3)), Vector3.new(0.3, 2.5, 0.3), Enum.Material.Metal, P.Graphite, false)
		end
	end
	return m
end

function Props.desk(parent: Instance, cf: CFrame, withPapers: boolean?): Model
	local m = Props.table(parent, cf, 7, 3.2, P.WoodDark)
	m.Name = "Desk"
	box(m, "Drawer", cf * CFrame.new(2.3, 1.6, 0), Vector3.new(2, 1.9, 2.8), Enum.Material.WoodPlanks, P.WoodDark)
	if withPapers ~= false then
		Props.papers(m, cf * CFrame.new(-1.2, 2.73, 0.3))
		Props.lampDesk(m, cf * CFrame.new(2.6, 2.73, -0.9))
	end
	return m
end

function Props.lampDesk(parent: Instance, cf: CFrame, color: Color3?, circuit: string?): Part
	local m = Builder.model(parent, "DeskLamp")
	box(m, "Base", cf * CFrame.new(0, 0.1, 0), Vector3.new(0.9, 0.2, 0.9), Enum.Material.Metal, P.OldGreenDark, false)
	box(m, "Arm", cf * CFrame.new(0, 1.0, 0) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.12, 2.0, 0.12), Enum.Material.Metal, P.OldGreenDark, false)
	box(m, "Shade", cf * CFrame.new(0, 1.85, 0.4) * CFrame.Angles(0.5, 0, 0), Vector3.new(1.3, 0.6, 1.1), Enum.Material.Metal, P.OldGreen, false)
	local lamp = box(m, "Lamp", cf * CFrame.new(0, 1.65, 0.6), Vector3.new(0.5, 0.15, 0.5), Enum.Material.Neon, color or P.LightWarmOld, false)
	lamp.CastShadow = false
	Builder.pointLight(lamp, color or P.LightWarmOld, 9, 0.7, false).Name = "Light"
	Builder.registerLamp(lamp, circuit or "LightsMain", color or P.LightWarmOld, 0.7)
	return lamp
end

function Props.chair(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = Builder.model(parent, "Chair")
	local c = color or P.Fabric
	box(m, "Seat", cf * CFrame.new(0, 1.6, 0), Vector3.new(1.8, 0.3, 1.8), Enum.Material.Fabric, c)
	box(m, "Back", cf * CFrame.new(0, 2.7, -0.75), Vector3.new(1.8, 2.0, 0.3), Enum.Material.Fabric, c)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, "Leg", cf * CFrame.new(sx * 0.7, 0.75, sz * 0.7), Vector3.new(0.15, 1.5, 0.15), Enum.Material.Metal, P.Graphite, false)
		end
	end
	m.PrimaryPart = m:FindFirstChild("Seat") :: Part
	return m
end

function Props.bed(parent: Instance, cf: CFrame, blanket: Color3?, name: string?): Model
	local m = Builder.model(parent, name or "Bed")
	box(m, "Frame", cf * CFrame.new(0, 0.9, 0), Vector3.new(3.4, 0.5, 7.2), Enum.Material.Metal, P.OldGreenDark)
	box(m, "Mattress", cf * CFrame.new(0, 1.45, 0), Vector3.new(3.2, 0.6, 7), Enum.Material.Fabric, P.DirtyWhiteDark)
	box(m, "Blanket", cf * CFrame.new(0, 1.8, 0.9), Vector3.new(3.2, 0.25, 5), Enum.Material.Fabric, blanket or P.Blanket, false)
	box(m, "Pillow", cf * CFrame.new(0, 1.9, -2.8), Vector3.new(2.4, 0.5, 1.4), Enum.Material.Fabric, P.DirtyWhite, false)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, "Leg", cf * CFrame.new(sx * 1.5, 0.35, sz * 3.4), Vector3.new(0.2, 0.7, 0.2), Enum.Material.Metal, P.OldGreenDark, false)
		end
	end
	box(m, "Headboard", cf * CFrame.new(0, 2.2, -3.6), Vector3.new(3.4, 2.2, 0.15), Enum.Material.Metal, P.OldGreenDark, false)
	local seat = Builder.invisible(m, "Seat", cf * CFrame.new(0, 1.8, 1.2), Vector3.new(2, 0.2, 2))
	seat:SetAttribute("BedSeat", true)
	m.PrimaryPart = m:FindFirstChild("Frame") :: Part
	return m
end

function Props.locker(parent: Instance, cf: CFrame, color: Color3?, label: string?): Model
	local m = Builder.model(parent, "Locker")
	local body = box(m, "Body", cf * CFrame.new(0, 3.2, 0), Vector3.new(2, 6.4, 1.8), Enum.Material.Metal, color or P.OldGreen)
	box(m, "Door", cf * CFrame.new(0, 3.2, 0.92), Vector3.new(1.8, 6.2, 0.1), Enum.Material.Metal, color or P.OldGreen, false)
	box(m, "Handle", cf * CFrame.new(0.6, 3.4, 1.03), Vector3.new(0.15, 0.6, 0.1), Enum.Material.Metal, P.Stainless, false)
	for i = 0, 2 do
		box(m, "Vent", cf * CFrame.new(0, 5.4 - i * 0.35, 1.0), Vector3.new(1.0, 0.08, 0.05), Enum.Material.Metal, P.Graphite, false)
	end
	if label then
		Builder.label(body, Enum.NormalId.Front, label, { textSize = 26, bold = true, textColor = P.DirtyWhite, alignY = Enum.TextYAlignment.Top, padding = 6 })
	end
	m.PrimaryPart = body
	return m
end

function Props.shelf(parent: Instance, cf: CFrame, w: number?, levels: number?, color: Color3?): Model
	local m = Builder.model(parent, "Shelf")
	local W, L = w or 4, levels or 4
	local c = color or P.Graphite
	for i = 1, L do
		box(m, "Board", cf * CFrame.new(0, i * 1.7 - 0.4, 0), Vector3.new(W, 0.12, 1.4), Enum.Material.Metal, c, i == 1)
	end
	box(m, "PostL", cf * CFrame.new(-W / 2 + 0.1, L * 0.85, 0), Vector3.new(0.15, L * 1.7, 1.4), Enum.Material.Metal, c)
	box(m, "PostR", cf * CFrame.new(W / 2 - 0.1, L * 0.85, 0), Vector3.new(0.15, L * 1.7, 1.4), Enum.Material.Metal, c)
	return m
end

function Props.cabinet(parent: Instance, cf: CFrame, color: Color3?, label: string?): Model
	local m = Builder.model(parent, "Cabinet")
	local body = box(m, "Body", cf * CFrame.new(0, 3, 0), Vector3.new(4, 6, 1.8), Enum.Material.Metal, color or P.DirtyWhiteDark)
	box(m, "DoorL", cf * CFrame.new(-1, 3, 0.92), Vector3.new(1.9, 5.8, 0.08), Enum.Material.Metal, color or P.DirtyWhiteDark, false)
	box(m, "DoorR", cf * CFrame.new(1, 3, 0.92), Vector3.new(1.9, 5.8, 0.08), Enum.Material.Metal, color or P.DirtyWhiteDark, false)
	box(m, "HandleL", cf * CFrame.new(-0.25, 3.1, 1.02), Vector3.new(0.12, 0.7, 0.08), Enum.Material.Metal, P.Stainless, false)
	box(m, "HandleR", cf * CFrame.new(0.25, 3.1, 1.02), Vector3.new(0.12, 0.7, 0.08), Enum.Material.Metal, P.Stainless, false)
	if label then
		Builder.label(body, Enum.NormalId.Front, label, { textSize = 30, bold = true, textColor = P.Red, alignY = Enum.TextYAlignment.Top, padding = 10 })
	end
	m.PrimaryPart = body
	return m
end

function Props.crate(parent: Instance, cf: CFrame, size: Vector3?, color: Color3?, label: string?): Model
	local m = Builder.model(parent, "Crate")
	local s = size or Vector3.new(3, 2.2, 2.4)
	local b = box(m, "Body", cf * CFrame.new(0, s.Y / 2, 0), s, Enum.Material.WoodPlanks, color or P.Wood)
	box(m, "Band", cf * CFrame.new(0, s.Y / 2, 0), Vector3.new(s.X + 0.05, 0.3, s.Z + 0.05), Enum.Material.Metal, P.Graphite, false)
	if label then
		Builder.label(b, Enum.NormalId.Front, label, { textSize = 24, bold = true, textColor = P.WarningBlack })
	end
	m.PrimaryPart = b
	return m
end

function Props.barrel(parent: Instance, cf: CFrame, color: Color3?, label: string?): Model
	local m = Builder.model(parent, "Barrel")
	local b = Builder.part({ name = "Body", cframe = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), size = Vector3.new(3.2, 2.2, 2.2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = color or P.StationOrangeDark, parent = m })
	for _, y in { 0.6, 2.6 } do
		Builder.part({ name = "Ring", cframe = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), size = Vector3.new(0.2, 2.3, 2.3), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Graphite, parent = m, canCollide = false })
	end
	if label then
		Builder.label(b, Enum.NormalId.Top, label, { textSize = 22, bold = true, textColor = P.DirtyWhite })
	end
	m.PrimaryPart = b
	return m
end

function Props.jerrycan(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = Builder.model(parent, "Jerrycan")
	local b = box(m, "Body", cf * CFrame.new(0, 0.9, 0), Vector3.new(1.3, 1.8, 0.7), Enum.Material.Metal, color or P.OldGreenDark)
	box(m, "Handle", cf * CFrame.new(0, 1.95, 0), Vector3.new(0.8, 0.15, 0.15), Enum.Material.Metal, color or P.OldGreenDark, false)
	box(m, "Cap", cf * CFrame.new(0.45, 1.95, 0), Vector3.new(0.3, 0.25, 0.3), Enum.Material.Metal, P.Graphite, false)
	m.PrimaryPart = b
	return m
end

function Props.bench(parent: Instance, cf: CFrame, len: number?): Model
	local m = Builder.model(parent, "Bench")
	local L = len or 6
	box(m, "Seat", cf * CFrame.new(0, 1.5, 0), Vector3.new(L, 0.3, 1.6), Enum.Material.WoodPlanks, P.Wood)
	box(m, "LegL", cf * CFrame.new(-L / 2 + 0.5, 0.7, 0), Vector3.new(0.3, 1.4, 1.4), Enum.Material.Metal, P.Graphite, false)
	box(m, "LegR", cf * CFrame.new(L / 2 - 0.5, 0.7, 0), Vector3.new(0.3, 1.4, 1.4), Enum.Material.Metal, P.Graphite, false)
	return m
end

function Props.sofa(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = Builder.model(parent, "Sofa")
	local c = color or P.FabricWarm
	box(m, "Seat", cf * CFrame.new(0, 1.2, 0), Vector3.new(7, 1.2, 3), Enum.Material.Fabric, c)
	box(m, "Back", cf * CFrame.new(0, 2.6, -1.2), Vector3.new(7, 2.2, 0.8), Enum.Material.Fabric, c)
	box(m, "ArmL", cf * CFrame.new(-3.2, 2.0, 0), Vector3.new(0.6, 1.6, 3), Enum.Material.Fabric, c)
	box(m, "ArmR", cf * CFrame.new(3.2, 2.0, 0), Vector3.new(0.6, 1.6, 3), Enum.Material.Fabric, c)
	local seat = Builder.invisible(m, "Seat1", cf * CFrame.new(-1.6, 1.9, 0.3), Vector3.new(2, 0.2, 2))
	seat:SetAttribute("Seat", true)
	m.PrimaryPart = m:FindFirstChild("Seat") :: Part
	return m
end

function Props.mug(parent: Instance, cf: CFrame, warm: boolean?, color: Color3?): Model
	local m = Builder.model(parent, "Mug")
	local b = Builder.part({ name = "Body", cframe = cf * CFrame.new(0, 0.3, 0), size = Vector3.new(0.6, 0.6, 0.6), shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, color = color or P.Mug, parent = m, canCollide = false })
	b.CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	box(m, "Handle", cf * CFrame.new(0.38, 0.3, 0), Vector3.new(0.12, 0.35, 0.3), Enum.Material.SmoothPlastic, color or P.Mug, false)
	local tea = box(m, "Tea", cf * CFrame.new(0, 0.56, 0), Vector3.new(0.5, 0.05, 0.5), Enum.Material.SmoothPlastic, Color3.fromRGB(120, 70, 30), false)
	if warm then
		local fx = Builder.fxAnchor(m, "Steam", cf * CFrame.new(0, 0.7, 0), "Steam")
		fx:SetAttribute("Rate", 2)
	end
	m:SetAttribute("Warm", warm == true)
	m.PrimaryPart = tea
	return m
end

function Props.papers(parent: Instance, cf: CFrame, count: number?): Model
	local m = Builder.model(parent, "Papers")
	for i = 1, count or 3 do
		box(m, "Sheet", cf * CFrame.new((i - 2) * 0.25, 0.02 * i, (i % 2) * 0.3) * CFrame.Angles(0, (i - 2) * 0.15, 0), Vector3.new(1.4, 0.03, 1.9), Enum.Material.SmoothPlastic, P.Paper, false)
	end
	return m
end

function Props.book(parent: Instance, cf: CFrame, color: Color3?): Part
	return box(parent, "Book", cf * CFrame.new(0, 0.15, 0), Vector3.new(1.1, 0.3, 1.5), Enum.Material.Fabric, color or P.OldGreenDark, false)
end

function Props.boots(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Boots")
	box(m, "L", cf * CFrame.new(-0.4, 0.45, 0), Vector3.new(0.6, 0.9, 1.4), Enum.Material.Fabric, P.Bakelite, false)
	box(m, "R", cf * CFrame.new(0.4, 0.45, 0.2) * CFrame.Angles(0, 0.2, 0), Vector3.new(0.6, 0.9, 1.4), Enum.Material.Fabric, P.Bakelite, false)
	return m
end

function Props.coatRack(parent: Instance, cf: CFrame, coats: number?): Model
	local m = Builder.model(parent, "CoatRack")
	box(m, "Rail", cf * CFrame.new(0, 6.2, 0), Vector3.new(5, 0.2, 0.3), Enum.Material.Metal, P.Graphite, false)
	for i = 1, coats or 3 do
		box(m, "Coat", cf * CFrame.new(-2 + i * 1.2, 4.3, 0.2), Vector3.new(1.3, 3.6, 0.7), Enum.Material.Fabric, if i % 2 == 0 then P.StationOrangeFaded else P.OldGreen, false)
	end
	return m
end

function Props.photoFrame(parent: Instance, cf: CFrame, caption: string?): Part
	local f = box(parent, "PhotoFrame", cf, Vector3.new(1.6, 1.2, 0.08), Enum.Material.Wood, P.WoodDark, false)
	local photo = box(f, "Photo", cf * CFrame.new(0, 0, 0.05), Vector3.new(1.4, 1.0, 0.02), Enum.Material.SmoothPlastic, Color3.fromRGB(150, 150, 140), false)
	if caption then
		Builder.label(photo, Enum.NormalId.Front, caption, { textSize = 14, textColor = P.WarningBlack, alignY = Enum.TextYAlignment.Bottom })
	end
	return f
end

function Props.noticeBoard(parent: Instance, cf: CFrame, w: number, h: number, lines: { string }): Part
	local b = box(parent, "NoticeBoard", cf, Vector3.new(w, h, 0.2), Enum.Material.Fabric, Color3.fromRGB(96, 82, 60), false)
	local text = table.concat(lines, "\n")
	Builder.label(b, Enum.NormalId.Front, text, { textSize = 18, textColor = P.Paper, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 8, pixelsPerStud = 30 })
	for i = 1, 3 do
		box(b, "Pin", cf * CFrame.new(-w / 2 + i * (w / 4), h / 2 - 0.3, 0.12), Vector3.new(0.15, 0.15, 0.1), Enum.Material.SmoothPlastic, P.Red, false)
	end
	return b
end

function Props.wallClock(parent: Instance, cf: CFrame, name: string?): Model
	local m = Builder.model(parent, name or "WallClock")
	local face = Builder.part({ name = "Face", cframe = cf * CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.2, 2.2, 2.2), shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, color = P.DirtyWhite, parent = m, canCollide = false })
	Builder.part({ name = "Rim", cframe = cf * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.15, 2.4, 2.4), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Bakelite, parent = m, canCollide = false })
	local hour = box(m, "Hour", cf * CFrame.new(0, 0.35, 0.15), Vector3.new(0.1, 0.7, 0.04), Enum.Material.SmoothPlastic, P.WarningBlack, false)
	local minute = box(m, "Minute", cf * CFrame.new(0, 0.45, 0.17), Vector3.new(0.07, 0.95, 0.04), Enum.Material.SmoothPlastic, P.WarningBlack, false)
	hour:SetAttribute("Hand", "hour")
	minute:SetAttribute("Hand", "minute")
	m:SetAttribute("Clock", true)
	m:SetAttribute("Center", cf)
	m.PrimaryPart = face
	return m
end

-- ===== Equipment =======================================================

function Props.monitor(parent: Instance, cf: CFrame, text: string, color: Color3?, circuit: string?): Model
	local m = Builder.model(parent, "Monitor")
	box(m, "Case", cf * CFrame.new(0, 0.9, 0), Vector3.new(2.2, 1.8, 1.6), Enum.Material.Plastic, P.DirtyWhiteDark, false)
	local screen = box(m, "Screen", cf * CFrame.new(0, 0.95, 0.82), Vector3.new(1.8, 1.3, 0.05), Enum.Material.Neon, color or P.ScreenBlue, false)
	screen.CastShadow = false
	local lbl = Builder.label(screen, Enum.NormalId.Front, text, { textSize = 14, textColor = Color3.new(0.9, 0.95, 1), font = Enum.Font.Code, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, padding = 4, pixelsPerStud = 40 })
	lbl.Name = "Text"
	Builder.pointLight(screen, color or P.ScreenBlue, 5, 0.35, false).Name = "Light"
	Builder.registerLamp(screen, circuit or "LightsMain", color or P.ScreenBlue, 0.35)
	m.PrimaryPart = screen
	return m
end

-- Analog gauge: needle angle driven by attribute `Value` (0..1) on the face.
function Props.gauge(parent: Instance, cf: CFrame, label: string, value: number?): Part
	local face = Builder.part({ name = "Gauge", cframe = cf * CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.15, 1.1, 1.1), shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, color = P.Paper, parent = parent, canCollide = false })
	Builder.part({ name = "Rim", cframe = cf * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.12, 1.25, 1.25), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Bakelite, parent = face, canCollide = false })
	local needle = box(face, "Needle", cf * CFrame.new(0, 0.2, 0.1), Vector3.new(0.05, 0.45, 0.03), Enum.Material.SmoothPlastic, P.Red, false)
	needle:SetAttribute("Needle", true)
	face:SetAttribute("Value", value or 0.5)
	face:SetAttribute("Center", cf)
	Builder.label(face, Enum.NormalId.Right, label, { textSize = 10, textColor = P.WarningBlack, alignY = Enum.TextYAlignment.Bottom, pixelsPerStud = 60 })
	return face
end

-- Control console with a bank of gauges, switches and a status screen.
function Props.console(parent: Instance, cf: CFrame, w: number, title: string, gauges: { string }, circuit: string?): Model
	local m = Builder.model(parent, "Console")
	box(m, "Base", cf * CFrame.new(0, 1.4, 0), Vector3.new(w, 2.8, 2.4), Enum.Material.Metal, P.OldGreen)
	local slope = cf * CFrame.new(0, 3.1, -0.3) * CFrame.Angles(-0.45, 0, 0)
	local top = box(m, "Panel", slope, Vector3.new(w, 0.3, 2.2), Enum.Material.Metal, P.OldGreenDark)
	Builder.label(top, Enum.NormalId.Top, title, { textSize = 22, bold = true, textColor = P.Paper, alignY = Enum.TextYAlignment.Top, padding = 6, pixelsPerStud = 30 })
	local n = #gauges
	for i, g in gauges do
		local x = (i - (n + 1) / 2) * math.min(1.6, (w - 1) / math.max(1, n))
		local gf = Props.gauge(m, slope * CFrame.new(x, 0.25, 0.3) * CFrame.Angles(math.pi / 2 - 0.45, 0, 0), g, 0.5)
		gf.Name = "Gauge_" .. g
	end
	for i = 1, math.max(2, math.floor(w / 2)) do
		local x = -w / 2 + 0.8 + (i - 1) * 1.1
		local sw = box(m, "Toggle", slope * CFrame.new(x, 0.25, -0.6), Vector3.new(0.3, 0.3, 0.5), Enum.Material.SmoothPlastic, P.Bakelite, false)
		local led = box(sw, "Led", slope * CFrame.new(x, 0.3, -0.95), Vector3.new(0.18, 0.12, 0.18), Enum.Material.Neon, if i % 3 == 0 then P.Red else P.Green, false)
		led.CastShadow = false
		Builder.registerLamp(led, circuit or "LightsMain", led.Color, 0.1)
	end
	m.PrimaryPart = top
	return m
end

-- Breaker panel. Returns the model; `Switches` folder holds parts with
-- attributes CircuitId / On and a child `Lamp`. `MainLever` resets the trip.
function Props.breakerPanel(parent: Instance, cf: CFrame, circuits: { { id: string, label: string } }): Model
	local m = Builder.model(parent, "BreakerPanel")
	local h = 1.2 + #circuits * 1.0
	local body = box(m, "Body", cf * CFrame.new(0, 2.2 + h / 2, 0), Vector3.new(4.2, h + 1.6, 0.8), Enum.Material.Metal, P.DirtyWhiteDark)
	Builder.label(body, Enum.NormalId.Front, "ЩИТ К-1  ~380 В", { textSize = 20, bold = true, textColor = P.WarningBlack, alignY = Enum.TextYAlignment.Top, padding = 8, pixelsPerStud = 30 })
	local sw = Builder.folder(m, "Switches")
	for i, c in circuits do
		local y = 2.2 + h / 2 + h / 2 - 1.4 - i * 1.0
		local s = box(sw, "Switch", cf * CFrame.new(-1.2, y, 0.48), Vector3.new(0.5, 0.7, 0.3), Enum.Material.SmoothPlastic, P.Bakelite, false)
		s:SetAttribute("CircuitId", c.id)
		s:SetAttribute("On", true)
		local lamp = box(s, "Lamp", cf * CFrame.new(-0.6, y, 0.45), Vector3.new(0.2, 0.2, 0.1), Enum.Material.Neon, P.Green, false)
		lamp.CastShadow = false
		local lbl = box(s, "Label", cf * CFrame.new(0.9, y, 0.42), Vector3.new(2.2, 0.6, 0.05), Enum.Material.SmoothPlastic, P.Paper, false)
		Builder.label(lbl, Enum.NormalId.Front, c.label, { textSize = 16, bold = true, textColor = P.WarningBlack, pixelsPerStud = 40 })
	end
	local lever = box(m, "MainLever", cf * CFrame.new(1.4, 2.2 + h + 0.2, 0.55), Vector3.new(0.4, 1.2, 0.3), Enum.Material.Metal, P.Red, false)
	lever:SetAttribute("Tripped", false)
	local tripLamp = box(m, "TripLamp", cf * CFrame.new(0.6, 2.2 + h + 0.2, 0.45), Vector3.new(0.25, 0.25, 0.1), Enum.Material.Neon, P.Green, false)
	tripLamp.CastShadow = false
	m.PrimaryPart = body
	return m
end

-- Fuse box with slots. Slots carry attribute `Index` and `Blown`.
function Props.fuseBox(parent: Instance, cf: CFrame, slots: number): Model
	local m = Builder.model(parent, "FuseBox")
	local body = box(m, "Body", cf * CFrame.new(0, 4.5, 0), Vector3.new(2.6, 2.2, 0.6), Enum.Material.Metal, P.OldGreen)
	Builder.label(body, Enum.NormalId.Front, "ПРЕДОХРАНИТЕЛИ", { textSize = 14, bold = true, textColor = P.Paper, alignY = Enum.TextYAlignment.Top, padding = 4, pixelsPerStud = 40 })
	local f = Builder.folder(m, "Slots")
	for i = 1, slots do
		local x = (i - (slots + 1) / 2) * 0.7
		local s = Builder.part({ name = "Slot", cframe = cf * CFrame.new(x, 4.3, 0.35) * CFrame.Angles(math.pi / 2, 0, 0), size = Vector3.new(0.5, 0.4, 0.5), shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, color = P.Paper, parent = f, canCollide = false })
		s:SetAttribute("Index", i)
		s:SetAttribute("Blown", false)
	end
	m.PrimaryPart = body
	return m
end

-- Old radio station console. `Dial` carries attribute Frequency; `PowerLamp`.
function Props.radioStation(parent: Instance, cf: CFrame, circuit: string?): Model
	local m = Builder.model(parent, "RadioStation")
	local body = box(m, "Body", cf * CFrame.new(0, 4.0, 0), Vector3.new(5, 2.6, 2.2), Enum.Material.Metal, P.OldGreen)
	box(m, "Stand", cf * CFrame.new(0, 1.35, 0), Vector3.new(5, 2.7, 2.2), Enum.Material.Metal, P.OldGreenDark)
	local face = box(m, "Face", cf * CFrame.new(0, 4.0, 1.12), Vector3.new(4.8, 2.4, 0.06), Enum.Material.SmoothPlastic, P.Bakelite, false)
	local scale = box(m, "Scale", cf * CFrame.new(-0.6, 4.5, 1.17), Vector3.new(2.8, 0.7, 0.03), Enum.Material.Neon, P.LightWarmOld, false)
	scale.CastShadow = false
	Builder.registerLamp(scale, circuit or "Radio", P.LightWarmOld, 0.3)
	Builder.pointLight(scale, P.LightWarmOld, 4, 0.3).Name = "Light"
	local dial = Builder.part({ name = "Dial", cframe = cf * CFrame.new(1.6, 4.2, 1.25) * CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(0.3, 1.0, 1.0), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.Stainless, parent = m, canCollide = false })
	dial:SetAttribute("Frequency", 4000)
	local needle = box(scale, "Needle", cf * CFrame.new(-0.6, 4.5, 1.2), Vector3.new(0.04, 0.6, 0.02), Enum.Material.SmoothPlastic, P.Red, false)
	needle:SetAttribute("Needle", true)
	for i = 0, 5 do
		box(face, "Knob", cf * CFrame.new(-2.0 + i * 0.5, 3.3, 1.2), Vector3.new(0.3, 0.3, 0.2), Enum.Material.SmoothPlastic, P.Bakelite, false)
	end
	local lamp = box(face, "PowerLamp", cf * CFrame.new(2.1, 3.3, 1.18), Vector3.new(0.2, 0.2, 0.1), Enum.Material.Neon, P.Green, false)
	lamp.CastShadow = false
	Builder.registerLamp(lamp, circuit or "Radio", P.Green, 0.2)
	-- microphone + headset
	box(m, "MicBase", cf * CFrame.new(2.0, 2.85, 1.9), Vector3.new(0.7, 0.2, 0.7), Enum.Material.Metal, P.Bakelite, false)
	box(m, "MicStem", cf * CFrame.new(2.0, 3.4, 1.9), Vector3.new(0.08, 1.0, 0.08), Enum.Material.Metal, P.Stainless, false)
	box(m, "Mic", cf * CFrame.new(2.0, 3.95, 1.9), Vector3.new(0.45, 0.3, 0.45), Enum.Material.Metal, P.Graphite, false)
	box(m, "Headset", cf * CFrame.new(-2.1, 2.85, 1.8), Vector3.new(1.1, 0.3, 0.6), Enum.Material.Plastic, P.Bakelite, false)
	Props.papers(m, cf * CFrame.new(-0.5, 2.75, 1.9), 2)
	local speaker = box(m, "Speaker", cf * CFrame.new(0, 5.6, 0.2), Vector3.new(2.4, 0.6, 1.6), Enum.Material.Fabric, P.Bakelite, false)
	speaker.Name = "Speaker"
	m.PrimaryPart = body
	return m
end

-- Small transistor radio (dorm, apartment).
function Props.radioSmall(parent: Instance, cf: CFrame, name: string?): Model
	local m = Builder.model(parent, name or "RadioSmall")
	local b = box(m, "Body", cf * CFrame.new(0, 0.45, 0), Vector3.new(1.6, 0.9, 0.6), Enum.Material.Plastic, P.Bakelite, false)
	box(m, "Grille", cf * CFrame.new(-0.35, 0.45, 0.31), Vector3.new(0.7, 0.6, 0.02), Enum.Material.Fabric, P.FabricWarm, false)
	box(m, "Dial", cf * CFrame.new(0.45, 0.45, 0.31), Vector3.new(0.5, 0.5, 0.02), Enum.Material.SmoothPlastic, P.Paper, false)
	box(m, "Antenna", cf * CFrame.new(0.7, 1.4, -0.2) * CFrame.Angles(0, 0, -0.3), Vector3.new(0.05, 1.2, 0.05), Enum.Material.Metal, P.Stainless, false)
	m.PrimaryPart = b
	return m
end

function Props.tv(parent: Instance, cf: CFrame, on: boolean?): Model
	local m = Builder.model(parent, "TV")
	box(m, "Case", cf * CFrame.new(0, 1.3, 0), Vector3.new(3.4, 2.6, 2.4), Enum.Material.Wood, P.WoodDark)
	local screen = box(m, "Screen", cf * CFrame.new(0, 1.35, 1.22), Vector3.new(2.6, 2.0, 0.05), if on then Enum.Material.Neon else Enum.Material.Glass, if on then Color3.fromRGB(120, 150, 180) else Color3.fromRGB(30, 34, 40), false)
	screen.CastShadow = false
	if on then
		Builder.pointLight(screen, Color3.fromRGB(140, 170, 210), 10, 0.8).Name = "Light"
		screen:SetAttribute("TVScreen", true)
	end
	box(m, "Knob", cf * CFrame.new(1.4, 0.7, 1.22), Vector3.new(0.3, 0.3, 0.15), Enum.Material.Plastic, P.Bakelite, false)
	m.PrimaryPart = screen
	return m
end

function Props.floorLamp(parent: Instance, cf: CFrame, color: Color3?): Part
	local m = Builder.model(parent, "FloorLamp")
	box(m, "Base", cf * CFrame.new(0, 0.1, 0), Vector3.new(1.4, 0.2, 1.4), Enum.Material.Metal, P.Bakelite, false)
	box(m, "Pole", cf * CFrame.new(0, 3, 0), Vector3.new(0.12, 6, 0.12), Enum.Material.Metal, P.Stainless, false)
	box(m, "Shade", cf * CFrame.new(0, 6.3, 0), Vector3.new(2.2, 1.4, 2.2), Enum.Material.Fabric, P.FabricWarm, false)
	local lamp = box(m, "Lamp", cf * CFrame.new(0, 5.9, 0), Vector3.new(0.5, 0.5, 0.5), Enum.Material.Neon, color or P.LightWarmOld, false)
	lamp.CastShadow = false
	Builder.pointLight(lamp, color or P.LightWarmOld, 16, 0.9, true).Name = "Light"
	return lamp
end

function Props.stretcher(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "Stretcher")
	box(m, "Bed", cf * CFrame.new(0, 2.4, 0), Vector3.new(2.6, 0.3, 6.6), Enum.Material.Fabric, P.OldGreenDark)
	for _, sx in { -1, 1 } do
		box(m, "Rail", cf * CFrame.new(sx * 1.4, 2.4, 0), Vector3.new(0.15, 0.15, 7.2), Enum.Material.Metal, P.Stainless, false)
		for _, sz in { -1, 1 } do
			box(m, "Leg", cf * CFrame.new(sx * 1.1, 1.2, sz * 2.8), Vector3.new(0.15, 2.4, 0.15), Enum.Material.Metal, P.Stainless, false)
		end
	end
	return m
end

function Props.analyzer(parent: Instance, cf: CFrame, circuit: string?): Model
	local m = Builder.model(parent, "Analyzer")
	box(m, "Body", cf * CFrame.new(0, 1.0, 0), Vector3.new(2.6, 2.0, 1.6), Enum.Material.Metal, P.DirtyWhite, false)
	local screen = box(m, "Screen", cf * CFrame.new(-0.4, 1.3, 0.82), Vector3.new(1.3, 0.9, 0.04), Enum.Material.Neon, P.LightLab, false)
	screen.CastShadow = false
	Builder.label(screen, Enum.NormalId.Front, "T: +2.4°C\nAC: 7/40s", { textSize = 12, font = Enum.Font.Code, textColor = P.WarningBlack, pixelsPerStud = 50 })
	Builder.registerLamp(screen, circuit or "Lab", P.LightLab, 0.3)
	Builder.pointLight(screen, P.LightLab, 5, 0.3).Name = "Light"
	for i = 0, 3 do
		local led = box(m, "Led", cf * CFrame.new(0.6 + i * 0.25, 1.6, 0.82), Vector3.new(0.12, 0.12, 0.04), Enum.Material.Neon, if i == 2 then P.Red else P.Green, false)
		led.CastShadow = false
		Builder.registerLamp(led, circuit or "Lab", led.Color, 0.1)
	end
	return m
end

function Props.sampleJar(parent: Instance, cf: CFrame, color: Color3?): Part
	local j = Builder.part({ name = "SampleJar", cframe = cf * CFrame.new(0, 0.5, 0), size = Vector3.new(0.7, 1.0, 0.7), shape = Enum.PartType.Cylinder, material = Enum.Material.Glass, color = color or P.Ice, parent = parent, canCollide = false, transparency = 0.4 })
	j.CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	box(j, "Lid", cf * CFrame.new(0, 1.05, 0), Vector3.new(0.75, 0.12, 0.75), Enum.Material.Metal, P.Graphite, false)
	return j
end

function Props.cableDrum(parent: Instance, cf: CFrame): Model
	local m = Builder.model(parent, "CableDrum")
	Builder.part({ name = "Drum", cframe = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, 0), size = Vector3.new(2.2, 4, 4), shape = Enum.PartType.Cylinder, material = Enum.Material.Wood, color = P.Wood, parent = m })
	Builder.part({ name = "Cable", cframe = cf * CFrame.new(0, 2, 0), size = Vector3.new(2.0, 3.2, 3.2), shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber, color = P.Cable, parent = m, canCollide = false })
	return m
end

-- Document pickup: a paper/folder with a prompt (StoryService wires it).
function Props.documentPickup(parent: Instance, cf: CFrame, docId: string, title: string, kind: string?): Part
	local p = box(parent, "Document_" .. docId, cf * CFrame.new(0, 0.05, 0), Vector3.new(1.5, 0.08, 2.0), Enum.Material.SmoothPlastic, if kind == "Фотография" then Color3.fromRGB(170, 170, 160) else P.Paper, false)
	Builder.label(p, Enum.NormalId.Top, title, { textSize = 12, bold = true, textColor = P.WarningBlack, pixelsPerStud = 50 })
	p:SetAttribute("DocumentId", docId)
	return p
end

-- Item pickup (fuse, battery, medkit, spare part, canister).
function Props.itemPickup(parent: Instance, cf: CFrame, itemId: string, name: string): Part
	local size, color, mat = Vector3.new(1, 0.6, 1), P.Yellow, Enum.Material.SmoothPlastic
	if itemId == "Battery" then
		size, color = Vector3.new(1.0, 0.5, 0.6), P.Graphite
	elseif itemId == "Medkit" then
		size, color = Vector3.new(1.4, 0.7, 1.0), P.DirtyWhite
	elseif itemId == "SpareRelay" or itemId == "SpareInjector" then
		size, color, mat = Vector3.new(0.9, 0.9, 0.9), P.OldGreen, Enum.Material.Metal
	elseif itemId == "FuelCanister" then
		size, color, mat = Vector3.new(1.3, 1.8, 0.7), P.OldGreenDark, Enum.Material.Metal
	elseif itemId == "Fuse" then
		size, color, mat = Vector3.new(0.5, 0.5, 0.9), P.Paper, Enum.Material.SmoothPlastic
	end
	local p = box(parent, "Item_" .. itemId, cf * CFrame.new(0, size.Y / 2, 0), size, mat, color, false)
	if itemId == "Medkit" then
		box(p, "Cross", cf * CFrame.new(0, size.Y + 0.01, 0), Vector3.new(0.6, 0.02, 0.2), Enum.Material.SmoothPlastic, P.Red, false)
		box(p, "Cross2", cf * CFrame.new(0, size.Y + 0.01, 0), Vector3.new(0.2, 0.02, 0.6), Enum.Material.SmoothPlastic, P.Red, false)
	end
	p:SetAttribute("ItemId", itemId)
	p:SetAttribute("ItemName", name)
	return p
end

-- ===== Outdoor ==========================================================

function Props.snowDrift(parent: Instance, position: Vector3, size: Vector3): Part
	local d = Builder.part({ name = "SnowDrift", cframe = CFrame.new(position - Vector3.new(0, size.Y * 0.35, 0)), size = size, shape = Enum.PartType.Ball, material = Enum.Material.Snow, color = P.Snow, parent = parent, castShadow = true })
	d.CanCollide = true
	return d
end

function Props.guidePost(parent: Instance, position: Vector3): Part
	local post = box(parent, "GuidePost", CFrame.new(position + Vector3.new(0, 2, 0)), Vector3.new(0.3, 4, 0.3), Enum.Material.Wood, P.StationOrangeFaded, true)
	box(post, "Flag", CFrame.new(position + Vector3.new(0.35, 3.6, 0)), Vector3.new(0.6, 0.4, 0.04), Enum.Material.Fabric, P.Red, false)
	return post
end

function Props.guideRope(parent: Instance, a: Vector3, b: Vector3): Model
	local m = Builder.model(parent, "GuideRope")
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 10))
	local prev: Vector3? = nil
	for i = 0, n do
		local pos = a:Lerp(b, i / n)
		Props.guidePost(m, pos)
		if prev then
			local pa, pb = prev + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0)
			box(m, "Rope", CFrame.lookAt((pa + pb) / 2 - Vector3.new(0, 0.25, 0), pb), Vector3.new(0.08, 0.08, (pb - pa).Magnitude), Enum.Material.Fabric, P.Bakelite, false)
		end
		prev = pos
	end
	return m
end

function Props.stairs(parent: Instance, cf: CFrame, width: number, height: number, depth: number, steps: number?): Model
	local m = Builder.model(parent, "Stairs")
	local n = steps or math.max(3, math.floor(height / 1.0))
	local sh, sd = height / n, depth / n
	for i = 1, n do
		box(m, "Step", cf * CFrame.new(0, (i - 0.5) * sh, -(i - 0.5) * sd), Vector3.new(width, sh, sd), Enum.Material.DiamondPlate, P.Graphite)
	end
	for _, sx in { -1, 1 } do
		local a = cf * CFrame.new(sx * (width / 2 + 0.15), height + 1.2, 0)
		local b = cf * CFrame.new(sx * (width / 2 + 0.15), 1.2, -depth)
		box(m, "Rail", CFrame.lookAt((a.Position + b.Position) / 2, b.Position), Vector3.new(0.12, 0.12, (a.Position - b.Position).Magnitude), Enum.Material.Metal, P.StationOrangeDark, false)
		for i = 0, 2 do
			local t = i / 2
			local pos = a.Position:Lerp(b.Position, t)
			box(m, "Baluster", CFrame.new(pos - Vector3.new(0, 0.6, 0)), Vector3.new(0.1, 1.2, 0.1), Enum.Material.Metal, P.StationOrangeDark, false)
		end
	end
	return m
end

function Props.railing(parent: Instance, a: Vector3, b: Vector3, height: number?): Model
	local m = Builder.model(parent, "Railing")
	local h = height or 3.2
	local len = (a - b).Magnitude
	local mid = (a + b) / 2
	box(m, "Top", CFrame.lookAt(mid + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0)), Vector3.new(0.14, 0.14, len), Enum.Material.Metal, P.StationOrangeDark, false)
	box(m, "Mid", CFrame.lookAt(mid + Vector3.new(0, h * 0.5, 0), b + Vector3.new(0, h * 0.5, 0)), Vector3.new(0.1, 0.1, len), Enum.Material.Metal, P.StationOrangeDark, false)
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		box(m, "Post", CFrame.new(a:Lerp(b, i / n) + Vector3.new(0, h / 2, 0)), Vector3.new(0.14, h, 0.14), Enum.Material.Metal, P.StationOrangeDark, false)
	end
	return m
end

-- Footprints: thin dark ovals on the snow. `count` prints walking from a to b.
function Props.footprintTrail(parent: Instance, a: Vector3, b: Vector3, count: number, big: boolean?): Model
	local m = Builder.model(parent, "FootprintTrail")
	local dir = (b - a)
	local look = CFrame.lookAt(a, b)
	for i = 0, count - 1 do
		local t = i / math.max(1, count - 1)
		local side = if i % 2 == 0 then -0.45 else 0.45
		local pos = a + dir * t
		local p = box(m, "Footprint", CFrame.new(pos + Vector3.new(0, 0.03, 0)) * (look - look.Position) * CFrame.new(side, 0, 0), if big then Vector3.new(1.0, 0.06, 2.2) else Vector3.new(0.7, 0.06, 1.4), Enum.Material.Snow, P.SnowShadow, false)
		p.CastShadow = false
	end
	return m
end

function Props.scratches(parent: Instance, cf: CFrame, length: number): Model
	local m = Builder.model(parent, "Scratches")
	for i = 0, 3 do
		local p = box(m, "Scratch", cf * CFrame.new((i - 1.5) * 0.35, 0.02, 0) * CFrame.Angles(0, (i - 1.5) * 0.03, 0), Vector3.new(0.06, 0.02, length), Enum.Material.Metal, P.Stainless, false)
		p.CastShadow = false
	end
	return m
end

-- Outdoor antenna mast with guy wires.
function Props.antennaMast(parent: Instance, position: Vector3, height: number): Model
	local m = Builder.model(parent, "AntennaMast")
	box(m, "Base", CFrame.new(position + Vector3.new(0, 1, 0)), Vector3.new(4, 2, 4), Enum.Material.Concrete, P.ConcreteDark)
	for i = 0, 2 do
		local ang = i * math.pi * 2 / 3
		local off = Vector3.new(math.cos(ang) * 0.9, 0, math.sin(ang) * 0.9)
		box(m, "Leg", CFrame.new(position + off + Vector3.new(0, 2 + height / 2, 0)), Vector3.new(0.3, height, 0.3), Enum.Material.Metal, P.Galvanized, true)
		for y = 6, height, 6 do
			local nxt = (i + 1) % 3 * math.pi * 2 / 3
			local off2 = Vector3.new(math.cos(nxt) * 0.9, 0, math.sin(nxt) * 0.9)
			local pa = position + off + Vector3.new(0, 2 + y, 0)
			local pb = position + off2 + Vector3.new(0, 2 + y, 0)
			box(m, "Brace", CFrame.lookAt((pa + pb) / 2, pb), Vector3.new(0.12, 0.12, (pa - pb).Magnitude), Enum.Material.Metal, P.Galvanized, false)
		end
		-- guy wire
		local anchor = position + Vector3.new(math.cos(ang) * 24, 0, math.sin(ang) * 24)
		local top = position + Vector3.new(0, 2 + height * 0.8, 0)
		box(m, "GuyWire", CFrame.lookAt((anchor + top) / 2, top), Vector3.new(0.06, 0.06, (anchor - top).Magnitude), Enum.Material.Metal, P.Graphite, false)
		box(m, "GuyAnchor", CFrame.new(anchor + Vector3.new(0, 0.5, 0)), Vector3.new(1.2, 1, 1.2), Enum.Material.Concrete, P.ConcreteDark, true)
	end
	local dish = Builder.part({ name = "Dish", cframe = CFrame.new(position + Vector3.new(0, 2 + height - 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), size = Vector3.new(1, 5, 5), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.DirtyWhite, parent = m, canCollide = false })
	dish:SetAttribute("Dish", true)
	dish:SetAttribute("Center", CFrame.new(position + Vector3.new(0, 2 + height - 4, 0)))
	local beacon = box(m, "Beacon", CFrame.new(position + Vector3.new(0, 2 + height + 0.5, 0)), Vector3.new(0.5, 0.5, 0.5), Enum.Material.Neon, P.Red, false)
	beacon.CastShadow = false
	Builder.pointLight(beacon, P.Red, 20, 1.2).Name = "Light"
	Builder.registerLamp(beacon, "Radio", P.Red, 1.2)
	beacon:SetAttribute("Blink", 1.2)
	m.PrimaryPart = dish
	return m
end

function Props.metStation(parent: Instance, position: Vector3, circuit: string?): Model
	local m = Builder.model(parent, "MetStation")
	box(m, "Pole", CFrame.new(position + Vector3.new(0, 5, 0)), Vector3.new(0.3, 10, 0.3), Enum.Material.Metal, P.Galvanized, true)
	local spinner = box(m, "Anemometer", CFrame.new(position + Vector3.new(0, 10.3, 0)), Vector3.new(1.6, 0.15, 1.6), Enum.Material.Metal, P.Stainless, false)
	spinner:SetAttribute("Spin", true)
	for i = 0, 2 do
		local ang = i * math.pi * 2 / 3
		local cup = Builder.part({ name = "Cup", cframe = CFrame.new(position + Vector3.new(math.cos(ang) * 0.8, 10.3, math.sin(ang) * 0.8)), size = Vector3.new(0.4, 0.4, 0.4), shape = Enum.PartType.Ball, material = Enum.Material.Metal, color = P.Stainless, parent = spinner, canCollide = false })
		cup.CastShadow = false
	end
	box(m, "Vane", CFrame.new(position + Vector3.new(0, 8.8, 0)), Vector3.new(0.1, 0.5, 1.8), Enum.Material.Metal, P.StationOrangeFaded, false)
	local boxp = box(m, "InstrumentBox", CFrame.new(position + Vector3.new(0, 4, 0.6)), Vector3.new(1.6, 1.4, 0.9), Enum.Material.Metal, P.DirtyWhite, true)
	local screen = box(boxp, "Screen", CFrame.new(position + Vector3.new(0, 4.1, 1.08)), Vector3.new(1.2, 0.6, 0.04), Enum.Material.Neon, P.LightCold, false)
	screen.CastShadow = false
	Builder.label(screen, Enum.NormalId.Front, "-61.3°C  W 14 м/с", { textSize = 12, font = Enum.Font.Code, textColor = P.WarningBlack, pixelsPerStud = 50 })
	Builder.registerLamp(screen, circuit or "Radio", P.LightCold, 0.25)
	box(m, "Shield", CFrame.new(position + Vector3.new(0, 6.5, 0)), Vector3.new(1.2, 1.0, 1.2), Enum.Material.Plastic, P.DirtyWhite, false)
	return m
end

return Props
