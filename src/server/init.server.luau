--!strict
local Arenas = require(script.Duels.Arenas)
local FormService = require(script.Forms.FormService)
local InviteService = require(script.Invites.InviteService)
local ScoreService = require(script.Score.ScoreService)

ScoreService.start()
Arenas.build()
FormService.start()
InviteService.start()
