--!strict
-- Keeps the camera on the right body and pointing the right way through a duel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"))

local localPlayer = Players.LocalPlayer

local DuelCamera = {}

-- Players land facing the cube, but the camera still points wherever it did in the hub
function DuelCamera.lookWhereFacing()
	local root = Characters.rootPart(localPlayer)
	local camera = workspace.CurrentCamera
	if root and camera then
		local forward = root.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(root.Position - forward * 16 + Vector3.yAxis * 7, root.Position + forward * 12)
	end
end

-- The camera keeps following the old body after a form swap unless we point it at the new one
function DuelCamera.start()
	localPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		local camera = workspace.CurrentCamera
		if humanoid and camera then
			camera.CameraSubject = humanoid
		end
	end)
end

return DuelCamera
