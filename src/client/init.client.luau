--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DuelCamera = require(script.Duels.DuelCamera)
local DuelHud = require(script.Duels.DuelHud)
local HubHint = require(script.Hub.HubHint)
local InvitePopup = require(script.Invites.InvitePopup)
local InviteWindow = require(script.Invites.InviteWindow)
local PlayerPicker = require(script.Invites.PlayerPicker)

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
DuelCamera.start()
HubHint.start(DuelHud.isActive)
