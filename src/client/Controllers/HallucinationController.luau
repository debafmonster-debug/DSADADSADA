--!nonstrict
-- Local-only perception tricks: distance disorientation stages (thicker fog,
-- a figure that stands far off and is gone when approached, a false station
-- light), the mirror reflection beat, and the blackout cut. Nothing here
-- touches server state or other players' worlds.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Utilities.Builder)
local Net = require(ReplicatedStorage.Shared.Utilities.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local WeatherController = require(script.Parent.WeatherController)
local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)

local camera = workspace.CurrentCamera

local HallucinationController = {}

local stage = 0
local figure: Model? = nil
local figureUntil = 0
local falseLight: Part? = nil
local fade: Frame? = nil

local function buildFigure(cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "FogFigure"
	local function p(name, size, off)
		local part = Builder.part({ name = name, size = size, cframe = cf * off, material = Enum.Material.Fabric, color = Color3.fromRGB(24, 26, 30), parent = m, canCollide = false })
		part.CanQuery = false
		part.CastShadow = false
		return part
	end
	p("Torso", Vector3.new(2.2, 4.4, 1.2), CFrame.new(0, 4.6, 0))
	p("Head", Vector3.new(1.2, 1.5, 1.2), CFrame.new(0, 7.6, 0))
	p("LegL", Vector3.new(0.8, 3.2, 0.8), CFrame.new(-0.6, 1.6, 0))
	p("LegR", Vector3.new(0.8, 3.2, 0.8), CFrame.new(0.6, 1.6, 0))
	m.Parent = camera
	return m
end

local function clearFigure()
	if figure then
		figure:Destroy()
		figure = nil
	end
end

local function spawnFigure()
	clearFigure()
	local char = game:GetService("Players").LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local dir = (camera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local side = CFrame.Angles(0, (math.random() - 0.5) * 0.8, 0)
	local pos = hrp.Position + side:VectorToWorldSpace(dir) * (WeatherController.Visibility * 0.6)
	figure = buildFigure(CFrame.lookAt(Vector3.new(pos.X, hrp.Position.Y - 3, pos.Z), Vector3.new(hrp.Position.X, hrp.Position.Y - 3, hrp.Position.Z)))
	figureUntil = os.clock() + 4 + math.random() * 4
end

local function setFalseLight(on: boolean)
	if on and not falseLight then
		local char = game:GetService("Players").LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		-- A warm "station" light in the wrong direction, far in the fog.
		local dir = (-camera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		local pos = hrp.Position + dir * (WeatherController.Visibility * 0.9) + Vector3.new(0, 6, 0)
		falseLight = Builder.part({ name = "FalseLight", size = Vector3.new(1, 1, 1), cframe = CFrame.new(pos), material = Enum.Material.Neon, color = Builder.Palette.LightWarmOld, parent = camera, canCollide = false })
		falseLight.CanQuery = false
		Builder.pointLight(falseLight, Builder.Palette.LightWarmOld, 40, 1.5)
	elseif not on and falseLight then
		falseLight:Destroy()
		falseLight = nil
	end
end

local function applyStage(s: number)
	if s == stage then
		return
	end
	stage = s
	WeatherController.SetExtraFog(if s >= 2 then 0.8 elseif s == 1 then 0.4 else 0)
	AudioController.SetMuffle(if s >= 1 then 0.4 else 0)
	if s == 0 then
		clearFigure()
		setFalseLight(false)
		HUDController.Subtitle("Ориентиры снова различимы.", 3)
	elseif s == 1 then
		HUDController.Subtitle("Ветер гудит сильнее. Станция где-то позади… или нет.", 4)
	elseif s == 2 then
		HUDController.Subtitle("Что-то стоит в тумане.", 3)
		spawnFigure()
		setFalseLight(true)
	end
end

local function reflection()
	-- A figure appears on the nearest mirror plane behind the player for a moment.
	local char = game:GetService("Players").LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local best, bestD = nil, 40
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Mirror") then
			local d = (inst.Position - hrp.Position).Magnitude
			if d < bestD then
				best, bestD = inst, d
			end
		end
	end
	if not best then
		return
	end
	local m = buildFigure(best.CFrame * CFrame.new(0.6, -3.2, 0.25) * CFrame.Angles(0, math.pi, 0))
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.Size = p.Size * 0.5
			p.Transparency = 0.25
		end
	end
	AudioController.Play(require(ReplicatedStorage.Shared.Config.SoundLibrary).Shiver, "Reflection")
	task.delay(0.55, function()
		m:Destroy()
	end)
end

local function blackout()
	if not fade then
		fade = Theme.fade(110)
	end
	Theme.fadeTo(fade, 0, 0.6)
	HUDController.Subtitle("…", 2)
	task.delay(3.5, function()
		if fade then
			Theme.fadeTo(fade, 1, 2.5)
		end
		HUDController.Subtitle("Вы очнулись. Холодно. Станции не видно.", 5)
	end)
end

function HallucinationController.init()
	Net.event("Hallucination").OnClientEvent:Connect(function(h)
		if h.kind == "Stage" then
			applyStage(h.stage or 0)
		elseif h.kind == "Reflection" then
			reflection()
		elseif h.kind == "Blackout" then
			applyStage(0)
			blackout()
		end
	end)
	Net.event("RoundState").OnClientEvent:Connect(function(st)
		if st.phase == "Idle" then
			applyStage(0)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if figure then
			local char = game:GetService("Players").LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local pos = figure:GetPivot().Position
			-- Gone when approached or when its window closes; never persists as evidence.
			if os.clock() > figureUntil or (hrp and (hrp.Position - pos).Magnitude < 18) then
				clearFigure()
				if stage >= 2 and math.random() < 0.5 then
					task.delay(6 + math.random() * 8, function()
						if stage >= 2 then
							spawnFigure()
						end
					end)
				end
			end
		end
	end)
end

return HallucinationController
