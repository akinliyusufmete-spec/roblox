--[[
	UiKit (ModuleScript, StarterPlayerScripts.BaldiClient.UiKit)
	Tiny UI construction helpers + the shared color theme. Every ScreenGui
	in the game is built in code through these, so no image assets or
	prefab GUIs are required.
]]

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.theme = {
	chalkboard = Color3.fromRGB(24, 40, 33),
	panel = Color3.fromRGB(18, 22, 20),
	panelLight = Color3.fromRGB(40, 48, 44),
	textPrimary = Color3.fromRGB(245, 245, 240),
	textDim = Color3.fromRGB(170, 175, 170),
	accent = Color3.fromRGB(255, 213, 70), -- school-bus yellow
	green = Color3.fromRGB(80, 200, 120),
	yellow = Color3.fromRGB(240, 200, 60),
	red = Color3.fromRGB(225, 70, 55),
	blue = Color3.fromRGB(90, 160, 255),
	ice = Color3.fromRGB(170, 225, 255),
}

-- Create an instance from a property table. Children listed under the
-- special key [1..n]; Parent is applied last.
function UiKit.new(className, props)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		elseif type(key) == "number" then
			value.Parent = instance
		else
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiKit.corner(radiusPixels)
	return UiKit.new("UICorner", { CornerRadius = UDim.new(0, radiusPixels) })
end

function UiKit.stroke(color, thickness, transparency)
	return UiKit.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UiKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.theme.textPrimary,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UiKit.new("TextLabel", defaults)
end

function UiKit.button(props)
	local defaults = {
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.theme.panel,
		BackgroundColor3 = UiKit.theme.accent,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local button = UiKit.new("TextButton", defaults)
	UiKit.corner(10).Parent = button
	return button
end

function UiKit.tween(instance, time, props, style)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- quick shake for "exhausted" / error feedback
function UiKit.shake(guiObject, magnitude)
	magnitude = magnitude or 6
	local original = guiObject.Position
	task.spawn(function()
		for i = 1, 4 do
			local offset = (i % 2 == 0) and magnitude or -magnitude
			guiObject.Position = original + UDim2.fromOffset(offset, 0)
			task.wait(0.04)
		end
		guiObject.Position = original
	end)
end

return UiKit
