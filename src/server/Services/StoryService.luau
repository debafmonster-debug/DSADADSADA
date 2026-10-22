--!nonstrict
-- Story documents: placement inside the complex, server-validated pickup,
-- personal archive queries and chapter progression.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Documents = require(ReplicatedStorage.Shared.Config.Documents)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Sounds = require(ReplicatedStorage.Shared.Config.SoundLibrary)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local SeededRandom = require(ReplicatedStorage.Shared.Utilities.SeededRandom)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local Props = require(script.Parent.Parent.MapModules.Props)
local PlayerDataService = require(script.Parent.PlayerDataService)
local FacilityService = require(script.Parent.FacilityService)

local StoryService = {}

local placed: { [string]: BasePart } = {}
local foundThisShift: { [Player]: { string } } = {}
local limiter = RateLimiter.new(5, 1)

-- Creature knowledge entries unlock as the archive grows; no positions, only lore.
local CreatureKnowledge = {
	{ docs = 1, title = "Смотритель — запись 1", text = "Высокий силуэт в повреждённом защитном снаряжении. Медленно обходит сервисные коридоры. Реагирует на звук." },
	{ docs = 3, title = "Смотритель — запись 2", text = "Замечает свет фонаря на большом расстоянии. Теряет цель, если её не видно несколько секунд, и проверяет последнее известное место." },
	{ docs = 5, title = "Смотритель — запись 3", text = "Не ломает двери. Ждёт, пока их откроют. Связан с линией питания 4 и изоляционным сектором." },
}

function StoryService.PlaceDocuments(map: FacilityService.MapHandle, mission: Missions.MissionDef, seed: number)
	table.clear(placed)
	table.clear(foundThisShift)
	local rng = SeededRandom.new(seed + 404)
	local folder = Builder.folder(map.root, "Documents")
	local spots = rng:shuffle(map.documentSpots)
	local used: { [number]: boolean } = {}
	for _, docId in mission.documents do
		local def = Documents.Defs[docId]
		if not def then
			continue
		end
		-- Prefer a spot in the document's home sector, else anywhere free.
		local chosen: number? = nil
		for i, spot in spots do
			if not used[i] and spot.sector == def.sector then
				chosen = i
				break
			end
		end
		if not chosen then
			for i in spots do
				if not used[i] then
					chosen = i
					break
				end
			end
		end
		if not chosen then
			break
		end
		used[chosen] = true
		local spot = spots[chosen]
		local paper = Props.documentPickup(folder, spot.cframe * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, rng:nextNumber(-0.4, 0.4), 0), docId, def.title)
		local prompt = Builder.prompt(paper, "Прочитать", def.title, 0.5, Enum.KeyCode.E, 7)
		prompt:SetAttribute("UI", "Document")
		prompt:SetAttribute("DocumentId", docId)
		prompt.Triggered:Connect(function(player)
			StoryService.Read(player, docId)
		end)
		placed[docId] = paper
	end
end

function StoryService.Read(player: Player, docId: string): boolean
	if not limiter:allow(player) then
		return false
	end
	local paper = placed[docId]
	local def = Documents.Defs[docId]
	if not paper or not def or not paper.Parent then
		return false
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - paper.Position).Magnitude > 12 then
		return false
	end
	local isNew = PlayerDataService.AddDocument(player, docId)
	if isNew then
		foundThisShift[player] = foundThisShift[player] or {}
		table.insert(foundThisShift[player], docId)
		local s = Builder.sound(paper, Sounds.UIConfirm, "Found")
		s:Play()
		task.delay(2, function()
			s:Destroy()
		end)
	end
	Net.event("DocumentFound"):FireClient(player, { id = docId, title = def.title, author = def.author, kind = def.kind, body = def.body, isNew = isNew })
	return true
end

function StoryService.FoundThisShift(player: Player): number
	local list = foundThisShift[player]
	return if list then #list else 0
end

function StoryService.ClearShift()
	table.clear(placed)
	table.clear(foundThisShift)
end

function StoryService.Archive(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return nil
	end
	local docs = {}
	for _, id in Documents.Order do
		local def = Documents.Defs[id]
		local found = profile.documents[id] == true
		table.insert(docs, {
			id = id,
			kind = def.kind,
			title = if found then def.title else "[НЕ НАЙДЕНО]",
			author = if found then def.author else "",
			body = if found then def.body else "",
			chapter = def.chapter,
			found = found,
		})
	end
	local count = PlayerDataService.CountDocuments(profile)
	local chapters = {}
	for _, ch in Missions.Chapters do
		table.insert(chapters, {
			index = ch.index,
			title = ch.title,
			summary = ch.summary,
			unlocked = profile.chaptersUnlocked[ch.index] == true,
			requires = ch.unlockRequires,
			available = #ch.missions > 0,
		})
	end
	local creatures = {}
	for _, k in CreatureKnowledge do
		table.insert(creatures, { title = k.title, text = if count >= k.docs then k.text else "[Требуется документов: " .. k.docs .. "]", unlocked = count >= k.docs })
	end
	local history = {}
	for _, h in profile.shiftHistory do
		local m = Missions.Defs[h.missionId]
		table.insert(history, { title = if m then m.title else h.missionId, success = h.success, reward = h.reward, time = h.time, seed = h.seed })
	end
	return { documents = docs, chapters = chapters, creatures = creatures, history = history, documentCount = count, stats = profile.stats }
end

function StoryService.Init()
	Net.func("GetArchive").OnServerInvoke = function(player)
		if not limiter:allow(player) then
			return nil
		end
		return StoryService.Archive(player)
	end
	Net.func("ReadDocument").OnServerInvoke = function(player, docId)
		if not Net.isString(docId, 64) then
			return Net.fail("bad id")
		end
		return if StoryService.Read(player, docId) then Net.ok() else Net.fail("too far")
	end
end

function StoryService.Start() end

return StoryService
