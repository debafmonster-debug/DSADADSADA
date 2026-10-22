--!nonstrict
-- Polar transport plane + snow apron set. Used by the client boarding
-- cinematic (built locally) and by the server at dawn for the evacuation
-- (built in the world). Simple shapes, one model, no interior.
local Builder = require(script.Parent.Parent.Utilities.Builder)
local Props = require(script.Parent.Parent.Utilities.Props)
local P = Builder.Palette

local Airfield = {}

local function part(parent, name, size, cf, mat, color, extra)
	local p = Builder.part({ name = name, size = size, cframe = cf, material = mat, color = color, parent = parent, canCollide = true })
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

-- Twin-engine turboprop on skis. `cf` is the ground point under the nose gear,
-- plane faces -Z. `doorOpen` lowers the rear stairs.
function Airfield.buildPlane(parent: Instance, cf: CFrame, doorOpen: boolean?): Model
	local m = Builder.model(parent, "Plane")
	local body = CFrame.new(0, 7, 0)
	local fus = Builder.part({ name = "Fuselage", size = Vector3.new(7, 7, 7), cframe = cf * body * CFrame.new(0, 0, 14) * CFrame.Angles(0, 0, math.pi / 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, color = P.StationOrange, parent = m })
	fus.Size = Vector3.new(44, 7, 7)
	fus.CFrame = cf * body * CFrame.new(0, 0, 14) * CFrame.Angles(0, math.pi / 2, 0)
	local nose = Builder.part({ name = "Nose", size = Vector3.new(7, 7, 7), cframe = cf * body * CFrame.new(0, 0, -8), shape = Enum.PartType.Ball, material = Enum.Material.Metal, color = P.StationOrange, parent = m })
	nose.CanCollide = true
	part(m, "Cockpit", Vector3.new(5.5, 2.4, 3), cf * body * CFrame.new(0, 2.2, -5.5), Enum.Material.Glass, Color3.fromRGB(60, 80, 100), { Transparency = 0.35 })
	part(m, "Stripe", Vector3.new(7.2, 0.8, 30), cf * body * CFrame.new(0, 0.5, 14), Enum.Material.SmoothPlastic, P.DirtyWhite, { CanCollide = false })
	-- Wings (high wing), engines with props.
	part(m, "Wing", Vector3.new(70, 0.9, 9), cf * body * CFrame.new(0, 3.3, 8), Enum.Material.Metal, P.StationOrange)
	for _, x in { -14, 14 } do
		part(m, "Engine", Vector3.new(3.2, 3.2, 9), cf * body * CFrame.new(x, 2.4, 4), Enum.Material.Metal, P.Graphite)
		local prop = part(m, "Prop", Vector3.new(0.4, 11, 0.6), cf * body * CFrame.new(x, 2.4, -0.8), Enum.Material.Metal, P.Bakelite, { CanCollide = false })
		prop:SetAttribute("Spin", true)
		local prop2 = part(m, "Prop", Vector3.new(0.4, 11, 0.6), cf * body * CFrame.new(x, 2.4, -0.8) * CFrame.Angles(0, 0, math.pi / 2), Enum.Material.Metal, P.Bakelite, { CanCollide = false })
		prop2:SetAttribute("Spin", true)
	end
	-- Tail.
	part(m, "TailFin", Vector3.new(0.8, 11, 9), cf * body * CFrame.new(0, 6, 34), Enum.Material.Metal, P.StationOrangeDark)
	part(m, "TailPlane", Vector3.new(24, 0.7, 6), cf * body * CFrame.new(0, 3, 35), Enum.Material.Metal, P.StationOrangeDark)
	-- Skis.
	for _, x in { -5, 5 } do
		part(m, "SkiStrut", Vector3.new(0.6, 5, 0.6), cf * CFrame.new(x, 3.5, 10), Enum.Material.Metal, P.Graphite)
		part(m, "Ski", Vector3.new(1.6, 0.5, 8), cf * CFrame.new(x, 0.7, 10), Enum.Material.Metal, P.Stainless)
	end
	part(m, "NoseStrut", Vector3.new(0.6, 4.5, 0.6), cf * CFrame.new(0, 3.2, -4), Enum.Material.Metal, P.Graphite)
	part(m, "NoseSki", Vector3.new(1.4, 0.5, 5), cf * CFrame.new(0, 0.7, -4), Enum.Material.Metal, P.Stainless)
	-- Windows and the rear door with stairs (left side).
	for i = 0, 5 do
		part(m, "Window", Vector3.new(0.2, 1.2, 1.2), cf * body * CFrame.new(-3.55, 1.2, -2 + i * 4), Enum.Material.Glass, Color3.fromRGB(90, 110, 130), { CanCollide = false, Transparency = 0.3 })
		part(m, "Window", Vector3.new(0.2, 1.2, 1.2), cf * body * CFrame.new(3.55, 1.2, -2 + i * 4), Enum.Material.Glass, Color3.fromRGB(90, 110, 130), { CanCollide = false, Transparency = 0.3 })
	end
	local doorCf = cf * body * CFrame.new(-3.6, -1, 26)
	local door = part(m, "Door", Vector3.new(0.3, 5.5, 3.2), if doorOpen then doorCf * CFrame.new(-1.6, -1.8, 0) * CFrame.Angles(0, 0, math.rad(80)) else doorCf, Enum.Material.Metal, P.StationOrangeDark)
	door:SetAttribute("ClosedCFrame", doorCf)
	door:SetAttribute("OpenCFrame", doorCf * CFrame.new(-1.6, -1.8, 0) * CFrame.Angles(0, 0, math.rad(80)))
	if doorOpen then
		Props.stairs(m, cf * CFrame.new(-8.5, 0, 26) * CFrame.Angles(0, -math.pi / 2, 0), 3, 4.5, 5)
	end
	local cabinLight = part(m, "CabinLight", Vector3.new(0.3, 1.6, 2.4), cf * body * CFrame.new(-3.2, 0.6, 26), Enum.Material.Neon, P.LightWarmOld, { CanCollide = false, CastShadow = false })
	Builder.pointLight(cabinLight, P.LightWarmOld, 14, 1.2).Name = "Light"
	-- Navigation lights.
	for _, l in { { -35, P.Red }, { 35, P.Green } } do
		local nav = part(m, "NavLight", Vector3.new(0.6, 0.6, 0.6), cf * body * CFrame.new(l[1], 3.3, 8), Enum.Material.Neon, l[2], { CanCollide = false, CastShadow = false })
		Builder.pointLight(nav, l[2], 16, 1.2).Name = "Light"
		nav:SetAttribute("Blink", 1.0)
	end
	local beacon = part(m, "Beacon", Vector3.new(0.6, 0.6, 0.6), cf * body * CFrame.new(0, 3.8, 14), Enum.Material.Neon, P.Red, { CanCollide = false, CastShadow = false })
	Builder.pointLight(beacon, P.Red, 20, 1.5).Name = "Light"
	beacon:SetAttribute("Blink", 0.8)
	local landing = part(m, "LandingLight", Vector3.new(1.2, 0.6, 0.3), cf * body * CFrame.new(0, -1.5, -11), Enum.Material.Neon, P.LightFlood, { CanCollide = false, CastShadow = false })
	local spot = Instance.new("SpotLight")
	spot.Angle = 60
	spot.Range = 80
	spot.Brightness = 3
	spot.Color = P.LightFlood
	spot.Face = Enum.NormalId.Front
	spot.Parent = landing
	m.PrimaryPart = fus
	return m
end

-- Client set: snow apron with marker lights, a fuel bowser and the plane.
function Airfield.build(parent: Instance, origin: Vector3): { root: Model, plane: Model, airlock: CFrame, stairs: CFrame, cameraStart: CFrame, cameraPlane: CFrame }
	local root = Builder.model(parent, "AirfieldSet")
	local cf = CFrame.new(origin)
	local snow = Builder.part({ name = "Snow", size = Vector3.new(400, 6, 400), cframe = cf * CFrame.new(0, -3, 0), material = Enum.Material.Snow, color = P.Snow, parent = root })
	snow:SetAttribute("Floor", "snow")
	for _, d in { { -80, -60, 30, 5, 24 }, { 90, 70, 26, 4, 22 }, { -60, 110, 36, 6, 30 }, { 120, -90, 40, 6, 30 } } do
		Props.snowDrift(root, origin + Vector3.new(d[1], 0, d[2]), Vector3.new(d[3], d[4], d[5]))
	end
	-- Transport-base airlock hut (where the players "come out").
	local hut = Builder.model(root, "AirlockHut")
	part(hut, "Hut", Vector3.new(18, 10, 12), cf * CFrame.new(0, 5, 40), Enum.Material.Metal, P.StationOrange)
	part(hut, "HutRoof", Vector3.new(19, 0.8, 13), cf * CFrame.new(0, 10.4, 40), Enum.Material.Snow, P.Snow)
	local hutDoor = Builder.door(hut, cf * CFrame.new(0, 0, 34), 6, 8, { heavy = true, label = "ШЛЮЗ" })
	hutDoor:SetAttribute("Set", true)
	Builder.cageLamp(hut, cf * CFrame.new(0, 9, 33), "Floodlights", P.LightEmergencyWarm, 1.0, 20)
	-- Marker lights and floodlights.
	for i = 0, 9 do
		local x = -22 + i * 5
		local l = part(root, "ApronLight", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(x, 0.4, -14), Enum.Material.Neon, if i % 2 == 0 then P.Orange else P.LightCold, { CanCollide = false, CastShadow = false })
		Builder.pointLight(l, l.Color, 8, 0.8).Name = "Light"
		l:SetAttribute("Blink", 1.4)
	end
	Builder.floodlight(root, origin + Vector3.new(-30, 0, 20), 14, origin + Vector3.new(0, 2, -5), "Floodlights")
	Builder.floodlight(root, origin + Vector3.new(30, 0, 20), 14, origin + Vector3.new(0, 2, -5), "Floodlights")
	Props.barrel(root, cf * CFrame.new(-20, 0, 30), P.StationOrangeDark, "ТС-1")
	Props.barrel(root, cf * CFrame.new(-22.5, 0, 31), P.Graphite)
	Props.crate(root, cf * CFrame.new(22, 0, 30) * CFrame.Angles(0, 0.3, 0), Vector3.new(3, 2.2, 2.4), P.Wood, "ВОСТОК-9")
	Props.guideRope(root, origin + Vector3.new(0, 0, 32), origin + Vector3.new(-6, 0, 0))
	local plane = Airfield.buildPlane(root, cf * CFrame.new(0, 0, -30) * CFrame.Angles(0, math.pi / 2, 0), true)
	Builder.fxAnchor(root, "SnowField", cf * CFrame.new(0, 20, 0), "SnowField", Vector3.new(300, 40, 300))
	return {
		root = root,
		plane = plane,
		airlock = cf * CFrame.new(0, 0, 33),
		stairs = cf * CFrame.new(28, 0, -20),
		cameraStart = cf * CFrame.new(16, 6, 42) * CFrame.Angles(0, math.rad(150), 0),
		cameraPlane = cf * CFrame.new(-50, 8, -5) * CFrame.Angles(0, math.rad(-100), 0),
	}
end

return Airfield
