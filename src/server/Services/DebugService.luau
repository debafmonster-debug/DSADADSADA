--!nonstrict
-- Developer debug: visualises the current layout graph (seed, node cells,
-- edges, start, tasks, evacuation, patrol points) when the Workspace
-- attribute NS_DebugLayout is true. Off by default.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local FacilityService = require(script.Parent.FacilityService)
local CreatureService = require(script.Parent.CreatureService)

local DebugService = {}
local folder: Folder? = nil
local thread: thread? = nil

local function clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function draw()
	clear()
	local map = FacilityService.Current()
	if not map then
		return
	end
	local f = Builder.folder(workspace, "Debug")
	folder = f
	local layout = map.layout
	local h = GameConfig.Grid.WallHeight + 6
	local byId = {}
	for _, n in layout.nodes do
		byId[n.id] = n
	end
	for _, handle in map.nodes do
		local n = handle.node
		local color = if n.id == layout.startNode then Color3.fromRGB(80, 200, 255) elseif n.id == layout.evacNode then Color3.fromRGB(80, 255, 120) elseif n.sector == "D" then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(230, 200, 80)
		local marker = Builder.part({ name = "Node" .. n.id, size = Vector3.new(6, 1, 6), cframe = handle.cframe * CFrame.new(0, h, 0), material = Enum.Material.Neon, color = color, parent = f, canCollide = false })
		local isTask = false
		for kind, id in layout.taskNodes do
			if id == n.id then
				isTask = true
				local _ = kind
			end
		end
		Builder.label(marker, Enum.NormalId.Top, string.format("%s\n%s%s", n.roomCode, n.moduleId, if isTask then "\n[TASK]" else ""), { textColor = Color3.new(0, 0, 0), textSize = 28, bold = true })
	end
	for _, e in layout.edges do
		local a, b = map.nodes[e.a], map.nodes[e.b]
		local pa, pb = a.cframe.Position + Vector3.new(0, h, 0), b.cframe.Position + Vector3.new(0, h, 0)
		local beam = Builder.beam(f, pa, pb, 1, 0.4, if e.locked then Color3.fromRGB(255, 60, 60) elseif e.doorType == "security" then Color3.fromRGB(255, 160, 60) else Color3.fromRGB(120, 220, 255))
		beam.Material = Enum.Material.Neon
	end
	for _, p in map.patrolPoints do
		Builder.part({ name = "Patrol", size = Vector3.new(1, 1, 1), cframe = CFrame.new(p + Vector3.new(0, 2, 0)), material = Enum.Material.Neon, color = Color3.fromRGB(200, 120, 255), parent = f, canCollide = false })
	end
	local info = Builder.part({ name = "Info", size = Vector3.new(16, 6, 0.2), cframe = map.nodes[layout.startNode].cframe * CFrame.new(0, h + 8, 0), material = Enum.Material.SmoothPlastic, color = Color3.new(0, 0, 0), parent = f, canCollide = false })
	Builder.label(info, Enum.NormalId.Front, string.format("SEED %d · nodes %d · edges %d · fallback %s · attempts %d", layout.seed, #layout.nodes, #layout.edges, tostring(layout.fallback), layout.attempts), { textColor = Color3.new(1, 1, 1), textSize = 30, font = Enum.Font.Code })
	Net.event("DebugLayout"):FireAllClients({ seed = layout.seed, nodes = layout.nodes, edges = layout.edges, startNode = layout.startNode, evacNode = layout.evacNode, taskNodes = layout.taskNodes })
	-- Warden tracker (developer only)
	local tracker = Builder.part({ name = "WardenTracker", size = Vector3.new(2, 2, 2), cframe = CFrame.new(0, -100, 0), material = Enum.Material.Neon, color = Color3.fromRGB(255, 0, 0), parent = f, canCollide = false })
	thread = task.spawn(function()
		while folder == f do
			task.wait(0.5)
			local pos = CreatureService.Position()
			if pos then
				tracker.CFrame = CFrame.new(pos + Vector3.new(0, h, 0))
				Builder.label(tracker, Enum.NormalId.Top, tostring(CreatureService.State()), { textSize = 20 })
				for _, g in tracker:GetChildren() do
					if g:IsA("SurfaceGui") and g ~= tracker:GetChildren()[#tracker:GetChildren()] then
						g:Destroy()
					end
				end
			end
		end
	end)
end

function DebugService.Init()
	workspace:GetAttributeChangedSignal(GameConfig.Debug.AttributeName):Connect(function()
		if workspace:GetAttribute(GameConfig.Debug.AttributeName) == true then
			draw()
		else
			clear()
			if thread then
				task.cancel(thread)
				thread = nil
			end
		end
	end)
end

function DebugService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			if workspace:GetAttribute(GameConfig.Debug.AttributeName) == true then
				local map = FacilityService.Current()
				if map and (not folder or folder.Parent == nil) then
					draw()
				elseif not map and folder then
					clear()
				end
			end
		end
	end)
end

return DebugService
