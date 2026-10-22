--!nonstrict
-- Local settings cache; persisted server-side through SaveSettings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)

local SettingsStore = {}
SettingsStore.Changed = Signal.new()
SettingsStore.Current = {
	musicVolume = 0.7,
	sfxVolume = 0.9,
	ambientVolume = 0.8,
	sensitivity = 0.5,
	textScale = 1,
	cameraShake = 0.6,
	subtitles = true,
	effectsQuality = 2,
	dialogueVolume = 1,
	particles = 2,
	frost = true,
	postFx = 1,
	breath = true,
}

local saveThread: thread? = nil

function SettingsStore.apply(settings: { [string]: any })
	for k, v in settings do
		SettingsStore.Current[k] = v
	end
	SettingsStore.Changed:Fire(SettingsStore.Current)
end

function SettingsStore.set(key: string, value: any)
	SettingsStore.Current[key] = value
	SettingsStore.Changed:Fire(SettingsStore.Current)
	-- Debounced save.
	if saveThread then
		task.cancel(saveThread)
	end
	saveThread = task.delay(1.0, function()
		saveThread = nil
		pcall(function()
			Net.func("SaveSettings"):InvokeServer(SettingsStore.Current)
		end)
	end)
end

function SettingsStore.init()
	Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
		if profile and profile.settings then
			SettingsStore.apply(profile.settings)
		end
	end)
	task.spawn(function()
		local ok, profile = pcall(function()
			return Net.func("GetProfile"):InvokeServer()
		end)
		if ok and profile and profile.settings then
			SettingsStore.apply(profile.settings)
		end
	end)
end

return SettingsStore
