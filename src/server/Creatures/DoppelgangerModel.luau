--!nonstrict
-- Doppelgänger body: a copy of a real participant's appearance that walks,
-- scans and waits. It carries no server-visible tag that clients could read;
-- IdentityService keeps the truth in a server-only table.
local Players = game:GetService("Players")

local DoppelgangerModel = {}

export type Body = { model: Model, humanoid: Humanoid, root: BasePart, ownerUserId: number }

local function strip(model: Model)
	for _, inst in model:GetDescendants() do
		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") or inst:IsA("Tool") or inst:IsA("ProximityPrompt") or inst:IsA("Light") or inst:IsA("Sound") or inst:IsA("ForceField") then
			inst:Destroy()
		end
	end
end

local function fromCharacter(player: Player): Model?
	local char = player.Character
	if not char then
		return nil
	end
	local wasArchivable = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(function()
		return char:Clone()
	end)
	char.Archivable = wasArchivable
	if ok and clone then
		return clone
	end
	return nil
end

local function fromUserId(userId: number): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	return if ok then model else nil
end

function DoppelgangerModel.build(player: Player, parent: Instance, cframe: CFrame): Body?
	local model = fromCharacter(player) or fromUserId(player.UserId)
	if not model then
		return nil
	end
	strip(model)
	model.Name = player.Name
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		model:Destroy()
		return nil
	end
	hum.DisplayName = player.DisplayName
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = 10.5
	hum.JumpPower = 0
	hum.AutoRotate = true
	hum.BreakJointsOnDeath = false
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = p.Name == "HumanoidRootPart"
		end
	end
	model:PivotTo(cframe)
	model.Parent = parent
	return { model = model, humanoid = hum, root = root, ownerUserId = player.UserId }
end

return DoppelgangerModel
