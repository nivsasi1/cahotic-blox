--!strict
-- One duelist's health: hits, knockdowns, getting up and the slow refill.
-- No Roblox calls in here, so Lune can test it from the terminal.

export type Settings = {
	maxHp: number,
	downTime: number, -- seconds on the floor after a knockdown
	refillTime: number, -- seconds to go from 0 back to full after getting up
	protectTime: number, -- seconds after getting up where hits do nothing
}

export type HitResult = "ignored" | "hit" | "down"

local Vitals = {}
Vitals.__index = Vitals

export type Vitals = typeof(setmetatable(
	{} :: {
		settings: Settings,
		clock: () -> number,
		hp: number,
		downUntil: number?,
		refilling: boolean,
		protectedUntil: number,
		updatedAt: number,
	},
	Vitals
))

function Vitals.new(settings: Settings, clock: (() -> number)?): Vitals
	local now = (clock or os.clock)()
	return setmetatable({
		settings = settings,
		clock = clock or os.clock,
		hp = settings.maxHp,
		downUntil = nil,
		refilling = false,
		protectedUntil = now,
		updatedAt = now,
	}, Vitals)
end

-- Moves time forward. Returns "up" on the call where the player gets back up.
function Vitals.update(self: Vitals): "up"?
	local now = self.clock()
	local event: "up"? = nil
	local downUntil = self.downUntil
	if downUntil and now >= downUntil then
		self.downUntil = nil
		self.hp = 0
		self.refilling = true
		self.protectedUntil = downUntil + self.settings.protectTime
		self.updatedAt = downUntil
		event = "up"
	end
	if self.refilling then
		local rate = self.settings.maxHp / self.settings.refillTime
		self.hp = math.min(self.settings.maxHp, self.hp + rate * (now - self.updatedAt))
		self.refilling = self.hp < self.settings.maxHp
	end
	self.updatedAt = now
	return event
end

function Vitals.isDown(self: Vitals): boolean
	return self.downUntil ~= nil
end

function Vitals.isProtected(self: Vitals): boolean
	return self.clock() < self.protectedUntil
end

-- `share` is a fraction of max HP, so damage stays the same if max HP changes
function Vitals.hit(self: Vitals, share: number): HitResult
	self:update()
	if self.downUntil or self:isProtected() then
		return "ignored"
	end
	self.hp = math.max(0, self.hp - share * self.settings.maxHp)
	if self.hp > 1e-6 then
		return "hit"
	end
	self.hp = 0
	self.refilling = false
	self.downUntil = self.clock() + self.settings.downTime
	return "down"
end

return Vitals
