--!nocheck
-- Module graph, player data, utilities, rewards and the creature rig.
local H = require("./harness")
local task = require("@lune/task")
local S = H.load()

print("Module loading (require graph)")
for _, root in { S.path("ServerScriptService.Vostok9"), S.path("ReplicatedStorage.Shared") } do
	for _, d in root:GetDescendants() do
		if d:IsA("ModuleScript") then
			H.test("require " .. d:GetFullName(), function()
				S.require(d)
			end)
		end
	end
end

print("PlayerDataService")
local PDS = S.require(S.path("ServerScriptService.Vostok9.Services.PlayerDataService"))
H.test("sanitizeSettings clamps and defaults", function()
	local s = PDS.sanitizeSettings({ musicVolume = 5, sensitivity = -1, subtitles = "yes", textScale = 1.2, effectsQuality = 9, particles = 7, frost = "no", postFx = 3 })
	H.eq(s.musicVolume, 1)
	H.eq(s.sensitivity, 0.05)
	H.eq(s.subtitles, true)
	H.eq(s.textScale, 1.2)
	H.eq(s.effectsQuality, 2)
	H.eq(s.particles, 2)
	H.eq(s.frost, true)
	H.eq(s.postFx, 1)
	local d = PDS.sanitizeSettings(nil)
	H.eq(d.musicVolume, 0.7)
	H.eq(d.dialogueVolume, 1)
end)
H.test("migrate rejects corrupt/unknown data and never grants", function()
	local p = PDS.Migrate({ currency = -500, documents = { doc_duty_log = true, fake_doc = true, doc_medical = "yes" }, chaptersUnlocked = { [3] = true, [2] = true, [99] = true }, selectedTool = "Laser", shiftHistory = { { missionId = 7 }, { missionId = "ch1_last_signal", success = true, reward = 1e12 } }, introSeen = "yes", cosmeticsEquipped = { suit = "orange", bad = 5 } })
	H.eq(p.currency, 0)
	H.eq(p.documents.doc_duty_log, true)
	H.eq(p.documents.fake_doc, nil)
	H.eq(p.documents.doc_medical, nil)
	H.eq(p.chaptersUnlocked[1], true)
	H.eq(p.chaptersUnlocked[2], true)
	H.eq(p.chaptersUnlocked[99], nil)
	H.eq(p.selectedTool, "Multimeter")
	H.eq(#p.shiftHistory, 1)
	H.eq(p.shiftHistory[1].reward, 1e6)
	H.eq(p.introSeen, false)
	H.eq(p.cosmeticsEquipped.suit, "orange")
	H.eq(p.cosmeticsEquipped.bad, nil)
end)
H.test("migrate of garbage yields default", function()
	local p = PDS.Migrate("garbage")
	H.eq(p.version, 2)
	H.eq(p.currency, 0)
	H.eq(p.stats.nightsSurvived, 0)
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
end)
local RateLimiter = S.require(S.path("ReplicatedStorage.Shared.Utilities.RateLimiter"))
H.test("rate limiter blocks bursts", function()
	local l = RateLimiter.new(3, 1)
	H.eq(l:allow("k"), true)
	H.eq(l:allow("k"), true)
	H.eq(l:allow("k"), true)
	H.eq(l:allow("k"), false)
end)
local Signal = S.require(S.path("ReplicatedStorage.Shared.Utilities.Signal"))
H.test("signal fires and disconnects", function()
	local s = Signal.new()
	local n = 0
	local c = s:Connect(function(v)
		n += v
	end)
	s:Fire(2)
	task.wait()
	c:Disconnect()
	s:Fire(5)
	task.wait()
	H.eq(n, 2)
end)
local Net = S.require(S.path("ReplicatedStorage.Shared.Utilities.Net"))
H.test("net validators", function()
	H.eq(Net.isInt(3, 1, 4), true)
	H.eq(Net.isInt(3.5), false)
	H.eq(Net.isInt(0 / 0), false)
	H.eq(Net.isString(string.rep("a", 65)), false)
	H.eq(Net.isNumber(math.huge), false)
	H.eq(Net.ok(1).ok, true)
	H.eq(Net.fail("x").reason, "x")
end)

print("Config consistency")
local Chapters = S.require(S.path("ReplicatedStorage.Shared.Config.Chapters"))
local Documents = S.require(S.path("ReplicatedStorage.Shared.Config.Documents"))
local Tools = S.require(S.path("ReplicatedStorage.Shared.Config.Tools"))
local Sounds = S.require(S.path("ReplicatedStorage.Shared.Config.SoundLibrary"))
local RadioPhrases = S.require(S.path("ReplicatedStorage.Shared.Config.RadioPhrases"))
local GameConfig = S.require(S.path("ReplicatedStorage.Shared.Config.GameConfig"))
H.test("every shift references real documents and known task kinds", function()
	local kinds = { PowerCheck = true, FuseReplace = true, AntennaAlign = true, RadioRestore = true, LogRetrieve = true }
	for id, def in Chapters.Shifts do
		H.eq(def.id, id)
		assert(Chapters.ByIndex[def.chapter], "chapter for " .. id)
		for _, docId in def.documents do
			assert(Documents.Defs[docId], id .. " references unknown document " .. docId)
		end
		for _, t in def.tasks do
			assert(kinds[t.kind], id .. " has unknown task kind " .. t.kind)
		end
	end
	for _, ch in Chapters.List do
		for _, sid in ch.shifts do
			assert(Chapters.Shifts[sid] and Chapters.Shifts[sid].chapter == ch.index, "chapter shift mismatch " .. sid)
		end
	end
end)
H.test("documents with secrets format cleanly", function()
	for id, d in Documents.Defs do
		if d.secret then
			local ok = pcall(string.format, d.body, "1234")
			assert(ok, "format failed for " .. id)
		end
	end
end)
H.test("tools use known sounds; items have stacks", function()
	for _, id in Tools.Order do
		local def = Tools.Defs[id]
		assert(Sounds[def.useSound], "missing sound " .. def.useSound)
	end
	for _, id in Tools.ItemOrder do
		assert(Tools.Items[id].stack >= 1)
	end
	for _, comp in GameConfig.Power.Components do
		assert(Tools.Items[comp.part], "component part not an item: " .. comp.part)
	end
end)
H.test("radio reactions are declared for every phrase that uses one", function()
	for _, p in RadioPhrases.List do
		if p.reaction then
			assert(RadioPhrases.Reactions[p.reaction], "missing reaction " .. p.reaction)
		end
		if p.nightReply and p.reaction == "echo" then
			assert(string.find(p.nightReply, "%%s"), "echo reply needs a %s")
		end
	end
end)
H.test("placeholder sounds are marked as such", function()
	for key, def in Sounds do
		if typeof(def) == "table" then
			assert(def.placeholder == true, key .. " must be flagged placeholder until authored")
		end
	end
end)

print("Rewards")
local Reward = S.require(S.path("ServerScriptService.Vostok9.Services.RewardService"))
local fakePlayer = { UserId = 1, DisplayName = "T", Name = "T" }
H.test("success pays tasks, night and evac; failure keeps a fraction", function()
	local win = Reward.Compute(fakePlayer, { success = true, mainDone = true, optionalDone = true, nightSurvived = true, fullTeamEvac = true, evacuated = {}, rescues = { [fakePlayer] = 2 } })
	H.eq(win.total, 90 + 40 + 70 + 60 + 50)
	local lose = Reward.Compute(fakePlayer, { success = false, mainDone = true, optionalDone = true, nightSurvived = false, fullTeamEvac = false, evacuated = {}, rescues = {} })
	assert(lose.total < 90 and lose.total >= 0)
	local nothing = Reward.Compute(fakePlayer, { success = false, mainDone = false, optionalDone = false, nightSurvived = false, fullTeamEvac = false, evacuated = {}, rescues = {} })
	H.eq(nothing.total, 0)
end)

print("Guest rig")
local GuestModel = S.require(S.path("ServerScriptService.Vostok9.Creatures.GuestModel"))
H.test("rig builds with the motor contract and poses in every mode", function()
	local rig = GuestModel.build(S.game:GetService("Workspace"), S.env.CFrame.new(0, 10, 0))
	for _, n in { "Root", "Waist", "Neck", "ShoulderL", "ShoulderR", "ElbowL", "ElbowR", "HipL", "HipR", "KneeL", "KneeR" } do
		assert(rig.motors[n], "motor " .. n)
	end
	for _, mode in { "Idle", "Walk", "Stalk", "Chase", "Observe", "Listen", "Attack" } do
		GuestModel.pose(rig, 1.2, 1, mode, 0.2, -0.1)
	end
	GuestModel.setEyes(rig, 1)
	GuestModel.setEyes(rig, 0)
	local parts = 0
	for _, p in rig.model:GetDescendants() do
		if p:IsA("BasePart") then
			parts += 1
		end
	end
	assert(parts < 60, "rig too heavy: " .. parts)
	assert(rig.humanoid.HipHeight > 5)
	rig.model:Destroy()
end)

print("Lobby")
local LobbyBuilder = S.require(S.path("ServerScriptService.Vostok9.Lobby.LobbyBuilder"))
H.test("lobby builds all zones and anchors within budget", function()
	local a = LobbyBuilder.build(S.game:GetService("Workspace"), S.env.CFrame.new(0, 0, 0))
	assert(a.spawn and a.shiftBoard and a.briefingConsole and a.registration and a.airlockDoor, "anchors")
	H.eq(#a.archiveTerminals, 2)
	for _, id in Tools.Order do
		assert(a.lockers[id], "locker " .. id)
	end
	local parts, lights = 0, 0
	for _, p in a.root:GetDescendants() do
		if p:IsA("BasePart") then
			parts += 1
		elseif p:IsA("Light") then
			lights += 1
		end
	end
	assert(parts > 500 and parts < 4000, "lobby parts " .. parts)
	assert(lights < 90, "lobby lights " .. lights)
	for _, name in { "RestRoom", "EquipmentRoom", "BriefingRoom", "ArchiveRoom", "ExitAirlock", "Outside" } do
		assert(a.root:FindFirstChild(name), "zone " .. name)
	end
	a.root:Destroy()
end)

print("Scenes")
local Apartment = S.require(S.path("ReplicatedStorage.Shared.Scenes.Apartment"))
local Airfield = S.require(S.path("ReplicatedStorage.Shared.Scenes.Airfield"))
H.test("apartment and airfield sets build with their anchors", function()
	local set = Apartment.build(S.game:GetService("Workspace"), S.env.Vector3.new(0, 500, 0))
	assert(set.sofaSeat and set.phone and set.door and set.taxi and set.tvScreen and set.cameraStreet)
	set.root:Destroy()
	local af = Airfield.build(S.game:GetService("Workspace"), S.env.Vector3.new(0, 600, 0))
	assert(af.plane and af.plane:FindFirstChild("Door") and af.airlock and af.stairs)
	af.root:Destroy()
end)

H.finish()
