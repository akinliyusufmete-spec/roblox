--[[
	SilverAI (ModuleScript, ServerScriptService.BaldiGame.SilverAI)

	The grabber.
	  - Roams between waypoints; chases any player it spots within
	    SIGHT_RANGE (slower than a sprint — you can run, if you dare run).
	  - On catch: GRABS the victim. They're locked in place and must win the
	    timing minigame — click the moving cube inside the center zone
	    GRAB_HITS times — to wriggle free. While held they're still fair
	    game for ChatRevive, so a grab in the open is very bad news.
	  - Safety Scissors (SilverEscape remote) cut you free instantly and
	    leave Silver snipped (stunned) for SCISSORS_DISABLE seconds.
	  - A BSODA hit on Silver mid-grab also frees the victim.
	  - After any grab: the victim gets GRAB_IMMUNITY seconds of protection
	    and Silver rests for GRAB_COOLDOWN before hunting again.

	Server-side validation: the client only reports successful hits; the
	server counts them and ignores hits closer together than
	GRAB_MIN_HIT_GAP, plus a GRAB_MAX_SECONDS failsafe release.

	Custom rig: ReplicatedStorage/BaldiAssets/Npcs/Silver
]]

local RunService = game:GetService("RunService")

local NpcFactory = require(script.Parent.NpcFactory)
local NpcBase = require(script.Parent.NpcBase)

local SilverAI = {}

local COLOR_BODY = Color3.fromRGB(185, 190, 200)
local COLOR_HEAD = Color3.fromRGB(215, 220, 230)

function SilverAI.init(ctx)
	local cfg = ctx.config.NPC.SILVER
	local self = { ctx = ctx, cfg = cfg }

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(225, 230, 240),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.SILVER,
		(cfg.ROAM_SPEED + cfg.CHASE_SPEED) / 2)
	self.base = base
	self.model = model

	-- ---------- grab state ----------

	local grabbed = nil -- { player, hits, lastHitAt, releaseAt }
	local immunityUntil = {} -- [player] = time they can be grabbed again
	local cooldownUntil = 0 -- Silver rests after a grab

	function self.isGrabbing(player)
		return grabbed ~= nil and grabbed.player == player
	end

	local function releaseGrab()
		if not grabbed then
			return
		end
		local player = grabbed.player
		grabbed = nil
		cooldownUntil = os.clock() + cfg.GRAB_COOLDOWN
		immunityUntil[player] = os.clock() + cfg.GRAB_IMMUNITY

		-- only unanchor players the grab itself anchored; someone who was
		-- caught/detained/teleported mid-grab is another system's business
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and ctx.manager and ctx.manager.isParticipant(player)
			and not ctx.detention.isDetained(player) then
			hrp.Anchored = false
		end
		if player.Parent then
			ctx.remotes.SilverReleased:FireClient(player)
		end
	end

	local function startGrab(player, hrp)
		grabbed = {
			player = player,
			hits = 0,
			lastHitAt = 0,
			releaseAt = os.clock() + cfg.GRAB_MAX_SECONDS,
		}
		if ctx.manager.recordGrab then
			ctx.manager.recordGrab(player) -- report card blemish
		end
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.Anchored = true

		base:stop()
		local look = Vector3.new(hrp.Position.X, base.root.Position.Y, hrp.Position.Z)
		if (look - base.root.Position).Magnitude > 0.5 then
			base.root.CFrame = CFrame.lookAt(base.root.Position, look)
		end

		ctx.remotes.SilverGrab:FireClient(player, cfg.GRAB_HITS)

		-- watcher: ends the grab on timeout, a BSODA hit, the round ending,
		-- or the victim being caught / leaving mid-grab
		task.spawn(function()
			while grabbed and grabbed.player == player do
				if os.clock() > grabbed.releaseAt then
					releaseGrab()
					return
				end
				if base:isStunned() then -- BSODA'd mid-grab: victim slips free
					releaseGrab()
					return
				end
				if not ctx.manager.isRoundActive() or not ctx.manager.isParticipant(player) then
					releaseGrab()
					return
				end
				local character = player.Character
				if not character or not character:FindFirstChild("HumanoidRootPart") then
					releaseGrab()
					return
				end
				task.wait(0.1)
			end
		end)
	end

	-- ---------- minigame remotes ----------

	ctx.remotes.SilverHit.OnServerEvent:Connect(function(player)
		if not grabbed or grabbed.player ~= player then
			return
		end
		local now = os.clock()
		if now - grabbed.lastHitAt < cfg.GRAB_MIN_HIT_GAP then
			return -- too fast to be a real timing hit
		end
		grabbed.lastHitAt = now
		grabbed.hits = grabbed.hits + 1
		if grabbed.hits >= cfg.GRAB_HITS then
			releaseGrab()
		end
	end)

	ctx.remotes.SilverEscape.OnServerEvent:Connect(function(player)
		if not grabbed or grabbed.player ~= player then
			return
		end
		if ctx.economy.consumeItem(player, "SCISSORS") then
			releaseGrab()
			base:stun(cfg.SCISSORS_DISABLE, nil) -- snipped!
		end
	end)

	-- ---------- target finding ----------

	local function targetRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	local function canGrab(player)
		return (immunityUntil[player] or 0) <= os.clock()
			and not ctx.detention.hasImmunity(player)
	end

	local lastScan = 0
	local cachedTarget = nil

	local function findVictim()
		if os.clock() - lastScan < cfg.SIGHT_INTERVAL then
			return cachedTarget
		end
		lastScan = os.clock()
		cachedTarget = nil
		if not ctx.manager or grabbed or os.clock() < cooldownUntil then
			return nil
		end
		local bestDistance = math.huge
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if canGrab(player) and not self.isGrabbing(player) then
				local hrp = targetRoot(player)
				if hrp and not hrp.Anchored then
					local distance = (hrp.Position - base.root.Position).Magnitude
					if distance < bestDistance and base:canSee(hrp, cfg.SIGHT_RANGE) then
						bestDistance = distance
						cachedTarget = player
					end
				end
			end
		end
		return cachedTarget
	end

	-- ---------- chase ----------

	local function chase(player)
		local lastSeenAt = os.clock()
		local lastKnown = nil

		base:pursue(
			function()
				if grabbed or os.clock() < cooldownUntil then
					return nil
				end
				if not ctx.manager.isRoundActive() then
					return nil
				end
				local hrp = targetRoot(player)
				if not hrp or hrp.Anchored or not ctx.manager.isTargetable(player) or not canGrab(player) then
					return nil
				end
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
				return cfg.CHASE_SPEED
			end
		)
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:canAct() or grabbed then
				task.wait(0.2)
			else
				local victim = findVictim()
				if victim then
					chase(victim)
				else
					base:roamStep(cfg.ROAM_SPEED, function()
						return findVictim() ~= nil
					end)
				end
			end
		end
	end)

	-- ---------- grab trigger ----------

	RunService.Heartbeat:Connect(function()
		if grabbed or not base:isActive() or os.clock() < cooldownUntil then
			return
		end
		if not ctx.manager or not ctx.manager.isRoundActive() then
			return
		end
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if canGrab(player) then
				local hrp = targetRoot(player)
				if hrp and not hrp.Anchored
					and (hrp.Position - base.root.Position).Magnitude < cfg.CATCH_DISTANCE then
					startGrab(player, hrp)
					break
				end
			end
		end
	end)

	function self.reset()
		releaseGrab()
		immunityUntil = {}
		cooldownUntil = 0
		base:resetToSpawn()
	end

	ctx.npcs.Silver = self
	return self
end

return SilverAI
