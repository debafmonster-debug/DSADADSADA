--!nonstrict
-- Builds the whole authored station into Workspace and returns a handle with
-- every named interactive instance and marker, resolved to world space.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Station = require(ReplicatedStorage.Shared.Config.Station)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Common = require(script.Parent.Common)
local MainBuilding = require(script.Parent.MainBuilding)
local DormBuilding = require(script.Parent.DormBuilding)
local Yard = require(script.Parent.Yard)

export type Handle = {
	root: Model,
	origin: Vector3,
	doors: { [string]: Model },
	roomDoors: { [string]: Model },
	allDoors: { Model },
	scanner: Model?,
	scannerOverride: BasePart?,
	radio: Model?,
	breakerPanel: Model?,
	fuseBox: Model?,
	generator: Model?,
	generatorSoundParent: BasePart?,
	keypad: Model?,
	antenna: Model?,
	antennaPanel: Model?,
	hatch: Model?,
	bunkerLever: Model?,
	dormBoard: BasePart?,
	dormRadio: Model?,
	statusBoard: BasePart?,
	powerConsole: Model?,
	medCabinet: Model?,
	evacApron: Model?,
	spawns: { CFrame },
	documentSpots: { [string]: CFrame },
	itemSpots: { { itemId: string, cframe: CFrame } },
	eventSpots: { [string]: { CFrame } },
	patrolOutdoor: { Vector3 },
	patrolIndoor: { Vector3 },
	observePoints: { Vector3 },
	guestSpawns: { Vector3 },
	lostPoints: { Vector3 },
	corners: { Vector3 },
	evacZone: Vector3,
	clocks: { Model },
	point: (string) -> Vector3,
	toLocal: (Vector3) -> Vector3,
}

local StationBuilder = {}

function StationBuilder.build(parent: Instance, origin: Vector3, seed: number, yieldEvery: number?): Handle
	local root = Builder.model(nil, "ActiveMap")
	root:SetAttribute("Seed", seed)
	root:SetAttribute("Map", "Vostok9")
	local ctx = Common.newCtx(root, origin, SeededRandom.new(seed))
	local handle: Handle = {
		root = root,
		origin = origin,
		doors = {},
		roomDoors = {},
		allDoors = {},
		spawns = {},
		documentSpots = {},
		itemSpots = {},
		eventSpots = {},
		patrolOutdoor = {},
		patrolIndoor = {},
		observePoints = {},
		guestSpawns = {},
		lostPoints = {},
		corners = {},
		evacZone = origin + Station.Points.EvacZone,
		clocks = {},
		point = function(name: string): Vector3
			local p = Station.Points[name]
			assert(typeof(p) == "Vector3", "unknown station point " .. name)
			return origin + p
		end,
		toLocal = function(world: Vector3): Vector3
			return world - origin
		end,
	}
	MainBuilding.build(ctx, handle)
	if yieldEvery then
		task.wait()
	end
	DormBuilding.build(ctx, handle)
	if yieldEvery then
		task.wait()
	end
	Yard.build(ctx, handle)
	-- Resolve markers.
	local spawnsByIndex = {}
	for _, mk in ctx.markers:GetChildren() do
		local n = mk.Name
		if n == "Spawn" then
			spawnsByIndex[mk:GetAttribute("Index") or (#spawnsByIndex + 1)] = mk.CFrame
		elseif n == "DocumentSpot" then
			handle.documentSpots[mk:GetAttribute("Spot")] = mk.CFrame
		elseif n == "ItemSpot" then
			table.insert(handle.itemSpots, { itemId = mk:GetAttribute("ItemId"), cframe = mk.CFrame })
		elseif n == "EventSpot" then
			local ev = mk:GetAttribute("Event")
			handle.eventSpots[ev] = handle.eventSpots[ev] or {}
			table.insert(handle.eventSpots[ev], mk.CFrame)
		elseif n == "Patrol" then
			if mk:GetAttribute("Zone") == "Indoor" then
				table.insert(handle.patrolIndoor, mk.CFrame.Position)
			else
				table.insert(handle.patrolOutdoor, mk.CFrame.Position)
			end
		elseif n == "Observe" then
			table.insert(handle.observePoints, mk.CFrame.Position)
		elseif n == "GuestSpawn" then
			table.insert(handle.guestSpawns, mk.CFrame.Position)
		elseif n == "LostPoint" then
			table.insert(handle.lostPoints, mk.CFrame.Position)
		elseif n == "Corner" then
			handle.corners[mk:GetAttribute("Index")] = mk.CFrame.Position
		elseif n == "EvacZone" then
			handle.evacZone = mk.CFrame.Position
		end
	end
	for i = 1, 4 do
		handle.spawns[i] = spawnsByIndex[i] or spawnsByIndex[1]
	end
	for _, d in ctx.doors:GetChildren() do
		if d:IsA("Model") then
			table.insert(handle.allDoors, d)
		end
	end
	for _, inst in root:GetDescendants() do
		if inst:IsA("Model") and inst:GetAttribute("Clock") then
			table.insert(handle.clocks, inst)
		end
	end
	root.Parent = parent
	return handle
end

return StationBuilder
