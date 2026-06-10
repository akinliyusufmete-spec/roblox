--[[
	VendingMachineUI (ModuleScript, StarterPlayerScripts.BaldiClient.VendingMachineUI)

	Popup shown when the vending machine's ProximityPrompt is triggered:
	item name, icon, cost, your current Nickel count, and a Buy button.
	Closes on buy, on the X, or automatically when you walk away.
]]

local RunService = game:GetService("RunService")

local VendingMachineUI = {}

function VendingMachineUI.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiVending",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Enabled = false,
		Parent = playerGui,
	})

	local panel = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(340, 250),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
		UiKit.corner(14),
		UiKit.stroke(theme.accent, 2),
	})

	local titleLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -60, 0, 30),
		Text = "BSODA",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local closeButton = UiKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(32, 32),
		Text = "X",
		BackgroundColor3 = theme.red,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	})

	local iconFrame = UiKit.new("Frame", {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = theme.blue,
		Parent = panel,
		UiKit.corner(10),
	})
	local iconText = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = "BSODA",
		Parent = iconFrame,
	})

	local descLabel = UiKit.label({
		Position = UDim2.fromOffset(104, 52),
		Size = UDim2.new(1, -120, 0, 76),
		Text = "",
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = theme.textDim,
		Parent = panel,
	})

	local costLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "Cost: 1 Nickel",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = theme.accent,
		Parent = panel,
	})
	local haveLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 162),
		Size = UDim2.new(1, -32, 0, 20),
		Text = "You have: 0 Nickels",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextColor3 = theme.textDim,
		Parent = panel,
	})

	local buyButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -32, 0, 42),
		Text = "BUY",
		Parent = panel,
	})

	local resultLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(1, -32, 0, 18),
		Text = "",
		TextColor3 = theme.green,
		Parent = panel,
	})

	-- ===================== behaviour =====================

	local current = nil -- { machineId, itemId, cost, position }
	local watcher = nil

	local function close()
		gui.Enabled = false
		current = nil
		if watcher then
			watcher:Disconnect()
			watcher = nil
		end
	end

	local function refreshAffordability(nickels)
		haveLabel.Text = "You have: " .. nickels .. " Nickel" .. (nickels == 1 and "" or "s")
		local canAfford = current ~= nil and nickels >= current.cost
		buyButton.AutoButtonColor = canAfford
		buyButton.BackgroundColor3 = canAfford and theme.accent or Color3.fromRGB(95, 95, 90)
	end

	ctx.remotes.OpenVending.OnClientEvent:Connect(function(data)
		local def = ctx.config.ITEMS[data.itemId]
		if not def then
			return
		end
		current = data
		titleLabel.Text = def.displayName
		iconFrame.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		iconText.Text = def.shortLabel
		descLabel.Text = def.description
		costLabel.Text = "Cost: " .. def.cost .. " Nickel" .. (def.cost == 1 and "" or "s")
		resultLabel.Text = ""
		refreshAffordability(data.nickels)
		gui.Enabled = true
		sounds.play("click")

		-- close automatically when the player walks away
		if watcher then
			watcher:Disconnect()
		end
		watcher = RunService.Heartbeat:Connect(function()
			local character = ctx.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp or not current then
				close()
				return
			end
			if (hrp.Position - current.position).Magnitude > ctx.config.VENDING_CLOSE_DISTANCE then
				close()
			end
		end)
	end)

	ctx.remotes.NickelChanged.OnClientEvent:Connect(function(count)
		if gui.Enabled then
			refreshAffordability(count)
		end
	end)

	buyButton.Activated:Connect(function()
		if current then
			ctx.remotes.BuyItem:FireServer(current.machineId)
		end
	end)

	closeButton.Activated:Connect(close)

	ctx.remotes.BuyResult.OnClientEvent:Connect(function(success, message)
		if not gui.Enabled then
			return
		end
		if success then
			sounds.play("buy")
			resultLabel.TextColor3 = theme.green
			resultLabel.Text = message
			task.delay(0.5, close)
		else
			sounds.play("error")
			resultLabel.TextColor3 = theme.red
			resultLabel.Text = message
			UiKit.shake(panel, 8)
		end
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(close)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(close)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(close)

	self.close = close
	return self
end

return VendingMachineUI
