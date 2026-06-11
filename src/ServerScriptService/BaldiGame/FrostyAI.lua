--[[
	FrostyAI (ModuleScript, ServerScriptService.BaldiGame.FrostyAI)

	The passive roamer.
	  - Wanders between waypoints, pausing briefly at each, forever. Uses the
	    shared robust pathfinding, so it follows real routes and recovers if
	    it wedges instead of grinding into a wall.
	  - Never chases and needs no line-of-sight checks.
	  - Heartbeat magnitude check: any player within DEBUFF_RADIUS gets a
	    SpeedDebuff RemoteEvent (client slows to base * multiplier for a few
	    seconds and shows the frost vignette). Per-player cooldown so it
	    doesn't re-trigger every frame.
	  - Optionally chills other NPCs that wander too close (SLOWS_NPCS) — use
	    Frosty to slow down ChatRevive or LP.

	Custom rig: ReplicatedStorage/BaldiAssets/Npcs/Frosty
	(the glow/transparency styling below applies to the placeholder only)
]]

local RunService = game:GetService("RunService")

local NpcFactory = require(script.Parent.NpcFactory)
local NpcBase = require(script.Parent.NpcBase)

local FrostyAI = {}

local COLOR_BODY = Color3.fromRGB(190, 230, 250)
local COLOR_HEAD = Color3.fromRGB(235, 250, 255)

function FrostyAI.init(ctx)
	local cfg = ctx.config.NPC.FROSTY
	local self = { ctx = ctx, cfg = cfg }

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		transparency = 0.15,
		glowColor = Color3.fromRGB(150, 220, 255),
		tagColor = Color3.fromRGB(170, 230, 255),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.FROSTY) -- never chases
	self.base = base
	self.model = model

	local rng = Random.new()
	local playerCooldowns = {} -- [player] = next allowed debuff time
	local npcCooldowns = {} -- [npcSelf] = next allowed slow time

	-- ---------- main roam loop: waypoint, pause, next waypoint ----------

	task.spawn(function()
		while true do
			if not base:canAct() then
				task.wait(0.2)
			else
				base:roamStep(cfg.ROAM_SPEED, nil)
				task.wait(rng:NextNumber(cfg.WAIT_MIN, cfg.WAIT_MAX))
			end
		end
	end)

	-- ---------- proximity chill ----------

	RunService.Heartbeat:Connect(function()
		if not base:isActive() or not ctx.manager or not ctx.manager.isRoundActive() then
			return
		end
		local now = os.clock()

		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - base.root.Position).Magnitude < cfg.DEBUFF_RADIUS then
				if (playerCooldowns[player] or 0) <= now then
					playerCooldowns[player] = now + cfg.DEBUFF_COOLDOWN
					ctx.remotes.SpeedDebuff:FireClient(player, cfg.DEBUFF_SECONDS, cfg.DEBUFF_MULTIPLIER)
				end
			end
		end

		if cfg.SLOWS_NPCS then
			for _, npc in pairs(ctx.npcs) do
				if npc ~= self and npc.base then
					local distance = (npc.base.root.Position - base.root.Position).Magnitude
					if distance < cfg.DEBUFF_RADIUS and (npcCooldowns[npc] or 0) <= now then
						npcCooldowns[npc] = now + cfg.DEBUFF_COOLDOWN
						npc.base:applySlow(cfg.DEBUFF_MULTIPLIER, cfg.DEBUFF_SECONDS)
					end
				end
			end
		end
	end)

	function self.reset()
		playerCooldowns = {}
		npcCooldowns = {}
		base:resetToSpawn()
	end

	ctx.npcs.Frosty = self
	return self
end

return FrostyAI
