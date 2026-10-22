--!nocheck
local H = require("./harness")
local S = H.load()
local roblox = require("@lune/roblox")

local Catalog = S.require(S.path("ServerScriptService.NightShift.MapModules.Catalog"))
local SeededRandom = S.require(S.path("ReplicatedStorage.Shared.Utilities.SeededRandom"))
local LobbyBuilder = S.require(S.path("ServerScriptService.NightShift.Lobby.LobbyBuilder"))
local GameConfig = S.require(S.path("ReplicatedStorage.Shared.Config.GameConfig"))
local Missions = S.require(S.path("ReplicatedStorage.Shared.Config.Missions"))
local Documents = S.require(S.path("ReplicatedStorage.Shared.Config.Documents"))
local Tools = S.require(S.path("ReplicatedStorage.Shared.Config.Tools"))

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local ws = S.game:GetService("Workspace")

local function countParts(inst)
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

print("Builders")
H.test("lobby builds with all anchors", function()
	local anchors = LobbyBuilder.build(ws, CFrame.new(0, 0, 0))
	assert(anchors.spawn and anchors.registration and anchors.shiftBoard and anchors.briefingConsole, "anchors")
	assert(#anchors.archiveTerminals == 3, "archive terminals")
	local lockerCount = 0
	for _ in anchors.lockers do
		lockerCount += 1
	end
	H.eq(lockerCount, #Tools.Order, "lockers")
	local parts = countParts(anchors.root)
	print("    lobby parts: " .. parts)
	assert(parts > 400 and parts < 3000, "lobby part budget: " .. parts)
	local lights = 0
	for _, d in anchors.root:GetDescendants() do
		if d:IsA("PointLight") then
			lights += 1
		end
	end
	print("    lobby lights: " .. lights)
	assert(lights < 80, "too many lights")
end)

local total = 0
for _, def in Catalog.List do
	for variant = 1, 3 do
		H.test(string.format("module %s v%d (all doors)", def.id, variant), function()
			local model = roblox.Instance.new("Model")
			model.Name = def.id
			model.Parent = ws
			local markers = roblox.Instance.new("Folder")
			markers.Name = "Markers"
			markers.Parent = model
			local doorsVariants = {
				{ N = true, E = true, S = true, W = true },
				{ N = true, E = false, S = true, W = false },
				{ N = false, E = true, S = false, W = false },
			}
			local ctx = {
				model = model,
				cframe = CFrame.new(Vector3.new(1000, 0, 1000)),
				size = GameConfig.Grid.Cell,
				height = GameConfig.Grid.WallHeight,
				doors = doorsVariants[variant],
				rng = SeededRandom.new(variant * 77),
				sector = def.sector,
				roomCode = def.sector .. "-0" .. variant,
				markers = markers,
				damage = 0.5,
			}
			def.build(ctx)
			local parts = countParts(model)
			total += parts
			assert(parts > 20 and parts < 450, "part budget " .. parts)
			-- Every room must give the Warden somewhere to walk.
			local patrol = 0
			for _, m in markers:GetChildren() do
				if m.Name == "Patrol" then
					patrol += 1
				end
			end
			assert(patrol >= 1, "no patrol markers")
			-- Task rooms must expose their target.
			for _, tag in def.tags do
				if tag == "PowerRestore" or tag == "Diagnostics" or tag == "CameraRepair" or tag == "DoorRepair" or tag == "Ventilation" then
					local found = false
					for _, m in markers:GetChildren() do
						if m.Name == "TaskTarget" and m:GetAttribute("Kind") == tag then
							local target = model:FindFirstChild(m:GetAttribute("TargetName"), true)
							assert(target, "task target instance missing for " .. tag)
							found = true
						end
					end
					assert(found, "no TaskTarget marker for " .. tag)
				end
			end
			if def.id == "A_Checkpoint" then
				local spawns = 0
				for _, m in markers:GetChildren() do
					if m.Name == "Spawn" then
						spawns += 1
					end
				end
				H.eq(spawns, 4, "spawns")
			end
			if def.id == "E_Airlock" then
				assert(markers:FindFirstChild("EvacZone"), "evac zone")
				assert(model:FindFirstChild("EvacShutter", true), "shutter")
			end
			model:Destroy()
		end)
	end
end
print("    average parts per module: " .. math.floor(total / (#Catalog.List * 3)))

print("Config consistency")
H.test("missions reference existing documents and task rooms", function()
	for id, m in Missions.Defs do
		for _, d in m.documents do
			assert(Documents.Defs[d], id .. " references unknown document " .. d)
		end
		local function hasRoom(kind, sector)
			for _, def in Catalog.List do
				if def.sector == sector and table.find(def.tags, kind) then
					return true
				end
			end
			return false
		end
		assert(hasRoom(m.mainTask.kind, m.mainTask.sector), id .. " main task has no room")
		if m.optionalTask then
			assert(hasRoom(m.optionalTask.kind, m.optionalTask.sector), id .. " optional task has no room")
		end
	end
	for _, ch in Missions.Chapters do
		for _, mid in ch.missions do
			assert(Missions.Defs[mid], "chapter references unknown mission " .. mid)
			H.eq(Missions.Defs[mid].chapter, ch.index, "mission chapter index")
		end
	end
end)

H.test("tool use sounds exist", function()
	local Sounds = S.require(S.path("ReplicatedStorage.Shared.Config.SoundLibrary"))
	for id, def in Tools.Defs do
		assert(Sounds[def.useSound], id .. " sound missing")
	end
end)

H.finish()
