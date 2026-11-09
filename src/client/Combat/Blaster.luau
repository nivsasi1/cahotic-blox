--!strict
-- Fires the toy blaster and draws every shot. Your own shots draw straight away so firing feels
-- instant, but only the server decides what got hit.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CombatHud = require(script.Parent.CombatHud)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Parent.Common.Ui)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BlasterFire = remotes:WaitForChild("BlasterFire") :: RemoteEvent
local BlasterShot = remotes:WaitForChild("BlasterShot") :: RemoteEvent

local localPlayer = Players.LocalPlayer
local GLOW = Color3.fromRGB(255, 240, 80)

local gui = Ui.screen("BlasterControls", 9)
local fireButton = Ui.button({
	Name = "FireButton",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -110),
	Size = UDim2.fromOffset(96, 96),
	Text = "FIRE",
	TextSize = 20,
	Visible = false,
	Parent = gui,
})
local round = fireButton:FindFirstChildOfClass("UICorner") :: UICorner
round.CornerRadius = UDim.new(1, 0)

local Blaster = {}

local live = false
local holding = false
local nextShot = 0

local function muzzleOf(player: Player?): Attachment?
	local blaster = player and player.Character and player.Character:FindFirstChild("ToyBlaster")
	local muzzle = blaster and blaster:FindFirstChild("Muzzle", true)
	return if muzzle and muzzle:IsA("Attachment") then muzzle else nil
end

local function skipMe(): RaycastParams
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { localPlayer.Character :: Instance }
	return params
end

-- Whatever is under the crosshair in the middle of the screen
local function aimPoint(): Vector3
	local camera = workspace.CurrentCamera :: Camera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local result = workspace:Raycast(ray.Origin, ray.Direction * (Config.BLASTER_RANGE + 30), skipMe())
	return if result then result.Position else ray.Origin + ray.Direction * Config.BLASTER_RANGE
end

local function effectPart(name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = GLOW
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace
	return part
end

local function drawShot(from: Vector3, to: Vector3, muzzle: Attachment?)
	local length = (to - from).Magnitude
	if length > 0.1 then
		local beam = effectPart("Tracer", Vector3.new(0.14, 0.14, length), CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2))
		Ui.tween(beam, 0.3, { Transparency = 1, Size = Vector3.new(0.03, 0.03, length) })
		Debris:AddItem(beam, 0.35)
	end

	local flash = effectPart("MuzzleFlash", Vector3.one * 0.7, CFrame.new(from))
	flash.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 8
	light.Brightness = 3
	light.Parent = flash
	Debris:AddItem(flash, 0.08)

	local spark = effectPart("Impact", Vector3.one * 0.4, CFrame.new(to))
	spark.Shape = Enum.PartType.Ball
	Debris:AddItem(spark, 0.12)

	Sfx.play("blaster", muzzle)
end

-- Fires at a world point if the blaster is ready. The test calls this directly.
function Blaster.fireAt(point: Vector3): boolean
	local muzzle = muzzleOf(localPlayer)
	if not live or not muzzle or localPlayer:GetAttribute("Downed") == true then
		return false
	end
	local now = os.clock()
	if now < nextShot then
		return false
	end
	local from = muzzle.WorldPosition
	local offset = point - from
	if offset.Magnitude < 0.05 then
		return false
	end
	nextShot = now + Config.BLASTER_COOLDOWN

	-- The same ray the server casts, so the tracer stops where the shot really stops
	local direction = offset.Unit * Config.BLASTER_RANGE
	local result = workspace:Raycast(from, direction, skipMe())
	drawShot(from, if result then result.Position else from + direction, muzzle)
	BlasterFire:FireServer(point)
	return true
end

local function onShot(shot: { [string]: any })
	if shot.shooter ~= localPlayer then
		drawShot(shot.from, shot.to, muzzleOf(shot.shooter))
	elseif shot.part and (shot.result == "hit" or shot.result == "down") then
		CombatHud.hitMarker(shot.part)
		Sfx.play("hitMarker")
	end
end

function Blaster.onState(payload: { [string]: any })
	live = payload.phase == "live"
	if not live then
		holding = false
	end
	fireButton.Visible = live and UserInputService.TouchEnabled
end

-- Hold the mouse (or the FIRE button on a phone) to keep firing at the blaster's own rate
function Blaster.start()
	BlasterShot.OnClientEvent:Connect(onShot)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	fireButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			holding = true
		end
	end)
	fireButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			holding = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if holding and live then
			Blaster.fireAt(aimPoint())
		end
	end)
end

return Blaster
