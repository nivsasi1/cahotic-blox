--!strict
-- Everything on screen during a duel: fades, countdown, goal, result
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Common.Ui)

local localPlayer = Players.LocalPlayer

local gui = Ui.screen("DuelHud", 10)
gui.IgnoreGuiInset = true

local fade = Ui.make("Frame", {
	Name = "Fade",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 5,
	Parent = gui,
})
local big = Ui.label({
	Name = "Big",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(1, -32, 0, 120),
	Text = "",
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 3,
	Parent = gui,
})
Ui.make("UIStroke", { Color = Ui.colors.panel, Thickness = 4, Parent = big })
Ui.make("UITextSizeConstraint", { MaxTextSize = 96, Parent = big })

local goal = Ui.panel({
	Name = "Goal",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(420, 64),
	Visible = false,
	ZIndex = 2,
	Parent = gui,
})
local goalText = Ui.label({
	Name = "Text",
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 2,
	Parent = goal,
})
local goalSub = Ui.label({
	Name = "Sub",
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(16, 34),
	Size = UDim2.new(1, -32, 0, 22),
	TextColor3 = Ui.colors.muted,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 2,
	Parent = goal,
})

local DuelHud = {}

local active = false
local step = 0 -- bumped on every phase, so old timers know to stop

local function setResetAllowed(allowed: boolean)
	-- Fails if the core UI hasn't loaded yet. Dying mid-duel is handled on the server anyway.
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", allowed)
	end)
end

local function pop(text: string, color: Color3?)
	big.Text = text
	big.TextColor3 = color or Ui.colors.text
	big.Rotation = -4
	Ui.tween(big, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
end

-- Players land facing the cube, but the camera still points wherever it did in the hub
local function lookWhereFacing()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if root and root:IsA("BasePart") and camera then
		local forward = root.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(root.Position - forward * 16 + Vector3.yAxis * 7, root.Position + forward * 12)
	end
end

function DuelHud.isActive(): boolean
	return active
end

local function resultText(payload: { [string]: any }): (string, Color3, string)
	if payload.winner == localPlayer then
		return "YOU WIN", Ui.colors.accent, "+1 win"
	elseif payload.winner then
		return "YOU LOST", Ui.colors.danger, `{payload.winner.DisplayName} got there first`
	elseif payload.reason == "timeout" then
		return "TIME UP", Ui.colors.text, "Nobody reached the cube"
	elseif payload.reason == "left" then
		return "DUEL OVER", Ui.colors.text, "Your opponent left"
	end
	return "DUEL OVER", Ui.colors.text, "The duel was cancelled"
end

function DuelHud.onState(payload: { [string]: any })
	step += 1
	local mine = step

	if payload.phase == "starting" then
		active = true
		setResetAllowed(false)
		Ui.tween(fade, Config.FADE_TIME, { BackgroundTransparency = 0 })
	elseif payload.phase == "countdown" then
		goalText.Text = `You are {payload.form or "yourself"}`
		goalSub.Text = `vs {payload.opponent.DisplayName}`
		goal.Visible = true
		Ui.tween(fade, Config.FADE_TIME, { BackgroundTransparency = 1 })
		task.spawn(function()
			task.wait() -- the camera needs a frame to pick up the new body
			lookWhereFacing()
			for remaining = payload.seconds, 1, -1 do
				if mine ~= step then
					return
				end
				pop(tostring(remaining))
				task.wait(1)
			end
		end)
	elseif payload.phase == "live" then
		pop("GO!", Ui.colors.accent)
		goalText.Text = "Touch the black cube first!"
		task.delay(0.8, function()
			if mine == step then
				big.Text = ""
			end
		end)
		task.spawn(function()
			for remaining = payload.seconds, 0, -1 do
				if mine ~= step then
					return
				end
				goalSub.Text = `{remaining}s left`
				task.wait(1)
			end
		end)
	elseif payload.phase == "result" then
		local text, color, detail = resultText(payload)
		pop(text, color)
		goalText.Text = "Back to the hub soon"
		goalSub.Text = detail
	elseif payload.phase == "returning" then
		Ui.tween(fade, Config.FADE_TIME, { BackgroundTransparency = 0 })
	elseif payload.phase == "ended" then
		active = false
		big.Text = ""
		goal.Visible = false
		setResetAllowed(true)
		Ui.tween(fade, Config.FADE_TIME, { BackgroundTransparency = 1 })
	end
end

return DuelHud
