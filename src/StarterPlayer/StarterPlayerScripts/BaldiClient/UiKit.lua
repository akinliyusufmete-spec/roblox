--[[
	UiKit (ModuleScript, StarterPlayerScripts.BaldiClient.UiKit)

	UI construction helpers + the shared theme. Every ScreenGui in the game
	is built in code through these.

	Image support: most helpers take an optional image id (from
	AssetConfig.IMAGES). With an id they build ImageLabels/ImageButtons so
	your art becomes the background; with "" they fall back to plain
	colored frames — so the UI works before any art exists.

	The default font is Cartoon (Comic Neue Angular), the closest built-in
	match to the original game's Comic Sans look.
]]

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.font = Enum.Font.Cartoon

UiKit.theme = {
	chalkboard = Color3.fromRGB(24, 40, 33),
	panel = Color3.fromRGB(18, 22, 20),
	panelLight = Color3.fromRGB(40, 48, 44),
	white = Color3.fromRGB(245, 245, 240),
	textPrimary = Color3.fromRGB(245, 245, 240),
	textDim = Color3.fromRGB(190, 195, 190),
	textDark = Color3.fromRGB(25, 25, 25),
	accent = Color3.fromRGB(255, 213, 70), -- school-bus yellow
	green = Color3.fromRGB(80, 200, 120),
	yellow = Color3.fromRGB(240, 200, 60),
	red = Color3.fromRGB(225, 70, 55),
	blue = Color3.fromRGB(90, 160, 255),
	ice = Color3.fromRGB(170, 225, 255),
}

function UiKit.hasImage(imageId)
	return type(imageId) == "string" and imageId ~= ""
end

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

-- Text label: Cartoon font, white with a black outline by default — the
-- original game draws its HUD text straight over the 3D view like this.
function UiKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UiKit.font,
		TextColor3 = UiKit.theme.textPrimary,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.25,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UiKit.new("TextLabel", defaults)
end

-- Container that is your image when you have one, a colored frame when
-- you don't. Children parent into it either way.
function UiKit.panel(props, imageId)
	if UiKit.hasImage(imageId) then
		local imageProps = {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Stretch,
		}
		for key, value in pairs(props) do
			if key ~= "BackgroundColor3" and key ~= "BackgroundTransparency" then
				imageProps[key] = value
			end
		end
		return UiKit.new("ImageLabel", imageProps)
	end
	return UiKit.new("Frame", props)
end

-- Button: an ImageButton showing your art (any Text prop is dropped —
-- bake the text into the image), or a yellow TextButton fallback.
function UiKit.button(props, imageId)
	if UiKit.hasImage(imageId) then
		local imageProps = {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = true,
		}
		for key, value in pairs(props) do
			if key ~= "Text" and key ~= "TextColor3" and key ~= "Font"
				and key ~= "BackgroundColor3" and key ~= "TextScaled" then
				imageProps[key] = value
			end
		end
		return UiKit.new("ImageButton", imageProps)
	end
	local defaults = {
		Font = UiKit.font,
		TextColor3 = UiKit.theme.textDark,
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

-- Full-bleed background for a screen/overlay: your image, or a solid color.
function UiKit.backdrop(parent, imageId, fallbackColor, fallbackTransparency)
	if UiKit.hasImage(imageId) then
		return UiKit.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 0,
			Parent = parent,
		})
	end
	return UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fallbackColor,
		BackgroundTransparency = fallbackTransparency or 0,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = parent,
	})
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
