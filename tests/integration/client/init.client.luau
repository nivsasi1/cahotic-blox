-- The hands of the integration test: does what the server harness asks and reports back
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local invites = script.Parent:WaitForChild("Client"):WaitForChild("Invites")

local InvitePopup = require(invites:WaitForChild("InvitePopup"))
local InviteWindow = require(invites:WaitForChild("InviteWindow"))
local PlayerPicker = require(invites:WaitForChild("PlayerPicker"))
local Blaster = require(script.Parent:WaitForChild("Client"):WaitForChild("Combat"):WaitForChild("Blaster"))

local bus = ReplicatedStorage:WaitForChild("TestBus") :: RemoteFunction
local blasterFire = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BlasterFire") :: RemoteEvent

local function inside(gui: GuiObject): boolean
	local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	return position.X >= 0 and position.Y >= 0 and position.X + size.X <= viewport.X and position.Y + size.Y <= viewport.Y
end

local function big(): string
	return (playerGui :: any).DuelHud.Big.Text
end

local commands = {}

function commands.pick(target: Player)
	local camera = workspace.CurrentCamera :: Camera
	local targetRoot = (target.Character :: any).HumanoidRootPart
	local mine = (localPlayer.Character :: any).HumanoidRootPart.Position
	local offset = (mine - targetRoot.Position).Unit * 12 + Vector3.yAxis * 2
	local before = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(targetRoot.Position + offset, targetRoot.Position)
	RunService.RenderStepped:Wait()
	local viewport = camera.ViewportSize
	local picked = PlayerPicker.playerOnRay(camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2))
	camera.CameraType = before
	return picked and picked.Name
end

function commands.open(target: Player)
	InviteWindow.open(target)
	task.wait(0.5)
	local panel = (playerGui :: any).InviteWindow.Panel
	return { inside = inside(panel), text = panel.Title.Text }
end

function commands.submit()
	InviteWindow.submit()
	task.wait(0.3)
end

function commands.invite(target: Player)
	local result = commands.open(target)
	commands.submit()
	return result
end

function commands.waitPopup()
	local deadline = os.clock() + 5
	while not InvitePopup.isOpen() and os.clock() < deadline do
		task.wait(0.05)
	end
	task.wait(0.5)
	local panel = (playerGui :: any).InvitePopup.Panel
	return { open = InvitePopup.isOpen(), inside = inside(panel), title = panel.Title.Text }
end

function commands.answer(accepted: boolean)
	InvitePopup.respond(accepted)
end

function commands.windowOpen()
	return InviteWindow.isOpen()
end

function commands.windowTitle()
	return (playerGui :: any).InviteWindow.Panel.Title.Text
end

function commands.toast()
	return (playerGui :: any).Toast.Message.Text
end

function commands.big()
	return big()
end

function commands.moveTo(position: Vector3)
	local humanoid = (localPlayer.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:MoveTo(position)
end

function commands.teleportTo(point: Vector3)
	local character = localPlayer.Character :: Model
	character:PivotTo(CFrame.new(point))
	task.wait(0.2)
end

function commands.topDown(center: Vector3)
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 170, 0.01), center)
	task.wait(0.3)
end

function commands.restoreCamera()
	local camera = workspace.CurrentCamera :: Camera
	local character = localPlayer.Character :: Model
	local root = (character :: any).HumanoidRootPart :: BasePart
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
	local forward = root.CFrame.LookVector
	camera.CFrame = CFrame.lookAt(root.Position - forward * 16 + Vector3.yAxis * 7, root.Position + forward * 12)
	task.wait(0.2)
end

function commands.animating()
	local humanoid = (localPlayer.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	return animator ~= nil and #animator:GetPlayingAnimationTracks() > 0
end

function commands.status()
	local character = localPlayer.Character :: Model
	return {
		character = character.Name,
		cameraOnHumanoid = (workspace.CurrentCamera :: Camera).CameraSubject == character:FindFirstChildOfClass("Humanoid"),
		hasAnimate = character:FindFirstChild("Animate") ~= nil,
		big = big(),
	}
end

-- The file lands in Roblox's capture folder, run.ps1 collects it after the test
function commands.capture()
	local done = false
	game:GetService("CaptureService"):CaptureScreenshot(function()
		done = true
	end)
	local deadline = os.clock() + 6
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	return done
end

function commands.fireAt(point: Vector3)
	return Blaster.fireAt(point)
end

-- Takes the picture a moment after firing, while the tracer is still in the air
function commands.fireAndCapture(point: Vector3)
	Blaster.fireAt(point)
	return commands.capture()
end

-- Straight to the server, skipping every check the client does
function commands.rawFire(value: any, count: number?)
	for _ = 1, count or 1 do
		blasterFire:FireServer(value)
	end
end

function commands.hud()
	local hud = (playerGui :: any).CombatHud
	return {
		crosshair = hud.Crosshair.Visible,
		vitals = hud.Vitals.Visible,
		mine = hud.Vitals.Mine.Value.Text,
		theirs = hud.Vitals.Theirs.Value.Text,
		downed = hud.Downed.Visible,
		downedText = hud.Downed.Sub.Text,
		banner = if hud.Banner.Visible then hud.Banner.Text else "",
		hitMarker = hud.HitMarker.Visible,
		hitMarkerColor = hud.HitMarker:GetChildren()[1].BackgroundColor3,
	}
end

function commands.shoulder()
	local UserInputService = game:GetService("UserInputService")
	return {
		mouse = UserInputService.MouseEnabled,
		locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter,
	}
end

function commands.canMove()
	local character = localPlayer.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local start = (character :: any).HumanoidRootPart.Position
	humanoid:MoveTo(start + Vector3.new(8, 0, 0))
	task.wait(1.5)
	return ((character :: any).HumanoidRootPart.Position - start).Magnitude > 3
end

bus.OnClientInvoke = function(command: string, ...: any)
	return (commands :: any)[command](...)
end
