--[[
	SweeperAI (ModuleScript, ServerScriptService.BaldiGame.SweeperAI)

	The hall sweepers — Guidelines and Sai (config: GameConfig.NPC.SWEEPERS).
	  - Each barrels along its route end to end at SWEEP_SPEED, rests a few
	    seconds, then sweeps back the other way. Forever.
	  - Anyone within SWEEP_RADIUS mid-sweep is shoved along the sweep
	    direction at PUSH_SPEED — never a catch or a game over, but being
	    swept into ChatRevive's arms is your problem.
	  - SWEEPS_NPCS: the other characters get shoved too. Baiting a sweeper
	    into ChatRevive is a legitimate survival strategy.
	  - BSODA stuns a sweeper; Frosty chills it (slow-motion sweep).

	Routes come from your map: BaldiMap/SweepRoutes/<Name> — a folder of
	parts, walked in name order (1, 2, 3...). No route? The sweeper picks
	random waypoints to charge instead (and the Output suggests adding one).

	Player pushes are applied CLIENT-side via the SweptPush remote (the
	client owns its character's physics, so a server-side velocity write
	would stutter); other NPCs are server-owned and pushed directly.

	Custom rigs: ReplicatedStorage/BaldiAssets/Npcs/Guidelines and /Sai
	Sweep sound: AssetConfig.SOUNDS.sweep (else a built-in swoosh)
]]

local RunService = game:GetService("RunService")

local NpcFactory = require(script.Parent.NpcFactory)
local NpcBase = require(script.Parent.NpcBase)

local SweeperAI = {}

local STYLES = {
	GUIDELINES = {
		bodyColor = Color3.fromRGB(240, 240, 235),
		headColor = Color3.fromRGB(90, 90, 95),
		tagColor = Color3.fromRGB(235, 235, 230),
	},
	SAI = {
		bodyColor = Color3.fromRGB(70, 160, 150),
		headColor = Color3.fromRGB(95, 200, 185),
		tagColor = Color3.fromRGB(150, 230, 215),
	},
}

local function reversed(list)
	local out = {}
	for index = #list, 1, -1 do
		table.insert(out, list[index])
	end
	return out
end

local function createSweeper(ctx, key, cfg)
	local self = { ctx = ctx, cfg = cfg, sweeping = false }
	local style = STYLES[key] or STYLES.GUIDELINES

	local route = ctx.map.sweepRoutes[cfg.NAME]
	if not route then
		print(string.format(
			"[BaldiGame] No BaldiMap/SweepRoutes/%s folder — %s will charge random waypoints instead. "
				.. "Add a folder of ordered parts to give it a proper hallway run.",
			cfg.NAME, cfg.NAME))
	end

	-- spawn at the route start, else at a waypoint, else at the origin
	local spawnPosition
	if route then
		spawnPosition = route[1]
	else
		local waypoint = ctx.map.waypointsFolder:FindFirstChildWhichIsA("BasePart")
		spawnPosition = waypoint and waypoint.Position or Vector3.new(0, 1, 0)
	end
	local spawnCFrame = CFrame.new(spawnPosition + Vector3.new(0, 2.5, 0))

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = style.bodyColor,
		headColor = style.headColor,
		tagColor = style.tagColor,
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, spawnCFrame) -- sweepers never "chase"
	self.base = base
	self.model = model

	local sweepSoundId = ctx.assets.SOUNDS.sweep
	local whoosh = Instance.new("Sound")
	whoosh.Name = "SweepSound"
	whoosh.SoundId = (sweepSoundId ~= "" and sweepSoundId) or "rbxasset://sounds/swoosh.mp3"
	whoosh.Looped = true
	whoosh.Volume = 0.7
	whoosh.PlaybackSpeed = sweepSoundId ~= "" and 1 or 0.85
	whoosh.RollOffMaxDistance = 70
	whoosh.Parent = base.root

	local function setSweeping(on)
		self.sweeping = on
		pcall(function()
			if on then
				whoosh:Play()
			else
				whoosh:Stop()
			end
		end)
	end

	-- ---------- the sweep run loop ----------

	local rng = Random.new()
	local forward = true

	task.spawn(function()
		while true do
			if not base:canAct() then
				if self.sweeping then
					setSweeping(false)
				end
				task.wait(0.2)
			else
				setSweeping(true)
				base:setMoveSpeed(cfg.SWEEP_SPEED)
				if route then
					local points = forward and route or reversed(route)
					for _, point in ipairs(points) do
						if not base:canAct() then
							break
						end
						local status = base:stepTo(point, nil, nil)
						if status == "stuck" or status == "blocked" then
							-- something's in the way: path around it
							base:navigateTo(point, cfg.SWEEP_SPEED, nil)
						end
					end
					forward = not forward
				else
					base:roamStep(cfg.SWEEP_SPEED, nil)
				end
				setSweeping(false)
				base:stop()
				task.wait(rng:NextNumber(cfg.WAIT_MIN, cfg.WAIT_MAX))
			end
		end
	end)

	-- ---------- the shove ----------

	local pushRefire = {} -- [player] = next time we re-send their push

	RunService.Heartbeat:Connect(function()
		if not self.sweeping or not base:isActive() then
			return
		end
		if not ctx.manager or not ctx.manager.isRoundActive() then
			return
		end

		-- push along our actual direction of travel
		local velocity = base.root.AssemblyLinearVelocity
		local direction = Vector3.new(velocity.X, 0, velocity.Z)
		if direction.Magnitude > 1 then
			direction = direction.Unit
		else
			local look = base.root.CFrame.LookVector
			direction = Vector3.new(look.X, 0, look.Z)
			if direction.Magnitude < 0.01 then
				return
			end
			direction = direction.Unit
		end

		local now = os.clock()
		local rootPosition = base.root.Position

		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and not hrp.Anchored
				and (hrp.Position - rootPosition).Magnitude < cfg.SWEEP_RADIUS then
				if (pushRefire[player] or 0) <= now then
					pushRefire[player] = now + 0.4
					ctx.remotes.SweptPush:FireClient(player, direction, cfg.PUSH_SPEED, 0.55)
				end
			end
		end

		if cfg.SWEEPS_NPCS then
			for _, npc in pairs(ctx.npcs) do
				if npc ~= self and npc.base and npc.base.model.Parent then
					local otherRoot = npc.base.root
					if (otherRoot.Position - rootPosition).Magnitude < cfg.SWEEP_RADIUS then
						otherRoot.AssemblyLinearVelocity = Vector3.new(
							direction.X * cfg.PUSH_SPEED,
							otherRoot.AssemblyLinearVelocity.Y,
							direction.Z * cfg.PUSH_SPEED
						)
					end
				end
			end
		end
	end)

	function self.reset()
		setSweeping(false)
		forward = true
		pushRefire = {}
		base:resetToSpawn()
	end

	ctx.npcs[cfg.NAME] = self
	return self
end

function SweeperAI.init(ctx)
	local sweepers = {}
	for key, cfg in pairs(ctx.config.NPC.SWEEPERS) do
		sweepers[key] = createSweeper(ctx, key, cfg)
	end
	return sweepers
end

return SweeperAI
