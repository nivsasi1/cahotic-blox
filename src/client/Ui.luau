--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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
	})
end

-- Studio test players have made-up ids with no picture, so this can fail
function Ui.setAvatar(image: ImageLabel, player: Player)
	image.Image = ""
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

return Ui
