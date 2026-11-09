-- Run with: lune run tests/unit
local process = require("@lune/process")

local Cooldown = require("../src/server/Combat/Cooldown")
local InviteBook = require("../src/server/Invites/InviteBook")
local RoomPool = require("../src/server/Duels/RoomPool")
local Vitals = require("../src/server/Combat/Vitals")

local passed, failed = 0, 0

local function test(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL  {name}\n      {err}`)
	end
end

local function eq(actual: any, expected: any)
	if actual ~= expected then
		error(`expected {expected}, got {actual}`, 2)
	end
end

local function newBook()
	local now = 0
	local book = InviteBook.new(15, 5, function()
		return now
	end)
	return book, function(seconds: number)
		now += seconds
	end
end

test("invite goes through and can be accepted", function()
	local book = newBook()
	local invite = assert(book:send(1, 2))
	eq(invite.from, 1)
	eq(invite.to, 2)
	local answered = book:answer(2, true)
	eq(answered, invite)
	eq(book:answer(2, true), nil)
end)

test("cannot invite yourself", function()
	local book = newBook()
	local invite, reason = book:send(1, 1)
	eq(invite, nil)
	eq(reason, "self")
end)

test("a player can only be in one invite", function()
	local book = newBook()
	assert(book:send(1, 2))
	eq(select(2, book:send(1, 3)), "pending")
	eq(select(2, book:send(2, 3)), "pending")
	eq(select(2, book:send(3, 1)), "busy")
	eq(select(2, book:send(3, 2)), "busy")
end)

test("only the invited player can answer", function()
	local book = newBook()
	assert(book:send(1, 2))
	eq(book:answer(1, true), nil)
	eq(book:answer(3, true), nil)
	assert(book:answer(2, false))
end)

test("only the inviter can cancel", function()
	local book = newBook()
	assert(book:send(1, 2))
	eq(book:cancel(2), nil)
	assert(book:cancel(1))
	eq(book:answer(2, true), nil)
end)

test("decline blocks that pair for the cooldown only", function()
	local book, advance = newBook()
	assert(book:send(1, 2))
	book:answer(2, false)
	eq(select(2, book:send(1, 2)), "cooldown")
	assert(book:send(2, 1))
	book:cancel(2)
	advance(5)
	book:expire()
	assert(book:send(1, 2))
end)

test("accepting leaves no cooldown", function()
	local book = newBook()
	assert(book:send(1, 2))
	book:answer(2, true)
	assert(book:send(1, 2))
end)

test("invites expire once, on time", function()
	local book, advance = newBook()
	assert(book:send(1, 2))
	advance(14.9)
	eq(#book:expire(), 0)
	advance(0.1)
	eq(#book:expire(), 1)
	eq(#book:expire(), 0)
	eq(book:answer(2, true), nil)
end)

test("a player leaving clears their invite from both sides", function()
	local book = newBook()
	local invite = assert(book:send(1, 2))
	eq(book:removePlayer(2), invite)
	eq(book:removePlayer(1), nil)
	assert(book:send(1, 3))
end)

test("rooms are reserved until released", function()
	local pool = RoomPool.new(2)
	eq(pool:freeCount(), 2)
	eq(pool:reserve(), 1)
	eq(pool:reserve(), 2)
	eq(pool:reserve(), nil)
	eq(pool:freeCount(), 0)
	pool:release(1)
	eq(pool:freeCount(), 1)
	eq(pool:reserve(), 1)
end)

test("releasing a free room is an error", function()
	local pool = RoomPool.new(2)
	eq(pcall(function()
		pool:release(1)
	end), false)
end)

local function newVitals()
	local now = 0
	local vitals = Vitals.new({ maxHp = 100, downTime = 5, refillTime = 6, protectTime = 2 }, function()
		return now
	end)
	return vitals, function(seconds: number)
		now += seconds
	end
end

local function near(actual: number, expected: number)
	if math.abs(actual - expected) > 0.01 then
		error(`expected about {expected}, got {actual}`, 2)
	end
end

test("seven body shots knock you down, not six", function()
	local vitals = newVitals()
	for _ = 1, 6 do
		eq(vitals:hit(0.15), "hit")
	end
	near(vitals.hp, 10)
	eq(vitals:hit(0.15), "down")
	eq(vitals.hp, 0)
	eq(vitals:isDown(), true)
end)

test("three headshots knock you down", function()
	local vitals = newVitals()
	eq(vitals:hit(0.35), "hit")
	eq(vitals:hit(0.35), "hit")
	eq(vitals:hit(0.35), "down")
end)

test("hits do nothing while you are down", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(4.9)
	eq(vitals:hit(0.35), "ignored")
	eq(vitals:update(), nil)
	eq(vitals:isDown(), true)
end)

test("you get up after the knockdown time, once", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(5)
	eq(vitals:update(), "up")
	eq(vitals:isDown(), false)
	eq(vitals:update(), nil)
end)

test("health refills slowly after getting up", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(5)
	vitals:update()
	near(vitals.hp, 0)
	advance(3)
	vitals:update()
	near(vitals.hp, 50)
	advance(10)
	vitals:update()
	eq(vitals.hp, 100)
	eq(vitals.refilling, false)
end)

test("a late update still counts the refill from when you got up", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(8)
	eq(vitals:update(), "up")
	near(vitals.hp, 50)
end)

test("hits do nothing during the protection after getting up", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(5)
	vitals:update()
	advance(1.9)
	eq(vitals:isProtected(), true)
	eq(vitals:hit(0.35), "ignored")
	advance(0.1)
	eq(vitals:isProtected(), false)
	eq(vitals:hit(0.15), "hit")
end)

test("the refill keeps going after a hit", function()
	local vitals, advance = newVitals()
	vitals:hit(1)
	advance(5 + 3)
	vitals:update()
	vitals:hit(0.15)
	near(vitals.hp, 35)
	advance(1)
	vitals:update()
	near(vitals.hp, 35 + 100 / 6)
end)

test("no refill without a knockdown", function()
	local vitals, advance = newVitals()
	vitals:hit(0.15)
	advance(30)
	vitals:update()
	near(vitals.hp, 85)
end)

test("the cooldown blocks until its time is up", function()
	local now = 0
	local cooldown = Cooldown.new(0.2, function()
		return now
	end)
	eq(cooldown:take("a"), true)
	eq(cooldown:take("a"), false)
	eq(cooldown:take("b"), true)
	now = 0.19
	eq(cooldown:take("a"), false)
	now = 0.2
	eq(cooldown:take("a"), true)
	cooldown:clear("a")
	eq(cooldown:take("a"), true)
end)

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
