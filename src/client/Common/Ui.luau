--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FULL_TIMER = UDim2.new(1, -28, 0, 3)

local Ui = {}

Ui.colors = {
	panel = Color3.fromRGB(18, 23, 43),
	edge = Color3.fromRGB(54, 224, 194),
	text = Color3.fromRGB(240, 244, 255),
	muted = Color3.fromRGB(160, 170, 200),
	accent = Color3.fromRGB(54, 224, 194),
	onAccent = Color3.fromRGB(10, 22, 30),
	danger = Color3.fromRGB(255, 84, 112),
	quiet = Color3.fromRGB(52, 60, 92),
}

function Ui.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance: any = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = props.Parent
	return instance
end

function Ui.screen(name: string, order: number): ScreenGui
	return Ui.make("ScreenGui", {
		Name = name,
		DisplayOrder = order,
		ResetOnSpawn = false, -- otherwise every respawn would wipe the UI
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

function Ui.panel(props: { [string]: any }): Frame
	local defaults = { BackgroundColor3 = Ui.colors.panel, BorderSizePixel = 0 }
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("Frame", defaults, {
		Ui.make("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Ui.make("UIStroke", { Color = Ui.colors.edge, Thickness = 2, Transparency = 0.25 }),
	})
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.colors.text,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextLabel", defaults)
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = Ui.colors.accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.colors.onAccent,
		TextSize = 16,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextButton", defaults, {
		Ui.make("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
end

function Ui.avatar(props: { [string]: any }): ImageLabel
	local defaults = { BackgroundColor3 = Ui.colors.quiet, BorderSizePixel = 0 }
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("ImageLabel", defaults, {
		Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ui.label({
			Name = "Initial",
			Size = UDim2.fromScale(1, 1),
			TextSize = 28,
			TextTruncate = Enum.TextTruncate.None,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

-- Shows the first letter until the photo loads. Studio test players never have a photo,
-- their ids are made up.
function Ui.setAvatar(image: ImageLabel, player: Player)
	local initial = image:FindFirstChild("Initial") :: TextLabel
	initial.Text = string.upper(string.sub(player.DisplayName, 1, 1))
	initial.Visible = true
	image.Image = ""
	if player.UserId <= 0 then
		return
	end

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok then
			image.Image = content
			initial.Visible = false
		end
	end)
end

function Ui.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- The thin bar along the bottom of a panel that shows how long is left to answer
function Ui.timerBar(parent: Instance): Frame
	return Ui.make("Frame", {
		Name = "Timer",
		BackgroundColor3 = Ui.colors.accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 1, -7),
		Size = FULL_TIMER,
		Parent = parent,
	})
end

function Ui.drainTimer(bar: Frame, seconds: number): Tween
	bar.Size = FULL_TIMER
	return Ui.tween(bar, seconds, { Size = UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Linear)
end

return Ui
