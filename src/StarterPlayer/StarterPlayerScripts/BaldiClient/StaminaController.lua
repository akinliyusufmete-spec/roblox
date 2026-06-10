--[[
	StaminaController (ModuleScript, StarterPlayerScripts.BaldiClient.StaminaController)

	Client-managed stamina, exactly per the plan:
	  - 0..100. Holding sprint (Shift / mobile RUN) while moving drains
	    10/sec and boosts WalkSpeed 16 -> 24.
	  - At 0: exhausted — speed snaps back to 16, sprint locks out, bar
	    flashes red and shakes.
	  - Regens 6/sec while not sprinting; sprint unlocks again at 30.
	  - Zesty Bar (StaminaRestore remote): instant 100 + lockout cleared.
	  - Frosty (applyDebuff): WalkSpeed multiplied by 0.4 for 4 seconds —
	    which also drops sprint speed under LP's radar.

	WalkSpeed is written every Heartbeat. LP's server check reads actual
	velocity, so sprint speed (24) > threshold (20) > walk speed (16)
	behaves exactly as designed.
]]

local RunService = game:GetService("RunService")

local StaminaController = {}

function StaminaController.init(ctx)
	local cfg = ctx.config.STAMINA
	local playerCfg = ctx.config.PLAYER
	local hud = ctx.controllers.HudController

	local self = {
		stamina = cfg.MAX,
		exhausted = false,
		sprintHeld = false,
		enabled = false,
		sprintLocked = false, -- detention
		debuffMultiplier = 1,
		debuffUntil = 0,
	}

	local function getHumanoid()
		local character = ctx.player.Character
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	ctx.controllers.InputHandler.onSprint(function(held)
		self.sprintHeld = held
	end)

	RunService.Heartbeat:Connect(function(dt)
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end
		if not self.enabled then
			humanoid.WalkSpeed = playerCfg.WALK_SPEED
			return
		end

		local debuffActive = os.clock() < self.debuffUntil
		local multiplier = debuffActive and self.debuffMultiplier or 1
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local sprinting = self.sprintHeld
			and not self.exhausted
			and not self.sprintLocked
			and self.stamina > 0
			and moving

		if sprinting then
			self.stamina = self.stamina - cfg.DRAIN_PER_SEC * dt
			if self.stamina <= 0 then
				self.stamina = 0
				self.exhausted = true -- lockout until SPRINT_REENABLE
				sprinting = false
			end
		else
			self.stamina = math.min(cfg.MAX, self.stamina + cfg.REGEN_PER_SEC * dt)
		end

		if self.exhausted and self.stamina >= cfg.SPRINT_REENABLE then
			self.exhausted = false
		end

		humanoid.WalkSpeed = (sprinting and playerCfg.SPRINT_SPEED or playerCfg.WALK_SPEED) * multiplier

		local mode = "ok"
		if self.exhausted then
			mode = "exhausted"
		elseif self.stamina < cfg.LOW_THRESHOLD then
			mode = "low"
		end
		hud.setStamina(self.stamina / cfg.MAX, mode, debuffActive)
	end)

	-- ===================== API =====================

	-- Zesty Bar: full reset on demand
	function self.restoreFull()
		self.stamina = cfg.MAX
		self.exhausted = false
		hud.flashStaminaFull()
		hud.setStamina(1, "ok", os.clock() < self.debuffUntil)
	end

	-- Frosty's chill
	function self.applyDebuff(multiplier, duration)
		self.debuffMultiplier = multiplier
		self.debuffUntil = os.clock() + duration
	end

	function self.setEnabled(enabled)
		self.enabled = enabled
		if enabled then
			self.stamina = cfg.MAX
			self.exhausted = false
			self.sprintLocked = false
			self.debuffUntil = 0
			hud.setStamina(1, "ok", false)
		else
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.WalkSpeed = playerCfg.WALK_SPEED
			end
		end
	end

	function self.setSprintLocked(locked)
		self.sprintLocked = locked
	end

	ctx.remotes.StaminaRestore.OnClientEvent:Connect(function()
		self.restoreFull()
		ctx.controllers.SoundController.play("buy", 1.6)
	end)

	return self
end

return StaminaController
