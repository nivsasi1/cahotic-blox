--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelService = require(script.Parent.Parent.Duels.DuelService)
local InviteBook = require(script.Parent.InviteBook)

local remotes = ReplicatedStorage.Remotes

local InviteService = {}

local book = InviteBook.new(Config.INVITE_TIMEOUT, Config.INVITE_COOLDOWN)

local function tell(player: Player?, payload: { [string]: any })
	if player and player.Parent == Players then
		remotes.InviteState:FireClient(player, payload)
	end
end

local function closeInvite(invite: InviteBook.Invite, reason: string)
	local payload = { kind = "closed", reason = reason }
	tell(Players:GetPlayerByUserId(invite.from), payload)
	tell(Players:GetPlayerByUserId(invite.to), payload)
end

local function reject(player: Player, reason: string?)
	tell(player, { kind = "rejected", reason = reason })
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function inRange(first: Player, second: Player): boolean
	local a, b = rootPosition(first), rootPosition(second)
	return a ~= nil and b ~= nil and (a - b).Magnitude <= Config.INVITE_RANGE + Config.INVITE_RANGE_SLACK
end

local function onSend(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		return
	end
	if DuelService.isBusy(player) then
		return
	end
	if DuelService.isBusy(target) then
		reject(player, "busy")
		return
	end
	if not inRange(player, target) then
		reject(player, "too_far")
		return
	end

	local invite, reason = book:send(player.UserId, target.UserId)
	if not invite then
		reject(player, reason)
		return
	end
	tell(player, { kind = "sent", target = target })
	tell(target, { kind = "received", from = player })
end

local function onCancel(player: Player)
	local invite = book:cancel(player.UserId)
	if invite then
		closeInvite(invite, "cancelled")
	end
end

local function onAnswer(player: Player, accept: any)
	if typeof(accept) ~= "boolean" then
		return
	end
	local invite = book:answer(player.UserId, accept)
	if not invite then
		return
	end
	if not accept then
		closeInvite(invite, "declined")
		return
	end

	closeInvite(invite, "accepted")
	local from = Players:GetPlayerByUserId(invite.from)
	if from then
		local started, reason = DuelService.start(from, player)
		if not started then
			reject(from, reason)
			reject(player, reason)
		end
	end
end

function InviteService.start()
	remotes.InviteSend.OnServerEvent:Connect(onSend)
	remotes.InviteCancel.OnServerEvent:Connect(onCancel)
	remotes.InviteAnswer.OnServerEvent:Connect(onAnswer)

	Players.PlayerRemoving:Connect(function(player)
		local invite = book:removePlayer(player.UserId)
		if invite then
			closeInvite(invite, "left")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, invite in book:expire() do
				closeInvite(invite, "timeout")
			end
		end
	end)
end

return InviteService
