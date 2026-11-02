--!strict
-- Finds the player under the mouse. A raycast instead of ClickDetectors means nothing has
-- to be added to characters, so this keeps working on any monster model.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Characters = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Toast = require(script.Parent.Parent.Common.Toast)
local Ui = require(script.Parent.Parent.Common.Ui)

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local highlight = Ui.make("Highlight", {
	Name = "PickHighlight",
	DepthMode = Enum.HighlightDepthMode.Occluded,
	Enabled = false,
	FillColor = Ui.colors.accent,
	FillTransparency = 0.8,
	OutlineColor = Ui.colors.accent,
	Parent = workspace,
})

local PlayerPicker = {}

local hovered: Player? = nil

function PlayerPicker.inRange(player: Player): boolean
	local mine, theirs = Characters.rootPart(localPlayer), Characters.rootPart(player)
	return mine ~= nil and theirs ~= nil and (mine.Position - theirs.Position).Magnitude <= Config.INVITE_RANGE
end

function PlayerPicker.playerOnRay(ray: Ray): Player?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character :: any }

	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return hit and Characters.playerFromPart(hit.Instance)
end

local function setHovered(player: Player?)
	hovered = player
	if player and player.Character then
		highlight.Adornee = player.Character
		highlight.Enabled = true
		highlight.OutlineColor = if PlayerPicker.inRange(player) then Ui.colors.accent else Ui.colors.danger
		highlight.FillColor = highlight.OutlineColor
		mouse.Icon = "rbxasset://SystemCursors/PointingHand"
	else
		highlight.Enabled = false
		highlight.Adornee = nil
		mouse.Icon = ""
	end
end

local function choose(player: Player, onPick: (Player) -> ())
	if PlayerPicker.inRange(player) then
		onPick(player)
	else
		Toast.show("too_far")
	end
end

function PlayerPicker.start(canPick: () -> boolean, onPick: (Player) -> ())
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not canPick() or not camera then
			setHovered(nil)
			return
		end
		local location = UserInputService:GetMouseLocation()
		setHovered(PlayerPicker.playerOnRay(camera:ViewportPointToRay(location.X, location.Y)))
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 and hovered then
			choose(hovered, onPick)
		end
	end)

	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		local camera = workspace.CurrentCamera
		if processed or not canPick() or not camera then
			return
		end
		local player = PlayerPicker.playerOnRay(camera:ScreenPointToRay(position.X, position.Y))
		if player then
			choose(player, onPick)
		end
	end)
end

return PlayerPicker
