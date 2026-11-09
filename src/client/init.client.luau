--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blaster = require(script.Combat.Blaster)
local CombatHud = require(script.Combat.CombatHud)
local DuelCamera = require(script.Duels.DuelCamera)
local DuelHud = require(script.Duels.DuelHud)
local HubHint = require(script.Hub.HubHint)
local InvitePopup = require(script.Invites.InvitePopup)
local InviteWindow = require(script.Invites.InviteWindow)
local PlayerPicker = require(script.Invites.PlayerPicker)
local ShoulderCamera = require(script.Combat.ShoulderCamera)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

remotes:WaitForChild("InviteState").OnClientEvent:Connect(function(payload)
	InviteWindow.onState(payload)
	InvitePopup.onState(payload)
end)
remotes:WaitForChild("DuelState").OnClientEvent:Connect(function(payload)
	DuelHud.onState(payload)
	CombatHud.onState(payload)
	Blaster.onState(payload)
	ShoulderCamera.onState(payload)
end)

local function canPick(): boolean
	return not DuelHud.isActive() and not InviteWindow.isLocked() and not InvitePopup.isOpen()
end

PlayerPicker.start(canPick, InviteWindow.open)
DuelCamera.start()
HubHint.start(DuelHud.isActive)
Blaster.start()
