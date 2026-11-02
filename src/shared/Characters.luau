--!strict
-- Getting from a player to their body, and from a body part back to the player
local Players = game:GetService("Players")

local Characters = {}

function Characters.rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Walks up from any part (limb, hat, a friend's nested monster mesh) to the player who owns it
function Characters.playerFromPart(part: Instance?): Player?
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

return Characters
