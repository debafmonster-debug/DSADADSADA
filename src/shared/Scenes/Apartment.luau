--!nonstrict
-- Intro set: a small winter flat and the street outside with a waiting taxi.
-- Built on the client only; nothing here replicates. Keep it cosy and sparse.
local Builder = require(script.Parent.Parent.Utilities.Builder)
local Props = require(script.Parent.Parent.Utilities.Props)
local P = Builder.Palette

local Apartment = {}

local function part(parent, name, size, cf, mat, color, extra)
	local p = Builder.part({ name = name, size = size, cframe = cf, material = mat, color = color, parent = parent })
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

export type Set = {
	root: Model,
	sofaSeat: CFrame,
	phone: CFrame,
	doorInside: CFrame,
	doorOutside: CFrame,
	door: Model,
	taxi: Model,
	taxiSeat: CFrame,
	taxiExit: CFrame,
	cameraRoom: CFrame,
	cameraPhone: CFrame,
	cameraDoor: CFrame,
	cameraStreet: CFrame,
	tvScreen: BasePart,
	lampWarm: BasePart,
}

function Apartment.build(parent: Instance, origin: Vector3): Set
	local root = Builder.model(parent, "ApartmentSet")
	local cf = CFrame.new(origin)
	local W, D, H = 26, 20, 10
	-- Shell: wooden floor, warm walls, ceiling.
	local floor = part(root, "Floor", Vector3.new(W, 1, D), cf * CFrame.new(0, -0.5, 0), Enum.Material.WoodPlanks, P.Wood)
	floor:SetAttribute("Floor", "wood")
	part(root, "Ceiling", Vector3.new(W, 1, D), cf * CFrame.new(0, H + 0.5, 0), Enum.Material.SmoothPlastic, P.DirtyWhite)
	local wallColor = Color3.fromRGB(176, 150, 120)
	part(root, "WallN", Vector3.new(W, H, 1), cf * CFrame.new(0, H / 2, -D / 2), Enum.Material.Fabric, wallColor)
	part(root, "WallS", Vector3.new(W, H, 1), cf * CFrame.new(0, H / 2, D / 2), Enum.Material.Fabric, wallColor)
	part(root, "WallE", Vector3.new(1, H, D), cf * CFrame.new(W / 2, H / 2, 0), Enum.Material.Fabric, wallColor)
	-- West wall has the window; a door to the hallway is in the south wall.
	part(root, "WallW1", Vector3.new(1, H, 6), cf * CFrame.new(-W / 2, H / 2, -7), Enum.Material.Fabric, wallColor)
	part(root, "WallW2", Vector3.new(1, H, 6), cf * CFrame.new(-W / 2, H / 2, 7), Enum.Material.Fabric, wallColor)
	part(root, "WallWSill", Vector3.new(1, 3, 8), cf * CFrame.new(-W / 2, 1.5, 0), Enum.Material.Fabric, wallColor)
	part(root, "WallWTop", Vector3.new(1, 2, 8), cf * CFrame.new(-W / 2, H - 1, 0), Enum.Material.Fabric, wallColor)
	Builder.window(root, cf * CFrame.new(-W / 2, 5.5, 0) * CFrame.Angles(0, math.pi / 2, 0), 8, 5)
	-- Curtains.
	part(root, "Curtain", Vector3.new(0.3, 7, 1.6), cf * CFrame.new(-W / 2 + 0.5, 5.5, -4.2), Enum.Material.Fabric, Color3.fromRGB(110, 70, 60), { CanCollide = false })
	part(root, "Curtain", Vector3.new(0.3, 7, 1.6), cf * CFrame.new(-W / 2 + 0.5, 5.5, 4.2), Enum.Material.Fabric, Color3.fromRGB(110, 70, 60), { CanCollide = false })
	-- Door (south wall, east side) leading to the hallway/street.
	local doorCf = cf * CFrame.new(8, 0, D / 2)
	part(root, "WallSFill", Vector3.new(1, H, 1), cf * CFrame.new(8, H / 2, D / 2), Enum.Material.Fabric, wallColor, { Transparency = 1, CanCollide = false })
	local door = Builder.door(root, doorCf, 4.5, 8, { color = P.WoodDark, name = "FlatDoor" })
	-- Furniture: sofa facing the TV, coffee table, floor lamp, rug, shelf, radiator.
	Props.sofa(root, cf * CFrame.new(3, 0, 4) * CFrame.Angles(0, math.pi, 0), P.FabricWarm)
	local coffee = Props.table(root, cf * CFrame.new(3, 0, -1), 5, 2.4, P.WoodDark)
	coffee.Name = "CoffeeTable"
	Props.mug(root, cf * CFrame.new(2.2, 2.75, -1.1), true)
	Props.book(root, cf * CFrame.new(4.2, 2.75, -0.6), P.OldGreenDark)
	Props.papers(root, cf * CFrame.new(3.6, 2.75, -1.6), 2)
	local tv = Props.tv(root, cf * CFrame.new(3, 2.75, -7.5), true)
	Props.table(root, cf * CFrame.new(3, 0, -7.5), 5, 2.6, P.WoodDark)
	local lamp = Props.floorLamp(root, cf * CFrame.new(9.5, 0, -6), P.LightWarmOld)
	part(root, "Rug", Vector3.new(10, 0.08, 7), cf * CFrame.new(3, 0.05, 0.5), Enum.Material.Fabric, Color3.fromRGB(120, 60, 50), { CanCollide = false })
	Props.shelf(root, cf * CFrame.new(-8, 0, -9.2), 6, 4)
	for i = 0, 5 do
		Props.book(root, cf * CFrame.new(-10 + i * 0.8, 1.3 + (i % 2) * 1.7, -9.2), if i % 3 == 0 then P.Red elseif i % 3 == 1 then P.Wood else P.OldGreenDark)
	end
	Props.photoFrame(root, cf * CFrame.new(-4, 6.5, -9.4), nil)
	Props.wallClock(root, cf * CFrame.new(11, 7.5, -9.4), "FlatClock")
	-- Radiator under the window and a small side table with the phone.
	part(root, "Radiator", Vector3.new(0.6, 2.2, 6), cf * CFrame.new(-W / 2 + 0.8, 1.3, 0), Enum.Material.Metal, P.DirtyWhite)
	local side = Props.table(root, cf * CFrame.new(-4.5, 0, 6.5), 2.4, 2.2, P.WoodDark)
	side.Name = "SideTable"
	local phoneBase = part(root, "PhoneBase", Vector3.new(1.4, 0.5, 1.0), cf * CFrame.new(-4.5, 2.85, 6.5), Enum.Material.Plastic, P.Bakelite, { CanCollide = false })
	part(root, "Handset", Vector3.new(1.6, 0.35, 0.5), cf * CFrame.new(-4.5, 3.25, 6.5), Enum.Material.Plastic, P.Bakelite, { CanCollide = false })
	part(root, "PhoneDial", Vector3.new(0.7, 0.08, 0.7), cf * CFrame.new(-4.6, 3.12, 6.2), Enum.Material.SmoothPlastic, P.Paper, { CanCollide = false })
	phoneBase.Name = "Phone"
	Props.coatRack(root, cf * CFrame.new(11.3, 0, 7) * CFrame.Angles(0, -math.pi / 2, 0), 2)
	Props.boots(root, cf * CFrame.new(10.5, 0, 8.6))
	-- Street outside the door: snow, a lamp post, a parked taxi, far building silhouettes.
	local street = Builder.model(root, "Street")
	local snow = part(street, "Snow", Vector3.new(160, 4, 120), cf * CFrame.new(10, -2, D / 2 + 62), Enum.Material.Snow, P.Snow)
	snow:SetAttribute("Floor", "snow")
	part(street, "Road", Vector3.new(160, 0.3, 14), cf * CFrame.new(10, 0.05, D / 2 + 26), Enum.Material.Asphalt, Color3.fromRGB(60, 62, 66))
	part(street, "Pavement", Vector3.new(160, 0.4, 10), cf * CFrame.new(10, 0.1, D / 2 + 14), Enum.Material.Concrete, Color3.fromRGB(120, 122, 126))
	part(street, "Porch", Vector3.new(8, 0.3, 6), cf * CFrame.new(8, 0.15, D / 2 + 3), Enum.Material.Concrete, Color3.fromRGB(110, 112, 116))
	part(street, "House", Vector3.new(W + 10, 30, 1), cf * CFrame.new(0, 15, D / 2 + 0.5), Enum.Material.Brick, Color3.fromRGB(110, 96, 86))
	for i = 0, 3 do
		local win = part(street, "HouseWindow", Vector3.new(2.2, 2.6, 0.2), cf * CFrame.new(-10 + i * 7, 15 + (i % 2) * 6, D / 2 + 1.1), Enum.Material.Neon, if i == 2 then Color3.fromRGB(40, 44, 52) else P.LightWarmOld, { CanCollide = false, CastShadow = false })
		win.Transparency = 0.2
	end
	for _, x in { -40, 40 } do
		part(street, "FarHouse", Vector3.new(30, 36, 20), cf * CFrame.new(x, 18, D / 2 + 70), Enum.Material.Concrete, Color3.fromRGB(70, 72, 80))
	end
	local post = part(street, "LampPost", Vector3.new(0.5, 14, 0.5), cf * CFrame.new(16, 7, D / 2 + 12), Enum.Material.Metal, P.Graphite)
	local streetLamp = part(post, "Lamp", Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(16, 14, D / 2 + 12), Enum.Material.Neon, Color3.fromRGB(190, 210, 240), { CanCollide = false, CastShadow = false })
	Builder.pointLight(streetLamp, Color3.fromRGB(190, 210, 240), 30, 1.6, true).Name = "Light"
	Builder.fxAnchor(street, "StreetSnow", cf * CFrame.new(10, 20, D / 2 + 40), "SnowField", Vector3.new(160, 40, 120))
	-- Taxi: boxy car, warm cabin light, roof sign.
	local taxi = Builder.model(street, "Taxi")
	local taxiCf = cf * CFrame.new(14, 0, D / 2 + 24) * CFrame.Angles(0, math.pi / 2, 0)
	local bodyP = part(taxi, "Body", Vector3.new(13, 2.6, 6), taxiCf * CFrame.new(0, 2.3, 0), Enum.Material.Metal, Color3.fromRGB(220, 190, 60))
	part(taxi, "Cabin", Vector3.new(7, 2.4, 5.6), taxiCf * CFrame.new(-0.5, 4.8, 0), Enum.Material.Metal, Color3.fromRGB(220, 190, 60))
	part(taxi, "Glass", Vector3.new(7.1, 1.6, 5.7), taxiCf * CFrame.new(-0.5, 4.9, 0), Enum.Material.Glass, Color3.fromRGB(70, 90, 110), { Transparency = 0.4, CanCollide = false })
	local sign = part(taxi, "Sign", Vector3.new(1.6, 0.6, 0.8), taxiCf * CFrame.new(-0.5, 6.3, 0), Enum.Material.Neon, P.Orange, { CanCollide = false, CastShadow = false })
	Builder.label(sign, Enum.NormalId.Left, "ТАКСИ", { textSize = 12, bold = true, textColor = P.WarningBlack, pixelsPerStud = 50 })
	for _, x in { -4.2, 4.2 } do
		for _, z in { -3.1, 3.1 } do
			local wheel = Builder.part({ name = "Wheel", size = Vector3.new(0.9, 2.2, 2.2), cframe = taxiCf * CFrame.new(x, 1.1, z) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber, color = P.Bakelite, parent = taxi })
			wheel.CFrame = taxiCf * CFrame.new(x, 1.1, z) * CFrame.Angles(math.pi / 2, 0, 0)
		end
	end
	for _, z in { -2.2, 2.2 } do
		local head = part(taxi, "Headlight", Vector3.new(0.3, 0.8, 1.2), taxiCf * CFrame.new(6.6, 2.4, z), Enum.Material.Neon, P.LightFlood, { CanCollide = false, CastShadow = false })
		local spot = Instance.new("SpotLight")
		spot.Angle = 50
		spot.Range = 40
		spot.Brightness = 2
		spot.Face = Enum.NormalId.Right
		spot.Parent = head
		part(taxi, "Taillight", Vector3.new(0.3, 0.6, 1.0), taxiCf * CFrame.new(-6.6, 2.4, z), Enum.Material.Neon, P.Red, { CanCollide = false, CastShadow = false })
	end
	local cabinLight = part(taxi, "CabinLight", Vector3.new(0.4, 0.3, 0.4), taxiCf * CFrame.new(-0.5, 5.8, 0), Enum.Material.Neon, P.LightWarmOld, { CanCollide = false, CastShadow = false })
	Builder.pointLight(cabinLight, P.LightWarmOld, 8, 0.8).Name = "Light"
	taxi.PrimaryPart = bodyP
	Builder.fxAnchor(taxi, "Exhaust", taxiCf * CFrame.new(-6.8, 0.8, 1.5), "Steam", nil, { Rate = 4 })
	return {
		root = root,
		sofaSeat = cf * CFrame.new(1.4, 1.9, 4.3) * CFrame.Angles(0, math.pi, 0),
		phone = cf * CFrame.new(-4.5, 0, 6.5),
		doorInside = doorCf * CFrame.new(0, 0, -3),
		doorOutside = doorCf * CFrame.new(0, 0, 4),
		door = door,
		taxi = taxi,
		taxiSeat = taxiCf * CFrame.new(-1, 3.2, 2.6),
		taxiExit = taxiCf * CFrame.new(-1, 0, 5.5),
		cameraRoom = cf * CFrame.new(-6, 6.5, -5) * CFrame.Angles(0, math.rad(-135), 0) * CFrame.Angles(math.rad(-10), 0, 0),
		cameraPhone = cf * CFrame.new(-1, 5.5, 2) * CFrame.Angles(0, math.rad(-150), 0) * CFrame.Angles(math.rad(-12), 0, 0),
		cameraDoor = cf * CFrame.new(2, 6, 2) * CFrame.Angles(0, math.rad(200), 0) * CFrame.Angles(math.rad(-8), 0, 0),
		cameraStreet = cf * CFrame.new(-6, 7, D / 2 + 14) * CFrame.Angles(0, math.rad(-120), 0) * CFrame.Angles(math.rad(-8), 0, 0),
		tvScreen = tv.PrimaryPart,
		lampWarm = lamp,
	}
end

return Apartment
