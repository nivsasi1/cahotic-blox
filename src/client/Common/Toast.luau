--!strict
local Ui = require(script.Parent.Ui)

local MESSAGES = {
	pending = "You already have an invite open",
	busy = "That player is busy right now",
	cooldown = "Give them a moment before asking again",
	too_far = "Get closer first",
	no_rooms = "All duel rooms are full, try again soon",
	declined = "They said no",
	timeout = "No answer",
	cancelled = "Invite cancelled",
	left = "They left the game",
}

local gui = Ui.screen("Toast", 6)

local label = Ui.label({
	Name = "Message",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Ui.colors.panel,
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, 0, 0, 122),
	Size = UDim2.fromOffset(360, 36),
	TextSize = 16,
	TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = gui,
})
Ui.make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = label })

local Toast = {}

local latest = 0

function Toast.show(reason: string?)
	local text = reason and (MESSAGES :: { [string]: string })[reason]
	if not text then
		return
	end

	latest += 1
	local mine = latest
	label.Text = text
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.1

	task.delay(2.5, function()
		if mine == latest then
			Ui.tween(label, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		end
	end)
end

return Toast
