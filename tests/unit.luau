-- Run with: lune run tests/unit
local process = require("@lune/process")

local InviteBook = require("../src/server/Invites/InviteBook")
local RoomPool = require("../src/server/Duels/RoomPool")

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

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
