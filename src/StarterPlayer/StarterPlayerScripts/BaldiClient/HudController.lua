--[[
	HudController (ModuleScript, StarterPlayerScripts.BaldiClient.HudController)

	The persistent in-game overlay, laid out like the original game:
	  - "Notebooks: 0/10" in the TOP LEFT, plain comic text drawn straight
	    over the 3D view, with a little notebook icon
	  - item slots in the TOP RIGHT as white squares, nickel count under
	  - stamina bar bottom center
	  - center banner for phase changes ("GET TO THE EXIT!")
	  - mobile Sprint / Use / Swap buttons when touch is enabled

	Your art (AssetConfig.IMAGES): NOTEBOOK_ICON, ITEM_SLOT, ITEMS.<id>,
	NICKEL_ICON, STAMINA_BACK, STAMINA_FILL. Everything falls back to
	plain shapes when an id is "".

	Subscribes to its own data remotes: NotebookCollected, NickelChanged,
	PickupFailed, PhaseChanged. InventoryChanged is consumed by
	ItemUseClient, which calls setSlots.
]]

local UiKit

local HudController = {}

function HudController.init(ctx)
	UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local images = ctx.assets.IMAGES
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

	-- ===================== notebook counter (top left) =====================

	local notebookFrame = UiKit.new("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(290, 44),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local notebookScale = UiKit.new("UIScale", { Parent = notebookFrame })

	local notebookIcon = UiKit.panel({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(28, 36),
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		Parent = notebookFrame,
	}, images.NOTEBOOK_ICON)
	if notebookIcon:IsA("Frame") then
		UiKit.corner(4).Parent = notebookIcon
	end

	local notebookLabel = UiKit.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = "Notebooks: 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notebookFrame,
	})

	local objectiveLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(420, 22),
		Text = "Collect 10 notebooks!",
		TextColor3 = theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = gui,
	})

	-- ===================== item slots (top right) =====================

	local slotsFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(198, 118),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local function buildSlot(xOffset, hintText, isActive)
		local slot = UiKit.panel({
			Position = UDim2.fromOffset(xOffset, 0),
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = theme.white,
			Parent = slotsFrame,
		}, images.ITEM_SLOT)
		if slot:IsA("Frame") then
			UiKit.corner(8).Parent = slot
			UiKit.stroke(isActive and theme.accent or Color3.fromRGB(40, 40, 40), isActive and 4 or 2).Parent = slot
		elseif isActive then
			UiKit.stroke(theme.accent, 4).Parent = slot
		end

		-- your item picture; hidden when the slot is empty
		local itemImage = UiKit.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(72, 72),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			Parent = slot,
		})
		-- fallback colored block + item name when no item picture exists
		local fallbackIcon = UiKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = theme.panelLight,
			Visible = false,
			Parent = slot,
			UiKit.corner(10),
		})
		local fallbackText = UiKit.label({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			Parent = fallbackIcon,
		})
		local emptyText = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 20),
			Text = "empty",
			TextColor3 = Color3.fromRGB(130, 130, 130),
			TextStrokeTransparency = 1,
			Parent = slot,
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(92, 18),
			Text = hintText,
			Parent = slot,
		})
		return {
			frame = slot,
			itemImage = itemImage,
			fallbackIcon = fallbackIcon,
			fallbackText = fallbackText,
			emptyText = emptyText,
		}
	end

	local slot1 = buildSlot(0, "[E] Use", true)
	local slot2 = buildSlot(106, "[Q] Swap", false)

	-- nickel counter, under the slots
	local nickelFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 134),
		Size = UDim2.fromOffset(198, 32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local nickelIcon = UiKit.panel({
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(255, 210, 70),
		Parent = nickelFrame,
	}, images.NICKEL_ICON)
	if nickelIcon:IsA("Frame") then
		UiKit.corner(14).Parent = nickelIcon
		UiKit.stroke(Color3.fromRGB(180, 140, 30), 2).Parent = nickelIcon
	end
	local nickelLabel = UiKit.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = "x 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nickelFrame,
	})

	local fullFlash = UiKit.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 170),
		Size = UDim2.fromOffset(198, 24),
		Text = "Inventory full",
		TextColor3 = theme.red,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== stamina bar (bottom center) =====================

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(120, 18),
		Text = "STAMINA",
		Parent = gui,
	})
	local staminaBack = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, images.STAMINA_BACK)
	if staminaBack:IsA("Frame") then
		UiKit.corner(8).Parent = staminaBack
		UiKit.stroke(Color3.fromRGB(0, 0, 0), 1, 0.5).Parent = staminaBack
	end
	local staminaFillArea = UiKit.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = staminaBack,
	})
	-- the fill is your STAMINA_FILL image (tinted by code) or a plain bar
	local fillIsImage = UiKit.hasImage(images.STAMINA_FILL)
	local staminaFill
	if fillIsImage then
		staminaFill = UiKit.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = images.STAMINA_FILL,
			ScaleType = Enum.ScaleType.Stretch,
			ImageColor3 = theme.green,
			Parent = staminaFillArea,
		})
	else
		staminaFill = UiKit.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme.green,
			Parent = staminaFillArea,
			UiKit.corner(6),
		})
	end
	local fillColorProp = fillIsImage and "ImageColor3" or "BackgroundColor3"
	local fillTransparencyProp = fillIsImage and "ImageTransparency" or "BackgroundTransparency"

	local coldTag = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(180, 18),
		Text = "COLD! Slowed...",
		TextColor3 = theme.ice,
		Visible = false,
		Parent = gui,
	})

	-- ===================== center banner =====================

	local banner = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 54),
		Text = "",
		TextColor3 = theme.accent,
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
			UiKit.tween(staminaFill, 0.2, { [fillColorProp] = color })
		end
	end

	function self.flashStaminaFull()
		staminaFill[fillColorProp] = theme.green
		staminaFill[fillTransparencyProp] = 0.6
		UiKit.tween(staminaFill, 0.4, { [fillTransparencyProp] = 0 })
	end

	local function renderSlot(slot, itemId)
		if itemId then
			local def = ctx.config.ITEMS[itemId]
			local picture = images.ITEMS[itemId]
			slot.emptyText.Visible = false
			if UiKit.hasImage(picture) then
				slot.itemImage.Image = picture
				slot.itemImage.Visible = true
				slot.fallbackIcon.Visible = false
			else
				slot.itemImage.Visible = false
				slot.fallbackIcon.Visible = true
				slot.fallbackIcon.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
				slot.fallbackText.Text = def.shortLabel
			end
		else
			slot.itemImage.Visible = false
			slot.fallbackIcon.Visible = false
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
			self.setObjective("Escape through the EXIT door!")
			sounds.play("collect", 0.7)
		end
	end)

	return self
end

return HudController
