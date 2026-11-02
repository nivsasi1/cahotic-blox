--!strict
-- The window that opens at the top of the screen after you click a player
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Toast = require(script.Parent.Parent.Common.Toast)
local Ui = require(script.Parent.Parent.Common.Ui)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local HIDDEN = UDim2.new(0.5, 0, 0, -130)
local SHOWN = UDim2.new(0.5, 0, 0, 12)

local gui = Ui.screen("InviteWindow", 5)

local panel = Ui.panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = HIDDEN,
	Size = UDim2.fromOffset(420, 100),
	Visible = false,
	Parent = gui,
})
local avatar = Ui.avatar({ Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(68, 68), Parent = panel })
local title = Ui.label({
	Name = "Title",
	Position = UDim2.fromOffset(96, 14),
	Size = UDim2.fromOffset(280, 28),
	TextSize = 20,
	Parent = panel,
})
local subtitle = Ui.label({
	Name = "Subtitle",
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(96, 48),
	Size = UDim2.fromOffset(190, 36),
	TextColor3 = Ui.colors.muted,
	TextSize = 14,
	TextTruncate = Enum.TextTruncate.None,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = panel,
})
local action = Ui.button({
	Name = "Action",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -14),
	Size = UDim2.fromOffset(112, 40),
	Text = "Invite",
	Parent = panel,
})
local closeButton = Ui.button({
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Ui.colors.quiet,
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(28, 28),
	Text = "X",
	TextColor3 = Ui.colors.text,
	TextSize = 14,
	Parent = panel,
})
local timer = Ui.timerBar(panel)
timer.Visible = false

local InviteWindow = {}

type State = "closed" | "pick" | "sending" | "waiting"

local state: State = "closed"
local target: Player? = nil
local timerTween: Tween? = nil

local function stopTimer()
	if timerTween then
		timerTween:Cancel()
		timerTween = nil
	end
	timer.Visible = false
end

local function hide()
	state = "closed"
	target = nil
	stopTimer()
	Ui.tween(panel, 0.2, { Position = HIDDEN }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
		if state == "closed" then
			panel.Visible = false
		end
	end)
end

function InviteWindow.isOpen(): boolean
	return state ~= "closed"
end

-- Waiting on an answer locks the picker, picking a different player is still fine
function InviteWindow.isLocked(): boolean
	return state == "sending" or state == "waiting"
end

function InviteWindow.open(player: Player)
	if InviteWindow.isLocked() then
		return
	end
	target = player
	state = "pick"
	Ui.setAvatar(avatar, player)
	title.Text = `Duel {player.DisplayName}?`
	subtitle.Text = "Send them a duel invite"
	action.Text = "Invite"
	action.BackgroundColor3 = Ui.colors.accent
	action.TextColor3 = Ui.colors.onAccent
	panel.Visible = true
	Ui.tween(panel, 0.3, { Position = SHOWN }, Enum.EasingStyle.Back)
end

function InviteWindow.close()
	if state == "pick" then
		hide()
	elseif state == "waiting" then
		remotes:WaitForChild("InviteCancel"):FireServer()
	end
end

function InviteWindow.submit()
	if state == "pick" and target then
		state = "sending"
		subtitle.Text = "Sending..."
		remotes:WaitForChild("InviteSend"):FireServer(target)
	elseif state == "waiting" then
		remotes:WaitForChild("InviteCancel"):FireServer()
	end
end

local function showWaiting(player: Player)
	state = "waiting"
	title.Text = `Waiting for {player.DisplayName}`
	subtitle.Text = "They have a moment to answer"
	action.Text = "Cancel"
	action.BackgroundColor3 = Ui.colors.danger
	action.TextColor3 = Ui.colors.text
	timer.Visible = true
	timerTween = Ui.drainTimer(timer, Config.INVITE_TIMEOUT)
end

function InviteWindow.onState(payload: { [string]: any })
	if payload.kind == "sent" and state == "sending" and target then
		showWaiting(target)
	elseif payload.kind == "rejected" then
		if state == "sending" then
			hide()
		end
		Toast.show(payload.reason)
	elseif payload.kind == "closed" and state == "waiting" then
		hide()
		if payload.reason ~= "accepted" then
			Toast.show(payload.reason)
		end
	end
end

action.Activated:Connect(InviteWindow.submit)
closeButton.Activated:Connect(InviteWindow.close)

return InviteWindow
