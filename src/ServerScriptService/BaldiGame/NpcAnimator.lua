--[[
	NpcAnimator (ModuleScript, ServerScriptService.BaldiGame.NpcAnimator)

	Animates an NPC rig. Two layers, picked automatically:

	1. YOUR animations. Put a Folder named "Animations" inside the rig
	   (ReplicatedStorage/BaldiAssets/Npcs/<Name>/Animations) holding
	   Animation instances named:
	     Idle   — standing still
	     Walk   — roaming
	     Chase  — moving faster than the chase threshold (optional -> Walk)
	   Tracks loop and crossfade. If an id is blank or fails to load you get
	   a clear warning in the Output window naming the exact animation.

	2. Procedural walk fallback. If the rig has no usable Animations folder
	   but DOES have standard R6 joints (the code-built placeholder, or any
	   R6 rig), the limbs are swung in code so the character visibly walks.
	   This is why the placeholder block characters animate out of the box.

	A rig with neither (a custom mesh with no Animations folder) simply
	stays in its rest pose — add an Animations folder to fix that.
]]

local NpcAnimator = {}

local POLL_INTERVAL = 0.12
local MOVING_THRESHOLD = 0.5 -- studs/sec; below this counts as standing

-- ===================== your animations =====================

local function attachTrackAnimator(model, humanoid, folder, chaseThreshold)
	chaseThreshold = chaseThreshold or math.huge

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks = {}
	local loaded = 0
	for _, name in ipairs({ "Idle", "Walk", "Chase" }) do
		local animation = folder:FindFirstChild(name)
		if animation and animation:IsA("Animation") then
			if animation.AnimationId == "" then
				warn(string.format(
					"[BaldiGame] %s/Animations/%s has a blank AnimationId — publish the animation and paste its id.",
					model.Name, name))
			else
				-- a freshly cloned rig can need a couple of tries before the
				-- Animator accepts a LoadAnimation, so retry briefly
				local track
				for _ = 1, 3 do
					local ok, loadedTrack = pcall(function()
						return animator:LoadAnimation(animation)
					end)
					if ok and loadedTrack then
						track = loadedTrack
						break
					end
					task.wait(0.1)
				end
				if track then
					track.Looped = true
					track.Priority = Enum.AnimationPriority.Movement
					tracks[name] = track
					loaded = loaded + 1
				else
					warn(string.format(
						"[BaldiGame] %s/Animations/%s failed to load — is the id published to this game's owner (user or group)?",
						model.Name, name))
				end
			end
		end
	end

	if loaded == 0 then
		return nil
	end
	print(string.format("[BaldiGame] %s: loaded %d custom animation(s).", model.Name, loaded))

	local self = { running = true, current = nil }

	local function play(name)
		local track = tracks[name]
		if name == "Chase" and not track then
			track = tracks.Walk
		end
		if not track and name == "Idle" then
			track = tracks.Walk -- a rig with only a Walk loop still moves
		end
		if track == self.current then
			return
		end
		if self.current then
			self.current:Stop(0.2)
		end
		self.current = track
		if track then
			track:Play(0.2)
		end
	end

	task.spawn(function()
		while self.running and model.Parent do
			local root = model.PrimaryPart
			if root then
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if speed < MOVING_THRESHOLD then
					play("Idle")
				elseif humanoid.WalkSpeed > chaseThreshold then
					play("Chase")
				else
					play("Walk")
				end
			end
			task.wait(POLL_INTERVAL)
		end
	end)

	function self.destroy()
		self.running = false
		if self.current then
			self.current:Stop()
			self.current = nil
		end
	end

	return self
end

-- ===================== procedural walk fallback =====================

-- Standard R6 limb joints and which way each should swing.
local SWING_JOINTS = {
	["Left Hip"] = 1,
	["Right Hip"] = -1,
	["Left Shoulder"] = -1,
	["Right Shoulder"] = 1,
}

local function attachProceduralWalk(model, humanoid)
	local joints = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and SWING_JOINTS[descendant.Name] then
			table.insert(joints, {
				motor = descendant,
				base = descendant.C0,
				sign = SWING_JOINTS[descendant.Name],
			})
		end
	end
	if #joints == 0 then
		return nil
	end

	local self = { running = true }
	task.spawn(function()
		local phase = 0
		while self.running and model.Parent do
			local dt = task.wait()
			local root = model.PrimaryPart
			local speed = 0
			if root then
				local velocity = root.AssemblyLinearVelocity
				speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			end
			if speed > MOVING_THRESHOLD then
				-- step cadence scales with how fast the NPC is moving
				phase = phase + dt * (4 + math.clamp(speed, 0, 24) * 0.5)
				local swing = math.sin(phase) * math.rad(38)
				for _, joint in ipairs(joints) do
					joint.motor.C0 = joint.base * CFrame.Angles(swing * joint.sign, 0, 0)
				end
			else
				-- ease the limbs back to a neutral stand
				for _, joint in ipairs(joints) do
					joint.motor.C0 = joint.motor.C0:Lerp(joint.base, 0.2)
				end
			end
		end
	end)

	function self.destroy()
		self.running = false
		for _, joint in ipairs(joints) do
			joint.motor.C0 = joint.base
		end
	end

	return self
end

-- ===================== entry point =====================

-- chaseThreshold: WalkSpeed above which "Chase" plays instead of "Walk".
-- Pass math.huge / nil for characters that never chase (e.g. Frosty).
function NpcAnimator.attach(model, chaseThreshold)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local folder = model:FindFirstChild("Animations")
	if folder then
		local tracked = attachTrackAnimator(model, humanoid, folder, chaseThreshold)
		if tracked then
			return tracked
		end
		-- folder present but nothing usable loaded: still try to move limbs
	end

	return attachProceduralWalk(model, humanoid)
end

return NpcAnimator
