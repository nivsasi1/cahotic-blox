--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arenas = require(script.Parent.Arenas)
local BlasterService = require(script.Parent.Parent.Combat.BlasterService)
local Characters = require(ReplicatedStorage.Shared.Characters)
local Config = require(ReplicatedStorage.Shared.Config)
local FormService = require(script.Parent.Parent.Forms.FormService)
local HealthService = require(script.Parent.Parent.Combat.HealthService)
local RoomPool = require(script.Parent.RoomPool)
local ScoreService = require(script.Parent.Parent.Score.ScoreService)

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

-- The other duelist, but only while the duel is live, so nobody can be hit during the countdown
function DuelService.opponentIfLive(player: Player): Player?
	local duel = duelOf[player]
	if not duel or duel.phase ~= "live" then
		return nil
	end
	return if duel.players[1] == player then duel.players[2] else duel.players[1]
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

local function showResult(duel: Duel, winner: Player?, reason: string)
	for _, connection in duel.connections do
		connection:Disconnect()
	end
	if winner then
		ScoreService.award(winner)
	end
	for _, player in duel.players do
		HealthService.clear(player)
		if isHere(player) then
			BlasterService.take(player)
			Characters.setFrozen(player, true)
		end
	end
	tell(duel, { phase = "result", winner = winner, reason = reason })
	task.wait(Config.RESULT_TIME)
end

-- Reloading gives back the player's own avatar on the hub spawn.
-- The pcall matters: a failure here must never leave a room reserved forever.
local function sendHome(duel: Duel)
	tell(duel, { phase = "returning" })
	task.wait(Config.FADE_TIME)

	for _, player in duel.players do
		if isHere(player) then
			local ok, err = pcall(player.LoadCharacterAsync, player)
			if not ok then
				warn(`Could not send {player.Name} back to the hub: {err}`)
			end
		end
	end
end

local function closeDuel(duel: Duel, reason: string)
	pool:release(duel.room)
	for _, player in duel.players do
		duelOf[player] = nil
	end

	tell(duel, { phase = "ended" })
	print(`[Duel] room {duel.room} released ({reason}), {pool:freeCount()} free`)
end

local function finish(duel: Duel, winner: Player?, reason: string)
	if duel.phase == "ending" then
		return
	end
	duel.phase = "ending"

	showResult(duel, winner, reason)
	sendHome(duel)
	closeDuel(duel, reason)
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
			-- A knocked down player is anchored, so they can't touch it anyway. This makes it a rule.
			local player = Characters.playerFromPart(part)
			if player and duelOf[player] == duel and duel.phase == "live" and not HealthService.isDown(player) then
				finish(duel, player, "cube")
			end
		end)
	)

	for _, player in duel.players do
		Characters.setFrozen(player, false)
	end
	tell(duel, { phase = "live", seconds = Config.DUEL_TIMEOUT })

	task.delay(Config.DUEL_TIMEOUT, function()
		if duel.phase == "live" then
			finish(duel, nil, "timeout")
		end
	end)
end

local function placePlayers(duel: Duel, formFirst: string?, formSecond: string?)
	local first, second = duel.players[1], duel.players[2]
	local spawnFirst, spawnSecond = Arenas.spawnFrames(duel.room)

	FormService.apply(first, formFirst, spawnFirst)
	FormService.apply(second, formSecond, spawnSecond)
	for _, player in duel.players do
		Characters.setFrozen(player, true)
		HealthService.reset(player)
		BlasterService.give(player)
		watchForDeath(duel, player)
	end
end

local function countDown(duel: Duel, formFirst: string?, formSecond: string?)
	local first, second = duel.players[1], duel.players[2]

	DuelState:FireClient(first, { phase = "countdown", seconds = Config.COUNTDOWN, opponent = second, form = formFirst })
	DuelState:FireClient(second, { phase = "countdown", seconds = Config.COUNTDOWN, opponent = first, form = formSecond })
	task.wait(Config.COUNTDOWN)
end

local function run(duel: Duel)
	local formFirst, formSecond = FormService.pickPair()
	Arenas.placeCube(duel.room)

	tell(duel, { phase = "starting" })
	task.wait(Config.FADE_TIME)
	if duel.phase ~= "starting" then
		return
	end

	placePlayers(duel, formFirst, formSecond)
	countDown(duel, formFirst, formSecond)
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
