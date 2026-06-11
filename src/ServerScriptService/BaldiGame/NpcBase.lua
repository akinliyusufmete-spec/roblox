--[[
	NpcBase (ModuleScript, ServerScriptService.BaldiGame.NpcBase)

	Shared locomotion for all three characters: robust pathfinding,
	roaming, continuous pursuit of a moving target, line-of-sight
	raycasts, stun/knockback (BSODA), slow (Frosty), animation hookup,
	and reset between rounds.

	The three AIs only differ in WHAT triggers a chase and WHERE the goal
	is — that lives in ChatReviveAI / LpAI / FrostyAI. Everything
	mechanical (how to actually get somewhere without wedging on a wall or
	a doorway) lives here.

	Movement is built to be reliable on a hand-made map:
	  - paths are recomputed continuously while chasing, aimed at the
	    target's LIVE position, so an NPC follows you into a room instead
	    of stopping at the door,
	  - a small agent radius fits through normal doorways,
	  - jump-capable agents clear small thresholds/lips,
	  - stuck detection + an unstick nudge recover from wedging on
	    geometry instead of grinding into it forever,
	  - we never blindly straight-line into a wall: if no path exists we
	    probe briefly and give up rather than push against geometry.
]]

local PathfindingService = game:GetService("PathfindingService")

local NpcAnimator = require(script.Parent.NpcAnimator)

local NpcBase = {}
NpcBase.__index = NpcBase

-- locomotion tuning
local STEP_POLL = 0.08 -- how often a single MoveTo leg samples progress
local STUCK_PROGRESS = 2 -- studs we must gain to count as "still moving"
local STUCK_GRACE = 0.55 -- seconds of no progress before we call it stuck
local ARRIVE_RADIUS = 4 -- "close enough" when picking the next path waypoint

-- chaseAnimThreshold: WalkSpeed above which the rig's "Chase" animation
-- plays (omit for characters that never chase).
function NpcBase.new(ctx, model, spawnCFrame, chaseAnimThreshold)
	local self = setmetatable({}, NpcBase)
	self.ctx = ctx
	self.model = model
	self.humanoid = model:WaitForChild("Humanoid")
	self.root = model:WaitForChild("HumanoidRootPart")
	self.spawnCFrame = spawnCFrame

	self.paused = true -- activation gating: frozen until the first notebook
	self.stunnedUntil = 0
	self.slowUntil = 0
	self.slowMultiplier = 1
	self.desiredSpeed = 0
	self.rng = Random.new()

	-- plays the Animations folder inside your rig, or a procedural walk
	self.animator = NpcAnimator.attach(model, chaseAnimThreshold)

	-- shared agent params: a tighter radius fits hand-made doorways, and
	-- jumping lets the NPC clear small lips/thresholds and unstick itself.
	local agent = ctx.config.NPC.AGENT or {}
	self.agentParams = {
		AgentRadius = agent.RADIUS or 2,
		AgentHeight = agent.HEIGHT or 5,
		AgentCanJump = agent.JUMP ~= false,
		AgentJumpHeight = agent.JUMP_HEIGHT or 4,
		WaypointSpacing = 4,
	}

	-- raycast params for sight checks: ignore everything that isn't level
	-- geometry or the player being checked
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = {
		ctx.map.npcFolder,
		ctx.map.notebooksFolder,
		ctx.map.pickupsFolder,
		ctx.map.projectilesFolder,
	}

	model.PrimaryPart = self.root
	model:PivotTo(spawnCFrame)

	-- server owns NPC physics so AI movement is smooth and authoritative
	task.defer(function()
		pcall(function()
			self.root:SetNetworkOwner(nil)
		end)
	end)

	return self
end

-- ===================== state helpers =====================

function NpcBase:isStunned()
	return os.clock() < self.stunnedUntil
end

function NpcBase:isActive()
	return (not self.paused) and (not self:isStunned()) and self.model.Parent ~= nil
end

-- True only while a round is running AND this NPC may move.
function NpcBase:canAct()
	local manager = self.ctx.manager
	return self:isActive() and manager ~= nil and manager.isRoundActive()
end

function NpcBase:setPaused(paused)
	self.paused = paused
	if paused then
		self:stop()
	end
end

function NpcBase:resetToSpawn()
	self.stunnedUntil = 0
	self.slowUntil = 0
	self.slowMultiplier = 1
	self:setPaused(true)
	local flash = self.model:FindFirstChild("StunFlash")
	if flash then
		flash:Destroy()
	end
	self.model:PivotTo(self.spawnCFrame)
	self.root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

function NpcBase:stop()
	self.desiredSpeed = 0
	self.humanoid.WalkSpeed = 0
	self.humanoid:MoveTo(self.root.Position)
end

-- ===================== speed / debuffs =====================

function NpcBase:applySpeed()
	local multiplier = (os.clock() < self.slowUntil) and self.slowMultiplier or 1
	self.humanoid.WalkSpeed = self.desiredSpeed * multiplier
end

function NpcBase:setMoveSpeed(speed)
	self.desiredSpeed = speed
	self:applySpeed()
end

-- Frosty's chill: also used on other NPCs when SLOWS_NPCS is on
function NpcBase:applySlow(multiplier, duration)
	self.slowMultiplier = multiplier
	self.slowUntil = os.clock() + duration
	self:applySpeed()
	task.delay(duration + 0.05, function()
		self:applySpeed()
	end)
end

-- BSODA hit: knock back and freeze in place for a few seconds.
-- The white flash is a Highlight, so it works on any rig (yours or the
-- placeholder) without touching part colors.
function NpcBase:stun(duration, pushDirection)
	local cfg = self.ctx.config.BSODA_PROJECTILE
	local alreadyStunned = self:isStunned()
	self.stunnedUntil = os.clock() + duration
	self.humanoid.WalkSpeed = 0
	self.humanoid:MoveTo(self.root.Position)

	if not alreadyStunned then
		local flash = Instance.new("Highlight")
		flash.Name = "StunFlash"
		flash.FillColor = Color3.fromRGB(235, 235, 245)
		flash.FillTransparency = 0.25
		flash.OutlineTransparency = 0.6
		flash.Parent = self.model
		task.spawn(function()
			while self:isStunned() do
				task.wait(0.1)
			end
			flash:Destroy()
			self:applySpeed()
		end)
	end

	-- physics shove: constant velocity for PUSH_DURATION covers PUSH_STUDS
	if pushDirection and pushDirection.Magnitude > 0.01 then
		local flat = Vector3.new(pushDirection.X, 0, pushDirection.Z)
		if flat.Magnitude > 0.01 then
			local pushVelocity = flat.Unit * (cfg.PUSH_STUDS / cfg.PUSH_DURATION)
			task.spawn(function()
				local started = os.clock()
				while os.clock() - started < cfg.PUSH_DURATION do
					if not self.root.Parent then
						return
					end
					self.root.AssemblyLinearVelocity = Vector3.new(pushVelocity.X, self.root.AssemblyLinearVelocity.Y, pushVelocity.Z)
					task.wait()
				end
				self.root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end)
		end
	end
end

-- ===================== sight =====================

-- True when there is a clear line of sight from this NPC to targetRoot.
function NpcBase:canSee(targetRoot, maxDistance)
	if not targetRoot or not targetRoot.Parent then
		return false
	end
	local origin = self.root.Position + Vector3.new(0, 1.5, 0)
	local delta = targetRoot.Position - origin
	if delta.Magnitude > maxDistance then
		return false
	end
	local result = workspace:Raycast(origin, delta, self.rayParams)
	if result == nil then
		return true
	end
	return result.Instance:IsDescendantOf(targetRoot.Parent)
end

-- ===================== pathfinding core =====================

function NpcBase:computePath(targetPosition)
	local path = PathfindingService:CreatePath(self.agentParams)
	local ok = pcall(function()
		path:ComputeAsync(self.root.Position, targetPosition)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- Back out of a wedge: shove away from whatever we're pressed against,
-- hop, and turn, so the next path compute starts from open floor.
function NpcBase:unstickNudge()
	local back = -self.root.CFrame.LookVector
	local sideSign = (self.rng:NextNumber() > 0.5) and 1 or -1
	local side = self.root.CFrame.RightVector * sideSign
	local escape = (back + side)
	if escape.Magnitude > 0.01 then
		escape = escape.Unit
		self.humanoid:MoveTo(self.root.Position + escape * 5)
	end
	if self.agentParams.AgentCanJump then
		self.humanoid.Jump = true
	end
	task.wait(0.3)
end

-- Move toward a single point. Returns one of:
--   "reached"    arrived
--   "stuck"      no progress for STUCK_GRACE seconds (caller should recompute)
--   "abort"      abortCheck() asked us to stop
--   "interrupted" paused/stunned mid-leg
--   "timeout"    maxDuration elapsed while still moving (caller repaths)
--   "blocked"    humanoid gave up on this point
-- maxDuration caps how long we commit to one leg (chasing repaths often);
-- omit it for roam legs that should run to completion.
function NpcBase:stepTo(position, abortCheck, maxDuration)
	local humanoid = self.humanoid
	local root = self.root
	if humanoid.Health <= 0 then
		return "interrupted"
	end

	local finished, reached = false, false
	local conn = humanoid.MoveToFinished:Connect(function(ok)
		finished = true
		reached = ok
	end)
	humanoid:MoveTo(position)

	local startTime = os.clock()
	local distance = (position - root.Position).Magnitude
	local walkTimeout = distance / math.max(humanoid.WalkSpeed, 1) + 1.5
	local lastProgressPos = root.Position
	local lastProgressTime = startTime
	local result

	while true do
		if finished then
			result = reached and "reached" or "blocked"
			break
		end
		if self.paused or self:isStunned() then
			result = "interrupted"
			break
		end
		if abortCheck and abortCheck() then
			result = "abort"
			break
		end
		local now = os.clock()
		if maxDuration and now - startTime > maxDuration then
			result = "timeout"
			break
		end
		if now - startTime > walkTimeout then
			result = "stuck"
			break
		end
		local moved = (root.Position - lastProgressPos).Magnitude
		if moved > STUCK_PROGRESS then
			lastProgressPos = root.Position
			lastProgressTime = now
		elseif now - lastProgressTime > STUCK_GRACE then
			result = "stuck"
			break
		end
		task.wait(STEP_POLL)
	end

	conn:Disconnect()
	return result
end

-- ===================== roaming (fixed destination) =====================

-- Walk a full path to a fixed point, recomputing if we wedge. Returns true
-- only if we actually arrived. abortCheck() bailing returns false early.
function NpcBase:navigateTo(targetPosition, speed, abortCheck)
	self:setMoveSpeed(speed)
	for _ = 1, 3 do
		if abortCheck and abortCheck() then
			return false
		end
		local waypoints = self:computePath(targetPosition)
		if not waypoints then
			-- no route: probe briefly toward it, but never grind on a wall
			local status = self:stepTo(targetPosition, abortCheck, 0.6)
			if status == "stuck" or status == "blocked" or status == "timeout" then
				return false
			end
			return status == "reached"
		end
		local wedged = false
		for index = 2, #waypoints do
			local waypoint = waypoints[index]
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.humanoid.Jump = true
			end
			local status = self:stepTo(waypoint.Position, abortCheck)
			if status == "abort" or status == "interrupted" then
				return false
			elseif status == "stuck" or status == "blocked" then
				wedged = true
				break
			end
		end
		if not wedged then
			return true
		end
		self:unstickNudge()
	end
	return false
end

-- One roam leg: walk to a random waypoint part. With no waypoints, wander
-- to a random nearby point we can actually reach (never into a wall).
function NpcBase:roamStep(speed, abortCheck)
	local parts = {}
	for _, node in ipairs(self.ctx.map.waypointsFolder:GetChildren()) do
		if node:IsA("BasePart") then
			table.insert(parts, node)
		end
	end
	if #parts == 0 then
		self:wanderStep(speed, abortCheck)
		return
	end
	-- prefer a waypoint that isn't the one we're already standing on
	local node = parts[self.rng:NextInteger(1, #parts)]
	if #parts > 1 and (node.Position - self.root.Position).Magnitude < ARRIVE_RADIUS then
		node = parts[self.rng:NextInteger(1, #parts)]
	end
	self:navigateTo(node.Position, speed, abortCheck)
end

-- Fallback roam when the map has no Waypoints folder: try a few random
-- nearby offsets and walk to the first one a path actually exists to.
function NpcBase:wanderStep(speed, abortCheck)
	for _ = 1, 6 do
		if abortCheck and abortCheck() then
			return
		end
		local angle = self.rng:NextNumber(0, math.pi * 2)
		local dist = self.rng:NextNumber(12, 28)
		local candidate = self.root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		if self:computePath(candidate) then
			self:navigateTo(candidate, speed, abortCheck)
			return
		end
	end
	task.wait(0.3)
end

-- ===================== pursuit (moving target) =====================

-- One pursuit leg toward a live goal position. Repaths every call, walks
-- only the next meaningful waypoint, and recovers if it wedges — so the
-- chase tracks a moving player tightly instead of committing to a stale
-- path. repathInterval caps how long we commit before recomputing.
function NpcBase:pursueStep(goalPosition, speed, repathInterval)
	self:setMoveSpeed(speed)
	local waypoints = self:computePath(goalPosition)
	if not waypoints or #waypoints < 2 then
		-- no route right now: probe straight at the goal, but bail on a wall
		local status = self:stepTo(goalPosition, nil, repathInterval)
		if status == "stuck" or status == "blocked" then
			self:unstickNudge()
		end
		return
	end
	local target = goalPosition
	local jump = false
	for index = 2, #waypoints do
		if (waypoints[index].Position - self.root.Position).Magnitude > ARRIVE_RADIUS then
			target = waypoints[index].Position
			jump = waypoints[index].Action == Enum.PathWaypointAction.Jump
			break
		end
	end
	if jump then
		self.humanoid.Jump = true
	end
	local status = self:stepTo(target, nil, repathInterval)
	if status == "stuck" or status == "blocked" then
		self:unstickNudge()
	end
end

-- Continuously chase a moving target. getGoal() returns the Vector3 to head
-- for right now (the target's live position, or a remembered spot), or nil
-- to stop chasing. getSpeed() returns the current chase speed. onTick() runs
-- once per leg (e.g. the chase noise). The caller's getGoal decides memory
-- and give-up logic; this just drives the legs and recovers from wedging.
function NpcBase:pursue(getGoal, getSpeed, onTick)
	local repathInterval = self.ctx.config.NPC.REPATH_INTERVAL or 0.35
	while self:canAct() do
		local goal = getGoal()
		if not goal then
			return
		end
		if onTick then
			onTick()
		end
		self:pursueStep(goal, getSpeed(), repathInterval)
	end
end

return NpcBase
