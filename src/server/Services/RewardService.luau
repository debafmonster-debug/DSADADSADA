--!nonstrict
-- Shift reward computation and idempotent grant.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StoryService = require(script.Parent.StoryService)

local RewardService = {}

export type Outcome = {
	success: boolean,
	mainDone: boolean,
	optionalDone: boolean,
	fullTeamEvac: boolean,
	evacuated: { [Player]: boolean },
}

function RewardService.Compute(player: Player, outcome: Outcome): { total: number, lines: { { label: string, value: number } } }
	local R = GameConfig.Rewards
	local lines = {}
	local total = 0
	if outcome.mainDone then
		table.insert(lines, { label = "Основная цель", value = R.MainObjective })
		total += R.MainObjective
	end
	if outcome.optionalDone and outcome.success then
		table.insert(lines, { label = "Дополнительная задача", value = R.OptionalObjective })
		total += R.OptionalObjective
	end
	if outcome.fullTeamEvac and outcome.success then
		table.insert(lines, { label = "Эвакуация всей команды", value = R.FullTeamEvac })
		total += R.FullTeamEvac
	end
	local docs = StoryService.FoundThisShift(player)
	if docs > 0 then
		table.insert(lines, { label = "Документы (" .. docs .. ")", value = R.DocumentFound * docs })
		total += R.DocumentFound * docs
	end
	if not outcome.success then
		local penalty = math.floor(total * R.FailurePenaltyFraction)
		table.insert(lines, { label = "Смена провалена", value = -penalty })
		total -= penalty
	end
	return { total = math.max(0, total), lines = lines }
end

function RewardService.Grant(player: Player, shiftId: string, missionId: string, seed: number, outcome: Outcome)
	local reward = RewardService.Compute(player, outcome)
	local token = string.format("shift:%s:%d", shiftId, player.UserId)
	local granted = PlayerDataService.GrantCurrency(player, reward.total, token)
	if granted then
		PlayerDataService.RecordShift(player, { missionId = missionId, success = outcome.success, reward = reward.total, seed = seed })
	end
	return reward
end

return RewardService
