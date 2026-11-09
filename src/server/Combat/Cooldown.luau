--!strict
-- How often each player may do something, like fire. No Roblox calls, so Lune can test it.

local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable(
	{} :: {
		seconds: number,
		clock: () -> number,
		readyAt: { [any]: number },
	},
	Cooldown
))

function Cooldown.new(seconds: number, clock: (() -> number)?): Cooldown
	return setmetatable({ seconds = seconds, clock = clock or os.clock, readyAt = {} }, Cooldown)
end

-- True when `key` may go now, and starts its next wait
function Cooldown.take(self: Cooldown, key: any): boolean
	local now = self.clock()
	local readyAt = self.readyAt[key]
	if readyAt and now < readyAt then
		return false
	end
	self.readyAt[key] = now + self.seconds
	return true
end

function Cooldown.clear(self: Cooldown, key: any)
	self.readyAt[key] = nil
end

return Cooldown
