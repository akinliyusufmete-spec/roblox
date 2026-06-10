--[[
	FrostyVignette (ModuleScript, StarterPlayerScripts.BaldiClient.FrostyVignette)

	Receives Frosty's SpeedDebuff remote:
	  - tells StaminaController to apply the WalkSpeed multiplier (0.4x, 4s)
	  - shows an icy screen-edge vignette (four gradient strips fading
	    toward the center — no image assets needed) until the chill expires
]]

local FrostyVignette = {}

function FrostyVignette.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local stamina = ctx.controllers.StaminaController
	local sounds = ctx.controllers.SoundController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiFrost",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	-- four edge strips, each with a gradient fading toward the screen center
	local function edgeStrip(anchorPoint, position, size, gradientRotation)
		local strip = UiKit.new("Frame", {
			AnchorPoint = anchorPoint,
			Position = position,
			Size = size,
			BackgroundColor3 = theme.ice,
			BorderSizePixel = 0,
			Parent = gui,
		})
		UiKit.new("UIGradient", {
			Rotation = gradientRotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = strip,
		})
		return strip
	end

	edgeStrip(Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.new(1, 0, 0.18, 0), 90) -- top
	edgeStrip(Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.new(1, 0, 0.18, 0), -90) -- bottom
	edgeStrip(Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.new(0.14, 0, 1, 0), 0) -- left
	edgeStrip(Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), UDim2.new(0.14, 0, 1, 0), 180) -- right

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(300, 24),
		Text = "Frosty chilled you! You feel slow...",
		TextColor3 = theme.ice,
		TextStrokeTransparency = 0.5,
		Parent = gui,
	})

	local expiresAt = 0

	ctx.remotes.SpeedDebuff.OnClientEvent:Connect(function(duration, multiplier)
		stamina.applyDebuff(multiplier, duration)
		expiresAt = os.clock() + duration
		gui.Enabled = true
		sounds.play("frost")

		task.delay(duration, function()
			if os.clock() >= expiresAt then
				gui.Enabled = false
			end
		end)
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(function()
		gui.Enabled = false
	end)

	return self
end

return FrostyVignette
