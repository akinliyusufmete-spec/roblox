--[[
	ChatReviveAI (ModuleScript, ServerScriptService.BaldiGame.ChatReviveAI)

	The on-sight chaser (the "Baldi" of this game).
	  - Roams between random waypoints.
	  - Raycast line-of-sight scan every SIGHT_INTERVAL (0.3s).
	  - On sight: PathfindingService chase, re-pathing every 0.5s.
	  - Loses sight: walks to the last known position, then resumes roaming.
	  - Touch (catch radius): game over for that player; a Nickel is dropped
	    where they were caught.
	  - Enrages when all notebooks are collected: faster, scans more often,
	    glows red (your rig gets a red Highlight; the placeholder also
	    recolors).

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

	-- the iconic chase noise, played on every re-path tick
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

	-- nearest targetable player with clear line of sight (throttled)
	local function findVisibleTarget()
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
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - base.root.Position).Magnitude
				if distance < bestDistance and base:canSee(hrp, cfg.SIGHT_RANGE) then
					bestDistance = distance
					cachedTarget = player
				end
			end
		end
		return cachedTarget
	end

	local function targetRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	-- ---------- chase ----------

	local function chase(player)
		local lastSeenAt = os.clock()
		local hrp = targetRoot(player)
		if not hrp then
			return
		end
		local lastKnown = hrp.Position

		while base:isActive() do
			if not ctx.manager.isRoundActive() then
				return
			end
			hrp = targetRoot(player)
			if not hrp or not ctx.manager.isTargetable(player) then
				break
			end

			if base:canSee(hrp, cfg.SIGHT_RANGE) then
				lastSeenAt = os.clock()
				lastKnown = hrp.Position
			elseif os.clock() - lastSeenAt > cfg.MEMORY_SECONDS then
				break
			end

			base:setMoveSpeed(chaseSpeed())
			base:chaseStepToward(lastKnown)
			pcall(function()
				self.slapSound.PlaybackSpeed = self.enraged and 1.3 or 1
				self.slapSound:Play()
			end)
			task.wait(cfg.REPATH_INTERVAL)
		end

		-- lost them: check out the last place they were seen
		if base:isActive() and ctx.manager.isRoundActive() then
			base:travelTo(lastKnown, chaseSpeed(), function()
				return findVisibleTarget() ~= nil
			end)
		end
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:isActive() or not (ctx.manager and ctx.manager.isRoundActive()) then
				task.wait(0.25)
			else
				local target = findVisibleTarget()
				if target then
					chase(target)
				else
					base:roamStep(cfg.ROAM_SPEED, function()
						return findVisibleTarget() ~= nil
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
