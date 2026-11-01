--!strict
local Arenas = require(script.Arenas)
local FormService = require(script.FormService)
local InviteService = require(script.InviteService)
local ScoreService = require(script.ScoreService)

ScoreService.start()
Arenas.build()
FormService.start()
InviteService.start()
