--!nocheck
-- Headless build of the authored station: geometry budget, named
-- interactive objects, marker contract and layout sanity checks.
local H = require("./harness")
local S = H.load()

local Station = S.require(S.path("ReplicatedStorage.Shared.Config.Station"))
local GameConfig = S.require(S.path("ReplicatedStorage.Shared.Config.GameConfig"))
local StationBuilder = S.require(S.path("ServerScriptService.Vostok9.Map.StationBuilder"))

local origin = GameConfig.World.StationOrigin
local handle

H.test("station builds without errors", function()
	handle = StationBuilder.build(S.game:GetService("Workspace"), origin, 42)
	assert(handle.root.Parent ~= nil, "root parented")
end)

H.test("part budget is reasonable (perf) and non-trivial (content)", function()
	local parts, lights, prompts = 0, 0, 0
	for _, inst in handle.root:GetDescendants() do
		if inst:IsA("BasePart") then
			parts += 1
		elseif inst:IsA("Light") then
			lights += 1
		elseif inst:IsA("ProximityPrompt") then
			prompts += 1
		end
	end
	assert(parts > 1500, "expected a detailed map, got " .. parts .. " parts")
	assert(parts < 9000, "too many parts: " .. parts)
	assert(lights < 260, "too many lights: " .. lights)
	print(string.format("     parts=%d lights=%d", parts, lights))
end)

H.test("every named interactive object exists", function()
	for _, key in { "scanner", "scannerOverride", "radio", "breakerPanel", "fuseBox", "generator", "keypad", "antennaPanel", "hatch", "bunkerLever", "dormBoard", "statusBoard", "medCabinet" } do
		assert(handle[key] ~= nil, "missing " .. key)
	end
	for _, key in { "airlockOuter", "airlockInner", "passageMain", "passageDorm", "dorm", "dormExit", "generatorShed", "warehouseL", "warehouseR", "bunker" } do
		assert(handle.doors[key] ~= nil, "missing door " .. key)
		assert(handle.doors[key]:FindFirstChild("Leaf"), "door has no leaf: " .. key)
		assert(handle.doors[key]:FindFirstChild("Hinge"), "door has no hinge: " .. key)
	end
end)

H.test("every room with a corridor door got a door model", function()
	for _, r in Station.Rooms do
		if r.door and r.building == "Main" then
			assert(handle.roomDoors[r.id], "no door for " .. r.id)
		end
	end
end)

H.test("markers resolved", function()
	H.eq(#handle.spawns, 4, "spawns")
	assert(#handle.patrolOutdoor >= 12, "outdoor patrol")
	assert(#handle.patrolIndoor >= 8, "indoor patrol")
	assert(#handle.observePoints >= 4, "observe")
	assert(#handle.guestSpawns >= 3, "guest spawns")
	assert(#handle.lostPoints >= 4, "lost points")
	assert(handle.corners[1] and handle.corners[2], "corners")
	assert(handle.evacZone, "evac")
	for _, spot in { "ControlDesk", "ControlShelf", "RadioShelf", "ArchiveTable", "ArchivePhoto", "StorageWall", "MedDesk" } do
		assert(handle.documentSpots[spot], "document spot " .. spot)
	end
	local items = {}
	for _, it in handle.itemSpots do
		items[it.itemId] = (items[it.itemId] or 0) + 1
	end
	assert((items.SpareRelay or 0) >= 1, "relay spot")
	assert((items.SpareInjector or 0) >= 1, "injector spot")
	assert((items.Fuse or 0) >= 2, "fuse spots")
	assert((items.Medkit or 0) >= 2, "medkit spots")
	assert((items.FuelCanister or 0) >= 1, "fuel spot")
end)

H.test("lamps are registered on real circuits", function()
	local valid = {}
	for _, c in GameConfig.Power.Circuits do
		valid[c.id] = true
	end
	local count, byCircuit = 0, {}
	for _, inst in handle.root:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Lamp") then
			local c = inst:GetAttribute("Circuit")
			assert(valid[c], "lamp on unknown circuit " .. tostring(c) .. " at " .. inst:GetFullName())
			count += 1
			byCircuit[c] = (byCircuit[c] or 0) + 1
		end
	end
	assert(count > 60, "lamp count " .. count)
	assert(byCircuit.LightsMain and byCircuit.LightsDorm and byCircuit.Floodlights and byCircuit.Lab and byCircuit.Radio, "circuits populated")
end)

H.test("rooms do not overlap and sit inside their building", function()
	for i, a in Station.Rooms do
		local b = Station.Buildings[a.building]
		assert(a.x1 >= b.x1 and a.x2 <= b.x2 and a.z1 >= b.z1 and a.z2 <= b.z2, "room outside building: " .. a.id)
		for j, c in Station.Rooms do
			if j > i and c.building == a.building then
				local overlap = a.x1 < c.x2 and c.x1 < a.x2 and a.z1 < c.z2 and c.z1 < a.z2
				assert(not overlap, "rooms overlap: " .. a.id .. " / " .. c.id)
			end
		end
	end
end)

H.test("zones cover rooms and the night-safe set is consistent", function()
	for _, r in Station.Rooms do
		local z = Station.zoneAt(Station.roomCenter(r))
		assert(z, "no zone for " .. r.id)
	end
	assert(Station.NightSafeZones.Dorm and Station.NightSafeZones.Bunker, "night zones")
	local dormZ = Station.zoneAt(S.env.Vector3.new(127, Station.FloorY + 2, -6))
	H.eq(dormZ.id, "Dorm")
	local outside = Station.zoneAt(S.env.Vector3.new(-100, 2, 0))
	H.eq(outside, nil)
end)

H.test("doors carry the attributes FacilityService relies on", function()
	for _, d in handle.allDoors do
		assert(d:GetAttribute("ClosedOffset") ~= nil, "ClosedOffset " .. d.Name)
		assert(d.PrimaryPart == d:FindFirstChild("Leaf"), "primary part " .. d.Name)
		local mod = d.Leaf:FindFirstChildOfClass("PathfindingModifier")
		assert(mod, "pathfinding modifier " .. d.Name)
	end
end)

H.finish()
