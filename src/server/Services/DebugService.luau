--!nonstrict
-- Developer helpers, enabled only when Workspace carries the debug attribute.
-- Lets a tester force weather, time, incidents and events without playing
-- through the whole evening. Never active for ordinary players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ClockService = require(script.Parent.ClockService)
local WeatherService = require(script.Parent.WeatherService)
local PowerGridService = require(script.Parent.PowerGridService)
local EventDirector = require(script.Parent.EventDirector)
local RoundManager = require(script.Parent.RoundManager)
local IdentityService = require(script.Parent.IdentityService)
local CreatureService = require(script.Parent.CreatureService)

local DebugService = {}

local function enabled(): boolean
	return workspace:GetAttribute(GameConfig.Debug.AttributeName) == true
end

local commands = {
	hour = function(arg)
		local h = tonumber(arg)
		if h then
			ClockService.StartShift(h)
		end
	end,
	weather = function(arg)
		WeatherService.Force(arg ~= "" and arg or nil)
	end,
	fault = function()
		PowerGridService.InjectFault(nil)
	end,
	trip = function()
		PowerGridService.Trip("debug")
	end,
	event = function(arg)
		EventDirector.Force(arg)
	end,
	guest = function()
		local shift = RoundManager.Current()
		local FacilityService = require(script.Parent.FacilityService)
		if shift and FacilityService.Current() then
			RoundManager.SpawnGuest(shift, FacilityService.Current())
		end
	end,
	double = function(_, player)
		IdentityService.SpawnDouble(player)
	end,
	alert = function(arg)
		CreatureService.AddAlertness(tonumber(arg) or 0.5)
	end,
}

function DebugService.Init() end

function DebugService.Start()
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(msg)
			if not enabled() then
				return
			end
			local cmd, arg = string.match(msg, "^/v9 (%a+)%s*(.*)$")
			local fn = cmd and commands[cmd]
			if fn then
				local ok, err = pcall(fn, arg or "", player)
				if not ok then
					warn("[Debug] " .. tostring(err))
				end
			end
		end)
	end)
end

return DebugService
