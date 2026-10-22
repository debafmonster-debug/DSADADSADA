--!nonstrict
-- Client entry point. Controllers are plain modules with init(); each is
-- isolated by pcall so one failure never takes the whole interface down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage.Shared.Utilities.Net)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local Controllers = script.Parent:WaitForChild("Controllers")
local order = {
	"SettingsStore",
	"CameraController",
	"FlashlightController",
	"ViewmodelController",
	"InteractionController",
	"HUDController",
	"LobbyUIController",
	"MenuController",
	"AudioController",
	"SpectatorController",
	"ToolViewController",
	"WorldFXController",
	"WeatherController",
	"TemperatureFXController",
	"RadioUIController",
	"KeypadUIController",
	"HallucinationController",
	"CinematicController",
}

for _, name in order do
	local ok, err = pcall(function()
		local mod = require(Controllers:WaitForChild(name))
		if mod.init then
			mod.init()
		end
	end)
	if not ok then
		warn(string.format("[Vostok9Client] %s failed: %s", name, tostring(err)))
	end
end

Net.event("ClientReady"):FireServer()
