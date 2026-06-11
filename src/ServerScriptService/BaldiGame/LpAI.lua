--[[
	LpAI (ModuleScript, ServerScriptService.BaldiGame.LpAI)

	The condition-based chaser (the "Principal" role).
	  - Roams normally and ignores everyone.
	  - Condition: a player is moving faster than SPEED_THRESHOLD *and* LP has
	    line of sight. Only sight = no reaction. Only speed = no reaction.
	  - Once provoked he chases via continuous re-pathing to your live
	    position (he follows you through doorways), and only loses interest
	    after MEMORY_SECONDS out of sight.
	  - Speeds up while you keep breaking the rule: as long as you're running
	    he moves at RULEBREAK_CHASE_SPEED (faster than a sprint, so you can't
	    just outrun him) — slow to a walk and he eases back to CHASE_SPEED, so
	    the smart escape is to stop running and break his line of sight.
	  - On catch: hands the player to DetentionSystem (teleport + lock).

	Server-side speed check: a client-side WalkSpeed change does NOT
	replicate to the server, so we measure the character's actual horizontal
	velocity instead — same threshold, but it can't be spoofed. Sprinting
	(24) trips it, walking (16) never does.

	Custom rig: ReplicatedStorage/BaldiAssets/Npcs/LP
	Alert sound: AssetConfig.SOUNDS.whistle (else a built-in ping)
]]

local RunService = game:GetService("RunService")

local NpcFactory = require(script.Parent.NpcFactory)
local NpcBase = require(script.Parent.NpcBase)

local LpAI = {}

local COLOR_BODY = Color3.fromRGB(35, 50, 120)
local COLOR_HEAD = Color3.fromRGB(225, 200, 170)

function LpAI.init(ctx)
	local cfg = ctx.config.NPC.LP
	local self = { ctx = ctx, cfg = cfg }

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(120, 150, 255),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.LP,
		(cfg.ROAM_SPEED + cfg.CHASE_SPEED) / 2)
	self.base = base
	self.model = model

	local whistleSoundId = ctx.assets.SOUNDS.whistle
	local whistle = Instance.new("Sound")
	whistle.Name = "Whistle"
	whistle.SoundId = (whistleSoundId ~= "" and whistleSoundId) or "rbxasset://sounds/electronicpingshort.wav"
	whistle.Volume = 0.9
	whistle.PlaybackSpeed = whistleSoundId ~= "" and 1 or 0.6
	whistle.RollOffMaxDistance = 80
	whistle.Parent = base.root

	-- ---------- helpers ----------

	local function targetRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	local function horizontalSpeed(hrp)
		local velocity = hrp.AssemblyLinearVelocity
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	end

	local function isBreakingRule(hrp)
		return hrp ~= nil and horizontalSpeed(hrp) > cfg.SPEED_THRESHOLD
	end

	local lastScan = 0
	local cachedOffender = nil

	-- a player breaking the speed rule in LP's line of sight (throttled scan)
	local function findOffender()
		if os.clock() - lastScan < cfg.SIGHT_INTERVAL then
			return cachedOffender
		end
		lastScan = os.clock()
		cachedOffender = nil
		if not ctx.manager then
			return nil
		end
		local bestDistance = math.huge
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if not ctx.detention.hasImmunity(player) then
				local hrp = targetRoot(player)
				if isBreakingRule(hrp) then
					local distance = (hrp.Position - base.root.Position).Magnitude
					if distance < bestDistance and base:canSee(hrp, cfg.SIGHT_RANGE) then
						bestDistance = distance
						cachedOffender = player
					end
				end
			end
		end
		return cachedOffender
	end

	-- ---------- chase ----------

	local function chase(player)
		local lastSeenAt = os.clock()
		local lastKnown = nil
		pcall(function()
			whistle:Play()
		end)

		base:pursue(
			function()
				if not ctx.manager.isRoundActive() then
					return nil
				end
				local hrp = targetRoot(player)
				if not hrp or not ctx.manager.isTargetable(player) or ctx.detention.isDetained(player) then
					return nil
				end
				-- once agitated, LP keeps coming whether or not you slow down;
				-- only losing line of sight for MEMORY_SECONDS calms him
				if base:canSee(hrp, cfg.SIGHT_RANGE) then
					lastSeenAt = os.clock()
					lastKnown = hrp.Position
					return lastKnown
				end
				if os.clock() - lastSeenAt > cfg.MEMORY_SECONDS then
					return nil
				end
				if lastKnown and (lastKnown - base.root.Position).Magnitude < 4 then
					return nil
				end
				return lastKnown
			end,
			function()
				-- faster while the target is actively breaking the speed rule
				if isBreakingRule(targetRoot(player)) then
					return cfg.RULEBREAK_CHASE_SPEED
				end
				return cfg.CHASE_SPEED
			end
		)
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:canAct() then
				task.wait(0.2)
			else
				local offender = findOffender()
				if offender then
					chase(offender)
				else
					base:roamStep(cfg.ROAM_SPEED, function()
						return findOffender() ~= nil
					end)
				end
			end
		end
	end)

	-- ---------- catch check: detention, not game over ----------

	RunService.Heartbeat:Connect(function()
		if not base:isActive() or not ctx.manager or not ctx.manager.isRoundActive() then
			return
		end
		local silver = ctx.npcs.Silver
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if not ctx.detention.hasImmunity(player)
				and not ctx.detention.isDetained(player)
				and not (silver and silver.isGrabbing(player)) then -- Silver's victim is Silver's
				local hrp = targetRoot(player)
				if hrp and (hrp.Position - base.root.Position).Magnitude < cfg.CATCH_DISTANCE then
					ctx.detention.detain(player, cfg.DETENTION_SECONDS, cfg.NAME)
				end
			end
		end
	end)

	function self.reset()
		base:resetToSpawn()
	end

	ctx.npcs.LP = self
	return self
end

return LpAI
