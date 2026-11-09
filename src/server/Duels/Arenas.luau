--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Arenas = {}

local rooms: { Model } = {}
local lastSpot: { [number]: Instance } = {}

function Arenas.build()
	local template = ServerStorage:WaitForChild("ArenaTemplate") :: Model
	local folder = Instance.new("Folder")
	folder.Name = "Arenas"

	for index = 1, Config.ROOM_COUNT do
		local room = template:Clone()
		room.Name = `Room{index}`
		room:PivotTo(CFrame.new(Config.ROOM_ORIGIN + Vector3.xAxis * index * Config.ROOM_SPACING))
		room.Parent = folder
		rooms[index] = room
	end

	folder.Parent = workspace
end

function Arenas.cube(index: number): BasePart
	return rooms[index]:FindFirstChild("Cube") :: BasePart
end

-- Hides the cube on one of the room's CubeSpots, never the same one twice in a row.
-- A room without spots keeps the cube where it is.
function Arenas.placeCube(index: number)
	local folder = rooms[index]:FindFirstChild("CubeSpots")
	local spots: { Instance } = if folder then folder:GetChildren() else {}
	local choices: { Instance } = {}
	for _, spot in spots do
		if spot ~= lastSpot[index] then
			table.insert(choices, spot)
		end
	end
	if #choices == 0 then
		choices = spots
	end
	if #choices == 0 then
		return
	end

	local spot = choices[math.random(#choices)] :: BasePart
	lastSpot[index] = spot
	Arenas.cube(index).CFrame = spot.CFrame
end

-- Where each player stands, turned towards the middle of the room so the spawn gives nothing away
function Arenas.spawnFrames(index: number): (CFrame, CFrame)
	local room = rooms[index]
	local center = room:GetPivot().Position

	local function frameOf(name: string): CFrame
		local spot = (room:FindFirstChild(name) :: BasePart).Position
		return CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
	end

	return frameOf("SpawnA"), frameOf("SpawnB")
end

return Arenas
