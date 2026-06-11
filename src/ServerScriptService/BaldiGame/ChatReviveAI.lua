--[[
	ChatReviveAI (ModuleScript, ServerScriptService.BaldiGame.ChatReviveAI)

	The relentless chaser (the "Baldi" of this game).
	  - OMNISCIENT: always knows where the nearest player is and hunts them
	    from anywhere on the map. Rounding a corner doesn't lose him — your
	    only escape is to outpace him (sprint), stun him (BSODA), chill him
	    (Frosty), or reach the exit. (Set OMNISCIENT = false in GameConfig
	    to fall back to line-of-sight hunting within SIGHT_RANGE.)
	  - Chases via continuous re-pathing to your LIVE position, so he
	    follows you into rooms instead of stopping at the doorway.
	  - Catch (within CATCH_DISTANCE): game over for that player; a Nickel is
	    dropped where they were caught.
	  - Enrages when all notebooks are collected: faster, scans more often,
	    glows red (your rig gets a red Highlight; the placeholder recolors).

	Custom rig: ReplicatedStorage/BaldiAssets/Npcs/ChatRevive
	Chase sound: AssetConfig.SOUNDS.chase (else a built-in snap)
]]

local RunService = game:GetService("RunService")

local NpcFactory = require(script.Parent.NpcFactory)
local NpcBase = require(script.Parent.NpcBase)

local ChatReviveAI = {}

local COLOR_BODY = Color3.fromRGB(170, 35, 35)
local COLOR_HEAD = Color3.fromRGB(220, 60, 50)
local COLOR_ENRAGED = Color3.fromRGB(90, 10, 10)

function ChatReviveAI.init(ctx)
	local cfg = ctx.config.NPC.CHATREVIVE
	local self = {
		ctx = ctx,
		cfg = cfg,
		enraged = false,
	}

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(255, 90, 80),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.CHATREVIVE,
		(cfg.ROAM_SPEED + cfg.CHASE_SPEED) / 2)
	self.base = base
	self.model = model

	-- the iconic chase noise, played while hunting
	local chaseSoundId = ctx.assets.SOUNDS.chase
	local slap = Instance.new("Sound")
	slap.Name = "ChaseSound"
	slap.SoundId = (chaseSoundId ~= "" and chaseSoundId) or "rbxasset://sounds/snap.mp3"
	slap.Volume = 0.8
	slap.RollOffMaxDistance = 90
	slap.Parent = base.root
	self.slapSound = slap

	-- ---------- helpers ----------

	local lastScan = 0
	local cachedTarget = nil

	local function sightInterval()
		return self.enraged and cfg.ENRAGED_SIGHT_INTERVAL or cfg.SIGHT_INTERVAL
	end

	local function chaseSpeed()
		return self.enraged and cfg.ENRAGED_CHASE_SPEED or cfg.CHASE_SPEED
	end

	local function targetRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	-- nearest targetable player (throttled). When OMNISCIENT, walls and
	-- distance don't matter — he always picks the closest target.
	local function findTarget()
		if os.clock() - lastScan < sightInterval() then
			return cachedTarget
		end
		lastScan = os.clock()
		cachedTarget = nil
		if not ctx.manager then
			return nil
		end
		local bestDistance = math.huge
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			local hrp = targetRoot(player)
			if hrp then
				local distance = (hrp.Position - base.root.Position).Magnitude
				local visible = cfg.OMNISCIENT or base:canSee(hrp, cfg.SIGHT_RANGE)
				if visible and distance < bestDistance then
					bestDistance = distance
					cachedTarget = player
				end
			end
		end
		return cachedTarget
	end

	-- a ringing Alarm Clock overrides everything else he wants to do
	local function getDistraction()
		return ctx.economy and ctx.economy.getDistraction() or nil
	end

	-- ---------- chase ----------

	local function chase(player)
		local lastSeenAt = os.clock()
		local lastKnown = nil

		base:pursue(
			function()
				-- where to head for this leg, or nil to give up
				if getDistraction() then
					return nil -- that noise! (breaks off to investigate)
				end
				if not ctx.manager.isRoundActive() then
					return nil
				end
				local hrp = targetRoot(player)
				if not hrp or not ctx.manager.isTargetable(player) then
					return nil
				end
				if cfg.OMNISCIENT or base:canSee(hrp, cfg.SIGHT_RANGE) then
					lastSeenAt = os.clock()
					lastKnown = hrp.Position
					return lastKnown
				end
				-- lost sight (only possible when not omniscient): chase the
				-- last place we saw them, then resume roaming
				if os.clock() - lastSeenAt > cfg.MEMORY_SECONDS then
					return nil
				end
				if lastKnown and (lastKnown - base.root.Position).Magnitude < 4 then
					return nil -- reached the last-known spot, they're gone
				end
				return lastKnown
			end,
			chaseSpeed,
			function()
				pcall(function()
					self.slapSound.PlaybackSpeed = self.enraged and 1.3 or 1
					if not self.slapSound.IsPlaying then
						self.slapSound:Play()
					end
				end)
			end
		)
	end

	-- walk to the ringing alarm and stand over it until it stops
	local function investigate()
		base:pursue(
			function()
				local d = getDistraction()
				if not d then
					return nil
				end
				if (d.position - base.root.Position).Magnitude < 5 then
					return nil -- close enough; go stare at it
				end
				return d.position
			end,
			chaseSpeed
		)
		while base:canAct() do
			local d = getDistraction()
			if not d then
				break
			end
			if (d.position - base.root.Position).Magnitude > 8 then
				break -- got shoved away; the outer loop re-approaches
			end
			task.wait(0.2)
		end
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:canAct() then
				task.wait(0.2)
			elseif getDistraction() then
				investigate()
			else
				local target = findTarget()
				if target then
					chase(target)
				else
					base:roamStep(cfg.ROAM_SPEED, function()
						return findTarget() ~= nil or getDistraction() ~= nil
					end)
				end
			end
		end
	end)

	-- ---------- catch check ----------

	RunService.Heartbeat:Connect(function()
		if not base:isActive() or not ctx.manager or not ctx.manager.isRoundActive() then
			return
		end
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			local hrp = targetRoot(player)
			if hrp and (hrp.Position - base.root.Position).Magnitude < cfg.CATCH_DISTANCE then
				ctx.manager.playerCaught(player, cfg.NAME)
			end
		end
	end)

	-- ---------- public API ----------

	local isPlaceholder = model:GetAttribute("BaldiPlaceholderRig") == true

	function self.enrage()
		if self.enraged then
			return
		end
		self.enraged = true
		if isPlaceholder then
			for _, part in ipairs(model:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "FaceMark" then
					part.Color = COLOR_ENRAGED
				end
			end
		else
			-- tint your rig without overwriting its colors
			local tint = Instance.new("Highlight")
			tint.Name = "EnrageTint"
			tint.FillColor = Color3.fromRGB(180, 20, 20)
			tint.FillTransparency = 0.7
			tint.OutlineColor = Color3.fromRGB(120, 0, 0)
			tint.OutlineTransparency = 0.4
			tint.Parent = model
		end
		local glow = Instance.new("PointLight")
		glow.Name = "EnrageGlow"
		glow.Color = Color3.fromRGB(255, 40, 40)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = base.root
	end

	function self.reset()
		self.enraged = false
		local oldGlow = base.root:FindFirstChild("EnrageGlow")
		if oldGlow then
			oldGlow:Destroy()
		end
		local oldTint = model:FindFirstChild("EnrageTint")
		if oldTint then
			oldTint:Destroy()
		end
		if isPlaceholder then
			for _, part in ipairs(model:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "FaceMark" then
					part.Color = (part.Name == "Head") and COLOR_HEAD or COLOR_BODY
				end
			end
		end
		base:resetToSpawn()
	end

	ctx.npcs.ChatRevive = self
	return self
end

return ChatReviveAI
