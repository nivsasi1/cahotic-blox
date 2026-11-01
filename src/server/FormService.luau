--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local forms = ServerStorage:WaitForChild("Forms")

local FormService = {}

local function formNames(): { string }
	local names = {}
	for _, form in forms:GetChildren() do
		if form:IsA("Model") then
			table.insert(names, form.Name)
		end
	end
	return names
end

local function buildPlaceholder(spec: typeof(Config.PLACEHOLDER_FORMS[1]))
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = spec.color
	description.TorsoColor = spec.color
	description.LeftArmColor = spec.color
	description.RightArmColor = spec.color
	description.LeftLegColor = spec.color
	description.RightLegColor = spec.color
	description.HeightScale = spec.height
	description.WidthScale = spec.width
	description.DepthScale = spec.width
	description.HeadScale = spec.head

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok then
		rig.Name = spec.name
		rig.Parent = forms
	else
		warn(`Could not build placeholder form {spec.name}: {rig}`)
	end
end

function FormService.start()
	if #formNames() == 0 then
		for _, spec in Config.PLACEHOLDER_FORMS do
			task.spawn(buildPlaceholder, spec)
		end
	end
end

-- Two different forms when we have them, so the players never look the same
function FormService.pickPair(): (string?, string?)
	local names = formNames()
	if #names == 0 then
		return nil, nil
	end
	local first = math.random(#names)
	if #names == 1 then
		return names[1], names[1]
	end
	local second = math.random(#names - 1)
	if second >= first then
		second += 1
	end
	return names[first], names[second]
end

-- Swaps the whole character, the same way a friend's rigged monster will go in.
-- With no form available the player keeps their avatar, so a duel can still run.
function FormService.apply(player: Player, formName: string?, frame: CFrame)
	local old = player.Character
	local template = formName and forms:FindFirstChild(formName)
	if not template or not template:IsA("Model") then
		if old then
			old:PivotTo(frame + Vector3.yAxis * 3)
		end
		return
	end

	local rig = template:Clone()
	rig.Name = player.Name

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = `{player.DisplayName} ({formName})`
	end

	-- Scripts from StarterCharacterScripts don't get added when we set Character ourselves
	local animate = old and old:FindFirstChild("Animate")
	if animate and not rig:FindFirstChild("Animate") then
		animate:Clone().Parent = rig
	end

	rig:PivotTo(frame + Vector3.yAxis * rig:GetExtentsSize().Y / 2)
	player.Character = rig
	rig.Parent = workspace
	if old then
		old:Destroy()
	end
end

return FormService
