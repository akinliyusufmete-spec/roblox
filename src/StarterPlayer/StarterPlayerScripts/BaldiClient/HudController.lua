--[[
	HudController (ModuleScript, StarterPlayerScripts.BaldiClient.HudController)

	The persistent in-game overlay (HUD shell from the plan):
	  - notebook counter (top center) + objective line
	  - nickel count with coin icon (top right)
	  - stamina bar (bottom center) — visuals only; logic in StaminaController
	  - two item slots (bottom right) + "Inventory full" flash
	  - center banner for phase changes ("EXIT IS OPEN!")
	  - mobile Sprint / Use / Swap buttons when touch is enabled

	Subscribes to its own data remotes: NotebookCollected, NickelChanged,
	InventoryChanged is consumed by ItemUseClient which calls setSlots.
]]

local UiKit

local HudController = {}

function HudController.init(ctx)
	UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local self = { mobile = {} }
	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local sounds = ctx.controllers.SoundController

	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiHUD",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	-- ===================== notebook counter (top center) =====================

	local notebookFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(250, 46),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.25,
		Parent = gui,
		UiKit.corner(10),
	})
	local notebookScale = UiKit.new("UIScale", { Parent = notebookFrame })
	UiKit.new("Frame", { -- little red book icon
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(22, 28),
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		Parent = notebookFrame,
		UiKit.corner(4),
	})
	local notebookLabel = UiKit.label({
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = "Notebooks: 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notebookFrame,
	})

	local objectiveLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(420, 22),
		Text = "Collect 10 notebooks!",
		TextColor3 = theme.textDim,
		Font = Enum.Font.Gotham,
		Parent = gui,
	})

	-- ===================== nickel counter (top right) =====================

	local nickelFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(140, 46),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.25,
		Parent = gui,
		UiKit.corner(10),
	})
	UiKit.new("Frame", { -- coin icon
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(255, 210, 70),
		Parent = nickelFrame,
		UiKit.corner(14),
		UiKit.stroke(Color3.fromRGB(180, 140, 30), 2),
	})
	local nickelLabel = UiKit.label({
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = "x 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nickelFrame,
	})

	-- ===================== stamina bar (bottom center) =====================

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(120, 16),
		Text = "STAMINA",
		TextColor3 = theme.textDim,
		Parent = gui,
	})
	local staminaBack = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.2,
		Parent = gui,
		UiKit.corner(8),
		UiKit.stroke(Color3.fromRGB(0, 0, 0), 1, 0.5),
	})
	local staminaFillArea = UiKit.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = staminaBack,
	})
	local staminaFill = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.green,
		Parent = staminaFillArea,
		UiKit.corner(6),
	})
	local coldTag = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(160, 18),
		Text = "COLD! Slowed...",
		TextColor3 = theme.ice,
		Visible = false,
		Parent = gui,
	})

	-- ===================== item slots (bottom right) =====================

	local slotsFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(198, 118),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local function buildSlot(xOffset, hintText, isActive)
		local slot = UiKit.new("Frame", {
			Position = UDim2.fromOffset(xOffset, 0),
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = theme.panel,
			BackgroundTransparency = 0.2,
			Parent = slotsFrame,
			UiKit.corner(12),
			UiKit.stroke(isActive and theme.accent or Color3.fromRGB(90, 95, 90), isActive and 3 or 2),
		})
		local icon = UiKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = theme.panelLight,
			Visible = false,
			Parent = slot,
			UiKit.corner(10),
		})
		local iconText = UiKit.label({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.5,
			Parent = icon,
		})
		local emptyText = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 20),
			Text = "empty",
			TextColor3 = Color3.fromRGB(110, 115, 110),
			Font = Enum.Font.Gotham,
			Parent = slot,
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(92, 18),
			Text = hintText,
			TextColor3 = theme.textDim,
			Font = Enum.Font.Gotham,
			Parent = slot,
		})
		return { frame = slot, icon = icon, iconText = iconText, emptyText = emptyText }
	end

	local slot1 = buildSlot(0, "[E] Use", true)
	local slot2 = buildSlot(106, "[Q] Swap", false)

	local fullFlash = UiKit.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -142),
		Size = UDim2.fromOffset(198, 24),
		Text = "Inventory full",
		TextColor3 = theme.red,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== center banner =====================

	local banner = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 54),
		Text = "",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== mobile buttons =====================

	if ctx.controllers.InputHandler.touchEnabled then
		local sprintButton = UiKit.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 18, 1, -90),
			Size = UDim2.fromOffset(96, 96),
			Text = "RUN",
			BackgroundColor3 = theme.green,
			Parent = gui,
		})
		local useButton = UiKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -230, 1, -16),
			Size = UDim2.fromOffset(80, 56),
			Text = "USE",
			Parent = gui,
		})
		local swapButton = UiKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -230, 1, -80),
			Size = UDim2.fromOffset(80, 38),
			Text = "SWAP",
			BackgroundColor3 = theme.panelLight,
			TextColor3 = theme.textPrimary,
			Parent = gui,
		})
		self.mobile = { sprintButton = sprintButton, useButton = useButton, swapButton = swapButton }

		-- sprint is a toggle on mobile
		local sprintOn = false
		sprintButton.Activated:Connect(function()
			sprintOn = not sprintOn
			sprintButton.BackgroundColor3 = sprintOn and theme.yellow or theme.green
			ctx.controllers.InputHandler.notifySprint(sprintOn)
		end)
		useButton.Activated:Connect(function()
			ctx.controllers.InputHandler.notifyUse()
		end)
		swapButton.Activated:Connect(function()
			ctx.controllers.InputHandler.notifySwap()
		end)
	end

	-- ===================== API =====================

	function self.show()
		gui.Enabled = true
	end

	function self.hide()
		gui.Enabled = false
	end

	function self.setObjective(text)
		objectiveLabel.Text = text
	end

	local lastNotebookCount = 0
	function self.setNotebooks(collected, total)
		notebookLabel.Text = string.format("Notebooks: %d/%d", collected, total)
		if collected > lastNotebookCount then
			sounds.play("collect")
			notebookScale.Scale = 1.18
			UiKit.tween(notebookScale, 0.25, { Scale = 1 })
		end
		lastNotebookCount = collected
	end

	function self.resetForRound(total)
		lastNotebookCount = 0
		notebookLabel.Text = string.format("Notebooks: 0/%d", total)
		self.setObjective("Collect " .. total .. " notebooks!")
	end

	function self.setNickels(count)
		nickelLabel.Text = "x " .. count
	end

	-- mode: "ok" | "low" | "exhausted"; cold: boolean
	local lastMode = "ok"
	function self.setStamina(alpha, mode, cold)
		staminaFill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		coldTag.Visible = cold == true
		if mode ~= lastMode then
			lastMode = mode
			local color = theme.green
			if mode == "low" then
				color = theme.yellow
			elseif mode == "exhausted" then
				color = theme.red
				UiKit.shake(staminaBack, 7)
				sounds.play("exhausted")
			end
			UiKit.tween(staminaFill, 0.2, { BackgroundColor3 = color })
		end
	end

	function self.flashStaminaFull()
		staminaFill.BackgroundColor3 = theme.green
		staminaFill.BackgroundTransparency = 0.6
		UiKit.tween(staminaFill, 0.4, { BackgroundTransparency = 0 })
	end

	local function renderSlot(slot, itemId)
		if itemId then
			local def = ctx.config.ITEMS[itemId]
			slot.icon.Visible = true
			slot.icon.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			slot.iconText.Text = def.shortLabel
			slot.emptyText.Visible = false
		else
			slot.icon.Visible = false
			slot.emptyText.Visible = true
		end
	end

	function self.setSlots(itemId1, itemId2)
		renderSlot(slot1, itemId1)
		renderSlot(slot2, itemId2)
	end

	function self.flashPickupFailed(message)
		fullFlash.Text = message or "Inventory full"
		fullFlash.TextTransparency = 0
		sounds.play("error")
		task.delay(1.5, function()
			UiKit.tween(fullFlash, 0.4, { TextTransparency = 1 })
		end)
	end

	function self.banner(text, color)
		banner.Text = text
		banner.TextColor3 = color or theme.accent
		banner.TextTransparency = 0
		task.delay(2.2, function()
			UiKit.tween(banner, 0.6, { TextTransparency = 1 })
		end)
	end

	-- ===================== remote subscriptions =====================

	ctx.remotes.NotebookCollected.OnClientEvent:Connect(function(collected, total)
		self.setNotebooks(collected, total)
	end)

	ctx.remotes.NickelChanged.OnClientEvent:Connect(function(count)
		local previousText = nickelLabel.Text
		self.setNickels(count)
		if gui.Enabled and previousText ~= nickelLabel.Text then
			sounds.play("nickel")
		end
	end)

	ctx.remotes.PickupFailed.OnClientEvent:Connect(function(message)
		self.flashPickupFailed(message)
	end)

	ctx.remotes.PhaseChanged.OnClientEvent:Connect(function(phaseName)
		if phaseName == "CHARACTERS_ACTIVE" then
			self.banner("You hear footsteps...", UiKit.theme.red)
			self.setObjective("Keep collecting — they're awake.")
		elseif phaseName == "EXIT_OPEN" then
			self.banner("ALL NOTEBOOKS! GET TO THE EXIT!", UiKit.theme.green)
			self.setObjective("Escape through the EXIT door (entrance corridor)!")
			sounds.play("collect", 0.7)
		end
	end)

	return self
end

return HudController
