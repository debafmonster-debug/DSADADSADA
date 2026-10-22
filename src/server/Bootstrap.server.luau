--!nonstrict
-- Server entry point. Order matters: data first, then world systems, then
-- gameplay, then the lobby that depends on all of them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)

-- Creates the Remotes folder before any client can ask for it.
Net.event("ClientReady")

local Services = script.Parent.Services
local order = {
	"PlayerDataService",
	"ClockService",
	"WeatherService",
	"FacilityService",
	"PowerGridService",
	"NoiseDirector",
	"TemperatureService",
	"CreatureService",
	"RescueService",
	"IdentityService",
	"EquipmentService",
	"TaskService",
	"WarehouseService",
	"BunkerService",
	"CommunicationService",
	"StoryService",
	"EventDirector",
	"FootprintService",
	"RoundManager",
	"RoomService",
	"LobbyService",
	"CinematicService",
	"DebugService",
}

Players.CharacterAutoLoads = true
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.EnableMouseLockOption = false

local loaded = {}
for _, name in order do
	local ok, mod = pcall(require, Services:FindFirstChild(name))
	if not ok then
		error(string.format("[Bootstrap] failed to load %s: %s", name, tostring(mod)))
	end
	loaded[name] = mod
end
for _, name in order do
	local mod = loaded[name]
	if mod.Init then
		local ok, err = pcall(mod.Init)
		if not ok then
			error(string.format("[Bootstrap] %s.Init failed: %s", name, tostring(err)))
		end
	end
end
for _, name in order do
	local mod = loaded[name]
	if mod.Start then
		local ok, err = pcall(mod.Start)
		if not ok then
			error(string.format("[Bootstrap] %s.Start failed: %s", name, tostring(err)))
		end
	end
end

-- Clients announce readiness; reply with the current room list and world state.
Net.event("ClientReady").OnServerEvent:Connect(function(player)
	Net.event("RoomListUpdated"):FireClient(player, { rooms = loaded.RoomService.List(player), mine = nil })
	Net.event("WeatherState"):FireClient(player, loaded.WeatherService.Snapshot())
	Net.event("ClockState"):FireClient(player, loaded.ClockService.Snapshot())
	Net.event("PowerState"):FireClient(player, loaded.PowerGridService.Snapshot())
end)

print(string.format("[Vostok9] %s v%s server ready (teleport: %s)", GameConfig.GameName, GameConfig.Version, tostring(GameConfig.UseTeleportForShifts)))
