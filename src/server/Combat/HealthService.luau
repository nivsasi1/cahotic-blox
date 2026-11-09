--!strict
-- Duel health for each player. It's mirrored to Player attributes (HP, MaxHP, Downed, Protected)
-- so every client can draw it and only the server can change it.
-- Humanoid.Health stays out of it: a Humanoid at 0 is dead for good, and a knockdown comes back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Config = require(ReplicatedStorage.Shared.Config)
local Vitals = require(script.Parent.Vitals)

type Entry = { vitals: Vitals.Vitals, standing: CFrame? }

local entries: { [Player]: Entry } = {}

local HealthService = {}

local function settings(): Vitals.Settings
	return {
		maxHp = Config.DUEL_HEALTH,
		downTime = Config.KNOCKDOWN_TIME,
		refillTime = Config.REGEN_TIME,
		protectTime = Config.GETUP_PROTECTION,
	}
end

-- Attributes only replicate when they change, and HP is rounded so the refill doesn't spam
local function mirror(player: Player, vitals: Vitals.Vitals)
	player:SetAttribute("HP", math.ceil(vitals.hp))
	player:SetAttribute("Downed", vitals:isDown())
	player:SetAttribute("Protected", vitals:isProtected())
end

local function setShield(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local shield = character:FindFirstChild("GetUpShield")
	if on and not shield then
		local field = Instance.new("ForceField")
		field.Name = "GetUpShield"
		field.Parent = character
	elseif not on and shield then
		shield:Destroy()
	end
end

-- Anchored and on its back, which works for any rig. A client can't move an anchored part.
local function layDown(player: Player, entry: Entry)
	local root = Characters.rootPart(player)
	local character = player.Character
	if not root or not character then
		return
	end
	entry.standing = root.CFrame

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local below = workspace:Raycast(root.Position, Vector3.yAxis * -50, params)
	local floorY = if below then below.Position.Y else root.Position.Y - 3

	root.Anchored = true
	root.CFrame = CFrame.new(root.Position.X, floorY + root.Size.Z, root.Position.Z)
		* root.CFrame.Rotation
		* CFrame.Angles(math.rad(90), 0, 0)
end

local function standUp(player: Player, entry: Entry)
	local root = Characters.rootPart(player)
	if root and entry.standing then
		root.CFrame = entry.standing
	end
	entry.standing = nil
	Characters.setFrozen(player, false)
	setShield(player, true)
end

function HealthService.reset(player: Player)
	entries[player] = { vitals = Vitals.new(settings()) }
	player:SetAttribute("MaxHP", Config.DUEL_HEALTH)
	mirror(player, entries[player].vitals)
end

-- Stops tracking, for when the duel ends. The duel puts the player back where it wants them.
function HealthService.clear(player: Player)
	entries[player] = nil
	setShield(player, false)
	for _, name in { "HP", "MaxHP", "Downed", "Protected" } do
		player:SetAttribute(name, nil)
	end
end

function HealthService.isDown(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.vitals:isDown()
end

-- Returns "ignored", "hit" or "down"
function HealthService.hit(player: Player, share: number): string
	local entry = entries[player]
	if not entry then
		return "ignored"
	end
	local result = entry.vitals:hit(share)
	if result == "down" then
		layDown(player, entry)
	end
	mirror(player, entry.vitals)
	return result
end

function HealthService.start()
	RunService.Heartbeat:Connect(function()
		for player, entry in entries do
			if entry.vitals:update() == "up" then
				standUp(player, entry)
			end
			if not entry.vitals:isProtected() then
				setShield(player, false)
			end
			mirror(player, entry.vitals)
		end
	end)
end

return HealthService
