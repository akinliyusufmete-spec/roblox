--[[
	NpcAnimator (ModuleScript, ServerScriptService.BaldiGame.NpcAnimator)

	Plays YOUR animations on an NPC rig. Put a Folder named "Animations"
	inside the rig (ReplicatedStorage/BaldiAssets/Npcs/<Name>/Animations)
	containing Animation instances named:

	  Idle   — played while standing still
	  Walk   — played while roaming
	  Chase  — played while moving faster than the chase threshold
	           (optional; falls back to Walk)

	All are optional — a rig with no Animations folder simply doesn't
	animate (the placeholder rigs work this way). Tracks loop and
	crossfade. Server-side playback replicates to every client.
]]

local NpcAnimator = {}

local POLL_INTERVAL = 0.15
local MOVING_THRESHOLD = 0.5 -- studs/sec; below this counts as standing

-- chaseThreshold: WalkSpeed above which "Chase" plays instead of "Walk".
-- Pass math.huge for characters that never chase (e.g. Frosty).
function NpcAnimator.attach(model, chaseThreshold)
	chaseThreshold = chaseThreshold or math.huge
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local folder = model:FindFirstChild("Animations")
	if not humanoid or not folder then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks = {}
	for _, name in ipairs({ "Idle", "Walk", "Chase" }) do
		local animation = folder:FindFirstChild(name)
		if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Movement
				tracks[name] = track
			else
				warn(string.format("[BaldiGame] Could not load animation %s/%s", model.Name, name))
			end
		end
	end
	if next(tracks) == nil then
		return nil
	end

	local self = { running = true, current = nil }

	local function play(name)
		local track = tracks[name]
		if name == "Chase" and not track then
			track = tracks.Walk
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

return NpcAnimator
