--!strict
-- Everything on screen for combat: crosshair, hit markers, both health bars, the red edge when
-- you get hit, and the knocked down screen. Health comes from Player attributes the server sets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Parent.Common.Ui)

local localPlayer = Players.LocalPlayer

type Payload = { [string]: any }
type Bar = { fill: Frame, who: TextLabel, value: TextLabel }

local CENTER = UDim2.fromScale(0.5, 0.5)
local MIDDLE = Vector2.new(0.5, 0.5)

local gui = Ui.screen("CombatHud", 9)
gui.IgnoreGuiInset = true -- so the crosshair sits exactly where the camera ray goes

local crosshair = Ui.make("Frame", {
	Name = "Crosshair",
	AnchorPoint = MIDDLE,
	BackgroundTransparency = 1,
	Position = CENTER,
	Size = UDim2.fromOffset(28, 28),
	Visible = false,
	Parent = gui,
})
for _, tick in
	{
		{ UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(4, 4) },
		{ UDim2.new(0.5, 0, 0, 3), UDim2.fromOffset(2, 7) },
		{ UDim2.new(0.5, 0, 1, -3), UDim2.fromOffset(2, 7) },
		{ UDim2.new(0, 3, 0.5, 0), UDim2.fromOffset(7, 2) },
		{ UDim2.new(1, -3, 0.5, 0), UDim2.fromOffset(7, 2) },
	}
do
	Ui.make("Frame", {
		AnchorPoint = MIDDLE,
		BackgroundColor3 = Ui.colors.text,
		BorderSizePixel = 0,
		Position = tick[1],
		Size = tick[2],
		Parent = crosshair,
	}, { Ui.make("UIStroke", { Color = Ui.colors.panel, Thickness = 1 }) })
end

local hitMarker = Ui.make("Frame", {
	Name = "HitMarker",
	AnchorPoint = MIDDLE,
	BackgroundTransparency = 1,
	Position = CENTER,
	Size = UDim2.fromOffset(28, 28),
	Visible = false,
	Parent = gui,
})
local hitBars: { Frame } = {}
for _, rotation in { 45, -45 } do
	table.insert(
		hitBars,
		Ui.make("Frame", {
			AnchorPoint = MIDDLE,
			BackgroundColor3 = Ui.colors.text,
			BorderSizePixel = 0,
			Position = CENTER,
			Rotation = rotation,
			Size = UDim2.new(1, 0, 0, 3),
			Parent = hitMarker,
		})
	)
end

local vitals = Ui.panel({
	Name = "Vitals",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(460, 58),
	Visible = false,
	Parent = gui,
})

local function bar(name: string, x: number, offset: number, color: Color3): Bar
	local holder = Ui.make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Position = UDim2.new(x, offset, 0, 8),
		Size = UDim2.new(0.5, -21, 1, -16),
		Parent = vitals,
	})
	local who = Ui.label({ Name = "Who", Size = UDim2.new(1, -44, 0, 18), TextSize = 14, Parent = holder })
	local value = Ui.label({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 18),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})
	local track = Ui.make("Frame", {
		Name = "Track",
		BackgroundColor3 = Ui.colors.quiet,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = holder,
	}, { Ui.make("UICorner", { CornerRadius = UDim.new(0, 7) }) })
	local fill = Ui.make("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { Ui.make("UICorner", { CornerRadius = UDim.new(0, 7) }) })
	return { fill = fill, who = who, value = value }
end

local mine = bar("Mine", 0, 14, Ui.colors.accent)
local theirs = bar("Theirs", 0.5, 7, Ui.colors.danger)

-- Red glow from the screen edges, faded out right after a hit
local hurtEdge = Ui.make("CanvasGroup", {
	Name = "HurtEdge",
	BackgroundTransparency = 1,
	GroupTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
})
for _, side in
	{
		{ at = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.12, 1), rotation = 0 },
		{ at = UDim2.fromScale(0.88, 0), size = UDim2.fromScale(0.12, 1), rotation = 180 },
		{ at = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.16), rotation = 90 },
		{ at = UDim2.fromScale(0, 0.84), size = UDim2.fromScale(1, 0.16), rotation = 270 },
	}
do
	Ui.make("Frame", {
		BackgroundColor3 = Ui.colors.danger,
		BorderSizePixel = 0,
		Position = side.at,
		Size = side.size,
		Parent = hurtEdge,
	}, { Ui.make("UIGradient", { Rotation = side.rotation, Transparency = NumberSequence.new(0.1, 1) }) })
end

local downed = Ui.make("Frame", {
	Name = "Downed",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 2,
	Parent = gui,
})
local downedTitle = Ui.label({
	Name = "Title",
	AnchorPoint = MIDDLE,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(1, -32, 0, 70),
	Text = "KNOCKED DOWN",
	TextColor3 = Ui.colors.danger,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 2,
	Parent = downed,
})
Ui.make("UIStroke", { Color = Ui.colors.panel, Thickness = 4, Parent = downedTitle })
Ui.make("UITextSizeConstraint", { MaxTextSize = 64, Parent = downedTitle })
local downedSub = Ui.label({
	Name = "Sub",
	AnchorPoint = MIDDLE,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(1, -32, 0, 30),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 2,
	Parent = downed,
})

local banner = Ui.label({
	Name = "Banner",
	AnchorPoint = MIDDLE,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(1, -32, 0, 40),
	TextColor3 = Ui.colors.accent,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
	Parent = gui,
})
Ui.make("UIStroke", { Color = Ui.colors.panel, Thickness = 3, Parent = banner })
Ui.make("UITextSizeConstraint", { MaxTextSize = 34, Parent = banner })

local CombatHud = {}

local live = false
local opponent: Player? = nil
local watching: { RBXScriptConnection } = {}
local myLastHp = 0
-- Bumped to cancel older timers, same idea as `step` in DuelHud
local markerStep, bannerStep, downedStep = 0, 0, 0

local function isDown(player: Player): boolean
	return player:GetAttribute("Downed") == true
end

local function showBar(entry: Bar, player: Player)
	local hp, max = player:GetAttribute("HP"), player:GetAttribute("MaxHP")
	if typeof(hp) ~= "number" or typeof(max) ~= "number" or max <= 0 then
		return
	end
	entry.value.Text = tostring(hp)
	Ui.tween(entry.fill, 0.15, { Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1) })
end

local function updateCrosshair()
	crosshair.Visible = live and not isDown(localPlayer)
end

local function onMyHp()
	showBar(mine, localPlayer)
	local hp = localPlayer:GetAttribute("HP")
	if typeof(hp) == "number" then
		if hp < myLastHp then
			hurtEdge.GroupTransparency = 0.1
			Ui.tween(hurtEdge, 0.5, { GroupTransparency = 1 })
		end
		myLastHp = hp
	end
end

local function onMyDowned()
	updateCrosshair()
	downedStep += 1
	local step = downedStep
	if isDown(localPlayer) then
		Sfx.play("knockdown")
		downed.Visible = true
		task.spawn(function()
			for remaining = Config.KNOCKDOWN_TIME, 1, -1 do
				if step ~= downedStep then
					return
				end
				downedSub.Text = `Up in {remaining}`
				task.wait(1)
			end
		end)
	elseif downed.Visible then
		downed.Visible = false
		-- HP is cleared first when the duel ends, so this only plays on a real get up
		if localPlayer:GetAttribute("HP") ~= nil then
			Sfx.play("getUp")
		end
	end
end

local function onTheirDowned()
	if not opponent or not isDown(opponent) then
		return
	end
	Sfx.play("knockdown")
	banner.Text = "Knocked them down! Find the cube!"
	banner.Visible = true
	bannerStep += 1
	local step = bannerStep
	task.delay(2.5, function()
		if step == bannerStep then
			banner.Visible = false
		end
	end)
end

local function stopWatching()
	for _, connection in watching do
		connection:Disconnect()
	end
	table.clear(watching)
end

local function watch(player: Player, onHp: () -> (), onDowned: () -> ())
	table.insert(watching, player:GetAttributeChangedSignal("HP"):Connect(onHp))
	table.insert(watching, player:GetAttributeChangedSignal("Downed"):Connect(onDowned))
	onHp()
end

-- White for a body shot, red for a headshot
function CombatHud.hitMarker(part: string)
	for _, line in hitBars do
		line.BackgroundColor3 = if part == "head" then Ui.colors.danger else Ui.colors.text
	end
	hitMarker.Size = UDim2.fromOffset(40, 40)
	hitMarker.Visible = true
	Ui.tween(hitMarker, 0.12, { Size = UDim2.fromOffset(28, 28) })
	markerStep += 1
	local step = markerStep
	task.delay(0.3, function()
		if step == markerStep then
			hitMarker.Visible = false
		end
	end)
end

function CombatHud.onState(payload: Payload)
	local phase = payload.phase
	if phase == "countdown" then
		stopWatching()
		local them = payload.opponent :: Player
		opponent = them
		mine.who.Text = "You"
		theirs.who.Text = them.DisplayName
		myLastHp = Config.DUEL_HEALTH
		watch(localPlayer, onMyHp, onMyDowned)
		watch(them, function()
			showBar(theirs, them)
		end, onTheirDowned)
		vitals.Visible = true
	elseif phase == "live" then
		live = true
	elseif phase == "result" or phase == "ended" then
		live = false
		downedStep += 1
		downed.Visible = false
		banner.Visible = false
		hitMarker.Visible = false
		if phase == "ended" then
			stopWatching()
			opponent = nil
			vitals.Visible = false
		end
	end
	updateCrosshair()
end

return CombatHud
