--!strict

return {
	-- Invites
	INVITE_RANGE = 30, -- studs, how close you must be to click someone
	INVITE_RANGE_SLACK = 10, -- the server allows a bit more, players keep moving after the click
	INVITE_TIMEOUT = 15, -- seconds to answer
	INVITE_COOLDOWN = 5, -- seconds before you can re-invite someone who said no

	-- Duel rooms
	ROOM_COUNT = 8,
	ROOM_ORIGIN = Vector3.new(3000, 100, 0), -- far enough that the hub can't see the rooms
	ROOM_SPACING = 200,

	-- Duel timing, in seconds
	FADE_TIME = 0.4,
	COUNTDOWN = 3,
	DUEL_TIMEOUT = 90,
	RESULT_TIME = 3,

	-- Stand-ins until the real monster models land in assets/forms
	PLACEHOLDER_FORMS = {
		{ name = "Ember", color = Color3.fromRGB(226, 76, 54), height = 1.3, width = 1.3, head = 1.4 },
		{ name = "Tide", color = Color3.fromRGB(46, 120, 230), height = 0.85, width = 0.9, head = 1.3 },
		{ name = "Moss", color = Color3.fromRGB(84, 170, 84), height = 1.1, width = 1.5, head = 0.9 },
	},
}
