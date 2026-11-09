--!strict
-- Over-the-shoulder camera for the live duel, like most shooters: the mouse is locked to the
-- crosshair, the camera sits off to the right, and the body turns with the camera.
-- Phones keep the normal camera, they aim by dragging and fire with the FIRE button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Characters = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"))

local localPlayer = Players.LocalPlayer

local STEP = "ShoulderCamera"
local OFFSET = Vector3.new(2, 0.6, 0) -- right of and a bit above the head
local ZOOM = { min = 6, max = 14 } -- far enough to see the body, close enough to aim

local ShoulderCamera = {}

local on = false
local savedZoom = { min = 0.5, max = 128 }
local turn: AlignOrientation? = nil

local function humanoid(): Humanoid?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Turns the body with a constraint instead of writing its CFrame every frame. CFrame writes act
-- like tiny teleports, which stopped walking and cube touches. Does nothing while anchored, so
-- the server's frozen and knocked down poses win.
local function makeTurn(root: BasePart): AlignOrientation
	local attachment = Instance.new("Attachment")
	attachment.Name = "ShoulderTurnAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "ShoulderTurn"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	return align
end

-- Runs right after Roblox's own camera, so our mouse lock wins every frame
local function step()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local camera = workspace.CurrentCamera
	if turn and camera then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			turn.CFrame = CFrame.lookAt(Vector3.zero, flat)
		end
	end
end

local function enable()
	if on or not UserInputService.MouseEnabled then
		return
	end
	on = true
	local body = humanoid()
	if body then
		body.AutoRotate = false
		body.CameraOffset = OFFSET
	end
	local root = Characters.rootPart(localPlayer)
	turn = if root then makeTurn(root) else nil
	savedZoom = { min = localPlayer.CameraMinZoomDistance, max = localPlayer.CameraMaxZoomDistance }
	localPlayer.CameraMinZoomDistance = ZOOM.min
	localPlayer.CameraMaxZoomDistance = ZOOM.max
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, step)
end

local function disable()
	if not on then
		return
	end
	on = false
	RunService:UnbindFromRenderStep(STEP)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	if turn then
		local attachment = turn.Attachment0
		turn:Destroy()
		if attachment then
			attachment:Destroy()
		end
		turn = nil
	end
	local body = humanoid()
	if body then
		body.AutoRotate = true
		body.CameraOffset = Vector3.zero
	end
	localPlayer.CameraMinZoomDistance = savedZoom.min
	localPlayer.CameraMaxZoomDistance = savedZoom.max
end

function ShoulderCamera.onState(payload: { [string]: any })
	if payload.phase == "live" then
		enable()
	else
		disable()
	end
end

return ShoulderCamera
