--!strict
local Players = game:GetService("Players")

-- Walks up from any part (limb, hat, a friend's nested monster mesh) to the player who owns it
return function(part: Instance?): Player?
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
