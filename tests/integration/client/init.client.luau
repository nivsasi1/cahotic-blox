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

local bus = ReplicatedStorage:WaitForChild("TestBus") :: RemoteFunction

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
