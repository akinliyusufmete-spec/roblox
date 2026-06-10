--[[
	InstallBaldiGame.lua  (GENERATED — do not edit; run tools/build_installer.py)

	HOW TO USE:
	  1. Open Roblox Studio with any place (an empty Baseplate is fine).
	  2. View -> Command Bar.
	  3. Paste this ENTIRE file into the command bar and press Enter.
	  4. Press Play. The school builds itself at runtime.

	Re-running the installer replaces any previous install.
]]

local function getRoot(rootName)
	if rootName == "StarterPlayerScripts" then
		return game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
	end
	return game:GetService(rootName)
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- wipe any previous install
for _, target in ipairs({
	{ "ServerScriptService", "BaldiGame" },
	{ "ReplicatedStorage", "BaldiShared" },
	{ "StarterPlayerScripts", "BaldiClient" },
}) do
	local root = getRoot(target[1])
	local old = root and root:FindFirstChild(target[2])
	if old then
		old:Destroy()
	end
end

local files = {
	{
		root = "ReplicatedStorage",
		folders = { "BaldiShared" },
		name = "GameConfig",
		class = "ModuleScript",
		source = [=====[
--[[
	GameConfig (ModuleScript, ReplicatedStorage.BaldiShared.GameConfig)
	Single source of truth for every tunable number in the game.
	Both the server and the client require this module.
]]

local GameConfig = {}

-- ========== General ==========
GameConfig.GAME_TITLE = "SCHOOLHOUSE SURVIVAL"
GameConfig.GAME_SUBTITLE = "a Baldi's Basics inspired fan game"
GameConfig.COUNTDOWN_SECONDS = 3
GameConfig.FIRST_PERSON = true -- lock camera to first person during a round

-- ========== Notebooks ==========
GameConfig.NOTEBOOK_SPAWN_COUNT = 10 -- how many notebooks are placed per round
GameConfig.NOTEBOOK_PROMPT_DISTANCE = 8

-- ========== Player movement / stamina ==========
GameConfig.PLAYER = {
	WALK_SPEED = 16,
	SPRINT_SPEED = 24,
}

GameConfig.STAMINA = {
	MAX = 100,
	DRAIN_PER_SEC = 10, -- while sprinting
	REGEN_PER_SEC = 6, -- while not sprinting
	SPRINT_REENABLE = 30, -- exhaustion lock clears at this value
	LOW_THRESHOLD = 30, -- bar turns yellow below this
}

-- ========== Items / economy ==========
GameConfig.ITEMS = {
	BSODA = {
		id = "BSODA",
		displayName = "BSODA",
		shortLabel = "BSODA",
		description = "Fires a fizzy blast that knocks a character back 20 studs and stuns it for 3 seconds.",
		cost = 1,
		color = { 40, 120, 255 }, -- RGB, built into Color3 where used
	},
	ZESTY = {
		id = "ZESTY",
		displayName = "Zesty Bar",
		shortLabel = "ZESTY",
		description = "Instantly restores your stamina to 100 and clears exhaustion.",
		cost = 1,
		color = { 250, 200, 40 },
	},
}

GameConfig.INVENTORY_SLOTS = 2
GameConfig.PICKUP_RADIUS = 3.5 -- walking this close to a world pickup grabs it
GameConfig.VENDING_CLOSE_DISTANCE = 9 -- vending popup closes past this distance
GameConfig.NICKELS_AT_ROUND_START = 2 -- scattered in the halls so a fresh run can buy something
GameConfig.WORLD_ITEMS_AT_ROUND_START = true -- one free BSODA + Zesty hidden in the school

GameConfig.BSODA_PROJECTILE = {
	SPEED = 55,
	RANGE = 70,
	PUSH_STUDS = 20,
	PUSH_DURATION = 0.5,
	STUN_SECONDS = 3,
	HIT_RADIUS = 4,
}

-- ========== NPCs ==========
GameConfig.NPC = {
	CHATREVIVE = {
		NAME = "ChatRevive",
		ROAM_SPEED = 10,
		CHASE_SPEED = 18.5, -- sprint (24) outruns it, walking (16) does not
		ENRAGED_CHASE_SPEED = 22, -- after all notebooks are collected
		ENRAGED_SIGHT_INTERVAL = 0.15,
		SIGHT_RANGE = 70,
		SIGHT_INTERVAL = 0.3,
		REPATH_INTERVAL = 0.5,
		MEMORY_SECONDS = 3, -- keeps chasing last-known position this long after losing sight
		CATCH_DISTANCE = 4,
	},
	LP = {
		NAME = "LP",
		ROAM_SPEED = 12,
		CHASE_SPEED = 23, -- a sprinting player (24) can barely escape
		SIGHT_RANGE = 60,
		SIGHT_INTERVAL = 0.3,
		REPATH_INTERVAL = 0.5,
		SPEED_THRESHOLD = 20, -- horizontal velocity above this + line of sight = trouble
		MEMORY_SECONDS = 4,
		CATCH_DISTANCE = 4,
		DETENTION_SECONDS = 15,
		RELEASE_IMMUNITY_SECONDS = 5, -- can't be re-detained right after release
	},
	FROSTY = {
		NAME = "Frosty",
		ROAM_SPEED = 8,
		WAIT_MIN = 1,
		WAIT_MAX = 2,
		DEBUFF_RADIUS = 6,
		DEBUFF_SECONDS = 4,
		DEBUFF_MULTIPLIER = 0.4, -- WalkSpeed becomes base * 0.4
		DEBUFF_COOLDOWN = 4, -- per victim
		SLOWS_NPCS = true, -- Frosty also chills ChatRevive / LP that wander too close
	},
}

-- ========== RemoteEvents (created by the server at startup) ==========
GameConfig.REMOTES_FOLDER = "BaldiRemotes"
GameConfig.REMOTE_NAMES = {
	-- client -> server
	"RequestStart",
	"UseItem",
	"SwapSlots",
	"BuyItem",
	-- server -> client
	"GameCountdown",
	"GameStarted",
	"RoundEnded",
	"NotebookCollected",
	"PhaseChanged",
	"PlayerWon",
	"PlayerLost",
	"NickelChanged",
	"InventoryChanged",
	"PickupFailed",
	"OpenVending",
	"BuyResult",
	"SendToDetention",
	"DetentionReleased",
	"SpeedDebuff",
	"StaminaRestore",
}

return GameConfig
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "Main",
		class = "Script",
		source = [=====[
--[[
	Main (Script, ServerScriptService.BaldiGame.Main)

	Server bootstrap. Builds the shared context table and initializes every
	system in dependency order:

	  config -> remotes -> map -> NPCs -> economy/detention/notebooks/exit
	         -> GameManager (last; it wires the Play button)

	All systems communicate through the ctx table instead of require-ing
	each other, which keeps the module graph cycle-free.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BaldiShared")
local GameConfig = require(shared:WaitForChild("GameConfig"))

local RemoteSetup = require(script.Parent.RemoteSetup)
local MapBuilder = require(script.Parent.MapBuilder)
local ChatReviveAI = require(script.Parent.ChatReviveAI)
local LpAI = require(script.Parent.LpAI)
local FrostyAI = require(script.Parent.FrostyAI)
local DetentionSystem = require(script.Parent.DetentionSystem)
local ItemEconomy = require(script.Parent.ItemEconomy)
local NotebookSpawner = require(script.Parent.NotebookSpawner)
local ExitDoorManager = require(script.Parent.ExitDoorManager)
local GameManager = require(script.Parent.GameManager)

local ctx = {
	config = GameConfig,
	remotes = nil, -- RemoteSetup
	map = nil, -- MapBuilder
	npcs = {}, -- ChatReviveAI / LpAI / FrostyAI register themselves
	manager = nil, -- GameManager
	economy = nil, -- ItemEconomy
	detention = nil, -- DetentionSystem
	notebookSpawner = nil, -- NotebookSpawner
	exitDoor = nil, -- ExitDoorManager
}

RemoteSetup.init(ctx)
MapBuilder.build(ctx)

-- Give the navmesh a moment to bake over the freshly generated geometry
-- before the first paths are computed (paths fail gracefully anyway).
task.wait(1)

DetentionSystem.init(ctx) -- before LpAI, which reads ctx.detention

ChatReviveAI.init(ctx)
LpAI.init(ctx)
FrostyAI.init(ctx)

ItemEconomy.init(ctx)
NotebookSpawner.init(ctx)
ExitDoorManager.init(ctx)
GameManager.init(ctx)

print("[BaldiGame] Server ready. Map built, NPCs spawned, remotes live.")
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "ChatReviveAI",
		class = "ModuleScript",
		source = [=====[
--[[
	ChatReviveAI (ModuleScript, ServerScriptService.BaldiGame.ChatReviveAI)

	The on-sight chaser (the "Baldi" of this game).
	  - Roams between random waypoints.
	  - Raycast line-of-sight scan every SIGHT_INTERVAL (0.3s).
	  - On sight: PathfindingService chase, re-pathing every 0.5s.
	  - Loses sight: walks to the last known position, then resumes roaming.
	  - Touch (catch radius): game over for that player; a Nickel is dropped
	    where they were caught.
	  - Enrages when all notebooks are collected: faster, scans more often.
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

	local model = NpcFactory.createRig({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(255, 90, 80),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.CHATREVIVE)
	self.base = base
	self.model = model

	-- the iconic chase noise: a snap played on every re-path tick
	local slap = Instance.new("Sound")
	slap.Name = "ChaseSlap"
	slap.SoundId = "rbxasset://sounds/snap.mp3"
	slap.Volume = 0.8
	slap.RollOffMaxDistance = 90
	slap.Parent = model:WaitForChild("Torso")
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

	function self.enrage()
		if self.enraged then
			return
		end
		self.enraged = true
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "FaceMark" then
				part.Color = COLOR_ENRAGED
			end
		end
		local glow = Instance.new("PointLight")
		glow.Name = "EnrageGlow"
		glow.Color = Color3.fromRGB(255, 40, 40)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = model:FindFirstChild("Torso")
	end

	function self.reset()
		self.enraged = false
		local torso = model:FindFirstChild("Torso")
		local oldGlow = torso and torso:FindFirstChild("EnrageGlow")
		if oldGlow then
			oldGlow:Destroy()
		end
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "FaceMark" then
				part.Color = (part.Name == "Head") and COLOR_HEAD or COLOR_BODY
			end
		end
		base:resetToSpawn()
	end

	ctx.npcs.ChatRevive = self
	return self
end

return ChatReviveAI
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "DetentionSystem",
		class = "ModuleScript",
		source = [=====[
--[[
	DetentionSystem (ModuleScript, ServerScriptService.BaldiGame.DetentionSystem)

	LP's punishment: teleport the offender to the detention room, anchor them
	for DETENTION_SECONDS while the client shows the countdown overlay, then
	release with a short immunity window so LP can't instantly re-detain.
]]

local DetentionSystem = {}

function DetentionSystem.init(ctx)
	local self = {}
	local detained = {} -- [player] = { releaseAt = t }
	local immunityUntil = {} -- [player] = t

	local function release(player)
		local info = detained[player]
		if not info then
			return
		end
		detained[player] = nil
		immunityUntil[player] = os.clock() + ctx.config.NPC.LP.RELEASE_IMMUNITY_SECONDS

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
		if player.Parent then
			ctx.remotes.DetentionReleased:FireClient(player)
		end
	end

	function self.detain(player, seconds, byName)
		if detained[player] then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		detained[player] = { releaseAt = os.clock() + seconds }
		character:PivotTo(ctx.map.detentionCFrame)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.Anchored = true
		ctx.remotes.SendToDetention:FireClient(player, seconds, byName)

		task.delay(seconds, function()
			release(player)
		end)
	end

	function self.isDetained(player)
		return detained[player] ~= nil
	end

	function self.hasImmunity(player)
		return (immunityUntil[player] or 0) > os.clock()
	end

	function self.releasePlayer(player)
		release(player)
	end

	function self.releaseAll()
		for player in pairs(detained) do
			release(player)
		end
	end

	function self.forget(player)
		detained[player] = nil
		immunityUntil[player] = nil
	end

	ctx.detention = self
	return self
end

return DetentionSystem
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "ExitDoorManager",
		class = "ModuleScript",
		source = [=====[
--[[
	ExitDoorManager (ModuleScript, ServerScriptService.BaldiGame.ExitDoorManager)

	The big red door at the end of the entrance corridor. Locked while
	notebooks remain; when all are collected it turns green and a proximity
	loop awards the win to any participant who reaches it.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ExitDoorManager = {}

local COLOR_LOCKED = Color3.fromRGB(140, 30, 30)
local COLOR_OPEN = Color3.fromRGB(40, 170, 70)

function ExitDoorManager.init(ctx)
	local self = { open = false }
	local door = ctx.map.exitDoor

	local function setLabel(text)
		if not door then
			return
		end
		local gui = door:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = text
		end
	end

	function self.close()
		self.open = false
		if door then
			door.Color = COLOR_LOCKED
			local glow = door:FindFirstChild("ExitGlow")
			if glow then
				glow:Destroy()
			end
			setLabel("EXIT")
		end
	end

	function self.openDoor()
		if self.open or not door then
			return
		end
		self.open = true
		door.Color = COLOR_OPEN
		setLabel("EXIT - OPEN!")
		local glow = Instance.new("PointLight")
		glow.Name = "ExitGlow"
		glow.Color = COLOR_OPEN
		glow.Range = 16
		glow.Brightness = 2
		glow.Parent = door
	end

	if door then
		RunService.Heartbeat:Connect(function()
			if not self.open or not ctx.manager or not ctx.manager.isRoundActive() then
				return
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if ctx.manager.isParticipant(player) then
					local character = player.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - door.Position).Magnitude < 6 then
						ctx.manager.playerWon(player)
					end
				end
			end
		end)
	else
		warn("[BaldiGame] No ExitDoor found in the map; wins cannot trigger.")
	end

	ctx.exitDoor = self
	return self
end

return ExitDoorManager
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "FrostyAI",
		class = "ModuleScript",
		source = [=====[
--[[
	FrostyAI (ModuleScript, ServerScriptService.BaldiGame.FrostyAI)

	The passive roamer.
	  - Picks random waypoints, walks to each, waits 1–2 seconds, repeats.
	  - Never chases and needs no line-of-sight checks.
	  - Heartbeat magnitude check: any player within DEBUFF_RADIUS gets a
	    SpeedDebuff RemoteEvent (client slows to base * 0.4 for 4 seconds
	    and shows the frost vignette). Per-player cooldown so it doesn't
	    re-trigger every frame.
	  - Optionally chills other NPCs that wander too close (SLOWS_NPCS).
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

	local model = NpcFactory.createRig({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		transparency = 0.15,
		glowColor = Color3.fromRGB(150, 220, 255),
		tagColor = Color3.fromRGB(170, 230, 255),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.FROSTY)
	self.base = base
	self.model = model

	local rng = Random.new()
	local playerCooldowns = {} -- [player] = next allowed debuff time
	local npcCooldowns = {} -- [npcSelf] = next allowed slow time

	-- ---------- main roam loop: waypoint, wait 1-2s, next waypoint ----------

	task.spawn(function()
		while true do
			if not base:isActive() or not (ctx.manager and ctx.manager.isRoundActive()) then
				task.wait(0.25)
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
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "GameManager",
		class = "ModuleScript",
		source = [=====[
--[[
	GameManager (ModuleScript, ServerScriptService.BaldiGame.GameManager)

	The round state machine:

	  IDLE ── Play pressed ──> COUNTDOWN (3s, players anchored at entrance)
	       <── all players out ── ACTIVE (notebooks spawned, NPCs gated)

	Activation gating per the plan:
	  0 notebooks  -> all NPCs frozen
	  1 notebook   -> all NPCs activate (roam loops start)
	  10 notebooks -> the main chaser enrages + the exit opens
	                  (the plan's "Silver enrages" trigger — wired to
	                   ChatRevive since it is the primary antagonist)

	Per-player outcomes:
	  - Caught by ChatRevive -> lose screen, a Nickel drops at the spot.
	  - Reach the open exit  -> win screen with elapsed + session best time.
	Players pressing Play during an active round simply join it.
]]

local Players = game:GetService("Players")

local GameManager = {}

function GameManager.init(ctx)
	local self = {}
	local config = ctx.config
	local remotes = ctx.remotes

	local phase = "IDLE" -- IDLE | COUNTDOWN | ACTIVE
	local participants = {} -- [player] = true
	local notebooksCollected = 0
	local notebooksTotal = config.NOTEBOOK_SPAWN_COUNT
	local roundStartedAt = 0
	local bestTimes = {} -- [userId] = seconds (session best)
	local startDebounce = {} -- [player] = next allowed RequestStart time

	-- ===================== queries used by the AIs =====================

	function self.isRoundActive()
		return phase == "ACTIVE"
	end

	function self.isParticipant(player)
		return participants[player] == true
	end

	function self.getNotebookCounts()
		return notebooksCollected, notebooksTotal
	end

	function self.isTargetable(player)
		if not participants[player] then
			return false
		end
		local character = player.Character
		if not character then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp or humanoid.Health <= 0 then
			return false
		end
		if hrp.Anchored then -- countdown or detention
			return false
		end
		if ctx.detention.isDetained(player) then
			return false
		end
		return true
	end

	function self.getTargetablePlayers()
		local list = {}
		for player in pairs(participants) do
			if self.isTargetable(player) then
				table.insert(list, player)
			end
		end
		return list
	end

	-- ===================== helpers =====================

	local function teleportToRoundSpawn(player, anchored)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not hrp then
			return false
		end
		-- spread players a little so they don't stack
		local offset = CFrame.new(math.random(-3, 3), 0, math.random(-2, 2))
		character:PivotTo(ctx.map.roundSpawnCFrame * offset)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.Anchored = anchored
		return true
	end

	local function teleportToLobby(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if character and hrp then
			hrp.Anchored = false
			if ctx.map.lobbySpawn then
				character:PivotTo(ctx.map.lobbySpawn.CFrame * CFrame.new(math.random(-4, 4), 3, math.random(-4, 4)))
			end
		end
	end

	local function setNpcsPaused(paused)
		for _, npc in pairs(ctx.npcs) do
			npc.base:setPaused(paused)
		end
	end

	local function resetNpcs()
		for _, npc in pairs(ctx.npcs) do
			if npc.reset then
				npc.reset()
			else
				npc.base:resetToSpawn()
			end
		end
	end

	-- ===================== round flow =====================

	local function endRound()
		if phase == "IDLE" then
			return
		end
		phase = "IDLE"
		for player in pairs(participants) do
			participants[player] = nil
			teleportToLobby(player)
		end
		ctx.detention.releaseAll()
		ctx.notebookSpawner.clear()
		ctx.economy.clearPickups()
		ctx.exitDoor.close()
		resetNpcs()
		notebooksCollected = 0
		remotes.RoundEnded:FireAllClients()
	end

	local function checkRoundEnd()
		if phase ~= "ACTIVE" then
			return
		end
		if next(participants) == nil then
			endRound()
		end
	end

	local function joinActiveRound(player)
		participants[player] = true
		if not teleportToRoundSpawn(player, false) then
			participants[player] = nil
			return
		end
		remotes.GameStarted:FireClient(player)
		remotes.NotebookCollected:FireClient(player, notebooksCollected, notebooksTotal)
		if ctx.exitDoor.open then
			remotes.PhaseChanged:FireClient(player, "EXIT_OPEN")
		elseif notebooksCollected > 0 then
			remotes.PhaseChanged:FireClient(player, "CHARACTERS_ACTIVE")
		end
	end

	local function beginCountdown(firstPlayer)
		phase = "COUNTDOWN"
		notebooksCollected = 0
		resetNpcs()
		ctx.exitDoor.close()
		notebooksTotal = ctx.notebookSpawner.spawnForRound()
		ctx.economy.onRoundStart()

		participants[firstPlayer] = true
		teleportToRoundSpawn(firstPlayer, true)
		remotes.GameCountdown:FireClient(firstPlayer, config.COUNTDOWN_SECONDS)

		task.delay(config.COUNTDOWN_SECONDS, function()
			if phase ~= "COUNTDOWN" then
				return
			end
			phase = "ACTIVE"
			roundStartedAt = os.clock()
			for player in pairs(participants) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = false
				end
				remotes.GameStarted:FireClient(player)
				remotes.NotebookCollected:FireClient(player, notebooksCollected, notebooksTotal)
			end
			checkRoundEnd() -- everyone may have left during the countdown
		end)
	end

	-- ===================== plan step 6: notebook -> HUD + gating =====================

	function self.onNotebookCollected(byPlayer)
		notebooksCollected = notebooksCollected + 1
		remotes.NotebookCollected:FireAllClients(notebooksCollected, notebooksTotal)

		if notebooksCollected == 1 then
			-- first notebook: every character wakes up
			setNpcsPaused(false)
			remotes.PhaseChanged:FireAllClients("CHARACTERS_ACTIVE")
		end
		if notebooksCollected >= notebooksTotal then
			-- final notebook: enrage + exit phase
			if ctx.npcs.ChatRevive and ctx.npcs.ChatRevive.enrage then
				ctx.npcs.ChatRevive.enrage()
			end
			ctx.exitDoor.openDoor()
			remotes.PhaseChanged:FireAllClients("EXIT_OPEN")
		end
	end

	-- ===================== outcomes =====================

	function self.playerCaught(player, catcherName)
		if not participants[player] then
			return
		end
		participants[player] = nil

		-- ChatRevive drops a Nickel where the victim stood
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			ctx.economy.spawnNickel(hrp.Position + Vector3.new(0, -1.5, 0))
		end

		ctx.detention.releasePlayer(player)
		teleportToLobby(player)
		remotes.PlayerLost:FireClient(player, catcherName, catcherName .. " caught you in the halls.")
		checkRoundEnd()
	end

	function self.playerWon(player)
		if not participants[player] then
			return
		end
		participants[player] = nil

		local elapsed = os.clock() - roundStartedAt
		local best = bestTimes[player.UserId]
		if not best or elapsed < best then
			best = elapsed
			bestTimes[player.UserId] = best
		end

		ctx.detention.releasePlayer(player)
		teleportToLobby(player)
		remotes.PlayerWon:FireClient(player, elapsed, best)
		checkRoundEnd()
	end

	-- ===================== player lifecycle =====================

	local function onCharacterAdded(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.WalkSpeed = config.PLAYER.WALK_SPEED
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "BaldiPlayer"
			end
		end
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "BaldiPlayer"
			end
		end)
		humanoid.Died:Connect(function()
			if participants[player] then
				participants[player] = nil
				remotes.PlayerLost:FireClient(player, "the schoolhouse", "You collapsed. The school wins this time.")
				checkRoundEnd()
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		if ctx.map.lobbySpawn then
			player.RespawnLocation = ctx.map.lobbySpawn
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		ctx.economy.syncAll(player)
	end)

	-- players already present when the server script started (Play Solo race)
	for _, player in ipairs(Players:GetPlayers()) do
		if ctx.map.lobbySpawn then
			player.RespawnLocation = ctx.map.lobbySpawn
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
			teleportToLobby(player)
		end
		ctx.economy.syncAll(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		ctx.detention.forget(player)
		ctx.economy.forget(player)
		startDebounce[player] = nil
		checkRoundEnd()
	end)

	-- ===================== Play button =====================

	remotes.RequestStart.OnServerEvent:Connect(function(player)
		if (startDebounce[player] or 0) > os.clock() then
			return
		end
		startDebounce[player] = os.clock() + 1

		if participants[player] then
			return
		end
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			return
		end

		if phase == "IDLE" then
			beginCountdown(player)
		elseif phase == "COUNTDOWN" then
			participants[player] = true
			teleportToRoundSpawn(player, true)
			remotes.GameCountdown:FireClient(player, config.COUNTDOWN_SECONDS)
		else -- ACTIVE: join the round in progress
			joinActiveRound(player)
		end
	end)

	ctx.manager = self
	return self
end

return GameManager
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "ItemEconomy",
		class = "ModuleScript",
		source = [=====[
--[[
	ItemEconomy (ModuleScript, ServerScriptService.BaldiGame.ItemEconomy)

	Server-authoritative inventory + currency:
	  - Two item slots per player; slot 1 is the active slot.
	  - Nickels: currency, picked up by walking over them, dropped by
	    ChatRevive where a player was caught, spent at vending machines.
	  - World pickups: walking over an item auto-collects it if a slot is
	    free, otherwise the client gets a PickupFailed ("Inventory full").
	  - UseItem: validates slot 1 and applies the effect —
	      ZESTY -> StaminaRestore to the client (instant stamina reset)
	      BSODA -> server-stepped projectile that knocks back + stuns NPCs
	  - Vending: ProximityPrompt opens the client popup; BuyItem validates
	    nickel count and a free slot before granting.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local ItemEconomy = {}

function ItemEconomy.init(ctx)
	local self = {}
	local config = ctx.config
	local states = {} -- [player] = { nickels = n, slots = {id?, id?} }

	-- ===================== player state =====================

	local function getState(player)
		local state = states[player]
		if not state then
			state = { nickels = 0, slots = {} }
			states[player] = state
		end
		return state
	end

	local function syncInventory(player)
		local state = getState(player)
		ctx.remotes.InventoryChanged:FireClient(player, state.slots[1], state.slots[2])
	end

	local function syncNickels(player)
		ctx.remotes.NickelChanged:FireClient(player, getState(player).nickels)
	end

	function self.addNickels(player, amount)
		local state = getState(player)
		state.nickels = state.nickels + amount
		syncNickels(player)
	end

	local function freeSlot(state)
		if state.slots[1] == nil then
			return 1
		end
		if state.slots[2] == nil then
			return 2
		end
		return nil
	end

	local function giveItem(player, itemId)
		local state = getState(player)
		local slot = freeSlot(state)
		if not slot then
			return false
		end
		state.slots[slot] = itemId
		syncInventory(player)
		return true
	end

	function self.syncAll(player)
		syncInventory(player)
		syncNickels(player)
	end

	function self.forget(player)
		states[player] = nil
	end

	-- ===================== world pickups =====================

	local function makePickupPart(name, color, size)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		return part
	end

	function self.spawnNickel(position)
		local coin = makePickupPart("Nickel", Color3.fromRGB(255, 210, 70), Vector3.new(0.25, 1.4, 1.4))
		coin.Shape = Enum.PartType.Cylinder
		coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		coin:SetAttribute("IsNickel", true)
		local sparkle = Instance.new("PointLight")
		sparkle.Color = Color3.fromRGB(255, 220, 90)
		sparkle.Range = 5
		sparkle.Parent = coin
		coin.Parent = ctx.map.pickupsFolder
	end

	function self.spawnItemPickup(itemId, position)
		local def = config.ITEMS[itemId]
		if not def then
			return
		end
		local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		local pickup
		if itemId == "BSODA" then
			pickup = makePickupPart("Pickup_BSODA", color, Vector3.new(2, 1.1, 1.1))
			pickup.Shape = Enum.PartType.Cylinder
			pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		else
			pickup = makePickupPart("Pickup_" .. itemId, color, Vector3.new(1.6, 0.5, 2.2))
			pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0))
		end
		pickup:SetAttribute("ItemId", itemId)
		pickup.Parent = ctx.map.pickupsFolder
	end

	function self.clearPickups()
		ctx.map.pickupsFolder:ClearAllChildren()
	end

	function self.onRoundStart()
		self.clearPickups()
		local spawned = 0
		for _, position in ipairs(ctx.map.nickelSpawns) do
			if spawned >= config.NICKELS_AT_ROUND_START then
				break
			end
			self.spawnNickel(position)
			spawned = spawned + 1
		end
		if config.WORLD_ITEMS_AT_ROUND_START then
			for itemId, position in pairs(ctx.map.itemSpawns) do
				self.spawnItemPickup(itemId, position)
			end
		end
	end

	-- proximity pickup scan (more reliable than Touched, and lets us flash
	-- "Inventory full" instead of silently swallowing the walk-over)
	local fullFlashCooldown = {} -- [player] = next allowed flash time
	task.spawn(function()
		while true do
			task.wait(0.1)
			if ctx.manager and ctx.manager.isRoundActive() then
				local pickups = ctx.map.pickupsFolder:GetChildren()
				if #pickups > 0 then
					for _, player in ipairs(Players:GetPlayers()) do
						if ctx.manager.isParticipant(player) then
							local character = player.Character
							local hrp = character and character:FindFirstChild("HumanoidRootPart")
							if hrp then
								for _, pickup in ipairs(pickups) do
									if pickup.Parent and (pickup.Position - hrp.Position).Magnitude < config.PICKUP_RADIUS then
										if pickup:GetAttribute("IsNickel") then
											pickup:Destroy()
											self.addNickels(player, 1)
										else
											local itemId = pickup:GetAttribute("ItemId")
											if itemId then
												if giveItem(player, itemId) then
													pickup:Destroy()
												elseif (fullFlashCooldown[player] or 0) <= os.clock() then
													fullFlashCooldown[player] = os.clock() + 1.5
													ctx.remotes.PickupFailed:FireClient(player, "Inventory full")
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	-- ===================== BSODA projectile =====================

	local function fireBsoda(player, direction)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local cfg = config.BSODA_PROJECTILE

		local can = Instance.new("Part")
		can.Name = "BsodaBlast"
		can.Shape = Enum.PartType.Ball
		can.Size = Vector3.new(1.4, 1.4, 1.4)
		can.Color = Color3.fromRGB(70, 140, 255)
		can.Material = Enum.Material.Neon
		can.Anchored = true
		can.CanCollide = false
		can.CanQuery = false
		can.CanTouch = false

		local fizz = Instance.new("ParticleEmitter")
		fizz.Rate = 40
		fizz.Lifetime = NumberRange.new(0.2, 0.4)
		fizz.Speed = NumberRange.new(2, 4)
		fizz.Color = ColorSequence.new(Color3.fromRGB(160, 210, 255))
		fizz.Parent = can

		local position = hrp.Position + direction * 2.5 + Vector3.new(0, 0.5, 0)
		can.CFrame = CFrame.new(position)
		can.Parent = ctx.map.projectilesFolder

		-- exclude the shooter so the can doesn't pop on their own body
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = { ctx.map.npcFolder, ctx.map.notebooksFolder, ctx.map.pickupsFolder, ctx.map.projectilesFolder }
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer.Character then
				table.insert(excluded, otherPlayer.Character)
			end
		end
		params.FilterDescendantsInstances = excluded

		task.spawn(function()
			local traveled = 0
			while traveled < cfg.RANGE and can.Parent do
				local dt = task.wait()
				local step = direction * cfg.SPEED * dt
				local wallHit = workspace:Raycast(position, step, params)
				if wallHit then
					break
				end
				position = position + step
				traveled = traveled + step.Magnitude
				can.CFrame = CFrame.new(position)

				local hitNpc = nil
				for _, npc in pairs(ctx.npcs) do
					if npc.base and npc.base.model.Parent then
						if (npc.base.root.Position - position).Magnitude < cfg.HIT_RADIUS then
							hitNpc = npc
							break
						end
					end
				end
				if hitNpc then
					hitNpc.base:stun(cfg.STUN_SECONDS, direction)
					local splat = Instance.new("Sound")
					splat.SoundId = "rbxasset://sounds/splat.mp3"
					splat.Volume = 1
					splat.Parent = hitNpc.base.root
					pcall(function()
						splat:Play()
					end)
					Debris:AddItem(splat, 2)
					break
				end
			end
			can:Destroy()
		end)
	end

	-- ===================== remote handlers =====================

	ctx.remotes.UseItem.OnServerEvent:Connect(function(player, direction)
		if not ctx.manager or not ctx.manager.isRoundActive() or not ctx.manager.isParticipant(player) then
			return
		end
		local state = getState(player)
		local itemId = state.slots[1]
		if not itemId then
			return
		end

		if itemId == "ZESTY" then
			-- consume, then let the client reset its stamina state
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
			syncInventory(player)
			ctx.remotes.StaminaRestore:FireClient(player)
		elseif itemId == "BSODA" then
			-- validate the client-supplied aim direction
			if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 or direction ~= direction then
				return
			end
			local flatish = Vector3.new(direction.X, math.clamp(direction.Y, -0.4, 0.4), direction.Z)
			if flatish.Magnitude < 0.01 then
				return
			end
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
			syncInventory(player)
			fireBsoda(player, flatish.Unit)
		end
	end)

	ctx.remotes.SwapSlots.OnServerEvent:Connect(function(player)
		local state = getState(player)
		state.slots[1], state.slots[2] = state.slots[2], state.slots[1]
		syncInventory(player)
	end)

	-- ===================== vending machines =====================

	for machineId, machine in ipairs(ctx.map.vendingMachines) do
		machine.prompt.Triggered:Connect(function(player)
			local def = config.ITEMS[machine.itemId]
			if not def then
				return
			end
			ctx.remotes.OpenVending:FireClient(player, {
				machineId = machineId,
				itemId = machine.itemId,
				cost = def.cost,
				nickels = getState(player).nickels,
				position = machine.part.Position,
			})
		end)
	end

	ctx.remotes.BuyItem.OnServerEvent:Connect(function(player, machineId)
		local machine = ctx.map.vendingMachines[machineId]
		if not machine or not machine.part.Parent then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - machine.part.Position).Magnitude > 12 then
			return
		end
		local def = config.ITEMS[machine.itemId]
		local state = getState(player)
		if state.nickels < def.cost then
			ctx.remotes.BuyResult:FireClient(player, false, "Not enough Nickels!")
			return
		end
		if not freeSlot(state) then
			ctx.remotes.BuyResult:FireClient(player, false, "Inventory full!")
			return
		end
		state.nickels = state.nickels - def.cost
		giveItem(player, machine.itemId)
		syncNickels(player)
		ctx.remotes.BuyResult:FireClient(player, true, def.displayName .. " dispensed!")
	end)

	ctx.economy = self
	return self
end

return ItemEconomy
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "LpAI",
		class = "ModuleScript",
		source = [=====[
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

	local model = NpcFactory.createRig({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(120, 150, 255),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.LP)
	self.base = base
	self.model = model

	local whistle = Instance.new("Sound")
	whistle.Name = "Whistle"
	whistle.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	whistle.Volume = 0.9
	whistle.PlaybackSpeed = 0.6
	whistle.RollOffMaxDistance = 80
	whistle.Parent = model:WaitForChild("Torso")

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
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "MapBuilder",
		class = "ModuleScript",
		source = [=====[
--[[
	MapBuilder (ModuleScript, ServerScriptService.BaldiGame.MapBuilder)

	Procedurally generates the entire schoolhouse at server startup so the game
	is playable in any empty baseplate place with zero manual Studio work:

	  - hallway ring + 4 classrooms + library + gym + detention room
	  - entrance corridor with the (locked) EXIT door
	  - 23 invisible NotebookSpawn nodes, tagged via CollectionService
	  - AI waypoints, NPC spawn markers, vending machines, lobby

	If a folder named "BaldiMap" already exists in Workspace (e.g. you built a
	custom school by hand), generation is skipped and your map is used instead.
	Any extra parts you tag "NotebookSpawn" in Studio are picked up too.

	Layout (top-down, studs). Floor top sits at Y = 0.
	  School rectangle: X -96..96, Z -72..72
	  North hall  Z -48..-36 / South hall Z 36..48 (between X -54..54)
	  West hall   X -54..-42 / East hall  X 42..54 (between Z -48..48)
	  Classrooms A/B along the north band, C/D along the south band
	  Gym west wing, Library east wing, detention room in the central block
	  Entrance corridor X -6..6, Z -72..-48 with the EXIT door at Z -72
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local WALL_HEIGHT = 14
local WALL_THICKNESS = 1

local COLOR_FLOOR = Color3.fromRGB(214, 196, 144)
local COLOR_WALL = Color3.fromRGB(233, 224, 162)
local COLOR_CEILING = Color3.fromRGB(245, 245, 240)
local COLOR_GYM_FLOOR = Color3.fromRGB(205, 140, 78)
local COLOR_LIBRARY_FLOOR = Color3.fromRGB(160, 120, 80)
local COLOR_DESK = Color3.fromRGB(150, 110, 70)
local COLOR_SHELF = Color3.fromRGB(110, 75, 45)
local COLOR_CHALKBOARD = Color3.fromRGB(40, 80, 50)
local COLOR_DETENTION = Color3.fromRGB(120, 120, 125)

-- ===================== part helpers =====================

local function basePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function makeInvisibleNode(name, position, parent)
	local part = basePart({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	part.Parent = parent
	return part
end

local function surfaceText(part, face, text, textColor, bgColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = bgColor and 0 or 1
	if bgColor then
		label.BackgroundColor3 = bgColor
	end
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return label
end

-- ===================== wall builder =====================

-- Builds an axis-aligned wall from (x1,z1) to (x2,z2) with optional door gaps.
-- gaps = { {center = <coordinate along the wall axis>, width = n}, ... }
local function buildWall(parent, x1, z1, x2, z2, gaps)
	gaps = gaps or {}
	local horizontal = (z1 == z2)
	local from = horizontal and math.min(x1, x2) or math.min(z1, z2)
	local to = horizontal and math.max(x1, x2) or math.max(z1, z2)

	-- collect cut points, sorted
	local cuts = {}
	for _, gap in ipairs(gaps) do
		table.insert(cuts, { lo = gap.center - gap.width / 2, hi = gap.center + gap.width / 2 })
	end
	table.sort(cuts, function(a, b)
		return a.lo < b.lo
	end)

	local segments = {}
	local cursor = from
	for _, cut in ipairs(cuts) do
		if cut.lo > cursor then
			table.insert(segments, { cursor, cut.lo })
		end
		cursor = math.max(cursor, cut.hi)
	end
	if cursor < to then
		table.insert(segments, { cursor, to })
	end

	for _, seg in ipairs(segments) do
		local length = seg[2] - seg[1]
		if length > 0.05 then
			local mid = (seg[1] + seg[2]) / 2
			local size, cframe
			if horizontal then
				size = Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS)
				cframe = CFrame.new(mid, WALL_HEIGHT / 2, z1)
			else
				size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length)
				cframe = CFrame.new(x1, WALL_HEIGHT / 2, mid)
			end
			local wall = basePart({
				Name = "Wall",
				Size = size,
				CFrame = cframe,
				Color = COLOR_WALL,
				Material = Enum.Material.Concrete,
			})
			wall.Parent = parent
		end
	end
end

-- ===================== furniture =====================

local function buildDesk(parent, x, z)
	local desk = basePart({
		Name = "Desk",
		Size = Vector3.new(4, 2.6, 2.4),
		CFrame = CFrame.new(x, 1.3, z),
		Color = COLOR_DESK,
		Material = Enum.Material.WoodPlanks,
	})
	desk.Parent = parent
end

local function buildShelf(parent, x, z, lengthX)
	local shelf = basePart({
		Name = "Bookshelf",
		Size = Vector3.new(lengthX, 7, 2),
		CFrame = CFrame.new(x, 3.5, z),
		Color = COLOR_SHELF,
		Material = Enum.Material.Wood,
	})
	shelf.Parent = parent
end

local function buildChalkboard(parent, x, z, text)
	local board = basePart({
		Name = "Chalkboard",
		Size = Vector3.new(10, 4, 0.3),
		CFrame = CFrame.new(x, 6, z),
		Color = COLOR_CHALKBOARD,
	})
	board.Parent = parent
	surfaceText(board, Enum.NormalId.Front, text, Color3.fromRGB(240, 240, 240))
	surfaceText(board, Enum.NormalId.Back, text, Color3.fromRGB(240, 240, 240))
end

local function buildLight(parent, x, z)
	local fixture = basePart({
		Name = "LightFixture",
		Size = Vector3.new(3, 0.3, 3),
		CFrame = CFrame.new(x, WALL_HEIGHT - 0.3, z),
		Color = Color3.fromRGB(255, 255, 230),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 250, 235)
	light.Parent = fixture
	fixture.Parent = parent
end

local function buildVendingMachine(parent, x, z, itemDef)
	local machine = basePart({
		Name = "VendingMachine_" .. itemDef.id,
		Size = Vector3.new(4, 7, 3),
		CFrame = CFrame.new(x, 3.5, z),
		Color = Color3.fromRGB(itemDef.color[1], itemDef.color[2], itemDef.color[3]),
		Material = Enum.Material.Metal,
	})
	surfaceText(machine, Enum.NormalId.Front, itemDef.displayName, Color3.new(1, 1, 1), Color3.fromRGB(30, 30, 35))
	surfaceText(machine, Enum.NormalId.Back, itemDef.displayName, Color3.new(1, 1, 1), Color3.fromRGB(30, 30, 35))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse"
	prompt.ObjectText = itemDef.displayName .. " Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 5
	prompt.RequiresLineOfSight = false
	prompt.Parent = machine

	machine.Parent = parent
	return machine, prompt
end

-- ===================== main build =====================

function MapBuilder.build(ctx)
	local config = ctx.config

	-- Collision groups: players never physically collide with NPCs, so a
	-- roaming character can never wedge a player into a doorway.
	pcall(function()
		PhysicsService:RegisterCollisionGroup("BaldiNpc")
		PhysicsService:RegisterCollisionGroup("BaldiPlayer")
		PhysicsService:CollisionGroupSetCollidable("BaldiNpc", "BaldiPlayer", false)
	end)

	local existing = workspace:FindFirstChild("BaldiMap")
	if existing then
		-- A hand-built map is present; just make sure runtime folders exist.
		local map = MapBuilder.collectExistingMap(existing)
		ctx.map = map
		return map
	end

	local root = Instance.new("Folder")
	root.Name = "BaldiMap"

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = root
	local waypoints = Instance.new("Folder")
	waypoints.Name = "Waypoints"
	waypoints.Parent = root
	local spawnNodes = Instance.new("Folder")
	spawnNodes.Name = "NotebookSpawns"
	spawnNodes.Parent = root
	local notebooks = Instance.new("Folder")
	notebooks.Name = "Notebooks"
	notebooks.Parent = root
	local pickups = Instance.new("Folder")
	pickups.Name = "Pickups"
	pickups.Parent = root
	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "Npcs"
	npcFolder.Parent = root
	local projectiles = Instance.new("Folder")
	projectiles.Name = "Projectiles"
	projectiles.Parent = root

	-- ---------- floor & ceiling ----------
	local floor = basePart({
		Name = "Floor",
		Size = Vector3.new(196, 1, 148),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = COLOR_FLOOR,
		Material = Enum.Material.Concrete,
	})
	floor.Parent = geometry

	local ceiling = basePart({
		Name = "Ceiling",
		Size = Vector3.new(196, 1, 148),
		CFrame = CFrame.new(0, WALL_HEIGHT + 0.5, 0),
		Color = COLOR_CEILING,
		Material = Enum.Material.Concrete,
	})
	ceiling.Parent = geometry

	-- room floor accents
	local gymFloor = basePart({
		Name = "GymFloor",
		Size = Vector3.new(40, 0.1, 46),
		CFrame = CFrame.new(-75, 0.05, 0),
		Color = COLOR_GYM_FLOOR,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	})
	gymFloor.Parent = geometry
	local libFloor = basePart({
		Name = "LibraryFloor",
		Size = Vector3.new(40, 0.1, 46),
		CFrame = CFrame.new(75, 0.05, 0),
		Color = COLOR_LIBRARY_FLOOR,
		Material = Enum.Material.Carpet,
		CanCollide = false,
	})
	libFloor.Parent = geometry
	local detFloor = basePart({
		Name = "DetentionFloor",
		Size = Vector3.new(22, 0.1, 22),
		CFrame = CFrame.new(0, 0.05, -24),
		Color = COLOR_DETENTION,
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	detFloor.Parent = geometry

	-- ---------- walls ----------
	-- School perimeter (exit door gap at the top of the entrance corridor)
	buildWall(geometry, -96, -72, 96, -72, { { center = 0, width = 10 } })
	buildWall(geometry, -96, 72, 96, 72)
	buildWall(geometry, -96, -72, -96, 72)
	buildWall(geometry, 96, -72, 96, 72)

	-- North band: classrooms A (X -54..-6) | entrance corridor (X -6..6) | B (X 6..54)
	buildWall(geometry, -96, -48, 96, -48, {
		{ center = -30, width = 8 }, -- classroom A door
		{ center = 0, width = 12 }, -- entrance corridor opening
		{ center = 30, width = 8 }, -- classroom B door
	})
	buildWall(geometry, -54, -72, -54, -48) -- A west wall (vs NW void)
	buildWall(geometry, -6, -72, -6, -48) -- A | corridor
	buildWall(geometry, 6, -72, 6, -48) -- corridor | B
	buildWall(geometry, 54, -72, 54, -48) -- B east wall (vs NE void)

	-- South band: classrooms C (X -54..0) and D (X 0..54)
	buildWall(geometry, -96, 48, 96, 48, {
		{ center = -27, width = 8 }, -- classroom C door
		{ center = 27, width = 8 }, -- classroom D door
	})
	buildWall(geometry, -54, 48, -54, 72)
	buildWall(geometry, 0, 48, 0, 72)
	buildWall(geometry, 54, 48, 54, 72)

	-- West wing: gym (door into west hall at Z 0)
	buildWall(geometry, -54, -48, -54, 48, { { center = 0, width = 10 } })
	buildWall(geometry, -96, -24, -54, -24)
	buildWall(geometry, -96, 24, -54, 24)

	-- East wing: library (door into east hall at Z 0)
	buildWall(geometry, 54, -48, 54, 48, { { center = 0, width = 10 } })
	buildWall(geometry, 54, -24, 96, -24)
	buildWall(geometry, 54, 24, 96, 24)

	-- Central block (detention room sits in its north middle)
	buildWall(geometry, -42, -36, 42, -36, { { center = 0, width = 8 } }) -- detention door
	buildWall(geometry, -42, 36, 42, 36)
	buildWall(geometry, -42, -36, -42, 36)
	buildWall(geometry, 42, -36, 42, 36)
	-- detention room inner walls (rest of the central block is sealed void)
	buildWall(geometry, -12, -36, -12, -12)
	buildWall(geometry, 12, -36, 12, -12)
	buildWall(geometry, -12, -12, 12, -12)

	-- ---------- exit door ----------
	local exitDoor = basePart({
		Name = "ExitDoor",
		Size = Vector3.new(9.8, WALL_HEIGHT, 1.4),
		CFrame = CFrame.new(0, WALL_HEIGHT / 2, -72),
		Color = Color3.fromRGB(140, 30, 30),
		Material = Enum.Material.Metal,
	})
	exitDoor.Parent = geometry
	surfaceText(exitDoor, Enum.NormalId.Back, "EXIT", Color3.new(1, 1, 1), Color3.fromRGB(60, 10, 10))

	-- ---------- furniture ----------
	-- classroom desks (2x2 grid per room) + chalkboards
	local deskSpots = {
		-- classroom A (center -30,-60)
		{ -38, -64 }, { -38, -55 }, { -22, -64 }, { -22, -55 },
		-- classroom B (center 30,-60)
		{ 22, -64 }, { 22, -55 }, { 38, -64 }, { 38, -55 },
		-- classroom C (center -27,60)
		{ -36, 56 }, { -36, 65 }, { -18, 56 }, { -18, 65 },
		-- classroom D (center 27,60)
		{ 18, 56 }, { 18, 65 }, { 36, 56 }, { 36, 65 },
	}
	for _, spot in ipairs(deskSpots) do
		buildDesk(geometry, spot[1], spot[2])
	end
	buildChalkboard(geometry, -30, -70.5, "2 + 2 = ?")
	buildChalkboard(geometry, 30, -70.5, "7 - 3 = ?")
	buildChalkboard(geometry, -27, 70.5, "5 + 5 = ?")
	buildChalkboard(geometry, 27, 70.5, "9 + 1 = ?")

	-- library shelves (three rows, aisles between)
	buildShelf(geometry, 74, -12, 28)
	buildShelf(geometry, 74, 0, 28)
	buildShelf(geometry, 74, 12, 28)

	-- detention bench (against the back wall, clear of the door path)
	local bench = basePart({
		Name = "DetentionBench",
		Size = Vector3.new(10, 1.6, 2),
		CFrame = CFrame.new(0, 0.8, -14.5),
		Color = Color3.fromRGB(80, 80, 85),
	})
	bench.Parent = geometry

	-- ---------- lights ----------
	local lightSpots = {
		{ -48, -42 }, { 0, -42 }, { 48, -42 }, -- north hall
		{ -48, 42 }, { 0, 42 }, { 48, 42 }, -- south hall
		{ -48, 0 }, { 48, 0 }, -- west/east halls
		{ -30, -60 }, { 30, -60 }, { -27, 60 }, { 27, 60 }, -- classrooms
		{ -75, 0 }, { -75, 16 }, { -75, -16 }, -- gym
		{ 75, 0 }, { 65, 16 }, { 85, -16 }, -- library
		{ 0, -24 }, -- detention
		{ 0, -60 }, -- entrance corridor
	}
	for _, spot in ipairs(lightSpots) do
		buildLight(geometry, spot[1], spot[2])
	end

	Lighting.Ambient = Color3.fromRGB(110, 110, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
	Lighting.Brightness = 2

	-- ---------- vending machines (south hall, against the central block) ----------
	local vendingMachines = {}
	local bsodaMachine, bsodaPrompt = buildVendingMachine(geometry, -16, 38.2, config.ITEMS.BSODA)
	local zestyMachine, zestyPrompt = buildVendingMachine(geometry, 16, 38.2, config.ITEMS.ZESTY)
	table.insert(vendingMachines, { part = bsodaMachine, prompt = bsodaPrompt, itemId = "BSODA" })
	table.insert(vendingMachines, { part = zestyMachine, prompt = zestyPrompt, itemId = "ZESTY" })

	-- ---------- AI waypoints ----------
	local waypointSpots = {
		{ -48, -42 }, { 0, -42 }, { 48, -42 }, -- north hall
		{ -48, 0 }, { 48, 0 }, -- west/east halls
		{ -48, 42 }, { 0, 42 }, { 48, 42 }, -- south hall
		{ -30, -60 }, { 30, -60 }, -- classrooms A, B
		{ -27, 60 }, { 27, 60 }, -- classrooms C, D
		{ -75, 0 }, { 75, -6 }, -- gym, library aisle (clear of the shelves)
		{ 0, -60 }, -- entrance corridor
	}
	for index, spot in ipairs(waypointSpots) do
		makeInvisibleNode("Waypoint" .. index, Vector3.new(spot[1], 1, spot[2]), waypoints)
	end

	-- ---------- notebook spawn nodes (23 total, 10 picked per round) ----------
	local nodeSpots = {
		-- classroom A (3)
		{ -44, -56 }, { -30, -66 }, { -14, -54 },
		-- classroom B (3)
		{ 14, -56 }, { 30, -66 }, { 44, -54 },
		-- classroom C (3)
		{ -44, 56 }, { -27, 66 }, { -12, 54 },
		-- classroom D (3)
		{ 12, 56 }, { 27, 66 }, { 44, 54 },
		-- library (4) — forces trips through the tight aisles
		{ 60, -18 }, { 74, -8 }, { 90, 2 }, { 66, 16 },
		-- gym (3) — open danger
		{ -90, -18 }, { -62, 18 }, { -86, 14 },
		-- hall corners (4)
		{ -50, -44 }, { 50, -44 }, { -50, 44 }, { 50, 44 },
	}
	for index, spot in ipairs(nodeSpots) do
		local node = makeInvisibleNode("NotebookSpawn" .. index, Vector3.new(spot[1], 1.5, spot[2]), spawnNodes)
		CollectionService:AddTag(node, "NotebookSpawn")
	end

	-- ---------- lobby (menu area, away from the school) ----------
	local lobbyFloor = basePart({
		Name = "LobbyFloor",
		Size = Vector3.new(44, 1, 44),
		CFrame = CFrame.new(0, -0.5, 140),
		Color = Color3.fromRGB(70, 110, 90),
		Material = Enum.Material.Grass,
	})
	lobbyFloor.Parent = geometry
	-- lobby walls so nobody wanders off while in the menu
	buildWall(geometry, -22, 118, 22, 118)
	buildWall(geometry, -22, 162, 22, 162)
	buildWall(geometry, -22, 118, -22, 162)
	buildWall(geometry, 22, 118, 22, 162)

	local lobbySign = basePart({
		Name = "LobbySign",
		Size = Vector3.new(18, 5, 0.5),
		CFrame = CFrame.new(0, 6, 124),
		Color = Color3.fromRGB(30, 50, 40),
	})
	lobbySign.Parent = geometry
	surfaceText(lobbySign, Enum.NormalId.Back, config.GAME_TITLE, Color3.fromRGB(255, 220, 80))

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 0.5, 140)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(90, 130, 105)
	spawnLocation.Parent = geometry

	root.Parent = workspace

	ctx.map = {
		root = root,
		geometry = geometry,
		waypointsFolder = waypoints,
		spawnNodesFolder = spawnNodes,
		notebooksFolder = notebooks,
		pickupsFolder = pickups,
		npcFolder = npcFolder,
		projectilesFolder = projectiles,
		exitDoor = exitDoor,
		lobbySpawn = spawnLocation,
		-- players start a round at the entrance corridor, facing the school
		roundSpawnCFrame = CFrame.lookAt(Vector3.new(0, 3.5, -58), Vector3.new(0, 3.5, -30)),
		detentionCFrame = CFrame.lookAt(Vector3.new(0, 3.5, -24), Vector3.new(0, 3.5, -36)),
		vendingMachines = vendingMachines,
		npcSpawns = {
			CHATREVIVE = CFrame.new(90, 3, 0), -- library east end, behind the shelves
			LP = CFrame.new(-75, 3, 0), -- gym center
			FROSTY = CFrame.new(0, 3, 42), -- south hall
		},
		nickelSpawns = {
			Vector3.new(-30, 1.5, -42), Vector3.new(30, 1.5, 42),
			Vector3.new(48, 1.5, 0), Vector3.new(-48, 1.5, 20),
		},
		itemSpawns = {
			BSODA = Vector3.new(-22, 1.5, -60), -- classroom A
			ZESTY = Vector3.new(18, 1.5, 60), -- classroom D
		},
	}
	return ctx.map
end

-- Used when a hand-built BaldiMap folder already exists in Workspace.
-- Expects the same child folder names; creates missing runtime folders.
function MapBuilder.collectExistingMap(root)
	local function ensureFolder(name)
		local folder = root:FindFirstChild(name)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = root
		end
		return folder
	end

	local geometry = ensureFolder("Geometry")
	local map = {
		root = root,
		geometry = geometry,
		waypointsFolder = ensureFolder("Waypoints"),
		spawnNodesFolder = ensureFolder("NotebookSpawns"),
		notebooksFolder = ensureFolder("Notebooks"),
		pickupsFolder = ensureFolder("Pickups"),
		npcFolder = ensureFolder("Npcs"),
		projectilesFolder = ensureFolder("Projectiles"),
		exitDoor = geometry:FindFirstChild("ExitDoor", true),
		lobbySpawn = geometry:FindFirstChild("LobbySpawn", true),
		roundSpawnCFrame = CFrame.lookAt(Vector3.new(0, 3.5, -58), Vector3.new(0, 3.5, -30)),
		detentionCFrame = CFrame.lookAt(Vector3.new(0, 3.5, -24), Vector3.new(0, 3.5, -36)),
		vendingMachines = {},
		npcSpawns = {
			CHATREVIVE = CFrame.new(90, 3, 0),
			LP = CFrame.new(-75, 3, 0),
			FROSTY = CFrame.new(0, 3, 42),
		},
		nickelSpawns = { Vector3.new(-30, 1.5, -42), Vector3.new(30, 1.5, 42) },
		itemSpawns = {},
	}
	for _, child in ipairs(geometry:GetDescendants()) do
		if child:IsA("BasePart") and child.Name:match("^VendingMachine_") then
			local itemId = child.Name:gsub("^VendingMachine_", "")
			local prompt = child:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				table.insert(map.vendingMachines, { part = child, prompt = prompt, itemId = itemId })
			end
		end
	end
	return map
end

return MapBuilder
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "NotebookSpawner",
		class = "ModuleScript",
		source = [=====[
--[[
	NotebookSpawner (ModuleScript, ServerScriptService.BaldiGame.NotebookSpawner)

	Random notebook generation, exactly per the plan:
	  1. MapBuilder placed ~23 invisible nodes tagged "NotebookSpawn"
	     (any parts you tag yourself in Studio are included too).
	  2. CollectionService:GetTagged("NotebookSpawn") collects them.
	  3. Fisher-Yates shuffle, take the first NOTEBOOK_SPAWN_COUNT (10).
	  4. Clone the Notebook model (built in code into ReplicatedStorage)
	     at each chosen node.
	  5. ProximityPrompt collect -> destroy model, bump the server counter,
	     fire NotebookCollected to all clients.

	Also runs a tiny spin/bob animation so notebooks read as pickups.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotebookSpawner = {}

local function buildNotebookTemplate()
	local folder = ReplicatedStorage:FindFirstChild("BaldiModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BaldiModels"
		folder.Parent = ReplicatedStorage
	end
	local existing = folder:FindFirstChild("Notebook")
	if existing then
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "Notebook"

	local cover = Instance.new("Part")
	cover.Name = "Cover"
	cover.Size = Vector3.new(1.7, 0.35, 2.2)
	cover.Color = Color3.fromRGB(200, 40, 40)
	cover.Material = Enum.Material.SmoothPlastic
	cover.Anchored = true
	cover.CanCollide = false
	cover.CanQuery = false
	cover.TopSurface = Enum.SurfaceType.Smooth
	cover.BottomSurface = Enum.SurfaceType.Smooth
	cover.Parent = model

	local pages = Instance.new("Part")
	pages.Name = "Pages"
	pages.Size = Vector3.new(1.5, 0.12, 2)
	pages.Color = Color3.fromRGB(245, 245, 235)
	pages.Material = Enum.Material.SmoothPlastic
	pages.Anchored = true
	pages.CanCollide = false
	pages.CanQuery = false
	pages.CFrame = cover.CFrame * CFrame.new(0, 0.23, 0)
	pages.Parent = model

	model.PrimaryPart = cover
	model.Parent = folder
	return model
end

function NotebookSpawner.init(ctx)
	local self = {}
	local template = buildNotebookTemplate()
	local active = {} -- [model] = { base = CFrame, phase = number }
	local rng = Random.new()

	-- spin & bob
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		for model, info in pairs(active) do
			if model.Parent then
				local yaw = CFrame.Angles(0, elapsed * 1.6 + info.phase, 0)
				local bob = Vector3.new(0, math.sin(elapsed * 2 + info.phase) * 0.2, 0)
				model:PivotTo(info.base * yaw + bob)
			end
		end
	end)

	function self.clear()
		for model in pairs(active) do
			active[model] = nil
			if model.Parent then
				model:Destroy()
			end
		end
		ctx.map.notebooksFolder:ClearAllChildren()
	end

	function self.remainingCount()
		local count = 0
		for model in pairs(active) do
			if model.Parent then
				count = count + 1
			end
		end
		return count
	end

	-- Returns how many notebooks were actually placed this round.
	function self.spawnForRound()
		self.clear()

		-- 2. collect every tagged node (built ones + any you added in Studio)
		local nodes = {}
		for _, node in ipairs(CollectionService:GetTagged("NotebookSpawn")) do
			if node:IsDescendantOf(workspace) then
				table.insert(nodes, node)
			end
		end

		-- 3. Fisher-Yates shuffle, no duplicates possible
		for index = #nodes, 2, -1 do
			local swap = rng:NextInteger(1, index)
			nodes[index], nodes[swap] = nodes[swap], nodes[index]
		end

		local count = math.min(ctx.config.NOTEBOOK_SPAWN_COUNT, #nodes)
		for index = 1, count do
			local node = nodes[index]

			-- 4. clone and position at the node
			local notebook = template:Clone()
			local baseCFrame = CFrame.new(node.Position + Vector3.new(0, 0.8, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			notebook:PivotTo(baseCFrame)

			-- 5. collect interaction
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Collect"
			prompt.ObjectText = "Notebook"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = ctx.config.NOTEBOOK_PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = notebook.PrimaryPart

			prompt.Triggered:Connect(function(player)
				if not active[notebook] then
					return -- already collected
				end
				if not ctx.manager.isRoundActive() or not ctx.manager.isParticipant(player) then
					return
				end
				active[notebook] = nil
				notebook:Destroy()
				ctx.manager.onNotebookCollected(player)
			end)

			notebook.Parent = ctx.map.notebooksFolder
			active[notebook] = { base = baseCFrame, phase = rng:NextNumber(0, math.pi * 2) }
		end

		return count
	end

	ctx.notebookSpawner = self
	return self
end

return NotebookSpawner
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "NpcBase",
		class = "ModuleScript",
		source = [=====[
--[[
	NpcBase (ModuleScript, ServerScriptService.BaldiGame.NpcBase)

	Shared behaviour for all three characters: pathfinding locomotion,
	roaming between waypoints, line-of-sight raycasts, stun/knockback
	(BSODA) and slow (Frosty) effects, and reset between rounds.

	Per the plan, the three AIs only differ in WHAT triggers a new path and
	WHAT the target is — that difference lives in ChatReviveAI / LpAI /
	FrostyAI; everything mechanical lives here.
]]

local PathfindingService = game:GetService("PathfindingService")

local NpcBase = {}
NpcBase.__index = NpcBase

function NpcBase.new(ctx, model, spawnCFrame)
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

-- BSODA hit: knock back and freeze in place for a few seconds
function NpcBase:stun(duration, pushDirection)
	local cfg = self.ctx.config.BSODA_PROJECTILE
	local alreadyStunned = self:isStunned()
	self.stunnedUntil = os.clock() + duration
	self.humanoid.WalkSpeed = 0
	self.humanoid:MoveTo(self.root.Position)

	-- white flash while stunned; a second hit while flashed must not capture
	-- the flash color as the "original", so only the first hit manages colors
	if not alreadyStunned then
		local originalColors = {}
		for _, part in ipairs(self.model:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				originalColors[part] = part.Color
				part.Color = Color3.fromRGB(230, 230, 240)
			end
		end
		task.spawn(function()
			while self:isStunned() do
				task.wait(0.1)
			end
			for part, color in pairs(originalColors) do
				if part.Parent then
					part.Color = color
				end
			end
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
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "NpcFactory",
		class = "ModuleScript",
		source = [=====[
--[[
	NpcFactory (ModuleScript, ServerScriptService.BaldiGame.NpcFactory)
	Builds simple R6 humanoid rigs entirely in code (no asset uploads needed),
	with a floating name tag so testers can tell the characters apart.
]]

local NpcFactory = {}

local function makeBodyPart(name, size, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = transparency or 0
	return part
end

local function joinParts(part0, part1, offset, jointName)
	-- Position part1 relative to part0, then join with a Motor6D named per
	-- the standard R6 convention so humanoid physics behaves normally.
	part1.CFrame = part0.CFrame * offset
	local motor = Instance.new("Motor6D")
	motor.Name = jointName or "Weld"
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = offset
	motor.Parent = part0
	return motor
end

-- spec = { name, bodyColor, headColor, transparency?, glowColor? }
function NpcFactory.createRig(spec, parent)
	local model = Instance.new("Model")
	model.Name = spec.name

	local hrp = makeBodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), spec.bodyColor, 1)
	hrp.CanCollide = false
	hrp.CFrame = CFrame.new(0, 3, 0)
	hrp.Parent = model

	local torso = makeBodyPart("Torso", Vector3.new(2, 2, 1), spec.bodyColor, spec.transparency)
	torso.Parent = model
	joinParts(hrp, torso, CFrame.new(0, 0, 0), "RootJoint")

	local head = makeBodyPart("Head", Vector3.new(1.4, 1.4, 1.4), spec.headColor, spec.transparency)
	head.Shape = Enum.PartType.Ball
	head.Parent = model
	joinParts(torso, head, CFrame.new(0, 1.7, 0), "Neck")

	local leftLeg = makeBodyPart("Left Leg", Vector3.new(1, 2, 1), spec.bodyColor, spec.transparency)
	leftLeg.Parent = model
	joinParts(torso, leftLeg, CFrame.new(-0.5, -2, 0), "Left Hip")
	local rightLeg = makeBodyPart("Right Leg", Vector3.new(1, 2, 1), spec.bodyColor, spec.transparency)
	rightLeg.Parent = model
	joinParts(torso, rightLeg, CFrame.new(0.5, -2, 0), "Right Hip")

	local leftArm = makeBodyPart("Left Arm", Vector3.new(1, 2, 1), spec.bodyColor, spec.transparency)
	leftArm.CanCollide = false
	leftArm.Parent = model
	joinParts(torso, leftArm, CFrame.new(-1.5, 0, 0), "Left Shoulder")
	local rightArm = makeBodyPart("Right Arm", Vector3.new(1, 2, 1), spec.bodyColor, spec.transparency)
	rightArm.CanCollide = false
	rightArm.Parent = model
	joinParts(torso, rightArm, CFrame.new(1.5, 0, 0), "Right Shoulder")

	-- simple face so the head has a "front"
	local face = makeBodyPart("FaceMark", Vector3.new(0.5, 0.3, 0.2), Color3.new(0, 0, 0), spec.transparency)
	face.CanCollide = false
	face.CanQuery = false
	face.Parent = model
	joinParts(head, face, CFrame.new(0, 0.15, -0.65))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = 100000
	humanoid.Health = 100000
	humanoid.RequiresNeck = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	humanoid.DisplayName = spec.name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- name tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 130, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Parent = head
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBold
	tag.TextScaled = true
	tag.TextColor3 = spec.tagColor or Color3.new(1, 1, 1)
	tag.TextStrokeTransparency = 0.2
	tag.Text = spec.name
	tag.Parent = billboard

	if spec.glowColor then
		local glow = Instance.new("PointLight")
		glow.Color = spec.glowColor
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Parent = torso
	end

	model.PrimaryPart = hrp

	-- keep NPCs out of the player collision group
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "BaldiNpc"
		end
	end

	model.Parent = parent

	-- BSODA knockback should shove, not ragdoll
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	return model
end

return NpcFactory
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "RemoteSetup",
		class = "ModuleScript",
		source = [=====[
--[[
	RemoteSetup (ModuleScript, ServerScriptService.BaldiGame.RemoteSetup)
	Creates the RemoteEvents folder in ReplicatedStorage at server startup.
	Building remotes in code means the project works identically whether it
	was synced with Rojo or pasted in with the installer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteSetup = {}

function RemoteSetup.init(ctx)
	local config = ctx.config

	local folder = ReplicatedStorage:FindFirstChild(config.REMOTES_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = config.REMOTES_FOLDER
		folder.Parent = ReplicatedStorage
	end

	ctx.remotes = {}
	for _, name in ipairs(config.REMOTE_NAMES) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		ctx.remotes[name] = remote
	end

	return ctx.remotes
end

return RemoteSetup
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "DetentionOverlay",
		class = "ModuleScript",
		source = [=====[
--[[
	DetentionOverlay (ModuleScript, StarterPlayerScripts.BaldiClient.DetentionOverlay)

	Shown while LP has you in detention. The server anchors your character;
	this overlay shows the countdown and locks the sprint key so the bar
	doesn't drain while you stand there fuming.
]]

local DetentionOverlay = {}

function DetentionOverlay.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local stamina = ctx.controllers.StaminaController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiDetention",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 8, 8),
		BackgroundTransparency = 0.45,
		Parent = gui,
	})

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.9, 0, 0, 70),
		Text = "DETENTION!",
		TextColor3 = theme.red,
		TextStrokeTransparency = 0.3,
		Parent = gui,
	})

	local quoteLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 28),
		Text = '"No running in the halls."',
		Font = Enum.Font.GothamMedium,
		TextColor3 = theme.textDim,
		Parent = gui,
	})

	local countdownLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(220, 84),
		Text = "15",
		TextColor3 = theme.textPrimary,
		Parent = gui,
	})

	local active = false

	ctx.remotes.SendToDetention.OnClientEvent:Connect(function(seconds, byName)
		active = true
		quoteLabel.Text = '"No running in the halls." — ' .. (byName or "LP")
		gui.Enabled = true
		stamina.setSprintLocked(true)
		sounds.play("detention")

		local releaseAt = os.clock() + seconds
		task.spawn(function()
			while active and os.clock() < releaseAt do
				countdownLabel.Text = tostring(math.max(0, math.ceil(releaseAt - os.clock())))
				task.wait(0.1)
			end
		end)
	end)

	local function release()
		if not active then
			return
		end
		active = false
		gui.Enabled = false
		stamina.setSprintLocked(false)
	end

	ctx.remotes.DetentionReleased.OnClientEvent:Connect(release)
	ctx.remotes.RoundEnded.OnClientEvent:Connect(release)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(release)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(release)

	self.release = release
	return self
end

return DetentionOverlay
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "FrostyVignette",
		class = "ModuleScript",
		source = [=====[
--[[
	FrostyVignette (ModuleScript, StarterPlayerScripts.BaldiClient.FrostyVignette)

	Receives Frosty's SpeedDebuff remote:
	  - tells StaminaController to apply the WalkSpeed multiplier (0.4x, 4s)
	  - shows an icy screen-edge vignette (four gradient strips fading
	    toward the center — no image assets needed) until the chill expires
]]

local FrostyVignette = {}

function FrostyVignette.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local stamina = ctx.controllers.StaminaController
	local sounds = ctx.controllers.SoundController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiFrost",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	-- four edge strips, each with a gradient fading toward the screen center
	local function edgeStrip(anchorPoint, position, size, gradientRotation)
		local strip = UiKit.new("Frame", {
			AnchorPoint = anchorPoint,
			Position = position,
			Size = size,
			BackgroundColor3 = theme.ice,
			BorderSizePixel = 0,
			Parent = gui,
		})
		UiKit.new("UIGradient", {
			Rotation = gradientRotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = strip,
		})
		return strip
	end

	edgeStrip(Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.new(1, 0, 0.18, 0), 90) -- top
	edgeStrip(Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.new(1, 0, 0.18, 0), -90) -- bottom
	edgeStrip(Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.new(0.14, 0, 1, 0), 0) -- left
	edgeStrip(Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), UDim2.new(0.14, 0, 1, 0), 180) -- right

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(300, 24),
		Text = "Frosty chilled you! You feel slow...",
		TextColor3 = theme.ice,
		TextStrokeTransparency = 0.5,
		Parent = gui,
	})

	local expiresAt = 0

	ctx.remotes.SpeedDebuff.OnClientEvent:Connect(function(duration, multiplier)
		stamina.applyDebuff(multiplier, duration)
		expiresAt = os.clock() + duration
		gui.Enabled = true
		sounds.play("frost")

		task.delay(duration, function()
			if os.clock() >= expiresAt then
				gui.Enabled = false
			end
		end)
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(function()
		gui.Enabled = false
	end)

	return self
end

return FrostyVignette
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "HudController",
		class = "ModuleScript",
		source = [=====[
--[[
	HudController (ModuleScript, StarterPlayerScripts.BaldiClient.HudController)

	The persistent in-game overlay (HUD shell from the plan):
	  - notebook counter (top center) + objective line
	  - nickel count with coin icon (top right)
	  - stamina bar (bottom center) — visuals only; logic in StaminaController
	  - two item slots (bottom right) + "Inventory full" flash
	  - center banner for phase changes ("EXIT IS OPEN!")
	  - mobile Sprint / Use / Swap buttons when touch is enabled

	Subscribes to its own data remotes: NotebookCollected, NickelChanged,
	InventoryChanged is consumed by ItemUseClient which calls setSlots.
]]

local UiKit

local HudController = {}

function HudController.init(ctx)
	UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local self = { mobile = {} }
	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local sounds = ctx.controllers.SoundController

	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiHUD",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	-- ===================== notebook counter (top center) =====================

	local notebookFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(250, 46),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.25,
		Parent = gui,
		UiKit.corner(10),
	})
	local notebookScale = UiKit.new("UIScale", { Parent = notebookFrame })
	UiKit.new("Frame", { -- little red book icon
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(22, 28),
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		Parent = notebookFrame,
		UiKit.corner(4),
	})
	local notebookLabel = UiKit.label({
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = "Notebooks: 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notebookFrame,
	})

	local objectiveLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(420, 22),
		Text = "Collect 10 notebooks!",
		TextColor3 = theme.textDim,
		Font = Enum.Font.Gotham,
		Parent = gui,
	})

	-- ===================== nickel counter (top right) =====================

	local nickelFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(140, 46),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.25,
		Parent = gui,
		UiKit.corner(10),
	})
	UiKit.new("Frame", { -- coin icon
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(255, 210, 70),
		Parent = nickelFrame,
		UiKit.corner(14),
		UiKit.stroke(Color3.fromRGB(180, 140, 30), 2),
	})
	local nickelLabel = UiKit.label({
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = "x 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nickelFrame,
	})

	-- ===================== stamina bar (bottom center) =====================

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(120, 16),
		Text = "STAMINA",
		TextColor3 = theme.textDim,
		Parent = gui,
	})
	local staminaBack = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.2,
		Parent = gui,
		UiKit.corner(8),
		UiKit.stroke(Color3.fromRGB(0, 0, 0), 1, 0.5),
	})
	local staminaFillArea = UiKit.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = staminaBack,
	})
	local staminaFill = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.green,
		Parent = staminaFillArea,
		UiKit.corner(6),
	})
	local coldTag = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(160, 18),
		Text = "COLD! Slowed...",
		TextColor3 = theme.ice,
		Visible = false,
		Parent = gui,
	})

	-- ===================== item slots (bottom right) =====================

	local slotsFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(198, 118),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local function buildSlot(xOffset, hintText, isActive)
		local slot = UiKit.new("Frame", {
			Position = UDim2.fromOffset(xOffset, 0),
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = theme.panel,
			BackgroundTransparency = 0.2,
			Parent = slotsFrame,
			UiKit.corner(12),
			UiKit.stroke(isActive and theme.accent or Color3.fromRGB(90, 95, 90), isActive and 3 or 2),
		})
		local icon = UiKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = theme.panelLight,
			Visible = false,
			Parent = slot,
			UiKit.corner(10),
		})
		local iconText = UiKit.label({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.5,
			Parent = icon,
		})
		local emptyText = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 20),
			Text = "empty",
			TextColor3 = Color3.fromRGB(110, 115, 110),
			Font = Enum.Font.Gotham,
			Parent = slot,
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(92, 18),
			Text = hintText,
			TextColor3 = theme.textDim,
			Font = Enum.Font.Gotham,
			Parent = slot,
		})
		return { frame = slot, icon = icon, iconText = iconText, emptyText = emptyText }
	end

	local slot1 = buildSlot(0, "[E] Use", true)
	local slot2 = buildSlot(106, "[Q] Swap", false)

	local fullFlash = UiKit.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -142),
		Size = UDim2.fromOffset(198, 24),
		Text = "Inventory full",
		TextColor3 = theme.red,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== center banner =====================

	local banner = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 54),
		Text = "",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== mobile buttons =====================

	if ctx.controllers.InputHandler.touchEnabled then
		local sprintButton = UiKit.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 18, 1, -90),
			Size = UDim2.fromOffset(96, 96),
			Text = "RUN",
			BackgroundColor3 = theme.green,
			Parent = gui,
		})
		local useButton = UiKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -230, 1, -16),
			Size = UDim2.fromOffset(80, 56),
			Text = "USE",
			Parent = gui,
		})
		local swapButton = UiKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -230, 1, -80),
			Size = UDim2.fromOffset(80, 38),
			Text = "SWAP",
			BackgroundColor3 = theme.panelLight,
			TextColor3 = theme.textPrimary,
			Parent = gui,
		})
		self.mobile = { sprintButton = sprintButton, useButton = useButton, swapButton = swapButton }

		-- sprint is a toggle on mobile
		local sprintOn = false
		sprintButton.Activated:Connect(function()
			sprintOn = not sprintOn
			sprintButton.BackgroundColor3 = sprintOn and theme.yellow or theme.green
			ctx.controllers.InputHandler.notifySprint(sprintOn)
		end)
		useButton.Activated:Connect(function()
			ctx.controllers.InputHandler.notifyUse()
		end)
		swapButton.Activated:Connect(function()
			ctx.controllers.InputHandler.notifySwap()
		end)
	end

	-- ===================== API =====================

	function self.show()
		gui.Enabled = true
	end

	function self.hide()
		gui.Enabled = false
	end

	function self.setObjective(text)
		objectiveLabel.Text = text
	end

	local lastNotebookCount = 0
	function self.setNotebooks(collected, total)
		notebookLabel.Text = string.format("Notebooks: %d/%d", collected, total)
		if collected > lastNotebookCount then
			sounds.play("collect")
			notebookScale.Scale = 1.18
			UiKit.tween(notebookScale, 0.25, { Scale = 1 })
		end
		lastNotebookCount = collected
	end

	function self.resetForRound(total)
		lastNotebookCount = 0
		notebookLabel.Text = string.format("Notebooks: 0/%d", total)
		self.setObjective("Collect " .. total .. " notebooks!")
	end

	function self.setNickels(count)
		nickelLabel.Text = "x " .. count
	end

	-- mode: "ok" | "low" | "exhausted"; cold: boolean
	local lastMode = "ok"
	function self.setStamina(alpha, mode, cold)
		staminaFill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		coldTag.Visible = cold == true
		if mode ~= lastMode then
			lastMode = mode
			local color = theme.green
			if mode == "low" then
				color = theme.yellow
			elseif mode == "exhausted" then
				color = theme.red
				UiKit.shake(staminaBack, 7)
				sounds.play("exhausted")
			end
			UiKit.tween(staminaFill, 0.2, { BackgroundColor3 = color })
		end
	end

	function self.flashStaminaFull()
		staminaFill.BackgroundColor3 = theme.green
		staminaFill.BackgroundTransparency = 0.6
		UiKit.tween(staminaFill, 0.4, { BackgroundTransparency = 0 })
	end

	local function renderSlot(slot, itemId)
		if itemId then
			local def = ctx.config.ITEMS[itemId]
			slot.icon.Visible = true
			slot.icon.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			slot.iconText.Text = def.shortLabel
			slot.emptyText.Visible = false
		else
			slot.icon.Visible = false
			slot.emptyText.Visible = true
		end
	end

	function self.setSlots(itemId1, itemId2)
		renderSlot(slot1, itemId1)
		renderSlot(slot2, itemId2)
	end

	function self.flashPickupFailed(message)
		fullFlash.Text = message or "Inventory full"
		fullFlash.TextTransparency = 0
		sounds.play("error")
		task.delay(1.5, function()
			UiKit.tween(fullFlash, 0.4, { TextTransparency = 1 })
		end)
	end

	function self.banner(text, color)
		banner.Text = text
		banner.TextColor3 = color or theme.accent
		banner.TextTransparency = 0
		task.delay(2.2, function()
			UiKit.tween(banner, 0.6, { TextTransparency = 1 })
		end)
	end

	-- ===================== remote subscriptions =====================

	ctx.remotes.NotebookCollected.OnClientEvent:Connect(function(collected, total)
		self.setNotebooks(collected, total)
	end)

	ctx.remotes.NickelChanged.OnClientEvent:Connect(function(count)
		local previousText = nickelLabel.Text
		self.setNickels(count)
		if gui.Enabled and previousText ~= nickelLabel.Text then
			sounds.play("nickel")
		end
	end)

	ctx.remotes.PickupFailed.OnClientEvent:Connect(function(message)
		self.flashPickupFailed(message)
	end)

	ctx.remotes.PhaseChanged.OnClientEvent:Connect(function(phaseName)
		if phaseName == "CHARACTERS_ACTIVE" then
			self.banner("You hear footsteps...", UiKit.theme.red)
			self.setObjective("Keep collecting — they're awake.")
		elseif phaseName == "EXIT_OPEN" then
			self.banner("ALL NOTEBOOKS! GET TO THE EXIT!", UiKit.theme.green)
			self.setObjective("Escape through the EXIT door (entrance corridor)!")
			sounds.play("collect", 0.7)
		end
	end)

	return self
end

return HudController
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "InputHandler",
		class = "ModuleScript",
		source = [=====[
--[[
	InputHandler (ModuleScript, StarterPlayerScripts.BaldiClient.InputHandler)
	Routes raw input to gameplay callbacks so the other controllers never
	talk to UserInputService directly:
	  Shift (hold)  -> sprint        E -> use slot 1        Q -> swap slots
	Mobile equivalents are on-screen buttons created by HudController; they
	call the same notify* functions.
]]

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}

function InputHandler.init(ctx)
	local self = {
		touchEnabled = UserInputService.TouchEnabled,
	}
	local sprintCallbacks = {}
	local useCallbacks = {}
	local swapCallbacks = {}

	local function fire(callbacks, ...)
		for _, callback in ipairs(callbacks) do
			callback(...)
		end
	end

	function self.onSprint(callback)
		table.insert(sprintCallbacks, callback)
	end

	function self.onUse(callback)
		table.insert(useCallbacks, callback)
	end

	function self.onSwap(callback)
		table.insert(swapCallbacks, callback)
	end

	-- mobile buttons (and anything else) report through these
	function self.notifySprint(held)
		fire(sprintCallbacks, held)
	end

	function self.notifyUse()
		fire(useCallbacks)
	end

	function self.notifySwap()
		fire(swapCallbacks)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(true)
		elseif input.KeyCode == Enum.KeyCode.E then
			self.notifyUse()
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.notifySwap()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self.notifySprint(false)
		end
	end)

	return self
end

return InputHandler
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "ItemUseClient",
		class = "ModuleScript",
		source = [=====[
--[[
	ItemUseClient (ModuleScript, StarterPlayerScripts.BaldiClient.ItemUseClient)

	Item slot input + HUD mirroring:
	  - InventoryChanged keeps the two HUD slots in sync with the server.
	  - E (or mobile USE) fires UseItem with the camera look direction
	    (the server only needs it for the BSODA projectile).
	  - Q (or mobile SWAP) asks the server to swap slot 1 and slot 2.

	Notebooks and vending machines also listen for E via ProximityPrompt,
	so while any prompt is on screen the E press belongs to the prompt and
	item use is suppressed (step away a few studs to drink your BSODA).
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local ItemUseClient = {}

function ItemUseClient.init(ctx)
	local self = { slots = {} }
	local hud = ctx.controllers.HudController
	local sounds = ctx.controllers.SoundController
	local lastUse = 0

	local visiblePrompts = 0
	ProximityPromptService.PromptShown:Connect(function()
		visiblePrompts = visiblePrompts + 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		visiblePrompts = math.max(0, visiblePrompts - 1)
	end)

	ctx.remotes.InventoryChanged.OnClientEvent:Connect(function(itemId1, itemId2)
		self.slots[1] = itemId1
		self.slots[2] = itemId2
		hud.setSlots(itemId1, itemId2)
	end)

	ctx.controllers.InputHandler.onUse(function()
		if visiblePrompts > 0 then
			return -- this E press is for a notebook / vending prompt
		end
		if not self.slots[1] then
			return
		end
		if os.clock() - lastUse < 0.3 then
			return
		end
		lastUse = os.clock()
		local camera = workspace.CurrentCamera
		local direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
		ctx.remotes.UseItem:FireServer(direction)
		sounds.play("use")
	end)

	ctx.controllers.InputHandler.onSwap(function()
		if not self.slots[1] and not self.slots[2] then
			return
		end
		ctx.remotes.SwapSlots:FireServer()
		sounds.play("click")
	end)

	return self
end

return ItemUseClient
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "Main",
		class = "LocalScript",
		source = [=====[
--[[
	Main (LocalScript, StarterPlayerScripts.BaldiClient.Main)

	Client bootstrap. Waits for the shared config + remotes the server
	creates, then initializes every controller module in dependency order.
	Controllers find each other through ctx.controllers, so the order below
	matters: sound/input first, HUD next, then everything that draws on it,
	and the menu last since it orchestrates all of them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("BaldiShared")
local config = require(shared:WaitForChild("GameConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild(config.REMOTES_FOLDER)
local remotes = {}
for _, name in ipairs(config.REMOTE_NAMES) do
	remotes[name] = remotesFolder:WaitForChild(name)
end

local ctx = {
	player = Players.LocalPlayer,
	config = config,
	remotes = remotes,
	controllers = {},
}

local INIT_ORDER = {
	"SoundController",
	"InputHandler",
	"HudController",
	"StaminaController",
	"ItemUseClient",
	"VendingMachineUI",
	"DetentionOverlay",
	"FrostyVignette",
	"MenuController",
}

for _, moduleName in ipairs(INIT_ORDER) do
	local module = require(script.Parent:WaitForChild(moduleName))
	ctx.controllers[moduleName] = module.init(ctx)
end

print("[BaldiGame] Client ready.")
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "MenuController",
		class = "ModuleScript",
		source = [=====[
--[[
	MenuController (ModuleScript, StarterPlayerScripts.BaldiClient.MenuController)

	Every full-screen state the player sees outside of live play:
	  - Main menu: title, PLAY, best time, controls list (fade transitions)
	  - Countdown: "Get ready..." 3-2-1 between pressing Play and spawning
	  - Win screen: ESCAPED! + time + best + Retry / Menu (green accent)
	  - Lose screen: CAUGHT! + catcher + cause + Retry / Menu (red accent)

	Also orchestrates the round lifecycle on the client: shows/hides the
	HUD, enables/disables the stamina controller, and locks the camera to
	first person during play.
]]

local MenuController = {}

function MenuController.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local hud = ctx.controllers.HudController
	local stamina = ctx.controllers.StaminaController
	local self = { inRound = false }

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiMenu",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		Parent = playerGui,
	})

	-- ===================== camera helpers =====================

	local function firstPersonCamera(enabled)
		if not ctx.config.FIRST_PERSON then
			return
		end
		if enabled then
			-- shrink Min first so Min <= Max holds at every step
			ctx.player.CameraMinZoomDistance = 0.5
			ctx.player.CameraMaxZoomDistance = 0.5
		else
			ctx.player.CameraMaxZoomDistance = 16
			ctx.player.CameraMinZoomDistance = 6
		end
	end

	-- ===================== screen scaffolding =====================

	local screens = {}

	local function makeScreen(name, backgroundColor)
		local screen = UiKit.new("CanvasGroup", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0,
			Visible = false,
			Parent = gui,
		})
		screens[name] = screen
		return screen
	end

	local function showScreen(name)
		for screenName, screen in pairs(screens) do
			if screenName == name then
				screen.GroupTransparency = 1
				screen.Visible = true
				UiKit.tween(screen, 0.3, { GroupTransparency = 0 })
			elseif screen.Visible then
				local closing = screen
				UiKit.tween(closing, 0.25, { GroupTransparency = 1 }).Completed:Connect(function()
					if closing.GroupTransparency > 0.95 then
						closing.Visible = false
					end
				end)
			end
		end
	end

	local function hideAllScreens()
		for _, screen in pairs(screens) do
			if screen.Visible then
				local closing = screen
				UiKit.tween(closing, 0.3, { GroupTransparency = 1 }).Completed:Connect(function()
					closing.Visible = false
				end)
			end
		end
	end

	local function formatTime(seconds)
		local minutes = math.floor(seconds / 60)
		local remainder = seconds - minutes * 60
		return string.format("%d:%04.1f", minutes, remainder)
	end

	-- ===================== main menu =====================

	local mainMenu = makeScreen("main", theme.chalkboard)

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(0.9, 0, 0, 84),
		Text = ctx.config.GAME_TITLE,
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0.4,
		Parent = mainMenu,
	})
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.245),
		Size = UDim2.new(0.8, 0, 0, 24),
		Text = ctx.config.GAME_SUBTITLE,
		Font = Enum.Font.Gotham,
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local playButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(260, 64),
		Text = "PLAY",
		Parent = mainMenu,
	})

	local bestTimeLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, 22),
		Text = "Best time: --",
		Font = Enum.Font.Gotham,
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local controlsPanel = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.35,
		Parent = mainMenu,
		UiKit.corner(12),
	})
	UiKit.label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "HOW TO PLAY",
		TextColor3 = theme.accent,
		Parent = controlsPanel,
	})
	UiKit.label({
		Position = UDim2.fromOffset(24, 38),
		Size = UDim2.new(1, -48, 1, -50),
		Text = table.concat({
			"Collect all 10 notebooks, then escape through the EXIT.",
			"WASD — move   |   Shift — sprint (drains stamina)",
			"E — use item   |   Q — swap item slots",
			"ChatRevive chases on sight. Don't let it touch you.",
			"LP detains anyone he SEES moving too fast. Walk near him.",
			"Frosty is harmless... but his chill slows you down.",
		}, "\n"),
		Font = Enum.Font.Gotham,
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = theme.textPrimary,
		Parent = controlsPanel,
	})

	-- ===================== countdown screen =====================

	local countdownScreen = makeScreen("countdown", theme.chalkboard)
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.new(0.9, 0, 0, 48),
		Text = "Get ready...",
		TextColor3 = theme.textPrimary,
		Parent = countdownScreen,
	})
	local countdownNumber = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(200, 120),
		Text = "3",
		TextColor3 = theme.accent,
		Parent = countdownScreen,
	})

	-- ===================== end screens =====================

	local function makeEndScreen(name, accent, titleText)
		local screen = makeScreen(name, theme.chalkboard)
		UiKit.new("Frame", { -- accent strip
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.new(0.6, 0, 0, 6),
			BackgroundColor3 = accent,
			Parent = screen,
			UiKit.corner(3),
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.22),
			Size = UDim2.new(0.9, 0, 0, 76),
			Text = titleText,
			TextColor3 = accent,
			TextStrokeTransparency = 0.4,
			Parent = screen,
		})
		local detailLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0.8, 0, 0, 30),
			Text = "",
			Font = Enum.Font.GothamMedium,
			TextColor3 = theme.textPrimary,
			Parent = screen,
		})
		local subLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.new(0.8, 0, 0, 22),
			Text = "",
			Font = Enum.Font.Gotham,
			TextColor3 = theme.textDim,
			Parent = screen,
		})
		local retryButton = UiKit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, -90, 0.6, 0),
			Size = UDim2.fromOffset(160, 52),
			Text = "RETRY",
			BackgroundColor3 = accent,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = screen,
		})
		local menuButton = UiKit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 90, 0.6, 0),
			Size = UDim2.fromOffset(160, 52),
			Text = "MENU",
			BackgroundColor3 = theme.panelLight,
			TextColor3 = theme.textPrimary,
			Parent = screen,
		})
		return { screen = screen, detail = detailLabel, sub = subLabel, retry = retryButton, menu = menuButton }
	end

	local winScreen = makeEndScreen("win", theme.green, "ESCAPED!")
	local loseScreen = makeEndScreen("lose", theme.red, "CAUGHT!")

	-- ===================== round lifecycle =====================

	local function enterRound()
		self.inRound = true
		hideAllScreens()
		hud.show()
		stamina.setEnabled(true)
		firstPersonCamera(true)
	end

	local function exitRound()
		self.inRound = false
		hud.hide()
		stamina.setEnabled(false)
		firstPersonCamera(false)
	end

	local function requestStart()
		sounds.play("click")
		ctx.remotes.RequestStart:FireServer()
	end

	playButton.Activated:Connect(requestStart)
	winScreen.retry.Activated:Connect(requestStart)
	loseScreen.retry.Activated:Connect(requestStart)
	winScreen.menu.Activated:Connect(function()
		sounds.play("click")
		showScreen("main")
	end)
	loseScreen.menu.Activated:Connect(function()
		sounds.play("click")
		showScreen("main")
	end)

	ctx.remotes.GameCountdown.OnClientEvent:Connect(function(seconds)
		showScreen("countdown")
		task.spawn(function()
			for remaining = seconds, 1, -1 do
				if screens.countdown.Visible == false then
					return
				end
				countdownNumber.Text = tostring(remaining)
				countdownNumber.TextTransparency = 0
				sounds.play("click", 1 + (seconds - remaining) * 0.15)
				task.wait(1)
			end
			countdownNumber.Text = "GO!"
		end)
	end)

	ctx.remotes.GameStarted.OnClientEvent:Connect(function()
		hud.resetForRound(ctx.config.NOTEBOOK_SPAWN_COUNT)
		enterRound()
	end)

	ctx.remotes.PlayerWon.OnClientEvent:Connect(function(elapsed, best)
		exitRound()
		sounds.winJingle()
		winScreen.detail.Text = "Time: " .. formatTime(elapsed)
		winScreen.sub.Text = "Session best: " .. formatTime(best)
		bestTimeLabel.Text = "Best time: " .. formatTime(best)
		showScreen("win")
	end)

	ctx.remotes.PlayerLost.OnClientEvent:Connect(function(catcherName, cause)
		exitRound()
		sounds.play("caught")
		loseScreen.detail.Text = "Caught by " .. tostring(catcherName)
		loseScreen.sub.Text = tostring(cause or "")
		showScreen("lose")
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(function()
		-- safety net: if the round collapsed while we thought we were in it
		-- (and no win/lose screen arrived), fall back to the menu
		if self.inRound then
			exitRound()
			showScreen("main")
		end
	end)

	-- boot state: menu visible, HUD hidden, third person in the lobby
	exitRound()
	showScreen("main")

	return self
end

return MenuController
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "SoundController",
		class = "ModuleScript",
		source = [=====[
--[[
	SoundController (ModuleScript, StarterPlayerScripts.BaldiClient.SoundController)
	UI / feedback sounds built only from rbxasset:// files that ship with the
	engine, so nothing depends on marketplace assets. Every play is wrapped
	in pcall — a missing sound never breaks gameplay.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundController = {}

local LIBRARY = {
	click = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.4, volume = 0.4 },
	collect = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.0, volume = 0.7 },
	nickel = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.8, volume = 0.6 },
	buy = { id = "rbxasset://sounds/snap.mp3", speed = 1.2, volume = 0.6 },
	error = { id = "rbxasset://sounds/snap.mp3", speed = 0.55, volume = 0.6 },
	exhausted = { id = "rbxasset://sounds/snap.mp3", speed = 0.4, volume = 0.5 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1.0, volume = 1 },
	detention = { id = "rbxasset://sounds/snap.mp3", speed = 0.35, volume = 0.8 },
	frost = { id = "rbxasset://sounds/swoosh.mp3", speed = 0.6, volume = 0.7 },
	use = { id = "rbxasset://sounds/swoosh.mp3", speed = 1.2, volume = 0.6 },
}

function SoundController.init(ctx)
	local self = {}

	function self.play(name, pitchOverride)
		local entry = LIBRARY[name]
		if not entry then
			return
		end
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			sound.Volume = entry.volume
			sound.PlaybackSpeed = pitchOverride or entry.speed
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 4)
		end)
	end

	-- little rising arpeggio for the win screen
	function self.winJingle()
		task.spawn(function()
			for _, pitch in ipairs({ 1.0, 1.26, 1.5 }) do
				self.play("collect", pitch)
				task.wait(0.18)
			end
		end)
	end

	return self
end

return SoundController
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "StaminaController",
		class = "ModuleScript",
		source = [=====[
--[[
	StaminaController (ModuleScript, StarterPlayerScripts.BaldiClient.StaminaController)

	Client-managed stamina, exactly per the plan:
	  - 0..100. Holding sprint (Shift / mobile RUN) while moving drains
	    10/sec and boosts WalkSpeed 16 -> 24.
	  - At 0: exhausted — speed snaps back to 16, sprint locks out, bar
	    flashes red and shakes.
	  - Regens 6/sec while not sprinting; sprint unlocks again at 30.
	  - Zesty Bar (StaminaRestore remote): instant 100 + lockout cleared.
	  - Frosty (applyDebuff): WalkSpeed multiplied by 0.4 for 4 seconds —
	    which also drops sprint speed under LP's radar.

	WalkSpeed is written every Heartbeat. LP's server check reads actual
	velocity, so sprint speed (24) > threshold (20) > walk speed (16)
	behaves exactly as designed.
]]

local RunService = game:GetService("RunService")

local StaminaController = {}

function StaminaController.init(ctx)
	local cfg = ctx.config.STAMINA
	local playerCfg = ctx.config.PLAYER
	local hud = ctx.controllers.HudController

	local self = {
		stamina = cfg.MAX,
		exhausted = false,
		sprintHeld = false,
		enabled = false,
		sprintLocked = false, -- detention
		debuffMultiplier = 1,
		debuffUntil = 0,
	}

	local function getHumanoid()
		local character = ctx.player.Character
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	ctx.controllers.InputHandler.onSprint(function(held)
		self.sprintHeld = held
	end)

	RunService.Heartbeat:Connect(function(dt)
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end
		if not self.enabled then
			humanoid.WalkSpeed = playerCfg.WALK_SPEED
			return
		end

		local debuffActive = os.clock() < self.debuffUntil
		local multiplier = debuffActive and self.debuffMultiplier or 1
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local sprinting = self.sprintHeld
			and not self.exhausted
			and not self.sprintLocked
			and self.stamina > 0
			and moving

		if sprinting then
			self.stamina = self.stamina - cfg.DRAIN_PER_SEC * dt
			if self.stamina <= 0 then
				self.stamina = 0
				self.exhausted = true -- lockout until SPRINT_REENABLE
				sprinting = false
			end
		else
			self.stamina = math.min(cfg.MAX, self.stamina + cfg.REGEN_PER_SEC * dt)
		end

		if self.exhausted and self.stamina >= cfg.SPRINT_REENABLE then
			self.exhausted = false
		end

		humanoid.WalkSpeed = (sprinting and playerCfg.SPRINT_SPEED or playerCfg.WALK_SPEED) * multiplier

		local mode = "ok"
		if self.exhausted then
			mode = "exhausted"
		elseif self.stamina < cfg.LOW_THRESHOLD then
			mode = "low"
		end
		hud.setStamina(self.stamina / cfg.MAX, mode, debuffActive)
	end)

	-- ===================== API =====================

	-- Zesty Bar: full reset on demand
	function self.restoreFull()
		self.stamina = cfg.MAX
		self.exhausted = false
		hud.flashStaminaFull()
		hud.setStamina(1, "ok", os.clock() < self.debuffUntil)
	end

	-- Frosty's chill
	function self.applyDebuff(multiplier, duration)
		self.debuffMultiplier = multiplier
		self.debuffUntil = os.clock() + duration
	end

	function self.setEnabled(enabled)
		self.enabled = enabled
		if enabled then
			self.stamina = cfg.MAX
			self.exhausted = false
			self.sprintLocked = false
			self.debuffUntil = 0
			hud.setStamina(1, "ok", false)
		else
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.WalkSpeed = playerCfg.WALK_SPEED
			end
		end
	end

	function self.setSprintLocked(locked)
		self.sprintLocked = locked
	end

	ctx.remotes.StaminaRestore.OnClientEvent:Connect(function()
		self.restoreFull()
		ctx.controllers.SoundController.play("buy", 1.6)
	end)

	return self
end

return StaminaController
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "UiKit",
		class = "ModuleScript",
		source = [=====[
--[[
	UiKit (ModuleScript, StarterPlayerScripts.BaldiClient.UiKit)
	Tiny UI construction helpers + the shared color theme. Every ScreenGui
	in the game is built in code through these, so no image assets or
	prefab GUIs are required.
]]

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.theme = {
	chalkboard = Color3.fromRGB(24, 40, 33),
	panel = Color3.fromRGB(18, 22, 20),
	panelLight = Color3.fromRGB(40, 48, 44),
	textPrimary = Color3.fromRGB(245, 245, 240),
	textDim = Color3.fromRGB(170, 175, 170),
	accent = Color3.fromRGB(255, 213, 70), -- school-bus yellow
	green = Color3.fromRGB(80, 200, 120),
	yellow = Color3.fromRGB(240, 200, 60),
	red = Color3.fromRGB(225, 70, 55),
	blue = Color3.fromRGB(90, 160, 255),
	ice = Color3.fromRGB(170, 225, 255),
}

-- Create an instance from a property table. Children listed under the
-- special key [1..n]; Parent is applied last.
function UiKit.new(className, props)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		elseif type(key) == "number" then
			value.Parent = instance
		else
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiKit.corner(radiusPixels)
	return UiKit.new("UICorner", { CornerRadius = UDim.new(0, radiusPixels) })
end

function UiKit.stroke(color, thickness, transparency)
	return UiKit.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UiKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.theme.textPrimary,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UiKit.new("TextLabel", defaults)
end

function UiKit.button(props)
	local defaults = {
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.theme.panel,
		BackgroundColor3 = UiKit.theme.accent,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local button = UiKit.new("TextButton", defaults)
	UiKit.corner(10).Parent = button
	return button
end

function UiKit.tween(instance, time, props, style)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- quick shake for "exhausted" / error feedback
function UiKit.shake(guiObject, magnitude)
	magnitude = magnitude or 6
	local original = guiObject.Position
	task.spawn(function()
		for i = 1, 4 do
			local offset = (i % 2 == 0) and magnitude or -magnitude
			guiObject.Position = original + UDim2.fromOffset(offset, 0)
			task.wait(0.04)
		end
		guiObject.Position = original
	end)
end

return UiKit
]=====],
	},
	{
		root = "StarterPlayerScripts",
		folders = { "BaldiClient" },
		name = "VendingMachineUI",
		class = "ModuleScript",
		source = [=====[
--[[
	VendingMachineUI (ModuleScript, StarterPlayerScripts.BaldiClient.VendingMachineUI)

	Popup shown when the vending machine's ProximityPrompt is triggered:
	item name, icon, cost, your current Nickel count, and a Buy button.
	Closes on buy, on the X, or automatically when you walk away.
]]

local RunService = game:GetService("RunService")

local VendingMachineUI = {}

function VendingMachineUI.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local self = {}

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiVending",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Enabled = false,
		Parent = playerGui,
	})

	local panel = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(340, 250),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
		UiKit.corner(14),
		UiKit.stroke(theme.accent, 2),
	})

	local titleLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -60, 0, 30),
		Text = "BSODA",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local closeButton = UiKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(32, 32),
		Text = "X",
		BackgroundColor3 = theme.red,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	})

	local iconFrame = UiKit.new("Frame", {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = theme.blue,
		Parent = panel,
		UiKit.corner(10),
	})
	local iconText = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = "BSODA",
		Parent = iconFrame,
	})

	local descLabel = UiKit.label({
		Position = UDim2.fromOffset(104, 52),
		Size = UDim2.new(1, -120, 0, 76),
		Text = "",
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = theme.textDim,
		Parent = panel,
	})

	local costLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "Cost: 1 Nickel",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = theme.accent,
		Parent = panel,
	})
	local haveLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 162),
		Size = UDim2.new(1, -32, 0, 20),
		Text = "You have: 0 Nickels",
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextColor3 = theme.textDim,
		Parent = panel,
	})

	local buyButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -32, 0, 42),
		Text = "BUY",
		Parent = panel,
	})

	local resultLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(1, -32, 0, 18),
		Text = "",
		TextColor3 = theme.green,
		Parent = panel,
	})

	-- ===================== behaviour =====================

	local current = nil -- { machineId, itemId, cost, position }
	local watcher = nil

	local function close()
		gui.Enabled = false
		current = nil
		if watcher then
			watcher:Disconnect()
			watcher = nil
		end
	end

	local function refreshAffordability(nickels)
		haveLabel.Text = "You have: " .. nickels .. " Nickel" .. (nickels == 1 and "" or "s")
		local canAfford = current ~= nil and nickels >= current.cost
		buyButton.AutoButtonColor = canAfford
		buyButton.BackgroundColor3 = canAfford and theme.accent or Color3.fromRGB(95, 95, 90)
	end

	ctx.remotes.OpenVending.OnClientEvent:Connect(function(data)
		local def = ctx.config.ITEMS[data.itemId]
		if not def then
			return
		end
		current = data
		titleLabel.Text = def.displayName
		iconFrame.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
		iconText.Text = def.shortLabel
		descLabel.Text = def.description
		costLabel.Text = "Cost: " .. def.cost .. " Nickel" .. (def.cost == 1 and "" or "s")
		resultLabel.Text = ""
		refreshAffordability(data.nickels)
		gui.Enabled = true
		sounds.play("click")

		-- close automatically when the player walks away
		if watcher then
			watcher:Disconnect()
		end
		watcher = RunService.Heartbeat:Connect(function()
			local character = ctx.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp or not current then
				close()
				return
			end
			if (hrp.Position - current.position).Magnitude > ctx.config.VENDING_CLOSE_DISTANCE then
				close()
			end
		end)
	end)

	ctx.remotes.NickelChanged.OnClientEvent:Connect(function(count)
		if gui.Enabled then
			refreshAffordability(count)
		end
	end)

	buyButton.Activated:Connect(function()
		if current then
			ctx.remotes.BuyItem:FireServer(current.machineId)
		end
	end)

	closeButton.Activated:Connect(close)

	ctx.remotes.BuyResult.OnClientEvent:Connect(function(success, message)
		if not gui.Enabled then
			return
		end
		if success then
			sounds.play("buy")
			resultLabel.TextColor3 = theme.green
			resultLabel.Text = message
			task.delay(0.5, close)
		else
			sounds.play("error")
			resultLabel.TextColor3 = theme.red
			resultLabel.Text = message
			UiKit.shake(panel, 8)
		end
	end)

	ctx.remotes.RoundEnded.OnClientEvent:Connect(close)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(close)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(close)

	self.close = close
	return self
end

return VendingMachineUI
]=====],
	},
}

for _, file in ipairs(files) do
	local parent = getRoot(file.root)
	for _, folderName in ipairs(file.folders) do
		parent = ensureFolder(parent, folderName)
	end
	local instance = Instance.new(file.class)
	instance.Name = file.name
	instance.Source = file.source
	instance.Parent = parent
end

print("[BaldiGame] Installed " .. #files .. " scripts. Press Play to test!")
