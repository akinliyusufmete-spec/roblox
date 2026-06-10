--[[
	ItemEconomy (ModuleScript, ServerScriptService.BaldiGame.ItemEconomy)

	Server-authoritative inventory + currency:
	  - Two item slots per player; slot 1 is the active slot.
	  - Nickels: currency, picked up by walking over them, dropped by
	    ChatRevive where a player was caught, spent at vending machines.
	  - World pickups: walking over an item auto-collects it if a slot is
	    free, otherwise the client gets a PickupFailed ("Inventory full").
	  - UseItem: validates slot 1 and applies the effect —
	      ZESTY -> StaminaRestore to the client (instant stamina reset)
	      BSODA -> server-stepped projectile that knocks back + stuns NPCs
	  - Vending: ProximityPrompt opens the client popup; BuyItem validates
	    nickel count and a free slot before granting.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local ItemEconomy = {}

function ItemEconomy.init(ctx)
	local self = {}
	local config = ctx.config
	local states = {} -- [player] = { nickels = n, slots = {id?, id?} }

	-- ===================== player state =====================

	local function getState(player)
		local state = states[player]
		if not state then
			state = { nickels = 0, slots = {} }
			states[player] = state
		end
		return state
	end

	local function syncInventory(player)
		local state = getState(player)
		ctx.remotes.InventoryChanged:FireClient(player, state.slots[1], state.slots[2])
	end

	local function syncNickels(player)
		ctx.remotes.NickelChanged:FireClient(player, getState(player).nickels)
	end

	function self.addNickels(player, amount)
		local state = getState(player)
		state.nickels = state.nickels + amount
		syncNickels(player)
	end

	local function freeSlot(state)
		if state.slots[1] == nil then
			return 1
		end
		if state.slots[2] == nil then
			return 2
		end
		return nil
	end

	local function giveItem(player, itemId)
		local state = getState(player)
		local slot = freeSlot(state)
		if not slot then
			return false
		end
		state.slots[slot] = itemId
		syncInventory(player)
		return true
	end

	function self.syncAll(player)
		syncInventory(player)
		syncNickels(player)
	end

	function self.forget(player)
		states[player] = nil
	end

	-- ===================== world pickups =====================

	local function makePickupPart(name, color, size)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		return part
	end

	function self.spawnNickel(position)
		local coin = makePickupPart("Nickel", Color3.fromRGB(255, 210, 70), Vector3.new(0.25, 1.4, 1.4))
		coin.Shape = Enum.PartType.Cylinder
		coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		coin:SetAttribute("IsNickel", true)
		local sparkle = Instance.new("PointLight")
		sparkle.Color = Color3.fromRGB(255, 220, 90)
		sparkle.Range = 5
		sparkle.Parent = coin
		coin.Parent = ctx.map.pickupsFolder
	end

	function self.spawnItemPickup(itemId, position)
		local def = config.ITEMS[itemId]
		if not def then
			return
		end
		local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		local pickup
		if itemId == "BSODA" then
			pickup = makePickupPart("Pickup_BSODA", color, Vector3.new(2, 1.1, 1.1))
			pickup.Shape = Enum.PartType.Cylinder
			pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		else
			pickup = makePickupPart("Pickup_" .. itemId, color, Vector3.new(1.6, 0.5, 2.2))
			pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0))
		end
		pickup:SetAttribute("ItemId", itemId)
		pickup.Parent = ctx.map.pickupsFolder
	end

	function self.clearPickups()
		ctx.map.pickupsFolder:ClearAllChildren()
	end

	function self.onRoundStart()
		self.clearPickups()
		local spawned = 0
		for _, position in ipairs(ctx.map.nickelSpawns) do
			if spawned >= config.NICKELS_AT_ROUND_START then
				break
			end
			self.spawnNickel(position)
			spawned = spawned + 1
		end
		if config.WORLD_ITEMS_AT_ROUND_START then
			for itemId, position in pairs(ctx.map.itemSpawns) do
				self.spawnItemPickup(itemId, position)
			end
		end
	end

	-- proximity pickup scan (more reliable than Touched, and lets us flash
	-- "Inventory full" instead of silently swallowing the walk-over)
	local fullFlashCooldown = {} -- [player] = next allowed flash time
	task.spawn(function()
		while true do
			task.wait(0.1)
			if ctx.manager and ctx.manager.isRoundActive() then
				local pickups = ctx.map.pickupsFolder:GetChildren()
				if #pickups > 0 then
					for _, player in ipairs(Players:GetPlayers()) do
						if ctx.manager.isParticipant(player) then
							local character = player.Character
							local hrp = character and character:FindFirstChild("HumanoidRootPart")
							if hrp then
								for _, pickup in ipairs(pickups) do
									if pickup.Parent and (pickup.Position - hrp.Position).Magnitude < config.PICKUP_RADIUS then
										if pickup:GetAttribute("IsNickel") then
											pickup:Destroy()
											self.addNickels(player, 1)
										else
											local itemId = pickup:GetAttribute("ItemId")
											if itemId then
												if giveItem(player, itemId) then
													pickup:Destroy()
												elseif (fullFlashCooldown[player] or 0) <= os.clock() then
													fullFlashCooldown[player] = os.clock() + 1.5
													ctx.remotes.PickupFailed:FireClient(player, "Inventory full")
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	-- ===================== BSODA projectile =====================

	local function fireBsoda(player, direction)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local cfg = config.BSODA_PROJECTILE

		local can = Instance.new("Part")
		can.Name = "BsodaBlast"
		can.Shape = Enum.PartType.Ball
		can.Size = Vector3.new(1.4, 1.4, 1.4)
		can.Color = Color3.fromRGB(70, 140, 255)
		can.Material = Enum.Material.Neon
		can.Anchored = true
		can.CanCollide = false
		can.CanQuery = false
		can.CanTouch = false

		local fizz = Instance.new("ParticleEmitter")
		fizz.Rate = 40
		fizz.Lifetime = NumberRange.new(0.2, 0.4)
		fizz.Speed = NumberRange.new(2, 4)
		fizz.Color = ColorSequence.new(Color3.fromRGB(160, 210, 255))
		fizz.Parent = can

		local position = hrp.Position + direction * 2.5 + Vector3.new(0, 0.5, 0)
		can.CFrame = CFrame.new(position)
		can.Parent = ctx.map.projectilesFolder

		-- exclude the shooter so the can doesn't pop on their own body
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = { ctx.map.npcFolder, ctx.map.notebooksFolder, ctx.map.pickupsFolder, ctx.map.projectilesFolder }
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer.Character then
				table.insert(excluded, otherPlayer.Character)
			end
		end
		params.FilterDescendantsInstances = excluded

		task.spawn(function()
			local traveled = 0
			while traveled < cfg.RANGE and can.Parent do
				local dt = task.wait()
				local step = direction * cfg.SPEED * dt
				local wallHit = workspace:Raycast(position, step, params)
				if wallHit then
					break
				end
				position = position + step
				traveled = traveled + step.Magnitude
				can.CFrame = CFrame.new(position)

				local hitNpc = nil
				for _, npc in pairs(ctx.npcs) do
					if npc.base and npc.base.model.Parent then
						if (npc.base.root.Position - position).Magnitude < cfg.HIT_RADIUS then
							hitNpc = npc
							break
						end
					end
				end
				if hitNpc then
					hitNpc.base:stun(cfg.STUN_SECONDS, direction)
					local splat = Instance.new("Sound")
					splat.SoundId = "rbxasset://sounds/splat.mp3"
					splat.Volume = 1
					splat.Parent = hitNpc.base.root
					pcall(function()
						splat:Play()
					end)
					Debris:AddItem(splat, 2)
					break
				end
			end
			can:Destroy()
		end)
	end

	-- ===================== remote handlers =====================

	ctx.remotes.UseItem.OnServerEvent:Connect(function(player, direction)
		if not ctx.manager or not ctx.manager.isRoundActive() or not ctx.manager.isParticipant(player) then
			return
		end
		local state = getState(player)
		local itemId = state.slots[1]
		if not itemId then
			return
		end

		if itemId == "ZESTY" then
			-- consume, then let the client reset its stamina state
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
			syncInventory(player)
			ctx.remotes.StaminaRestore:FireClient(player)
		elseif itemId == "BSODA" then
			-- validate the client-supplied aim direction
			if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 or direction ~= direction then
				return
			end
			local flatish = Vector3.new(direction.X, math.clamp(direction.Y, -0.4, 0.4), direction.Z)
			if flatish.Magnitude < 0.01 then
				return
			end
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
			syncInventory(player)
			fireBsoda(player, flatish.Unit)
		end
	end)

	ctx.remotes.SwapSlots.OnServerEvent:Connect(function(player)
		local state = getState(player)
		state.slots[1], state.slots[2] = state.slots[2], state.slots[1]
		syncInventory(player)
	end)

	-- ===================== vending machines =====================

	for machineId, machine in ipairs(ctx.map.vendingMachines) do
		machine.prompt.Triggered:Connect(function(player)
			local def = config.ITEMS[machine.itemId]
			if not def then
				return
			end
			ctx.remotes.OpenVending:FireClient(player, {
				machineId = machineId,
				itemId = machine.itemId,
				cost = def.cost,
				nickels = getState(player).nickels,
				position = machine.part.Position,
			})
		end)
	end

	ctx.remotes.BuyItem.OnServerEvent:Connect(function(player, machineId)
		local machine = ctx.map.vendingMachines[machineId]
		if not machine or not machine.part.Parent then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - machine.part.Position).Magnitude > 12 then
			return
		end
		local def = config.ITEMS[machine.itemId]
		local state = getState(player)
		if state.nickels < def.cost then
			ctx.remotes.BuyResult:FireClient(player, false, "Not enough Nickels!")
			return
		end
		if not freeSlot(state) then
			ctx.remotes.BuyResult:FireClient(player, false, "Inventory full!")
			return
		end
		state.nickels = state.nickels - def.cost
		giveItem(player, machine.itemId)
		syncNickels(player)
		ctx.remotes.BuyResult:FireClient(player, true, def.displayName .. " dispensed!")
	end)

	ctx.economy = self
	return self
end

return ItemEconomy
