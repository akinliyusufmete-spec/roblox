--[[
	MenuController (ModuleScript, StarterPlayerScripts.BaldiClient.MenuController)

	Every full-screen state the player sees outside of live play:
	  - Main menu: title, PLAY, best time, controls list (fade transitions)
	  - Countdown: "Get ready..." 3-2-1 between pressing Play and spawning
	  - Win screen: ESCAPED! + time + best + Retry / Menu (green accent)
	  - Lose screen: CAUGHT! + catcher + cause + Retry / Menu (red accent)

	Your art (AssetConfig.IMAGES): MENU_BACKGROUND, COUNTDOWN_BACKGROUND,
	WIN_BACKGROUND, LOSE_BACKGROUND fill each screen edge to edge (like the
	original game's title art); PLAY_BUTTON replaces the PLAY button; PANEL
	backs the HOW TO PLAY box.

	Also orchestrates the round lifecycle on the client: shows/hides the
	HUD, enables/disables the stamina controller, and locks the camera to
	first person during play.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MenuController = {}

function MenuController.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local images = ctx.assets.IMAGES
	local sounds = ctx.controllers.SoundController
	local hud = ctx.controllers.HudController
	local stamina = ctx.controllers.StaminaController
	local self = { inRound = false }

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiMenu",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		Parent = playerGui,
	})

	-- ===================== camera helpers =====================

	local function firstPersonCamera(enabled)
		if not ctx.config.FIRST_PERSON then
			return
		end
		if enabled then
			-- shrink Min first so Min <= Max holds at every step
			ctx.player.CameraMinZoomDistance = 0.5
			ctx.player.CameraMaxZoomDistance = 0.5
		else
			ctx.player.CameraMaxZoomDistance = 16
			ctx.player.CameraMinZoomDistance = 6
		end
	end

	-- While the main menu is up, the camera sits on the MENU_CAMERA marker
	-- part, looking the way the part faces. Held every frame (a respawn
	-- resets the camera otherwise); released the moment play starts.
	local menuCameraConn = nil
	local function menuCamera(enabled)
		local cfg = ctx.config.MENU_CAMERA
		local camera = Workspace.CurrentCamera
		if enabled and cfg then
			if menuCameraConn then
				return -- already holding the shot
			end
			local part = nil
			local nextSearch = 0
			menuCameraConn = RunService.RenderStepped:Connect(function()
				local cam = Workspace.CurrentCamera
				if not cam then
					return
				end
				if not part or not part:IsDescendantOf(Workspace) then
					-- the map may build after the menu first shows; keep
					-- looking (cheaply) until the marker exists
					if os.clock() < nextSearch then
						return
					end
					nextSearch = os.clock() + 1
					local found = Workspace:FindFirstChild(cfg.PART_NAME or "MENU_CAMERA", true)
					if found and found:IsA("BasePart") then
						part = found
					else
						return -- no marker: leave the camera alone
					end
				end
				cam.CameraType = Enum.CameraType.Scriptable
				cam.FieldOfView = cfg.FIELD_OF_VIEW or 70
				cam.CFrame = part.CFrame
			end)
		else
			if menuCameraConn then
				menuCameraConn:Disconnect()
				menuCameraConn = nil
			end
			if camera then
				camera.CameraType = Enum.CameraType.Custom
				camera.FieldOfView = 70
			end
		end
	end

	-- ===================== screen scaffolding =====================

	local screens = {}

	-- imageKey: AssetConfig.IMAGES entry used as the full-screen backdrop
	local function makeScreen(name, backgroundColor, imageKey)
		local screen = UiKit.new("CanvasGroup", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0,
			Visible = false,
			Parent = gui,
		})
		if imageKey and UiKit.hasImage(images[imageKey]) then
			UiKit.backdrop(screen, images[imageKey])
		end
		screens[name] = screen
		return screen
	end

	local function showScreen(name)
		menuCamera(name == "main") -- orbit the school only behind the main menu
		for screenName, screen in pairs(screens) do
			if screenName == name then
				screen.GroupTransparency = 1
				screen.Visible = true
				UiKit.tween(screen, 0.3, { GroupTransparency = 0 })
			elseif screen.Visible then
				local closing = screen
				UiKit.tween(closing, 0.25, { GroupTransparency = 1 }).Completed:Connect(function()
					if closing.GroupTransparency > 0.95 then
						closing.Visible = false
					end
				end)
			end
		end
	end

	local function hideAllScreens()
		for _, screen in pairs(screens) do
			if screen.Visible then
				local closing = screen
				UiKit.tween(closing, 0.3, { GroupTransparency = 1 }).Completed:Connect(function()
					closing.Visible = false
				end)
			end
		end
	end

	local function formatTime(seconds)
		local minutes = math.floor(seconds / 60)
		local remainder = seconds - minutes * 60
		return string.format("%d:%04.1f", minutes, remainder)
	end

	-- ===================== main menu =====================

	local mainMenu = makeScreen("main", theme.chalkboard, "MENU_BACKGROUND")
	-- no flat background art? let the orbiting school show through instead
	if not UiKit.hasImage(images.MENU_BACKGROUND) then
		mainMenu.BackgroundTransparency = 1
	end

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(0.9, 0, 0, 84),
		Text = ctx.config.GAME_TITLE,
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = mainMenu,
	})
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.245),
		Size = UDim2.new(0.8, 0, 0, 24),
		Text = ctx.config.GAME_SUBTITLE,
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local playButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(260, 64),
		Text = "PLAY",
		Parent = mainMenu,
	}, images.PLAY_BUTTON)

	local bestTimeLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, 22),
		Text = "Best time: --",
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local controlsPanel = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.35,
		Parent = mainMenu,
	}, images.PANEL)
	if controlsPanel:IsA("Frame") then
		UiKit.corner(12).Parent = controlsPanel
	end
	UiKit.label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "HOW TO PLAY",
		TextColor3 = theme.accent,
		Parent = controlsPanel,
	})
	UiKit.label({
		Position = UDim2.fromOffset(24, 38),
		Size = UDim2.new(1, -48, 1, -50),
		Text = table.concat({
			"Collect all the notebooks, then escape through the EXIT.",
			"WASD — move   |   Shift — sprint (drains stamina)",
			"E — use item   |   Q — swap item slots",
			"ChatRevive chases on sight. Don't let it touch you.",
			"LP detains anyone he SEES moving too fast. Walk near him.",
			"Frosty is harmless... but his chill slows you down.",
		}, "\n"),
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = theme.textPrimary,
		Parent = controlsPanel,
	})

	-- ===================== countdown screen =====================

	local countdownScreen = makeScreen("countdown", theme.chalkboard, "COUNTDOWN_BACKGROUND")
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.new(0.9, 0, 0, 48),
		Text = "Get ready...",
		Parent = countdownScreen,
	})
	local countdownNumber = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(200, 120),
		Text = "3",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = countdownScreen,
	})

	-- ===================== end screens =====================

	local function makeEndScreen(name, accent, titleText, imageKey)
		local screen = makeScreen(name, theme.chalkboard, imageKey)
		UiKit.new("Frame", { -- accent strip
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.new(0.6, 0, 0, 6),
			BackgroundColor3 = accent,
			Parent = screen,
			UiKit.corner(3),
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.22),
			Size = UDim2.new(0.9, 0, 0, 76),
			Text = titleText,
			TextColor3 = accent,
			TextStrokeTransparency = 0,
			Parent = screen,
		})
		local detailLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0.8, 0, 0, 30),
			Text = "",
			Parent = screen,
		})
		local subLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.new(0.8, 0, 0, 22),
			Text = "",
			TextColor3 = theme.textDim,
			Parent = screen,
		})
		local retryButton = UiKit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, -90, 0.6, 0),
			Size = UDim2.fromOffset(160, 52),
			Text = "RETRY",
			BackgroundColor3 = accent,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = screen,
		})
		local menuButton = UiKit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 90, 0.6, 0),
			Size = UDim2.fromOffset(160, 52),
			Text = "MENU",
			BackgroundColor3 = theme.panelLight,
			TextColor3 = theme.textPrimary,
			Parent = screen,
		})
		return { screen = screen, detail = detailLabel, sub = subLabel, retry = retryButton, menu = menuButton }
	end

	local winScreen = makeEndScreen("win", theme.green, "ESCAPED!", "WIN_BACKGROUND")
	local loseScreen = makeEndScreen("lose", theme.red, "CAUGHT!", "LOSE_BACKGROUND")

	-- ===================== round lifecycle =====================

	local function enterRound()
		self.inRound = true
		hideAllScreens()
		menuCamera(false) -- stop the orbit; the round camera follows the player
		hud.show()
		stamina.setEnabled(true)
		firstPersonCamera(true)
	end

	local function exitRound()
		self.inRound = false
		hud.hide()
		stamina.setEnabled(false)
		firstPersonCamera(false)
	end

	local function requestStart()
		sounds.play("click")
		ctx.remotes.RequestStart:FireServer()
	end

	playButton.Activated:Connect(requestStart)
	winScreen.retry.Activated:Connect(requestStart)
	loseScreen.retry.Activated:Connect(requestStart)
	winScreen.menu.Activated:Connect(function()
		sounds.play("click")
		showScreen("main")
	end)
	loseScreen.menu.Activated:Connect(function()
		sounds.play("click")
		showScreen("main")
	end)

	ctx.remotes.GameCountdown.OnClientEvent:Connect(function(seconds)
		showScreen("countdown")
		task.spawn(function()
			for remaining = seconds, 1, -1 do
				if screens.countdown.Visible == false then
					return
				end
				countdownNumber.Text = tostring(remaining)
				countdownNumber.TextTransparency = 0
				sounds.play("click", 1 + (seconds - remaining) * 0.15)
				task.wait(1)
			end
			countdownNumber.Text = "GO!"
		end)
	end)

	ctx.remotes.GameStarted.OnClientEvent:Connect(function(notebooksTotal)
		hud.resetForRound(notebooksTotal or ctx.config.NOTEBOOK_SPAWN_COUNT)
		enterRound()
	end)

	ctx.remotes.PlayerWon.OnClientEvent:Connect(function(elapsed, best)
		exitRound()
		sounds.winJingle()
		winScreen.detail.Text = "Time: " .. formatTime(elapsed)
		winScreen.sub.Text = "Session best: " .. formatTime(best)
		bestTimeLabel.Text = "Best time: " .. formatTime(best)
		showScreen("win")
	end)

	ctx.remotes.PlayerLost.OnClientEvent:Connect(function(catcherName, cause)
		exitRound()
		sounds.play("caught")
		loseScreen.detail.Text = "Caught by " .. tostring(catcherName)
		loseScreen.sub.Text = tostring(cause or "")
		showScreen("lose")
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(function()
		-- safety net: if the round collapsed while we thought we were in it
		-- (and no win/lose screen arrived), fall back to the menu
		if self.inRound then
			exitRound()
			showScreen("main")
		end
	end)

	-- boot state: menu visible, HUD hidden, third person in the lobby
	exitRound()
	showScreen("main")

	return self
end

return MenuController
