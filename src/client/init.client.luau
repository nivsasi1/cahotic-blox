--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DuelHud = require(script.DuelHud)
local InvitePopup = require(script.InvitePopup)
local InviteWindow = require(script.InviteWindow)
local PlayerPicker = require(script.PlayerPicker)
local Ui = require(script.Ui)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

remotes:WaitForChild("InviteState").OnClientEvent:Connect(function(payload)
	InviteWindow.onState(payload)
	InvitePopup.onState(payload)
end)
remotes:WaitForChild("DuelState").OnClientEvent:Connect(DuelHud.onState)

local function canPick(): boolean
	return not DuelHud.isActive() and not InviteWindow.isLocked() and not InvitePopup.isOpen()
end

PlayerPicker.start(canPick, InviteWindow.open)

-- The camera keeps following the old body after a form swap unless we point it at the new one
Players.LocalPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local camera = workspace.CurrentCamera
	if humanoid and camera then
		camera.CameraSubject = humanoid
	end
end)

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

game:GetService("RunService").Heartbeat:Connect(function()
	hint.Visible = not DuelHud.isActive() and #Players:GetPlayers() > 1
end)
