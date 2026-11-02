--!strict
-- The line at the bottom of the screen that tells you what to do in the hub
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Parent.Common.Ui)

local HubHint = {}

function HubHint.start(isInDuel: () -> boolean)
	local hint = Ui.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(360, 24),
		Text = "Walk up to a player and click them to duel",
		TextSize = 15,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = Ui.screen("HubHint", 1),
	})

	RunService.Heartbeat:Connect(function()
		hint.Visible = not isInDuel() and #Players:GetPlayers() > 1
	end)
end

return HubHint
