--[[
	InputHandler (ModuleScript, StarterPlayerScripts.BaldiClient.InputHandler)
	Routes raw input to gameplay callbacks so the other controllers never
	talk to UserInputService directly:
	  Shift (hold)  -> sprint     E -> use slot 1     Q -> swap slots
	  F -> cancel (give up the notebook minigame)
	E and Q also report held-state (onUseHeld / onSwapHeld) for the
	sweet-spot minigame's continuous rotation. Mobile equivalents are
	on-screen buttons created by HudController / the minigame UIs; they
	call the same notify* functions.
]]

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}

function InputHandler.init(ctx)
	local self = {
		touchEnabled = UserInputService.TouchEnabled,
	}
	local sprintCallbacks = {}
	local useCallbacks = {}
	local swapCallbacks = {}
	local useHeldCallbacks = {}
	local swapHeldCallbacks = {}
	local cancelCallbacks = {}

	local function fire(callbacks, ...)
		for _, callback in ipairs(callbacks) do
			callback(...)
		end
	end

	function self.onSprint(callback)
		table.insert(sprintCallbacks, callback)
	end

	function self.onUse(callback)
		table.insert(useCallbacks, callback)
	end

	function self.onSwap(callback)
		table.insert(swapCallbacks, callback)
	end

	-- held-state versions of E / Q, fired (true) on press and (false) on
	-- release — the sweet-spot minigame rotates while these are held
	function self.onUseHeld(callback)
		table.insert(useHeldCallbacks, callback)
	end

	function self.onSwapHeld(callback)
		table.insert(swapHeldCallbacks, callback)
	end

	function self.onCancel(callback)
		table.insert(cancelCallbacks, callback)
	end

	-- mobile buttons (and anything else) report through these
	function self.notifySprint(held)
		fire(sprintCallbacks, held)
	end

	function self.notifyUse()
		fire(useCallbacks)
	end

	function self.notifySwap()
		fire(swapCallbacks)
	end

	function self.notifyUseHeld(held)
		fire(useHeldCallbacks, held)
	end

	function self.notifySwapHeld(held)
		fire(swapHeldCallbacks, held)
	end

	function self.notifyCancel()
		fire(cancelCallbacks)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(true)
		elseif input.KeyCode == Enum.KeyCode.E then
			self.notifyUse()
			self.notifyUseHeld(true)
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.notifySwap()
			self.notifySwapHeld(true)
		elseif input.KeyCode == Enum.KeyCode.F then
			self.notifyCancel()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(false)
		elseif input.KeyCode == Enum.KeyCode.E then
			self.notifyUseHeld(false)
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.notifySwapHeld(false)
		end
	end)

	return self
end

return InputHandler
