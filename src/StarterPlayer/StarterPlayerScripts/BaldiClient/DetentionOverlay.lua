--[[
	DetentionOverlay (ModuleScript, StarterPlayerScripts.BaldiClient.DetentionOverlay)

	Shown while LP has you in detention. The server anchors your character;
	this overlay shows the countdown and locks the sprint key so the bar
	doesn't drain while you stand there fuming.

	Your art: AssetConfig.IMAGES.DETENTION_BACKGROUND fills the screen
	(use a semi-transparent PNG so the player still sees the room).
]]

local DetentionOverlay = {}

function DetentionOverlay.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local stamina = ctx.controllers.StaminaController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiDetention",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	UiKit.backdrop(gui, ctx.assets.IMAGES.DETENTION_BACKGROUND, Color3.fromRGB(20, 8, 8), 0.45)

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.9, 0, 0, 70),
		Text = "DETENTION!",
		TextColor3 = theme.red,
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	local quoteLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 28),
		Text = '"No running in the halls."',
		TextColor3 = theme.textDim,
		Parent = gui,
	})

	local countdownLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(220, 84),
		Text = "15",
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	local active = false

	ctx.remotes.SendToDetention.OnClientEvent:Connect(function(seconds, byName)
		active = true
		quoteLabel.Text = '"No running in the halls." — ' .. (byName or "LP")
		gui.Enabled = true
		stamina.setSprintLocked(true)
		sounds.play("detention")

		local releaseAt = os.clock() + seconds
		task.spawn(function()
			while active and os.clock() < releaseAt do
				countdownLabel.Text = tostring(math.max(0, math.ceil(releaseAt - os.clock())))
				task.wait(0.1)
			end
		end)
	end)

	local function release()
		if not active then
			return
		end
		active = false
		gui.Enabled = false
		stamina.setSprintLocked(false)
	end

	ctx.remotes.DetentionReleased.OnClientEvent:Connect(release)
	ctx.remotes.RoundEnded.OnClientEvent:Connect(release)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(release)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(release)

	self.release = release
	return self
end

return DetentionOverlay
