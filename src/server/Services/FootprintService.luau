--!nonstrict
-- Footprints in the snow. Server-made so everyone sees the same trail (and
-- so a trail can be evidence). Ring buffer keeps the part count bounded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local FacilityService = require(script.Parent.FacilityService)

local F = GameConfig.Footprints

local FootprintService = {}

local folder: Folder? = nil
local prints: { { part: BasePart, at: number } } = {}
local lastPos: { [Player]: Vector3 } = {}
local side: { [Player]: number } = {}
local active = false

local function onSnow(pos: Vector3): (boolean, number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local ok, hit = pcall(function()
		return workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
	end)
	if ok and hit and hit.Instance and hit.Instance:GetAttribute("Floor") == "snow" then
		return true, hit.Position.Y
	end
	return false, nil
end

function FootprintService.Stamp(pos: Vector3, lookDir: Vector3, offset: number, big: boolean?)
	if not folder then
		return
	end
	local isSnow, y = onSnow(pos)
	if not isSnow then
		return
	end
	local look = CFrame.lookAt(Vector3.new(pos.X, y + 0.03, pos.Z), Vector3.new(pos.X, y + 0.03, pos.Z) + Vector3.new(lookDir.X, 0, lookDir.Z))
	local p = Builder.part({
		name = "Footprint",
		size = if big then Vector3.new(1.0, 0.06, 2.2) else Vector3.new(0.7, 0.06, 1.4),
		cframe = look * CFrame.new(offset, 0, 0),
		material = Enum.Material.Snow,
		color = Builder.Palette.SnowShadow,
		parent = folder,
		canCollide = false,
		castShadow = false,
	})
	p.CanQuery = false
	table.insert(prints, { part = p, at = os.clock() })
	while #prints > F.MaxPrints do
		local old = table.remove(prints, 1)
		old.part:Destroy()
	end
end

function FootprintService.Begin(map)
	FootprintService.End()
	folder = Builder.folder(map.root, "Footprints")
	active = true
end

function FootprintService.End()
	active = false
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(prints)
	table.clear(lastPos)
end

function FootprintService.Init() end

function FootprintService.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			if not active then
				continue
			end
			for _, p in Players:GetPlayers() do
				local pos = FacilityService.PlayerPosition(p)
				if not pos then
					continue
				end
				if FacilityService.ZoneAt(pos) then
					lastPos[p] = pos
					continue
				end
				local last = lastPos[p]
				if not last or (pos - last).Magnitude >= F.StrideStuds then
					local dir = if last then (pos - last) else Vector3.new(0, 0, -1)
					if dir.Magnitude > 0.1 then
						side[p] = -(side[p] or 1)
						FootprintService.Stamp(pos - Vector3.new(0, 3, 0), dir.Unit, side[p] * 0.45)
					end
					lastPos[p] = pos
				end
			end
			-- Blizzards cover old prints faster; calm nights keep them for a while.
			local now = os.clock()
			while prints[1] and now - prints[1].at > F.LifetimeSeconds do
				local old = table.remove(prints, 1)
				old.part:Destroy()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastPos[p] = nil
		side[p] = nil
	end)
end

return FootprintService
