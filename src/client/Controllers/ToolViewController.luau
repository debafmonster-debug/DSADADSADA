--!nonstrict
-- First-person tool presentation: holds the tool in view, bobs with
-- movement, plays a use animation + sound on activation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ToolViewController = {}

local currentTool: Tool? = nil
local useT = 0

local function onTool(tool: Tool)
	currentTool = tool
	tool.Activated:Connect(function()
		useT = 0.45
		local handle = tool:FindFirstChild("Handle")
		local s = handle and handle:FindFirstChild("UseSound") :: Sound?
		if s then
			s:Play()
		end
	end)
	tool.Unequipped:Connect(function()
		if currentTool == tool then
			currentTool = nil
		end
	end)
end

function ToolViewController.init()
	local function hook(char: Model)
		char.ChildAdded:Connect(function(ch)
			if ch:IsA("Tool") then
				onTool(ch)
			end
		end)
		-- Auto-equip the shift tool so the viewmodel is visible immediately.
		task.delay(1, function()
			local backpack = player:FindFirstChildOfClass("Backpack")
			local hum = char:FindFirstChildOfClass("Humanoid")
			local tool = backpack and backpack:FindFirstChildOfClass("Tool")
			if tool and hum then
				hum:EquipTool(tool)
			end
		end)
		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			backpack.ChildAdded:Connect(function(ch)
				if ch:IsA("Tool") then
					task.delay(0.2, function()
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum and ch.Parent == backpack then
							hum:EquipTool(ch)
						end
					end)
				end
			end)
		end
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
	RunService.RenderStepped:Connect(function(dt)
		local tool = currentTool
		if not tool or not tool.Parent then
			return
		end
		-- Use animation: dip and rotate the grip briefly.
		if useT > 0 then
			useT = math.max(0, useT - dt)
			local k = math.sin((0.45 - useT) / 0.45 * math.pi)
			tool.Grip = CFrame.new(0, -0.2 - k * 0.25, 0.3 - k * 0.3) * CFrame.Angles(-0.3 - k * 0.5, 0, k * 0.15)
		else
			tool.Grip = CFrame.new(0, -0.2, 0.3) * CFrame.Angles(-0.3, 0, 0)
		end
	end)
end

return ToolViewController
