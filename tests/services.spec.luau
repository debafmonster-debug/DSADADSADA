--!nocheck
local H = require("./harness")
local task = require("@lune/task")
local S = H.load()

print("Module loading (require graph)")
local serverRoot = S.path("ServerScriptService.NightShift")
for _, d in serverRoot:GetDescendants() do
	if d:IsA("ModuleScript") then
		H.test("require " .. d:GetFullName(), function()
			S.require(d)
		end)
	end
end
for _, d in S.path("ReplicatedStorage.Shared"):GetDescendants() do
	if d:IsA("ModuleScript") then
		H.test("require " .. d:GetFullName(), function()
			S.require(d)
		end)
	end
end

print("PlayerDataService")
local PDS = S.require(S.path("ServerScriptService.NightShift.Services.PlayerDataService"))
H.test("sanitizeSettings clamps and defaults", function()
	local s = PDS.sanitizeSettings({ musicVolume = 5, sensitivity = -1, subtitles = "yes", textScale = 1.2, effectsQuality = 9 })
	H.eq(s.musicVolume, 1)
	H.eq(s.sensitivity, 0.05)
	H.eq(s.subtitles, true)
	H.eq(s.textScale, 1.2)
	H.eq(s.effectsQuality, 2)
	local d = PDS.sanitizeSettings(nil)
	H.eq(d.musicVolume, 0.7)
end)
H.test("migrate rejects corrupt/unknown data and never grants", function()
	local p = PDS.Migrate({ currency = -500, documents = { doc_shift_report_41 = true, fake_doc = true, doc_note_security = "yes" }, chaptersUnlocked = { [4] = true, [2] = true }, selectedTool = "Laser", shiftHistory = { { missionId = 7 }, { missionId = "ch1_last_shift", success = true, reward = 1e12 } } })
	H.eq(p.currency, 0)
	H.eq(p.documents.doc_shift_report_41, true)
	H.eq(p.documents.fake_doc, nil)
	H.eq(p.documents.doc_note_security, nil)
	H.eq(p.chaptersUnlocked[1], true)
	H.eq(p.chaptersUnlocked[2], true)
	H.eq(p.chaptersUnlocked[4], true) -- chapter 4 exists in config, boolean true is accepted
	H.eq(p.selectedTool, "Multimeter")
	H.eq(#p.shiftHistory, 1)
	H.eq(p.shiftHistory[1].reward, 1e6)
end)
H.test("migrate of garbage yields default", function()
	local p = PDS.Migrate("garbage")
	H.eq(p.version, 1)
	H.eq(p.currency, 0)
end)

print("Utilities")
local SeededRandom = S.require(S.path("ReplicatedStorage.Shared.Utilities.SeededRandom"))
H.test("seeded random is deterministic and in range", function()
	local a, b = SeededRandom.new(123), SeededRandom.new(123)
	for _ = 1, 200 do
		local x, y = a:nextInteger(1, 10), b:nextInteger(1, 10)
		H.eq(x, y)
		assert(x >= 1 and x <= 10)
	end
	local c = SeededRandom.new(124)
	local same = 0
	for _ = 1, 50 do
		if SeededRandom.new(123):nextNumber() == c:nextNumber() then
			same += 1
		end
	end
	assert(same < 5, "different seeds should differ")
end)
local RateLimiter = S.require(S.path("ReplicatedStorage.Shared.Utilities.RateLimiter"))
H.test("rate limiter blocks bursts", function()
	local rl = RateLimiter.new(3, 1)
	assert(rl:allow("a") and rl:allow("a") and rl:allow("a"))
	assert(not rl:allow("a"))
	assert(rl:allow("b"))
end)
local Signal = S.require(S.path("ReplicatedStorage.Shared.Utilities.Signal"))
H.test("signal fires and disconnects", function()
	local s = Signal.new()
	local n = 0
	local c = s:Connect(function(v) n += v end)
	s:Fire(2)
	task.wait()
	c:Disconnect()
	s:Fire(5)
	task.wait()
	H.eq(n, 2)
end)
local Net = S.require(S.path("ReplicatedStorage.Shared.Utilities.Net"))
H.test("net validators", function()
	assert(Net.isInt(3) and not Net.isInt(3.5) and not Net.isInt("3") and not Net.isInt(0/0))
	assert(Net.isNumber(1.5, 0, 2) and not Net.isNumber(math.huge))
	assert(Net.isString("abc", 3) and not Net.isString("abcd", 3))
end)

print("Rewards")
local Reward = S.require(S.path("ServerScriptService.NightShift.Services.RewardService"))
local GameConfig = S.require(S.path("ReplicatedStorage.Shared.Config.GameConfig"))
H.test("success reward includes all bonuses", function()
	local r = Reward.Compute({ UserId = 1 }, { success = true, mainDone = true, optionalDone = true, fullTeamEvac = true, evacuated = {} })
	H.eq(r.total, GameConfig.Rewards.MainObjective + GameConfig.Rewards.OptionalObjective + GameConfig.Rewards.FullTeamEvac)
end)
H.test("failure keeps a fraction and never goes negative", function()
	local r = Reward.Compute({ UserId = 1 }, { success = false, mainDone = true, optionalDone = true, fullTeamEvac = false, evacuated = {} })
	H.eq(r.total, GameConfig.Rewards.MainObjective - math.floor(GameConfig.Rewards.MainObjective * GameConfig.Rewards.FailurePenaltyFraction))
	local z = Reward.Compute({ UserId = 1 }, { success = false, mainDone = false, optionalDone = false, fullTeamEvac = false, evacuated = {} })
	H.eq(z.total, 0)
end)

print("Warden rig")
local WardenModel = S.require(S.path("ServerScriptService.NightShift.Creatures.WardenModel"))
local roblox = require("@lune/roblox")
H.test("warden rig builds with motors and pose runs", function()
	local rig = WardenModel.build(S.game:GetService("Workspace"), roblox.CFrame.new(0, 10, 0))
	assert(rig.humanoid and rig.root and rig.head)
	for _, name in { "Root", "Neck", "ShoulderL", "ShoulderR", "ElbowL", "ElbowR", "HipL", "HipR" } do
		assert(rig.motors[name], "motor " .. name)
	end
	for _, mode in { "Patrol", "Chase", "Attack", "Suspicious" } do
		WardenModel.pose(rig, 1.3, 0.7, mode)
	end
	local parts = 0
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") then parts += 1 end
	end
	print("    warden parts: " .. parts)
	assert(parts < 60)
end)

H.finish()
