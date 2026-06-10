--[[
	InputHandler (ModuleScript, StarterPlayerScripts.BaldiClient.InputHandler)
	Routes raw input to gameplay callbacks so the other controllers never
	talk to UserInputService directly:
	  Shift (hold)  -> sprint        E -> use slot 1        Q -> swap slots
	Mobile equivalents are on-screen buttons created by HudController; they
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(true)
		elseif input.KeyCode == Enum.KeyCode.E then
			self.notifyUse()
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.notifySwap()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(false)
		end
	end)

	return self
end

return InputHandler
