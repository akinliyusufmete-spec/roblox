--[[
	NpcBase (ModuleScript, ServerScriptService.BaldiGame.NpcBase)

	Shared behaviour for all three characters: pathfinding locomotion,
	roaming between waypoints, line-of-sight raycasts, stun/knockback
	(BSODA) and slow (Frosty) effects, animation hookup, and reset
	between rounds.

	The three AIs only differ in WHAT triggers a new path and WHAT the
	target is — that difference lives in ChatReviveAI / LpAI / FrostyAI;
	everything mechanical lives here.
]]

local PathfindingService = game:GetService("PathfindingService")

local NpcAnimator = require(script.Parent.NpcAnimator)

local NpcBase = {}
NpcBase.__index = NpcBase

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

	-- plays the Animations folder inside your rig, if present
	self.animator = NpcAnimator.attach(model, chaseAnimThreshold)

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

-- ===================== pathfinding =====================

function NpcBase:computePath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(self.root.Position, targetPosition)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- MoveTo a single point and wait until arrival / timeout / abort.
function NpcBase:waitMoveTo(position, timeout, abortCheck)
	if self.humanoid.Health <= 0 then
		return false
	end
	local finished = false
	local reached = false
	local conn = self.humanoid.MoveToFinished:Connect(function(ok)
		finished = true
		reached = ok
	end)
	self.humanoid:MoveTo(position)
	local started = os.clock()
	while not finished do
		if os.clock() - started > timeout then
			break
		end
		if self.paused or self:isStunned() then
			break
		end
		if abortCheck and abortCheck() then
			break
		end
		task.wait(0.05)
	end
	conn:Disconnect()
	return finished and reached
end

-- Full path-follow to a target position. Returns true if it got there.
-- abortCheck() returning true bails out early (e.g. "I spotted a player").
function NpcBase:travelTo(targetPosition, speed, abortCheck)
	self:setMoveSpeed(speed)
	local waypoints = self:computePath(targetPosition)
	if not waypoints then
		-- navmesh not ready or target unreachable: straight-line fallback
		return self:waitMoveTo(targetPosition, 4, abortCheck)
	end
	for index = 2, #waypoints do
		local waypoint = waypoints[index]
		local distance = (waypoint.Position - self.root.Position).Magnitude
		local timeout = distance / math.max(self.humanoid.WalkSpeed, 1) + 1.5
		local ok = self:waitMoveTo(waypoint.Position, timeout, abortCheck)
		if self.paused or self:isStunned() then
			return false
		end
		if abortCheck and abortCheck() then
			return false
		end
		if not ok then
			return false
		end
	end
	return true
end

-- One roam leg: pick a random waypoint part and walk to it.
function NpcBase:roamStep(speed, abortCheck)
	local nodes = self.ctx.map.waypointsFolder:GetChildren()
	if #nodes == 0 then
		task.wait(1)
		return
	end
	local node = nodes[self.rng:NextInteger(1, #nodes)]
	self:travelTo(node.Position, speed, abortCheck)
end

-- During a chase we re-path every REPATH_INTERVAL instead of walking the
-- whole path; aim for the first waypoint a few studs ahead so motion stays
-- smooth at chase speed.
function NpcBase:chaseStepToward(goalPosition)
	local waypoints = self:computePath(goalPosition)
	local stepTarget = goalPosition
	if waypoints then
		for index = 2, #waypoints do
			if (waypoints[index].Position - self.root.Position).Magnitude > 5 then
				stepTarget = waypoints[index].Position
				break
			end
		end
	end
	self.humanoid:MoveTo(stepTarget)
end

return NpcBase
