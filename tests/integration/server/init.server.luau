-- Plays the whole game with two real test clients and prints [TEST] lines.
-- Only goes into the test place, see tests/integration/run.ps1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("DuelService"))

local bus = Instance.new("RemoteFunction")
bus.Name = "TestBus"
bus.Parent = ReplicatedStorage

local passed, failed = 0, 0

local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
	end
	print(`[TEST] {if ok then "PASS" else "FAIL"} {name}{if detail ~= nil then ` :: {detail}` else ""}`)
end

local function waitUntil(predicate: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

local function ask(player: Player, command: string, ...: any): any
	return bus:InvokeClient(player, command, ...)
end

local testPlayers: { Player } = {}

local function shot(name: string)
	print(`[TEST] SHOT {name}`)
	for index, player in testPlayers do
		print(`[TEST] SHOT result {name} player{index}: {ask(player, "capture", `{name}_player{index}`)}`)
	end
end

local function wins(player: Player): number
	return (player:FindFirstChild("leaderstats") :: any).Wins.Value
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inHub(player: Player): boolean
	local part = root(player)
	return part ~= nil and part.Position.Magnitude < 100
end

local function invite(from: Player, to: Player): any
	local window = ask(from, "invite", to)
	local popup = ask(to, "waitPopup")
	return window, popup
end

-- Runs one duel up to the moment the cube goes live
local function startDuel(from: Player, to: Player)
	local characterFrom, characterTo = from.Character, to.Character
	invite(from, to)
	ask(to, "answer", true)
	check("both players are marked busy", waitUntil(function()
		return DuelService.isBusy(from) and DuelService.isBusy(to)
	end, 3))
	check("one room is reserved", DuelService.freeRooms() == Config.ROOM_COUNT - 1, DuelService.freeRooms())
	check("both players changed form", waitUntil(function()
		return from.Character ~= characterFrom and to.Character ~= characterTo
	end, 5))
	return true
end

local function waitLive(from: Player, to: Player)
	return waitUntil(function()
		local a, b = root(from), root(to)
		return a ~= nil and b ~= nil and not a.Anchored and not b.Anchored
	end, Config.COUNTDOWN + 3)
end

local function backToHub(from: Player, to: Player)
	check("duel ends and both players are free", waitUntil(function()
		return not DuelService.isBusy(from) and not DuelService.isBusy(to)
	end, Config.RESULT_TIME + 5))
	check("room is released", DuelService.freeRooms() == Config.ROOM_COUNT, DuelService.freeRooms())
	check("players are back in the hub", waitUntil(function()
		return inHub(from) and inHub(to)
	end, 5))
	task.wait(1)
end

local function main()
	assert(waitUntil(function()
		return #Players:GetPlayers() >= 2
	end, 90), "second player never joined")

	local players = Players:GetPlayers()
	table.sort(players, function(left, right)
		return left.Name < right.Name
	end)
	local a, b = players[1], players[2]
	testPlayers = { a, b }

	assert(waitUntil(function()
		return root(a) ~= nil and root(b) ~= nil and a:FindFirstChild("leaderstats") ~= nil
	end, 30), "characters never loaded")
	check("placeholder forms built", waitUntil(function()
		return #ServerStorage.Forms:GetChildren() >= 2
	end, 20), #ServerStorage.Forms:GetChildren())
	task.wait(2)
	shot("hub")

	-- Clicking and invites
	local picked = ask(a, "pick", b)
	check("clicking finds the other player", picked == b.Name, picked)

	local window = ask(a, "open", b)
	check("invite window opens inside the screen", window.inside, window.text)
	shot("invite_window")
	ask(a, "submit")
	local popup = ask(b, "waitPopup")
	check("popup reaches the invited player", popup.open and popup.title == a.DisplayName, popup.title)
	check("popup sits inside the screen", popup.inside)
	check("inviter sees the waiting state", ask(a, "windowTitle") == `Waiting for {b.DisplayName}`)
	shot("invite_popup")

	ask(b, "answer", false)
	check("decline closes the inviter's window", waitUntil(function()
		return not ask(a, "windowOpen")
	end, 3))

	ask(a, "open", b)
	ask(a, "submit")
	check("cooldown blocks a second invite", waitUntil(function()
		return ask(a, "toast") == "Give them a moment before asking again"
	end, 3))
	task.wait(Config.INVITE_COOLDOWN + 0.5)

	-- Cube win
	local winsA, winsB = wins(a), wins(b)
	startDuel(a, b)
	local humanoid = (a.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	check("form name is on the nametag", string.find(humanoid.DisplayName, "(", 1, true) ~= nil, humanoid.DisplayName)
	check("players are in the room", root(a) ~= nil and (root(a) :: BasePart).Position.X > 1000, root(a) and (root(a) :: BasePart).Position)
	check("players start on opposite sides", root(a) ~= nil and root(b) ~= nil and ((root(a) :: BasePart).Position - (root(b) :: BasePart).Position).Magnitude > 40)
	check("players are held during the countdown", (root(a) :: BasePart).Anchored)
	check("two different forms", a.Character ~= nil and (a.Character :: any).Humanoid.DisplayName ~= (b.Character :: any).Humanoid.DisplayName)

	local status = ask(a, "status")
	check("camera follows the new form", status.cameraOnHumanoid)
	check("client sees the new character", status.character == a.Name)
	check("form has an Animate script", status.hasAnimate)
	check("countdown text is showing", status.big ~= "", status.big)
	shot("countdown")

	check("cube goes live after the countdown", waitLive(a, b))
	local cube = workspace.Arenas.Room1.Cube
	ask(a, "moveTo", cube.Position)
	task.wait(0.4)
	shot("live")
	check("walking animation plays on the form", ask(a, "animating"))
	check("reaching the cube gives a win", waitUntil(function()
		return wins(a) == winsA + 1
	end, 15), wins(a))
	check("the other player gets nothing", wins(b) == winsB)
	check("winner sees the result", ask(a, "big") == "YOU WIN", ask(a, "big"))
	check("loser sees the result", ask(b, "big") == "YOU LOST", ask(b, "big"))
	shot("result")
	backToHub(a, b)
	check("players got their own avatar back", (a.Character :: any).Humanoid.DisplayName == a.DisplayName)
	check("controls still work after the duel", ask(a, "canMove"))
	shot("back_in_hub")

	-- Dying cancels without a point
	startDuel(b, a)
	check("second duel goes live", waitLive(b, a))
	winsA, winsB = wins(a), wins(b)
	local victim = (b.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	victim.Health = 0
	backToHub(a, b)
	check("dying gives nobody a point", wins(a) == winsA and wins(b) == winsB)

	-- Time running out
	local config: any = Config
	local originalTimeout = config.DUEL_TIMEOUT
	config.DUEL_TIMEOUT = 2
	startDuel(a, b)
	check("third duel goes live", waitLive(a, b))
	check("timeout ends the duel", waitUntil(function()
		return ask(a, "big") == "TIME UP"
	end, 5))
	backToHub(a, b)
	config.DUEL_TIMEOUT = originalTimeout

	-- Leaving mid-duel
	startDuel(a, b)
	check("fourth duel goes live", waitLive(a, b))
	winsA = wins(a)
	b:Kick("integration test")
	check("leaving ends the duel", waitUntil(function()
		return ask(a, "big") == "DUEL OVER"
	end, 5))
	check("the player who stayed is free again", waitUntil(function()
		return not DuelService.isBusy(a)
	end, Config.RESULT_TIME + 5))
	check("room is released after a leave", DuelService.freeRooms() == Config.ROOM_COUNT, DuelService.freeRooms())
	check("the player who stayed is back in the hub", waitUntil(function()
		return inHub(a)
	end, 5))
	check("leaving gives nobody a point", wins(a) == winsA)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
	check("harness finished", false, err)
end
print(`[TEST] DONE passed={passed} failed={failed}`)
game:GetService("StudioTestService"):EndTest({ passed = passed, failed = failed })
