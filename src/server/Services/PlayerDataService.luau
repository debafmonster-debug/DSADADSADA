--!nonstrict
-- Persistent per-player profile with versioning, validation, retry and
-- idempotent reward grants. Server is the only writer.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Documents = require(ReplicatedStorage.Shared.Config.Documents)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)

export type Settings = {
	musicVolume: number,
	sfxVolume: number,
	ambientVolume: number,
	sensitivity: number,
	textScale: number,
	cameraShake: number,
	subtitles: boolean,
	effectsQuality: number,
}

export type Profile = {
	version: number,
	documents: { [string]: boolean },
	chaptersUnlocked: { [number]: boolean },
	shiftHistory: { { missionId: string, success: boolean, reward: number, time: number, seed: number } },
	currency: number,
	cosmetics: { [string]: boolean },
	settings: Settings,
	stats: { shifts: number, successes: number, documentsFound: number, rescues: number },
	selectedTool: string,
	grantTokens: { [string]: number },
	transient: boolean?,
}

local DEFAULT_SETTINGS: Settings = {
	musicVolume = 0.7,
	sfxVolume = 0.9,
	ambientVolume = 0.8,
	sensitivity = 0.5,
	textScale = 1,
	cameraShake = 0.6,
	subtitles = true,
	effectsQuality = 2,
}

local PlayerDataService = {}
PlayerDataService.ProfileChanged = Signal.new() :: Signal.Signal<Player, Profile>

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil
local STORE_NAME = "NightShiftProfiles_v" .. GameConfig.DataVersion
local MAX_HISTORY = 20

local function defaultProfile(): Profile
	return {
		version = GameConfig.DataVersion,
		documents = {},
		chaptersUnlocked = { [1] = true },
		shiftHistory = {},
		currency = 0,
		cosmetics = {},
		settings = table.clone(DEFAULT_SETTINGS),
		stats = { shifts = 0, successes = 0, documentsFound = 0, rescues = 0 },
		selectedTool = "Multimeter",
		grantTokens = {},
	}
end

local function clampNumber(v: any, min: number, max: number, default: number): number
	if typeof(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, min, max)
end

function PlayerDataService.sanitizeSettings(raw: any): Settings
	local s = if typeof(raw) == "table" then raw else {}
	return {
		musicVolume = clampNumber(s.musicVolume, 0, 1, DEFAULT_SETTINGS.musicVolume),
		sfxVolume = clampNumber(s.sfxVolume, 0, 1, DEFAULT_SETTINGS.sfxVolume),
		ambientVolume = clampNumber(s.ambientVolume, 0, 1, DEFAULT_SETTINGS.ambientVolume),
		sensitivity = clampNumber(s.sensitivity, 0.05, 1, DEFAULT_SETTINGS.sensitivity),
		textScale = clampNumber(s.textScale, 0.8, 1.5, DEFAULT_SETTINGS.textScale),
		cameraShake = clampNumber(s.cameraShake, 0, 1, DEFAULT_SETTINGS.cameraShake),
		subtitles = if typeof(s.subtitles) == "boolean" then s.subtitles else DEFAULT_SETTINGS.subtitles,
		effectsQuality = math.floor(clampNumber(s.effectsQuality, 0, 2, DEFAULT_SETTINGS.effectsQuality)),
	}
end

-- Validates loaded data; unknown or corrupt fields fall back to defaults so a
-- bad record can never grant rewards or unlock content.
local function migrate(raw: any): Profile
	local p = defaultProfile()
	if typeof(raw) ~= "table" then
		return p
	end
	if typeof(raw.documents) == "table" then
		for id, v in raw.documents do
			if typeof(id) == "string" and Documents.Defs[id] and v == true then
				p.documents[id] = true
			end
		end
	end
	if typeof(raw.chaptersUnlocked) == "table" then
		for idx, v in raw.chaptersUnlocked do
			local n = tonumber(idx)
			if n and Missions.Chapters[n] and v == true then
				p.chaptersUnlocked[n] = true
			end
		end
	end
	if typeof(raw.shiftHistory) == "table" then
		for _, h in raw.shiftHistory do
			if typeof(h) == "table" and typeof(h.missionId) == "string" and #p.shiftHistory < MAX_HISTORY then
				table.insert(p.shiftHistory, {
					missionId = h.missionId,
					success = h.success == true,
					reward = clampNumber(h.reward, 0, 1e6, 0),
					time = clampNumber(h.time, 0, 1e12, 0),
					seed = clampNumber(h.seed, 0, 2 ^ 32, 0),
				})
			end
		end
	end
	p.currency = math.floor(clampNumber(raw.currency, 0, 1e9, 0))
	if typeof(raw.cosmetics) == "table" then
		for id, v in raw.cosmetics do
			if typeof(id) == "string" and v == true then
				p.cosmetics[id] = true
			end
		end
	end
	p.settings = PlayerDataService.sanitizeSettings(raw.settings)
	if typeof(raw.stats) == "table" then
		for k in p.stats do
			p.stats[k] = math.floor(clampNumber(raw.stats[k], 0, 1e9, 0))
		end
	end
	if typeof(raw.selectedTool) == "string" and Tools.Defs[raw.selectedTool] then
		p.selectedTool = raw.selectedTool
	end
	if typeof(raw.grantTokens) == "table" then
		local count = 0
		for token, t in raw.grantTokens do
			if typeof(token) == "string" and typeof(t) == "number" and count < 200 then
				p.grantTokens[token] = t
				count += 1
			end
		end
	end
	return p
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return result
	end
	warn("[PlayerData] DataStore unavailable: " .. tostring(result))
	return nil
end

local function withRetry<T>(attempts: number, fn: () -> T): (boolean, T?)
	local lastErr
	for i = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(0.5 * i)
	end
	warn("[PlayerData] operation failed: " .. tostring(lastErr))
	return false, nil
end

local function load(player: Player): Profile
	local ds = getStore()
	if not ds then
		local p = defaultProfile()
		p.transient = true
		return p
	end
	local ok, raw = withRetry(3, function()
		return ds:GetAsync("p_" .. player.UserId)
	end)
	if not ok then
		local p = defaultProfile()
		p.transient = true
		return p
	end
	return migrate(raw)
end

local function save(player: Player, profile: Profile): boolean
	if profile.transient then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	local snapshot = table.clone(profile)
	snapshot.transient = nil
	local ok = withRetry(3, function()
		ds:UpdateAsync("p_" .. player.UserId, function(old)
			-- Never regress permanent unlocks if another server wrote meanwhile.
			local merged = snapshot
			if typeof(old) == "table" then
				local oldP = migrate(old)
				for id in oldP.documents do
					merged.documents[id] = true
				end
				for idx in oldP.chaptersUnlocked do
					merged.chaptersUnlocked[idx] = true
				end
			end
			return merged
		end)
	end)
	return ok
end

-- Exposed for headless tests.
PlayerDataService.Migrate = migrate
PlayerDataService.DefaultProfile = defaultProfile

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.WaitFor(player: Player, timeout: number?): Profile?
	local t0 = os.clock()
	while not profiles[player] do
		if os.clock() - t0 > (timeout or 10) or player.Parent == nil then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player]
end

function PlayerDataService.Public(profile: Profile)
	-- What the client is allowed to see (everything but grant tokens).
	local copy = table.clone(profile)
	copy.grantTokens = nil :: any
	return copy
end

function PlayerDataService.Update(player: Player, fn: (Profile) -> ())
	local p = profiles[player]
	if not p then
		return
	end
	fn(p)
	dirty[player] = true
	PlayerDataService.ProfileChanged:Fire(player, p)
	Net.event("ProfileUpdated"):FireClient(player, PlayerDataService.Public(p))
end

function PlayerDataService.AddDocument(player: Player, docId: string): boolean
	local p = profiles[player]
	if not p or not Documents.Defs[docId] or p.documents[docId] then
		return false
	end
	PlayerDataService.Update(player, function(prof)
		prof.documents[docId] = true
		prof.stats.documentsFound += 1
	end)
	PlayerDataService.CheckChapterUnlocks(player)
	return true
end

function PlayerDataService.CountDocuments(p: Profile): number
	local n = 0
	for _ in p.documents do
		n += 1
	end
	return n
end

function PlayerDataService.CheckChapterUnlocks(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local docs = PlayerDataService.CountDocuments(p)
	local completed = {}
	for _, h in p.shiftHistory do
		if h.success then
			local m = Missions.Defs[h.missionId]
			if m then
				completed[m.chapter] = true
			end
		end
	end
	for _, ch in Missions.Chapters do
		if p.chaptersUnlocked[ch.index] then
			continue
		end
		local req = ch.unlockRequires
		if docs >= req.documents and (req.chapter == nil or completed[req.chapter]) and #ch.missions > 0 then
			PlayerDataService.Update(player, function(prof)
				prof.chaptersUnlocked[ch.index] = true
			end)
			Net.event("Notification"):FireClient(player, { title = "Открыта глава", text = ch.title, kind = "story" })
		end
	end
end

-- Idempotent grant: the same token never pays twice (e.g. shift result replays).
function PlayerDataService.GrantCurrency(player: Player, amount: number, token: string): boolean
	local p = profiles[player]
	if not p or p.grantTokens[token] then
		return false
	end
	PlayerDataService.Update(player, function(prof)
		prof.grantTokens[token] = os.time()
		prof.currency = math.max(0, prof.currency + math.floor(amount))
		-- Keep token table bounded.
		local count = 0
		for _ in prof.grantTokens do
			count += 1
		end
		if count > 150 then
			local oldest, oldestT = nil, math.huge
			for t, when in prof.grantTokens do
				if when < oldestT then
					oldest, oldestT = t, when
				end
			end
			if oldest then
				prof.grantTokens[oldest] = nil
			end
		end
	end)
	return true
end

function PlayerDataService.RecordShift(player: Player, entry: { missionId: string, success: boolean, reward: number, seed: number })
	PlayerDataService.Update(player, function(prof)
		table.insert(prof.shiftHistory, 1, { missionId = entry.missionId, success = entry.success, reward = entry.reward, time = os.time(), seed = entry.seed })
		while #prof.shiftHistory > MAX_HISTORY do
			table.remove(prof.shiftHistory)
		end
		prof.stats.shifts += 1
		if entry.success then
			prof.stats.successes += 1
		end
	end)
	PlayerDataService.CheckChapterUnlocks(player)
end

function PlayerDataService.IsMissionAvailable(player: Player, missionId: string): boolean
	local p = profiles[player]
	local m = Missions.Defs[missionId]
	if not p or not m then
		return false
	end
	return p.chaptersUnlocked[m.chapter] == true
end

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if player.Parent == nil then
		return
	end
	profiles[player] = profile
	Net.event("ProfileUpdated"):FireClient(player, PlayerDataService.Public(profile))
	PlayerDataService.ProfileChanged:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local p = profiles[player]
	profiles[player] = nil
	dirty[player] = nil
	if p then
		save(player, p)
	end
end

function PlayerDataService.Init()
	Net.func("GetProfile").OnServerInvoke = function(player)
		local p = PlayerDataService.WaitFor(player, 15)
		return if p then PlayerDataService.Public(p) else nil
	end
	Net.func("SaveSettings").OnServerInvoke = function(player, raw)
		if typeof(raw) ~= "table" then
			return Net.fail("bad settings")
		end
		local clean = PlayerDataService.sanitizeSettings(raw)
		PlayerDataService.Update(player, function(prof)
			prof.settings = clean
		end)
		return Net.ok(clean)
	end
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	task.spawn(function()
		while true do
			task.wait(120)
			for player, isDirty in dirty do
				if isDirty and profiles[player] then
					dirty[player] = false
					save(player, profiles[player])
				end
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player, p in profiles do
			save(player, p)
		end
	end)
end

return PlayerDataService
