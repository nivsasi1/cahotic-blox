--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arenas = require(script.Parent.Arenas)
local Config = require(ReplicatedStorage.Shared.Config)
local FormService = require(script.Parent.FormService)
local RoomPool = require(script.Parent.RoomPool)
local ScoreService = require(script.Parent.ScoreService)
local playerFromPart = require(ReplicatedStorage.Shared.PlayerFromPart)

local DuelState = ReplicatedStorage.Remotes.DuelState

type Phase = "starting" | "live" | "ending"

type Duel = {
	room: number,
	players: { Player },
	phase: Phase,
	connections: { RBXScriptConnection },
}

local pool = RoomPool.new(Config.ROOM_COUNT)
local duelOf: { [Player]: Duel } = {}

local DuelService = {}

function DuelService.isBusy(player: Player): boolean
	return duelOf[player] ~= nil
end

function DuelService.freeRooms(): number
	return pool:freeCount()
end

local function isHere(player: Player): boolean
	return player.Parent == Players
end

local function tell(duel: Duel, payload: { [string]: any })
	for _, player in duel.players do
		if isHere(player) then
			DuelState:FireClient(player, payload)
		end
	end
end

-- Anchoring holds any rig still, so this needs no per-form walk speed
local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
		if not frozen then
			root:SetNetworkOwner(player)
		end
	end
end

local function finish(duel: Duel, winner: Player?, reason: string)
	if duel.phase == "ending" then
		return
	end
	duel.phase = "ending"

	for _, connection in duel.connections do
		connection:Disconnect()
	end
	if winner then
		ScoreService.award(winner)
	end
	for _, player in duel.players do
		if isHere(player) then
			setFrozen(player, true)
		end
	end
	tell(duel, { phase = "result", winner = winner, reason = reason })
	task.wait(Config.RESULT_TIME)

	tell(duel, { phase = "returning" })
	task.wait(Config.FADE_TIME)

	-- Reloading gives back the player's own avatar on the hub spawn.
	-- The pcall matters: a failure here must never leave a room reserved forever.
	for _, player in duel.players do
		if isHere(player) then
			local ok, err = pcall(player.LoadCharacterAsync, player)
			if not ok then
				warn(`Could not send {player.Name} back to the hub: {err}`)
			end
		end
	end
	pool:release(duel.room)
	for _, player in duel.players do
		duelOf[player] = nil
	end

	tell(duel, { phase = "ended" })
	print(`[Duel] room {duel.room} released ({reason}), {pool:freeCount()} free`)
end

local function watchForDeath(duel: Duel, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(
			duel.connections,
			humanoid.Died:Connect(function()
				finish(duel, nil, "cancelled")
			end)
		)
	end
end

local function goLive(duel: Duel)
	duel.phase = "live"

	table.insert(
		duel.connections,
		Arenas.cube(duel.room).Touched:Connect(function(part)
			local player = playerFromPart(part)
			if player and duelOf[player] == duel and duel.phase == "live" then
				finish(duel, player, "cube")
			end
		end)
	)

	for _, player in duel.players do
		setFrozen(player, false)
	end
	tell(duel, { phase = "live", seconds = Config.DUEL_TIMEOUT })

	task.delay(Config.DUEL_TIMEOUT, function()
		if duel.phase == "live" then
			finish(duel, nil, "timeout")
		end
	end)
end

local function run(duel: Duel)
	local first, second = duel.players[1], duel.players[2]
	local formFirst, formSecond = FormService.pickPair()
	local spawnFirst, spawnSecond = Arenas.spawnFrames(duel.room)

	tell(duel, { phase = "starting" })
	task.wait(Config.FADE_TIME)
	if duel.phase ~= "starting" then
		return
	end

	FormService.apply(first, formFirst, spawnFirst)
	FormService.apply(second, formSecond, spawnSecond)
	for _, player in duel.players do
		setFrozen(player, true)
		watchForDeath(duel, player)
	end

	DuelState:FireClient(first, { phase = "countdown", seconds = Config.COUNTDOWN, opponent = second, form = formFirst })
	DuelState:FireClient(second, { phase = "countdown", seconds = Config.COUNTDOWN, opponent = first, form = formSecond })
	task.wait(Config.COUNTDOWN)
	if duel.phase == "starting" then
		goLive(duel)
	end
end

function DuelService.start(first: Player, second: Player): (boolean, string?)
	if duelOf[first] or duelOf[second] then
		return false, "busy"
	end
	local room = pool:reserve()
	if not room then
		return false, "no_rooms"
	end

	local duel: Duel = { room = room, players = { first, second }, phase = "starting", connections = {} }
	duelOf[first] = duel
	duelOf[second] = duel
	print(`[Duel] {first.Name} vs {second.Name} in room {room}, {pool:freeCount()} free`)
	task.spawn(run, duel)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	local duel = duelOf[player]
	if duel then
		finish(duel, nil, "left")
	end
end)

return DuelService
