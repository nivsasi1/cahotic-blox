--!strict
-- Who invited whom. No Roblox calls in here, so Lune can test it from the terminal.

export type Invite = { from: number, to: number, expiresAt: number }

local InviteBook = {}
InviteBook.__index = InviteBook

export type InviteBook = typeof(setmetatable(
	{} :: {
		timeout: number,
		cooldown: number,
		clock: () -> number,
		byPlayer: { [number]: Invite }, -- a player sits in at most one invite, on either side
		blockedUntil: { [string]: number },
	},
	InviteBook
))

function InviteBook.new(timeout: number, cooldown: number, clock: (() -> number)?): InviteBook
	return setmetatable({
		timeout = timeout,
		cooldown = cooldown,
		clock = clock or os.clock,
		byPlayer = {},
		blockedUntil = {},
	}, InviteBook)
end

local function pairKey(from: number, to: number): string
	return `{from}:{to}`
end

local function remove(self: InviteBook, invite: Invite)
	self.byPlayer[invite.from] = nil
	self.byPlayer[invite.to] = nil
end

local function block(self: InviteBook, invite: Invite)
	self.blockedUntil[pairKey(invite.from, invite.to)] = self.clock() + self.cooldown
end

function InviteBook.send(self: InviteBook, from: number, to: number): (Invite?, string?)
	if from == to then
		return nil, "self"
	end
	if self.byPlayer[from] then
		return nil, "pending"
	end
	if self.byPlayer[to] then
		return nil, "busy"
	end
	local blocked = self.blockedUntil[pairKey(from, to)]
	if blocked and blocked > self.clock() then
		return nil, "cooldown"
	end

	local invite = { from = from, to = to, expiresAt = self.clock() + self.timeout }
	self.byPlayer[from] = invite
	self.byPlayer[to] = invite
	return invite
end

function InviteBook.answer(self: InviteBook, to: number, accept: boolean): Invite?
	local invite = self.byPlayer[to]
	if not invite or invite.to ~= to then
		return nil
	end
	remove(self, invite)
	if not accept then
		block(self, invite)
	end
	return invite
end

function InviteBook.cancel(self: InviteBook, from: number): Invite?
	local invite = self.byPlayer[from]
	if not invite or invite.from ~= from then
		return nil
	end
	remove(self, invite)
	block(self, invite)
	return invite
end

function InviteBook.expire(self: InviteBook): { Invite }
	local now = self.clock()
	local expired = {}
	for id, invite in self.byPlayer do
		if id == invite.from and invite.expiresAt <= now then
			table.insert(expired, invite)
		end
	end
	for _, invite in expired do
		remove(self, invite)
		block(self, invite)
	end
	for key, blocked in self.blockedUntil do
		if blocked <= now then
			self.blockedUntil[key] = nil
		end
	end
	return expired
end

function InviteBook.removePlayer(self: InviteBook, id: number): Invite?
	local invite = self.byPlayer[id]
	if invite then
		remove(self, invite)
	end
	return invite
end

return InviteBook
