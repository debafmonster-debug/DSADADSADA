--!nonstrict
-- Client entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Net = require(ReplicatedStorage.Shared.Utilities.Net)

-- Hide default Roblox UI that clashes with the custom HUD.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local Controllers = script.Parent.Controllers
local order = {
	"SettingsStore",
	"CameraController",
	"InteractionController",
	"HUDController",
	"LobbyUIController",
	"MenuController",
	"AudioController",
	"SpectatorController",
	"ToolViewController",
}

for _, name in order do
	local ok, err = pcall(function()
		local mod = require(Controllers:WaitForChild(name))
		if mod.init then
			mod.init()
		end
	end)
	if not ok then
		warn(string.format("[NightShift] controller %s failed: %s", name, tostring(err)))
	end
end

Net.event("ClientReady"):FireServer()
print("[NightShift] client ready")
