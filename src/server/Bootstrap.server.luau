--!nonstrict
-- Server entry point. Order matters: data first, then world, then gameplay.
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
	"FacilityService",
	"CreatureService",
	"RescueService",
	"TaskService",
	"StoryService",
	"EquipmentService",
	"CommunicationService",
	"RoundManager",
	"MatchmakingService",
	"LobbyService",
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

-- Clients announce readiness; reply with the current shift list and profile.
Net.event("ClientReady").OnServerEvent:Connect(function(player)
	local Matchmaking = loaded.MatchmakingService
	Net.event("ShiftListUpdated"):FireClient(player, { shifts = Matchmaking.List(player), mine = nil })
end)

print(string.format("[NightShift] %s v%s server ready (teleport mode: %s)", GameConfig.GameName, GameConfig.Version, tostring(GameConfig.UseTeleportForShifts)))
