--[[
	ItemUseClient (ModuleScript, StarterPlayerScripts.BaldiClient.ItemUseClient)

	Item slot input + HUD mirroring:
	  - InventoryChanged keeps the two HUD slots in sync with the server.
	  - E (or mobile USE) fires UseItem with the camera look direction
	    (the server only needs it for the BSODA projectile).
	  - Q (or mobile SWAP) asks the server to swap slot 1 and slot 2.

	Notebooks and vending machines also listen for E via ProximityPrompt,
	so while any prompt is on screen the E press belongs to the prompt and
	item use is suppressed (step away a few studs to drink your BSODA).
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local ItemUseClient = {}

function ItemUseClient.init(ctx)
	local self = { slots = {} }
	local hud = ctx.controllers.HudController
	local sounds = ctx.controllers.SoundController
	local lastUse = 0

	local visiblePrompts = 0
	ProximityPromptService.PromptShown:Connect(function()
		visiblePrompts = visiblePrompts + 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		visiblePrompts = math.max(0, visiblePrompts - 1)
	end)

	ctx.remotes.InventoryChanged.OnClientEvent:Connect(function(itemId1, itemId2)
		self.slots[1] = itemId1
		self.slots[2] = itemId2
		hud.setSlots(itemId1, itemId2)
	end)

	ctx.controllers.InputHandler.onUse(function()
		if visiblePrompts > 0 then
			return -- this E press is for a notebook / vending prompt
		end
		local minigame = ctx.controllers.SilverMinigame
		if minigame and minigame.active then
			return -- this E press is a timing hit in Silver's grab minigame
		end
		local lockFace = ctx.controllers.NotebookMinigame
		if lockFace and lockFace.active then
			return -- this E press is rotating the sweet-spot dial
		end
		if not self.slots[1] then
			return
		end
		if os.clock() - lastUse < 0.3 then
			return
		end
		lastUse = os.clock()
		local camera = workspace.CurrentCamera
		local direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
		ctx.remotes.UseItem:FireServer(direction)
		sounds.play("use")
	end)

	ctx.controllers.InputHandler.onSwap(function()
		local lockFace = ctx.controllers.NotebookMinigame
		if lockFace and lockFace.active then
			return -- this Q press is rotating the sweet-spot dial
		end
		if not self.slots[1] and not self.slots[2] then
			return
		end
		ctx.remotes.SwapSlots:FireServer()
		sounds.play("click")
	end)

	return self
end

return ItemUseClient
