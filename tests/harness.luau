--!nocheck
-- Lune harness: loads the Rojo-built place file and executes ModuleScripts
-- with a Roblox-like environment so pure logic (layout generation,
-- validation, config consistency, geometry builders) can be tested headless.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local task = require("@lune/task")

local Harness = {}

local PLACE = "build/NightShift.rbxl"

local function fakeSignal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Once = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Wait = function()
			coroutine.yield()
		end,
		_fire = function(...)
			for _, h in handlers do
				h(...)
			end
		end,
	}
end

function Harness.load()
	local game = roblox.deserializePlace(fs.readFile(PLACE))
	local cache = {}
	local services = {}

	local runService = {
		IsServer = function() return true end,
		IsClient = function() return false end,
		IsStudio = function() return true end,
		IsRunning = function() return false end,
		Heartbeat = fakeSignal(),
		Stepped = fakeSignal(),
		RenderStepped = fakeSignal(),
	}
	local players = {
		GetPlayers = function() return {} end,
		PlayerAdded = fakeSignal(),
		PlayerRemoving = fakeSignal(),
		GetPlayerFromCharacter = function() return nil end,
	}
	local dataStoreService = {
		GetDataStore = function()
			local store = {}
			return {
				GetAsync = function(_, key) return store[key] end,
				UpdateAsync = function(_, key, fn)
					store[key] = fn(store[key])
					return store[key]
				end,
				SetAsync = function(_, key, v) store[key] = v end,
			}
		end,
	}
	local pathfinding = { CreatePath = function() error("PathfindingService unavailable in Lune") end }
	local stubs = {
		RunService = runService,
		Players = players,
		DataStoreService = dataStoreService,
		PathfindingService = pathfinding,
		TeleportService = {},
		CollectionService = { AddTag = function() end, GetTagged = function() return {} end, HasTag = function() return false end },
		TweenService = { Create = function() return { Play = function() end, Completed = fakeSignal() } end },
		SoundService = {},
		Debris = { AddItem = function() end },
		PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end },
		HttpService = { GenerateGUID = function() return tostring(math.random(1e9)) end, JSONEncode = function(_, t) return tostring(t) end },
		MarketplaceService = {},
		UserInputService = {},
		ContextActionService = {},
		GuiService = {},
		Lighting = game:GetService("Lighting"),
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		ServerScriptService = game:GetService("ServerScriptService"),
		ServerStorage = game:GetService("ServerStorage"),
		Workspace = game:GetService("Workspace"),
		StarterGui = game:GetService("StarterGui"),
	}
	local gameStub = setmetatable({
		GetService = function(_, name)
			local s = stubs[name]
			if not s then
				error("Harness: service not stubbed: " .. name)
			end
			return s
		end,
		BindToClose = function() end,
		PlaceId = 0,
		JobId = "",
		PrivateServerId = "",
		Workspace = game:GetService("Workspace"),
	}, { __index = function(_, k)
		return stubs[k] or game[k]
	end })
	services.gameStub = gameStub

	local env
	local function requireModule(inst)
		if typeof(inst) ~= "Instance" then
			error("require expects ModuleScript, got " .. typeof(inst))
		end
		if cache[inst] ~= nil then
			return cache[inst]
		end
		local src = inst.Source
		-- luau.load copies the environment table, so build a flat one per module.
		local moduleEnv = {}
		for k, v in env do
			moduleEnv[k] = v
		end
		for k, v in _G do
			if moduleEnv[k] == nil then
				moduleEnv[k] = v
			end
		end
		moduleEnv.script = inst
		local fn = luau.load(src, { debugName = inst:GetFullName(), environment = moduleEnv })
		local result = fn()
		cache[inst] = result
		return result
	end

	env = setmetatable({
		game = gameStub,
		workspace = game:GetService("Workspace"),
		require = requireModule,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		Rect = roblox.Rect,
		TweenInfo = roblox.TweenInfo,
		RaycastParams = { new = function() return { FilterDescendantsInstances = {} } end },
		task = task,
		tick = os.clock,
		time = os.clock,
		warn = print,
		typeof = typeof,
		settings = function() return { Rendering = {} } end,
	}, { __index = _G })
	services.env = env
	services.game = game
	services.require = requireModule
	services.path = function(path: string)
		local cur = game
		for seg in string.gmatch(path, "[^%.]+") do
			cur = cur:FindFirstChild(seg)
			if not cur then
				error("path not found: " .. path)
			end
		end
		return cur
	end
	return services
end

-- tiny test runner
local results = { passed = 0, failed = 0 }
function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  ✓ " .. name)
	else
		results.failed += 1
		print("  ✗ " .. name .. "\n     " .. tostring(err))
	end
end

function Harness.finish()
	print(string.format("\n%d passed, %d failed", results.passed, results.failed))
	if results.failed > 0 then
		local process = require("@lune/process")
		process.exit(1)
	end
end

function Harness.eq(a, b, msg)
	if a ~= b then
		error((msg or "assertion") .. string.format(": expected %s, got %s", tostring(b), tostring(a)), 2)
	end
end

return Harness
