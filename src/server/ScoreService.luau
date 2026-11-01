--!strict
local Players = game:GetService("Players")

local ScoreService = {}

local function setUp(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- this exact name is what puts it on Roblox's built-in scoreboard

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats

	stats.Parent = player
end

function ScoreService.start()
	Players.PlayerAdded:Connect(setUp)
	for _, player in Players:GetPlayers() do
		setUp(player)
	end
end

function ScoreService.award(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	if wins and wins:IsA("IntValue") then
		wins.Value += 1
	end
end

return ScoreService
