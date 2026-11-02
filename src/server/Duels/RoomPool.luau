--!strict
-- Which duel rooms are reserved. No Roblox calls in here, so Lune can test it from the terminal.

local RoomPool = {}
RoomPool.__index = RoomPool

export type RoomPool = typeof(setmetatable({} :: { count: number, taken: { [number]: boolean } }, RoomPool))

function RoomPool.new(count: number): RoomPool
	return setmetatable({ count = count, taken = {} }, RoomPool)
end

function RoomPool.reserve(self: RoomPool): number?
	for room = 1, self.count do
		if not self.taken[room] then
			self.taken[room] = true
			return room
		end
	end
	return nil
end

function RoomPool.release(self: RoomPool, room: number)
	assert(self.taken[room], `room {room} was not reserved`)
	self.taken[room] = nil
end

function RoomPool.freeCount(self: RoomPool): number
	local free = self.count
	for _ in self.taken do
		free -= 1
	end
	return free
end

return RoomPool
