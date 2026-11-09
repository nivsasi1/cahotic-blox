-- Plays the whole game with two real test clients and prints [TEST] lines.
-- Only goes into the test place, see tests/integration/run.ps1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Duels"):WaitForChild("DuelService"))

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
local lastCubeSpot = Vector3.zero

local function shot(name: string)
	task.wait(0.3)
	for _, player in testPlayers do
		task.spawn(ask, player, "capture")
	end
	print(`[TEST] SHOT {name}`)
	task.wait(1)
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

local function onSpot(room: Model): boolean
	local cube = room:FindFirstChild("Cube") :: BasePart
	for _, spot in (room:FindFirstChild("CubeSpots") :: Folder):GetChildren() do
		if ((spot :: BasePart).Position - cube.Position).Magnitude < 0.1 then
			return true
		end
	end
	return false
end

-- The cube can sit behind cover, so stand on its open side first and walk the last few studs
local function walkToCube(player: Player, cube: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { cube }
	for _, direction in { Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis } do
		if not workspace:Raycast(cube.Position, direction * 9, params) then
			ask(player, "teleportTo", cube.Position + direction * 7 + Vector3.yAxis)
			break
		end
	end
	ask(player, "moveTo", cube.Position)
end

local function waitForPlayers(): (Player, Player)
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
	return a, b
end

local function testInvites(a: Player, b: Player)
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
end

local function testCubeWin(a: Player, b: Player)
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
	check("countdown text is showing", waitUntil(function()
		return ask(a, "big") ~= ""
	end, 1), ask(a, "big"))
	shot("countdown")

	check("cube goes live after the countdown", waitLive(a, b))
	local room = workspace.Arenas.Room1
	local cube = room.Cube
	check("cube is hidden on one of the spots", onSpot(room), cube.Position)
	lastCubeSpot = cube.Position
	task.wait(0.6) -- let "GO!" clear for a clean picture
	ask(a, "topDown", room:GetPivot().Position)
	shot("room_top")
	ask(a, "restoreCamera")
	shot("live")
	walkToCube(a, cube)
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
end

local function testDying(a: Player, b: Player)
	startDuel(b, a)
	local cube = workspace.Arenas.Room1.Cube
	check("the cube moves to a different spot next duel", (cube.Position - lastCubeSpot).Magnitude > 1, cube.Position)
	check("second duel goes live", waitLive(b, a))
	local winsA, winsB = wins(a), wins(b)
	local victim = (b.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	victim.Health = 0
	backToHub(a, b)
	check("dying gives nobody a point", wins(a) == winsA and wins(b) == winsB)
end

local function testTimeout(a: Player, b: Player)
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
end

local function testLeaving(a: Player, b: Player)
	startDuel(a, b)
	check("fourth duel goes live", waitLive(a, b))
	local winsA = wins(a)
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

local function main()
	local a, b = waitForPlayers()
	testInvites(a, b)
	testCubeWin(a, b)
	testDying(a, b)
	testTimeout(a, b)
	testLeaving(a, b)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
	check("harness finished", false, err)
end
print(`[TEST] DONE passed={passed} failed={failed}`)
game:GetService("StudioTestService"):EndTest({ passed = passed, failed = failed })
