--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Arenas = {}

local rooms: { Model } = {}

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

-- Where each player stands, already turned towards the cube
function Arenas.spawnFrames(index: number): (CFrame, CFrame)
	local room = rooms[index]
	local cube = Arenas.cube(index).Position

	local function frameOf(name: string): CFrame
		local spot = (room:FindFirstChild(name) :: BasePart).Position
		return CFrame.lookAt(spot, Vector3.new(cube.X, spot.Y, cube.Z))
	end

	return frameOf("SpawnA"), frameOf("SpawnB")
end

return Arenas
