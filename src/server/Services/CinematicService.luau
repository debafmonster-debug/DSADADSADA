--!nonstrict
-- Cinematics are rendered by each client; the server only decides when they
-- play, records the intro choice and enforces the decline path (a clean kick
-- with a message, never a fake error).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Dialogue = require(ReplicatedStorage.Shared.Config.Dialogue)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CinematicService = {}

local limiter = RateLimiter.new(4, 1)
local introDone: { [Player]: boolean } = {}

function CinematicService.IntroDone(player: Player): boolean
	return introDone[player] == true
end

local function offerIntro(player: Player)
	local profile = PlayerDataService.WaitFor(player, 15)
	if not profile or player.Parent ~= Players then
		return
	end
	Net.event("Cinematic"):FireClient(player, { kind = "Intro", skippable = profile.introSeen == true, lines = Dialogue.IntroCall })
end

function CinematicService.Init()
	Net.func("IntroChoice").OnServerInvoke = function(player, accept)
		if not limiter:allow(player) or not Net.isBool(accept) then
			return Net.fail("bad args")
		end
		if accept then
			introDone[player] = true
			PlayerDataService.MarkIntroSeen(player)
			return Net.ok()
		end
		-- Declining the job: leave the server politely.
		task.delay(0.5, function()
			if player.Parent == Players then
				player:Kick(Dialogue.DeclineMessage)
			end
		end)
		return Net.ok({ leaving = true })
	end
	Net.event("CinematicDone").OnServerEvent:Connect(function(player, kind)
		if kind == "Intro" then
			introDone[player] = true
		end
	end)
end

function CinematicService.Start()
	-- The intro is offered only once the client has its controllers up.
	local offered: { [Player]: boolean } = {}
	Net.event("ClientReady").OnServerEvent:Connect(function(p)
		if offered[p] then
			return
		end
		offered[p] = true
		task.spawn(offerIntro, p)
	end)
	Players.PlayerRemoving:Connect(function(p)
		introDone[p] = nil
		offered[p] = nil
	end)
end

return CinematicService
