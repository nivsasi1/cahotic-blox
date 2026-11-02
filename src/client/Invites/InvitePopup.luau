--!strict
-- The popup the invited player gets
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Toast = require(script.Parent.Parent.Common.Toast)
local Ui = require(script.Parent.Parent.Common.Ui)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local HIDDEN = UDim2.new(0.5, 0, 0, -190)
local SHOWN = UDim2.new(0.5, 0, 0, 12)

local gui = Ui.screen("InvitePopup", 7)

local panel = Ui.panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = HIDDEN,
	Size = UDim2.fromOffset(420, 150),
	Visible = false,
	Parent = gui,
})
local avatar = Ui.avatar({ Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(64, 64), Parent = panel })
local title = Ui.label({
	Name = "Title",
	Position = UDim2.fromOffset(92, 16),
	Size = UDim2.fromOffset(314, 30),
	TextSize = 20,
	Parent = panel,
})
Ui.label({
	Name = "Subtitle",
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(92, 48),
	Size = UDim2.fromOffset(314, 22),
	Text = "wants to duel you",
	TextColor3 = Ui.colors.muted,
	TextSize = 15,
	Parent = panel,
})
local accept = Ui.button({
	Name = "Accept",
	Position = UDim2.fromOffset(14, 92),
	Size = UDim2.new(0.5, -20, 0, 42),
	Text = "Accept",
	Parent = panel,
})
local decline = Ui.button({
	Name = "Decline",
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Ui.colors.quiet,
	Position = UDim2.new(1, -14, 0, 92),
	Size = UDim2.new(0.5, -20, 0, 42),
	Text = "Decline",
	TextColor3 = Ui.colors.text,
	Parent = panel,
})
local timer = Ui.timerBar(panel)

local InvitePopup = {}

local open = false
local timerTween: Tween? = nil

local function hide()
	open = false
	if timerTween then
		timerTween:Cancel()
		timerTween = nil
	end
	Ui.tween(panel, 0.2, { Position = HIDDEN }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
		if not open then
			panel.Visible = false
		end
	end)
end

function InvitePopup.isOpen(): boolean
	return open
end

function InvitePopup.respond(accepted: boolean)
	if open then
		hide()
		remotes:WaitForChild("InviteAnswer"):FireServer(accepted)
	end
end

function InvitePopup.onState(payload: { [string]: any })
	if payload.kind == "received" then
		open = true
		Ui.setAvatar(avatar, payload.from)
		title.Text = payload.from.DisplayName
		panel.Visible = true
		Ui.tween(panel, 0.35, { Position = SHOWN }, Enum.EasingStyle.Back)
		timerTween = Ui.drainTimer(timer, Config.INVITE_TIMEOUT)
	elseif payload.kind == "closed" and open then
		hide()
		Toast.show(payload.reason)
	end
end

accept.Activated:Connect(function()
	InvitePopup.respond(true)
end)
decline.Activated:Connect(function()
	InvitePopup.respond(false)
end)

return InvitePopup
