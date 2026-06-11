--[[
	SilverMinigame (ModuleScript, StarterPlayerScripts.BaldiClient.SilverMinigame)

	Shown while Silver has you grabbed. A cube slides back and forth along
	a bar; click HIT (or press E, or tap the bar) exactly while the cube is
	inside the center zone. Land GRAB_HITS perfect hits to wriggle free.
	Each hit speeds the cube up. If you're carrying Safety Scissors, a CUT
	FREE button escapes instantly (and leaves Silver snipped).

	The server validates hits (minimum gap between them) and releases you;
	this UI closes on the SilverReleased remote.

	Your art: AssetConfig.IMAGES.SILVER_OVERLAY backs the screen.
	Tuning lives in GameConfig.NPC.SILVER (window, period, speedup).
]]

local RunService = game:GetService("RunService")

local SilverMinigame = {}

function SilverMinigame.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local cfg = ctx.config.NPC.SILVER
	local sounds = ctx.controllers.SoundController
	local stamina = ctx.controllers.StaminaController
	local self = { active = false }

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiSilverGrab",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	UiKit.backdrop(gui, ctx.assets.IMAGES.SILVER_OVERLAY, Color3.fromRGB(18, 18, 26), 0.4)

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.new(0.9, 0, 0, 60),
		Text = "SILVER GRABBED YOU!",
		TextColor3 = Color3.fromRGB(220, 225, 235),
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.31),
		Size = UDim2.new(0.9, 0, 0, 24),
		Text = "Hit the cube in the green zone to wriggle free!",
		TextColor3 = theme.textDim,
		Parent = gui,
	})

	local progressLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(200, 40),
		Text = "0 / 5",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	-- ---------- the timing bar ----------

	local barBack = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.55, 0, 0, 34),
		BackgroundColor3 = theme.panel,
		Parent = gui,
		UiKit.corner(10),
	})
	UiKit.stroke(Color3.fromRGB(0, 0, 0), 2, 0.4).Parent = barBack

	-- the green target zone, centered, width = the timing window both ways
	local zone = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(cfg.GRAB_HIT_WINDOW * 2, 0, 1, -6),
		BackgroundColor3 = theme.green,
		BackgroundTransparency = 0.35,
		Parent = barBack,
		UiKit.corner(8),
	})

	local cube = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.white,
		ZIndex = 2,
		Parent = barBack,
		UiKit.corner(6),
	})
	UiKit.stroke(Color3.fromRGB(0, 0, 0), 2).Parent = cube

	local hitButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(220, 64),
		Text = "HIT!  [E]",
		Parent = gui,
	})

	local scissorsButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromOffset(260, 46),
		Text = "CUT FREE (use Scissors)",
		BackgroundColor3 = theme.panelLight,
		TextColor3 = theme.textPrimary,
		Visible = false,
		Parent = gui,
	})

	-- ---------- behaviour ----------

	local hits = 0
	local hitsRequired = cfg.GRAB_HITS
	local period = cfg.GRAB_CUBE_PERIOD
	local clock = 0
	local alpha = 0.5

	local function hasScissors()
		local items = ctx.controllers.ItemUseClient
		return items ~= nil and (items.slots[1] == "SCISSORS" or items.slots[2] == "SCISSORS")
	end

	RunService.RenderStepped:Connect(function(dt)
		if not self.active then
			return
		end
		clock = clock + dt
		alpha = 0.5 + 0.5 * math.sin(clock * math.pi * 2 / period)
		cube.Position = UDim2.new(alpha, 0, 0.5, 0)
	end)

	local function attemptHit()
		if not self.active then
			return
		end
		if math.abs(alpha - 0.5) <= cfg.GRAB_HIT_WINDOW then
			hits = hits + 1
			period = period / cfg.GRAB_SPEEDUP -- faster every time
			progressLabel.Text = hits .. " / " .. hitsRequired
			ctx.remotes.SilverHit:FireServer()
			sounds.play("click", 1 + hits * 0.12)
			zone.BackgroundTransparency = 0
			UiKit.tween(zone, 0.25, { BackgroundTransparency = 0.35 })
			if hits >= hitsRequired then
				progressLabel.Text = "FREE!"
				progressLabel.TextColor3 = theme.green
			end
		else
			sounds.play("error")
			UiKit.shake(barBack, 8)
		end
	end

	hitButton.Activated:Connect(attemptHit)
	barBack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			attemptHit()
		end
	end)
	-- E doubles as the hit key (ItemUseClient yields to us while active)
	ctx.controllers.InputHandler.onUse(function()
		if self.active then
			attemptHit()
		end
	end)

	scissorsButton.Activated:Connect(function()
		if self.active and hasScissors() then
			ctx.remotes.SilverEscape:FireServer()
		end
	end)

	-- ---------- open / close ----------

	ctx.remotes.SilverGrab.OnClientEvent:Connect(function(required)
		hits = 0
		hitsRequired = required or cfg.GRAB_HITS
		period = cfg.GRAB_CUBE_PERIOD
		clock = 0
		progressLabel.Text = "0 / " .. hitsRequired
		progressLabel.TextColor3 = theme.accent
		scissorsButton.Visible = hasScissors()
		self.active = true
		gui.Enabled = true
		stamina.setSprintLocked(true)
		sounds.play("grab")
	end)

	local function close()
		if not self.active then
			return
		end
		self.active = false
		gui.Enabled = false
		stamina.setSprintLocked(false)
	end

	ctx.remotes.SilverReleased.OnClientEvent:Connect(close)
	ctx.remotes.RoundEnded.OnClientEvent:Connect(close)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(close)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(close)

	-- keep the scissors button honest if inventory changes mid-grab
	ctx.remotes.InventoryChanged.OnClientEvent:Connect(function()
		if self.active then
			scissorsButton.Visible = hasScissors()
		end
	end)

	self.close = close
	return self
end

return SilverMinigame
