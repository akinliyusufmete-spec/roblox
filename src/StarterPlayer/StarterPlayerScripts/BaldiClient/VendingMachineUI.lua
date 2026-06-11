--[[
	VendingMachineUI (ModuleScript, StarterPlayerScripts.BaldiClient.VendingMachineUI)

	Activating a vending machine's ProximityPrompt immediately attempts the
	purchase on the server — no popup needed. This module shows a brief
	on-screen toast confirming the purchase or explaining why it failed.
]]

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
		Parent = playerGui,
	})

	local toast = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.new(0.7, 0, 0, 38),
		Text = "",
		TextColor3 = theme.green,
		TextTransparency = 1,
		Parent = gui,
	})

	local toastThread = nil
	local function showToast(success, message)
		if toastThread then
			task.cancel(toastThread)
			toastThread = nil
		end
		toast.Text = message
		toast.TextColor3 = success and theme.green or theme.red
		toast.TextTransparency = 0
		sounds.play(success and "buy" or "error")
		toastThread = task.delay(2, function()
			UiKit.tween(toast, 0.4, { TextTransparency = 1 })
			toastThread = nil
		end)
	end

	ctx.remotes.BuyResult.OnClientEvent:Connect(showToast)

	return self
end

return VendingMachineUI
