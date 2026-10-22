--!nonstrict
-- Team signals: rate-limited, only carries what the sender knows (their own
-- position and a predefined message).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signals = require(ReplicatedStorage.Shared.Config.Signals)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)

local CommunicationService = {}

local limiter = RateLimiter.new(1, 1 / GameConfig.Communication.SignalCooldown)
local recipients: (Player) -> { Player } = function(_: Player)
	return Players:GetPlayers()
end

function CommunicationService.SetRecipientResolver(fn: (Player) -> { Player })
	recipients = fn
end

function CommunicationService.Init()
	Net.event("SignalSend").OnServerEvent:Connect(function(player, signalId)
		if not Net.isString(signalId, 16) or not Signals.ById[signalId] then
			return
		end
		if not limiter:allow(player) then
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local payload = {
			id = signalId,
			text = Signals.ById[signalId].text,
			sender = player.DisplayName,
			senderId = player.UserId,
			position = if hrp then hrp.Position else nil,
			lifetime = GameConfig.Communication.SignalLifetime,
		}
		for _, p in recipients(player) do
			Net.event("SignalBroadcast"):FireClient(p, payload)
		end
	end)
end

function CommunicationService.Start() end

return CommunicationService
