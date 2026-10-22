--!nonstrict
-- Spectator: after elimination the camera follows a living teammate in
-- first person. No extra information is revealed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SpectatorController = {}
local target: Player? = nil
local banner: ScreenGui? = nil

local function follow(p: Player?)
	target = p
	if banner then
		banner:Destroy()
		banner = nil
	end
	if not p or not p.Character then
		camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = hum
	end
	banner = Theme.screen("NS_Spectate", 30)
	local f = Theme.frame(banner, { Position = UDim2.new(0.5, 0, 0, 60), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 360, 0, 50), BackgroundColor3 = Theme.Colors.Bg, BackgroundTransparency = 0.3 })
	Theme.stroke(f)
	Theme.corner(f)
	Theme.label(f, "НАБЛЮДЕНИЕ: " .. p.DisplayName, 14, { Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.new(1, 0, 0, 26) })
	Theme.button(f, "СЛЕДУЮЩИЙ", function()
		local list = {}
		for _, o in Players:GetPlayers() do
			if o ~= player and o.Character and (o.Character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health > 0 then
				table.insert(list, o)
			end
		end
		if #list == 0 then
			return
		end
		local idx = (table.find(list, target) or 0) % #list + 1
		follow(list[idx])
	end, { Position = UDim2.new(0.5, 0, 1, -22), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 140, 0, 20), TextSize = 11 })
end

function SpectatorController.init()
	Net.event("SpectateTarget").OnClientEvent:Connect(follow)
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase == "Idle" or st.phase == "Results" then
			follow(nil)
		end
	end)
	player.CharacterAdded:Connect(function()
		follow(nil)
	end)
end

return SpectatorController
