--!strict
-- Plays the sounds listed in Config.SOUNDS
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

-- With `at` (a part or attachment) the sound comes from that spot, otherwise it plays flat
function Sfx.play(name: string, at: Instance?)
	local spec = (Config.SOUNDS :: any)[name]
	if not spec then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.PlaybackSpeed = spec.speed
	sound.Volume = spec.volume
	sound.Parent = at or SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

return Sfx
