--!strict
-- The toy blaster. Hands one to each duelist and checks every shot on the server:
-- the client only says where it aimed, the server decides what got hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Config = require(ReplicatedStorage.Shared.Config)
local Cooldown = require(script.Parent.Cooldown)
local HealthService = require(script.Parent.HealthService)

local BlasterFire = ReplicatedStorage.Remotes.BlasterFire
local BlasterShot = ReplicatedStorage.Remotes.BlasterShot

local cooldown = Cooldown.new(Config.BLASTER_COOLDOWN - Config.BLASTER_COOLDOWN_SLACK)

-- Set by start(). Returns the opponent when the shooter is in a live duel.
local opponentIfLive: (shooter: Player) -> Player? = function(_shooter: Player): Player?
	return nil
end

local BlasterService = {}

local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false -- shots and clicks go through it
	part.CanTouch = false
	part.Massless = true
	return part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = to
	joint.Part1 = part
	joint.Parent = part
end

-- A chunky orange toy, so nobody mistakes it for a real gun
local function build(hand: BasePart, gripOffset: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "ToyBlaster"

	local body = piece("Body", Vector3.new(0.45, 0.7, 1.5), Color3.fromRGB(255, 140, 40))
	weld(body, hand, gripOffset)
	body.Parent = model

	local barrel = piece("Barrel", Vector3.new(0.3, 0.3, 0.7), Color3.fromRGB(60, 200, 255))
	weld(barrel, body, CFrame.new(0, 0.15, -1.05))
	barrel.Parent = model

	local tip = piece("Tip", Vector3.new(0.34, 0.34, 0.12), Color3.fromRGB(255, 240, 80), Enum.Material.Neon)
	weld(tip, barrel, CFrame.new(0, 0, -0.4))
	tip.Parent = model

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -0.1)
	muzzle.Parent = tip

	model.PrimaryPart = body
	return model
end

-- In the right hand when the form has one, otherwise on the right side of the body
function BlasterService.give(player: Player)
	local character = player.Character
	local root = Characters.rootPart(player)
	if not character or not root or character:FindFirstChild("ToyBlaster") then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local model
	if hand and hand:IsA("BasePart") then
		model = build(hand, CFrame.new(0, -hand.Size.Y / 2, -0.55))
	else
		model = build(root, CFrame.new(root.Size.X / 2 + 0.4, 0, -0.6))
	end
	model.Parent = character
end

function BlasterService.take(player: Player)
	cooldown:clear(player)
	local blaster = player.Character and player.Character:FindFirstChild("ToyBlaster")
	if blaster then
		blaster:Destroy()
	end
end

local function muzzleOf(player: Player): Attachment?
	local blaster = player.Character and player.Character:FindFirstChild("ToyBlaster")
	local muzzle = blaster and blaster:FindFirstChild("Muzzle", true)
	return if muzzle and muzzle:IsA("Attachment") then muzzle else nil
end

local function isAimPoint(value: any): boolean
	-- NaN never equals itself, and a huge number would mean a junk direction
	return typeof(value) == "Vector3" and value == value and value.Magnitude < 1e6
end

local function onFire(shooter: Player, aimPoint: any)
	if not isAimPoint(aimPoint) then
		return
	end
	local opponent = opponentIfLive(shooter)
	local muzzle = muzzleOf(shooter)
	if not opponent or not muzzle or HealthService.isDown(shooter) then
		return
	end
	local from = muzzle.WorldPosition
	local offset = (aimPoint :: Vector3) - from
	if offset.Magnitude < 0.05 or not cooldown:take(shooter) then
		return
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { shooter.Character :: Model }
	local direction = offset.Unit * Config.BLASTER_RANGE
	local result = workspace:Raycast(from, direction, params)

	local shot: { [string]: any } = { shooter = shooter, from = from, to = from + direction }
	if result then
		shot.to = result.Position
		if Characters.playerFromPart(result.Instance) == opponent then
			shot.part = if result.Instance.Name == "Head" then "head" else "body"
			local share = if shot.part == "head" then Config.BLASTER_HEAD_DAMAGE else Config.BLASTER_BODY_DAMAGE
			shot.result = HealthService.hit(opponent, share)
		end
	end

	BlasterShot:FireClient(shooter, shot)
	BlasterShot:FireClient(opponent, shot)
end

-- `opponentOf` comes from DuelService, passed in so the two modules don't require each other
function BlasterService.start(opponentOf: (shooter: Player) -> Player?)
	opponentIfLive = opponentOf
	BlasterFire.OnServerEvent:Connect(onFire)
end

return BlasterService
