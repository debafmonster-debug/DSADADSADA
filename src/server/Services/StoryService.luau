--!nonstrict
-- Documents in the world and the player's archive. Per-shift secrets (the
-- warehouse code, the dispatcher frequency) are substituted into document
-- bodies at placement so the paper trail is the real source of truth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Documents = require(ReplicatedStorage.Shared.Config.Documents)
local Chapters = require(ReplicatedStorage.Shared.Config.Chapters)
local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Props = require(ReplicatedStorage.Shared.Utilities.Props)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Utilities.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StoryService = {}
StoryService.DocumentRead = Signal.new() :: Signal.Signal<Player, string>

local placed: { [string]: { part: BasePart, body: string } } = {}
local foundThisShift: { [Player]: { [string]: boolean } } = {}
local limiter = RateLimiter.new(6, 2)
local folder: Folder? = nil
local deps = {
	inShift = function(_: Player)
		return false
	end,
}

function StoryService.Configure(api)
	for k, v in api do
		deps[k] = v
	end
end

local function bodyFor(def: Documents.DocumentDef, secrets: { [string]: string }): string
	if def.secret and secrets[def.secret] then
		return string.format(def.body, secrets[def.secret])
	end
	return def.body
end

function StoryService.PlaceDocuments(map, shiftDef, secrets: { [string]: string })
	StoryService.ClearShift()
	folder = Builder.folder(map.root, "Documents")
	for _, docId in shiftDef.documents do
		local def = Documents.Defs[docId]
		local cf = def and map.documentSpots[def.spot]
		if not def or not cf then
			continue
		end
		local part = Props.documentPickup(folder, cf, docId, def.title, def.kind)
		local body = bodyFor(def, secrets)
		placed[docId] = { part = part, body = body }
		local prompt = Builder.prompt(part, "Прочитать", def.kind, 0.4, Enum.KeyCode.E, 7)
		prompt:SetAttribute("UI", "Document")
		prompt:SetAttribute("DocumentId", docId)
		prompt.Triggered:Connect(function(player)
			StoryService.Read(player, docId)
		end)
	end
end

function StoryService.Read(player: Player, docId: string): boolean
	local entry = placed[docId]
	local def = Documents.Defs[docId]
	if not entry or not def or not deps.inShift(player) then
		return false
	end
	if not limiter:allow(player) or not Net.near(player, entry.part.CFrame.Position, 12) then
		return false
	end
	foundThisShift[player] = foundThisShift[player] or {}
	local isNew = not foundThisShift[player][docId]
	foundThisShift[player][docId] = true
	local profileNew = PlayerDataService.AddDocument(player, docId)
	Net.event("DocumentFound"):FireClient(player, { id = docId, title = def.title, author = def.author, kind = def.kind, body = entry.body, isNew = profileNew })
	if isNew then
		StoryService.DocumentRead:Fire(player, docId)
	end
	return true
end

function StoryService.FoundThisShift(player: Player): number
	local n = 0
	for _ in foundThisShift[player] or {} do
		n += 1
	end
	return n
end

function StoryService.ClearShift()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(placed)
	table.clear(foundThisShift)
end

function StoryService.Archive(player: Player)
	local p = PlayerDataService.Get(player)
	if not p then
		return nil
	end
	local docs = {}
	for _, id in Documents.Order do
		local def = Documents.Defs[id]
		local found = p.documents[id] == true
		table.insert(docs, { id = id, title = if found then def.title else "???", kind = def.kind, author = if found then def.author else "—", chapter = def.chapter, found = found, body = if found then (if def.secret then string.format(def.body, "****") else def.body) else "Документ ещё не найден." })
	end
	local count = PlayerDataService.CountDocuments(p)
	local chapters = {}
	for _, ch in Chapters.List do
		table.insert(chapters, { index = ch.index, title = ch.title, summary = ch.summary, unlocked = p.chaptersUnlocked[ch.index] == true, available = #ch.shifts > 0, requires = ch.unlockRequires })
	end
	local lore = {}
	for _, l in Documents.Lore do
		table.insert(lore, { title = l.title, text = if count >= l.threshold then l.text else string.format("Откроется после %d документов.", l.threshold), unlocked = count >= l.threshold })
	end
	return { documentCount = count, documents = docs, chapters = chapters, creatures = lore, stats = p.stats, history = p.shiftHistory }
end

function StoryService.Init()
	Net.func("GetArchive").OnServerInvoke = function(player)
		if not limiter:allow(player) then
			return nil
		end
		return StoryService.Archive(player)
	end
	Net.func("ReadDocument").OnServerInvoke = function(player, docId)
		if not limiter:allow(player) or not Net.isString(docId, 48) then
			return Net.fail("bad args")
		end
		return if StoryService.Read(player, docId) then Net.ok() else Net.fail("Документ недоступен")
	end
end

function StoryService.Start() end

return StoryService
