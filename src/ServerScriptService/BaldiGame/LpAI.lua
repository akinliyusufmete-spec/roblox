--[[
	LpAI (ModuleScript, ServerScriptService.BaldiGame.LpAI)

	The condition-based chaser (the "Principal" role).
	  - Roams normally and ignores everyone.
	  - Condition: player is moving faster than SPEED_THRESHOLD *and* LP has
	    line of sight. Only sight = no reaction. Only speed = no reaction.
	  - Condition met: chases until catch or sight lost for MEMORY_SECONDS.
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
				if hrp and horizontalSpeed(hrp) > cfg.SPEED_THRESHOLD then
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
		local hrp = targetRoot(player)
		if not hrp then
			return
		end
		local lastKnown = hrp.Position
		pcall(function()
			whistle:Play()
		end)

		while base:isActive() do
			if not ctx.manager.isRoundActive() then
				return
			end
			hrp = targetRoot(player)
			if not hrp or not ctx.manager.isTargetable(player) or ctx.detention.isDetained(player) then
				break
			end

			-- once agitated, LP keeps coming whether or not you slow down;
			-- only losing line of sight for MEMORY_SECONDS calms him
			if base:canSee(hrp, cfg.SIGHT_RANGE) then
				lastSeenAt = os.clock()
				lastKnown = hrp.Position
			elseif os.clock() - lastSeenAt > cfg.MEMORY_SECONDS then
				break
			end

			base:setMoveSpeed(cfg.CHASE_SPEED)
			base:chaseStepToward(lastKnown)
			task.wait(cfg.REPATH_INTERVAL)
		end

		if base:isActive() and ctx.manager.isRoundActive() then
			base:travelTo(lastKnown, cfg.CHASE_SPEED, function()
				return findOffender() ~= nil
			end)
		end
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:isActive() or not (ctx.manager and ctx.manager.isRoundActive()) then
				task.wait(0.25)
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
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if not ctx.detention.hasImmunity(player) and not ctx.detention.isDetained(player) then
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
