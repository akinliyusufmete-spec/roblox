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
		name = "AssetConfig",
		class = "ModuleScript",
		source = [=====[
--[[
	AssetConfig (ModuleScript, ReplicatedStorage.BaldiShared.AssetConfig)

	PASTE YOUR ASSET IDS HERE — this is the one file you edit to skin the
	whole game with your own images and sounds.

	Every entry left as "" falls back to a built-in placeholder (plain
	colors / engine sounds), so the game always runs. Replace entries one
	at a time as you finish assets.

	An image id looks like:  "rbxassetid://1234567890"
	To get one: Studio -> Asset Manager -> Import your image (Decal),
	right-click it -> Copy Asset ID.

	Sound ids use the same format. Leave "" to keep the built-in sound.
]]

local AssetConfig = {}

-- ========== UI images ==========
AssetConfig.IMAGES = {
	-- full-screen backgrounds
	MENU_BACKGROUND = "", -- main menu (like the original game's title art)
	COUNTDOWN_BACKGROUND = "", -- "Get ready..." screen
	WIN_BACKGROUND = "", -- ESCAPED! screen
	LOSE_BACKGROUND = "", -- CAUGHT! screen
	DETENTION_BACKGROUND = "", -- detention overlay (semi-transparent works best)
	FROST_OVERLAY = "", -- Frosty chill overlay (transparent PNG, icy edges)
	SILVER_OVERLAY = "", -- Silver grab minigame backdrop (semi-transparent PNG)

	-- HUD pieces
	NOTEBOOK_ICON = "", -- little notebook next to the counter (top left)
	NICKEL_ICON = "", -- coin icon (top right)
	ITEM_SLOT = "", -- background of each item square (top right)
	STAMINA_BACK = "", -- stamina bar backplate
	STAMINA_FILL = "", -- stamina bar fill (tinted green/yellow/red by code)

	-- buttons / panels
	PLAY_BUTTON = "", -- the main menu PLAY button
	PANEL = "", -- "HOW TO PLAY" panel background
	VENDING_PANEL = "", -- vending machine popup background

	-- item pictures (shown inside slots and the vending popup)
	ITEMS = {
		BSODA = "",
		ZESTY = "",
		SCISSORS = "",
		ALARM = "",
	},
}

-- ========== sounds ==========
-- Client feedback sounds (played by SoundController):
--   click, collect, nickel, buy, error, exhausted, caught, detention,
--   frost, use, win, grab (Silver caught you), swept (a sweeper hit you)
-- Server NPC/world sounds:
--   chase   = ChatRevive's repeating chase noise (the "slap")
--   whistle = LP's alert when he starts chasing
--   sweep   = looping noise a sweeper makes mid-sweep
--   alarm   = the placed Alarm Clock's ringing loop
AssetConfig.SOUNDS = {
	click = "",
	collect = "",
	nickel = "",
	buy = "",
	error = "",
	exhausted = "",
	caught = "",
	detention = "",
	frost = "",
	use = "",
	win = "",
	grab = "",
	swept = "",
	chase = "",
	whistle = "",
	sweep = "",
	alarm = "",
}

return AssetConfig
]=====],
	},
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
	SCISSORS = {
		id = "SCISSORS",
		displayName = "Safety Scissors",
		shortLabel = "SNIP",
		description = "Cut yourself free the instant Silver grabs you — and Silver stays snipped for a while. Only works while grabbed.",
		cost = 1,
		color = { 210, 210, 220 },
	},
	ALARM = {
		id = "ALARM",
		displayName = "Alarm Clock",
		shortLabel = "ALARM",
		description = "Drops at your feet and rings loudly. ChatRevive can't resist investigating the noise.",
		cost = 1,
		color = { 255, 150, 50 },
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

GameConfig.ALARM_CLOCK = {
	RING_SECONDS = 12, -- how long a placed alarm distracts ChatRevive
}

-- ========== NPCs ==========
GameConfig.NPC = {
	-- How often a chasing NPC recomputes its path to your live position.
	-- Lower = tighter tracking (less "goldfish"), slightly more CPU.
	REPATH_INTERVAL = 0.3,

	-- Pathfinding agent shape, shared by every NPC. A small radius fits
	-- through hand-made doorways; jumping clears small thresholds/lips and
	-- lets a wedged NPC hop free. Make doorways at least ~5 studs wide.
	AGENT = {
		RADIUS = 2,
		HEIGHT = 5,
		JUMP = true,
		JUMP_HEIGHT = 4,
	},

	CHATREVIVE = {
		NAME = "ChatRevive",
		-- Knows where the nearest player is from anywhere on the map and
		-- hunts relentlessly. Set false to require line of sight within
		-- SIGHT_RANGE instead.
		OMNISCIENT = true,
		ROAM_SPEED = 11,
		CHASE_SPEED = 19, -- sprint (24) outruns it, walking (16) does not
		ENRAGED_CHASE_SPEED = 23, -- after all notebooks are collected
		ENRAGED_SIGHT_INTERVAL = 0.12,
		SIGHT_RANGE = 200, -- only used when OMNISCIENT = false
		SIGHT_INTERVAL = 0.25, -- how often he re-picks the nearest target
		MEMORY_SECONDS = 6, -- chases last-known position this long after losing sight
		CATCH_DISTANCE = 4,
	},
	LP = {
		NAME = "LP",
		ROAM_SPEED = 12,
		CHASE_SPEED = 18, -- when you've stopped running you can break his sight to escape
		RULEBREAK_CHASE_SPEED = 25, -- while you keep running he outpaces a sprint
		SIGHT_RANGE = 70,
		SIGHT_INTERVAL = 0.25,
		SPEED_THRESHOLD = 20, -- horizontal velocity above this + line of sight = trouble
		MEMORY_SECONDS = 6,
		CATCH_DISTANCE = 4,
		DETENTION_SECONDS = 15,
		RELEASE_IMMUNITY_SECONDS = 5, -- can't be re-detained right after release
	},
	FROSTY = {
		NAME = "Frosty",
		ROAM_SPEED = 9,
		WAIT_MIN = 0.6,
		WAIT_MAX = 1.4,
		DEBUFF_RADIUS = 7,
		DEBUFF_SECONDS = 4,
		DEBUFF_MULTIPLIER = 0.4, -- WalkSpeed becomes base * 0.4
		DEBUFF_COOLDOWN = 4, -- per victim
		SLOWS_NPCS = true, -- Frosty also chills any character that wanders too close
	},
	SILVER = {
		NAME = "Silver",
		ROAM_SPEED = 10,
		CHASE_SPEED = 17, -- slower than a sprint — but sprinting risks LP
		SIGHT_RANGE = 45,
		SIGHT_INTERVAL = 0.3,
		MEMORY_SECONDS = 3,
		CATCH_DISTANCE = 4,
		-- the grab minigame: click the cube as it crosses the center zone
		GRAB_HITS = 5, -- perfect hits needed to wriggle free
		GRAB_HIT_WINDOW = 0.14, -- timing tolerance (fraction of the bar around center)
		GRAB_CUBE_PERIOD = 1.4, -- seconds per full cube swing at the start
		GRAB_SPEEDUP = 1.12, -- cube speeds up this much per successful hit
		GRAB_MIN_HIT_GAP = 0.3, -- server-side: hits closer together than this are ignored
		GRAB_MAX_SECONDS = 15, -- failsafe: held at most this long
		GRAB_IMMUNITY = 10, -- can't be re-grabbed right after escaping
		GRAB_COOLDOWN = 6, -- Silver rests after any grab
		SCISSORS_DISABLE = 8, -- cutting free stuns Silver this long
	},
	-- The hall sweepers: never catch anyone, just barrel down their route
	-- and shove whoever they touch along with them.
	SWEEPERS = {
		GUIDELINES = {
			NAME = "Guidelines",
			SWEEP_SPEED = 26, -- faster than a sprint while mid-sweep
			PUSH_SPEED = 30, -- how hard victims are carried along
			SWEEP_RADIUS = 5,
			WAIT_MIN = 4, -- rest at each end of the route
			WAIT_MAX = 7,
			SWEEPS_NPCS = true, -- also shoves the other characters (use it!)
		},
		SAI = {
			NAME = "Sai",
			SWEEP_SPEED = 23,
			PUSH_SPEED = 27,
			SWEEP_RADIUS = 5,
			WAIT_MIN = 6,
			WAIT_MAX = 10,
			SWEEPS_NPCS = true,
		},
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
	"SilverHit", -- one successful timing hit in Silver's grab minigame
	"SilverEscape", -- "use my scissors" while grabbed
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
	"SilverGrab", -- you've been grabbed: open the minigame
	"SilverReleased", -- grab over: close it
	"SweptPush", -- a sweeper is carrying you: apply the push client-side
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

	  config/assets -> remotes -> map -> NPCs -> economy/detention/
	  notebooks/exit -> GameManager (last; it wires the Play button)

	All systems communicate through the ctx table instead of require-ing
	each other, which keeps the module graph cycle-free.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BaldiShared")
local GameConfig = require(shared:WaitForChild("GameConfig"))
local AssetConfig = require(shared:WaitForChild("AssetConfig"))

local RemoteSetup = require(script.Parent.RemoteSetup)
local MapResolver = require(script.Parent.MapResolver)
local ChatReviveAI = require(script.Parent.ChatReviveAI)
local LpAI = require(script.Parent.LpAI)
local FrostyAI = require(script.Parent.FrostyAI)
local SilverAI = require(script.Parent.SilverAI)
local SweeperAI = require(script.Parent.SweeperAI)
local DetentionSystem = require(script.Parent.DetentionSystem)
local ItemEconomy = require(script.Parent.ItemEconomy)
local NotebookSpawner = require(script.Parent.NotebookSpawner)
local ExitDoorManager = require(script.Parent.ExitDoorManager)
local GameManager = require(script.Parent.GameManager)

local ctx = {
	config = GameConfig,
	assets = AssetConfig, -- your image/sound ids (NPC sounds read these)
	remotes = nil, -- RemoteSetup
	map = nil, -- MapResolver (your BaldiMap, or the placeholder school)
	npcs = {}, -- ChatReviveAI / LpAI / FrostyAI register themselves
	manager = nil, -- GameManager
	economy = nil, -- ItemEconomy
	detention = nil, -- DetentionSystem
	notebookSpawner = nil, -- NotebookSpawner
	exitDoor = nil, -- ExitDoorManager
}

RemoteSetup.init(ctx)
MapResolver.resolve(ctx)

-- Give the navmesh a moment to bake over freshly generated geometry
-- before the first paths are computed (paths fail gracefully anyway).
task.wait(1)

DetentionSystem.init(ctx) -- before LpAI/SilverAI, which read ctx.detention

ChatReviveAI.init(ctx)
LpAI.init(ctx)
FrostyAI.init(ctx)
SilverAI.init(ctx)
SweeperAI.init(ctx) -- Guidelines + Sai

ItemEconomy.init(ctx)
NotebookSpawner.init(ctx)
ExitDoorManager.init(ctx)
GameManager.init(ctx)

print("[BaldiGame] Server ready. Map resolved, NPCs spawned, remotes live.")
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "AssetResolver",
		class = "ModuleScript",
		source = [=====[
--[[
	AssetResolver (ModuleScript, ServerScriptService.BaldiGame.AssetResolver)

	Looks up the hand-made models you place under:

	  ReplicatedStorage
	  └── BaldiAssets
	      ├── Npcs
	      │   ├── ChatRevive   (Model with Humanoid + HumanoidRootPart)
	      │   ├── LP
	      │   └── Frosty
	      └── Items
	          ├── Notebook     (Model or Part)
	          ├── Nickel
	          ├── BSODA
	          ├── ZESTY
	          └── BsodaProjectile  (optional — the flying blast visual)

	Everything is optional: a missing asset gets a one-time console note and
	the game uses its built-in placeholder instead, so you can replace
	pieces one at a time while you build.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetResolver = {}

local noted = {}

local function noteOnce(key, message)
	if noted[key] then
		return
	end
	noted[key] = true
	print("[BaldiGame] " .. message)
end

local function assetsFolder(childName)
	local root = ReplicatedStorage:FindFirstChild("BaldiAssets")
	if not root then
		return nil
	end
	return root:FindFirstChild(childName)
end

-- Your NPC rig, validated; nil -> caller builds the placeholder rig.
function AssetResolver.npcTemplate(name)
	local folder = assetsFolder("Npcs")
	local model = folder and folder:FindFirstChild(name)
	if not model then
		noteOnce("npc_" .. name, string.format(
			"No custom rig at ReplicatedStorage/BaldiAssets/Npcs/%s — using the placeholder rig.", name))
		return nil
	end
	if not model:IsA("Model") or not model:FindFirstChildOfClass("Humanoid")
		or not model:FindFirstChild("HumanoidRootPart") then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Npcs/%s must be a Model containing a Humanoid and a HumanoidRootPart — using the placeholder rig instead.",
			name))
		return nil
	end
	return model
end

-- Your item/pickup model; nil -> caller builds the placeholder.
function AssetResolver.itemTemplate(name)
	local folder = assetsFolder("Items")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		noteOnce("item_" .. name, string.format(
			"No custom model at ReplicatedStorage/BaldiAssets/Items/%s — using the placeholder.", name))
		return nil
	end
	if not (template:IsA("Model") or template:IsA("BasePart")) then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Items/%s must be a Model or a Part — using the placeholder instead.", name))
		return nil
	end
	if template:IsA("Model") and not template:FindFirstChildWhichIsA("BasePart", true) then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Items/%s has no parts inside — using the placeholder instead.", name))
		return nil
	end
	return template
end

-- Clone helper for pickups/props: anchored, non-colliding, script-free.
function AssetResolver.preparePropClone(template)
	local clone = template:Clone()
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		elseif descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
	elseif clone:IsA("Model") and not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	return clone
end

return AssetResolver
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

	Activation gating:
	  0 notebooks    -> all NPCs frozen
	  1 notebook     -> all NPCs activate (roam loops start)
	  last notebook  -> the main chaser enrages + the exit opens

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
		if hrp.Anchored then -- countdown or detention...
			-- ...but a player in Silver's grasp stays fair game: getting
			-- grabbed in the open with ChatRevive nearby SHOULD be lethal
			local silver = ctx.npcs.Silver
			if not (silver and silver.isGrabbing and silver.isGrabbing(player)) then
				return false
			end
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
		remotes.GameStarted:FireClient(player, notebooksTotal)
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
				remotes.GameStarted:FireClient(player, notebooksTotal)
				remotes.NotebookCollected:FireClient(player, notebooksCollected, notebooksTotal)
			end
			checkRoundEnd() -- everyone may have left during the countdown
		end)
	end

	-- ===================== notebook -> HUD + gating =====================

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

	Your models (all optional, placeholders otherwise):
	  ReplicatedStorage/BaldiAssets/Items/Nickel
	  ReplicatedStorage/BaldiAssets/Items/BSODA            (world pickup)
	  ReplicatedStorage/BaldiAssets/Items/ZESTY            (world pickup)
	  ReplicatedStorage/BaldiAssets/Items/BsodaProjectile  (flying blast)
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local AssetResolver = require(script.Parent.AssetResolver)

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

	-- Take a specific item from either slot (slot 1 first). Used by systems
	-- that consume items outside the normal slot-1 "use" flow, like Silver's
	-- scissors escape. Returns true if the item was found and removed.
	function self.consumeItem(player, itemId)
		local state = getState(player)
		if state.slots[1] == itemId then
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
		elseif state.slots[2] == itemId then
			state.slots[2] = nil
		else
			return false
		end
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
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		return part
	end

	function self.spawnNickel(position)
		local template = AssetResolver.itemTemplate("Nickel")
		local coin
		if template then
			coin = AssetResolver.preparePropClone(template)
			coin:PivotTo(CFrame.new(position + Vector3.new(0, 0.7, 0)))
		else
			coin = makePickupPart("Nickel", Color3.fromRGB(255, 210, 70), Vector3.new(0.25, 1.4, 1.4))
			coin.Shape = Enum.PartType.Cylinder
			coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
			local sparkle = Instance.new("PointLight")
			sparkle.Color = Color3.fromRGB(255, 220, 90)
			sparkle.Range = 5
			sparkle.Parent = coin
		end
		coin:SetAttribute("IsNickel", true)
		coin.Parent = ctx.map.pickupsFolder
	end

	function self.spawnItemPickup(itemId, position)
		local def = config.ITEMS[itemId]
		if not def then
			return
		end
		local template = AssetResolver.itemTemplate(itemId)
		local pickup
		if template then
			pickup = AssetResolver.preparePropClone(template)
			pickup:PivotTo(CFrame.new(position + Vector3.new(0, 0.7, 0)))
		else
			local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			if itemId == "BSODA" then
				pickup = makePickupPart("Pickup_BSODA", color, Vector3.new(2, 1.1, 1.1))
				pickup.Shape = Enum.PartType.Cylinder
				pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
			else
				pickup = makePickupPart("Pickup_" .. itemId, color, Vector3.new(1.6, 0.5, 2.2))
				pickup.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0))
			end
		end
		pickup:SetAttribute("ItemId", itemId)
		pickup.Parent = ctx.map.pickupsFolder
	end

	-- ===================== alarm clock distraction =====================

	local distraction = nil -- { position, expiresAt }
	local alarmClock = nil -- the placed ringing prop

	-- ChatRevive polls this: a ringing alarm overrides his usual hunting.
	function self.getDistraction()
		if distraction and os.clock() < distraction.expiresAt then
			return distraction
		end
		return nil
	end

	local function stopAlarm()
		distraction = nil
		if alarmClock then
			alarmClock:Destroy()
			alarmClock = nil
		end
	end

	local function placeAlarm(position)
		stopAlarm()
		local ringSeconds = config.ALARM_CLOCK.RING_SECONDS

		local template = AssetResolver.itemTemplate("ALARM")
		local clock
		if template then
			clock = AssetResolver.preparePropClone(template)
			clock:PivotTo(CFrame.new(position + Vector3.new(0, 0.7, 0)))
		else
			clock = makePickupPart("AlarmClock", Color3.fromRGB(255, 150, 50), Vector3.new(1.2, 1.2, 0.8))
			clock.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))
			local blink = Instance.new("PointLight")
			blink.Color = Color3.fromRGB(255, 160, 60)
			blink.Range = 8
			blink.Brightness = 2
			blink.Parent = clock
		end

		local soundParent = clock:IsA("BasePart") and clock
			or clock.PrimaryPart
			or clock:FindFirstChildWhichIsA("BasePart", true)
		if soundParent then
			local customRing = ctx.assets.SOUNDS.alarm
			local ring = Instance.new("Sound")
			ring.Name = "AlarmRing"
			ring.SoundId = (customRing ~= "" and customRing) or "rbxasset://sounds/electronicpingshort.wav"
			ring.Looped = true
			ring.Volume = 1
			ring.PlaybackSpeed = customRing ~= "" and 1 or 1.1
			ring.RollOffMaxDistance = 150
			ring.Parent = soundParent
			pcall(function()
				ring:Play()
			end)
		end

		-- not a pickup: parent with the other transient props
		clock.Parent = ctx.map.projectilesFolder
		alarmClock = clock
		distraction = { position = position, expiresAt = os.clock() + ringSeconds }

		task.delay(ringSeconds, function()
			if alarmClock == clock then
				stopAlarm()
			end
		end)
	end

	function self.clearPickups()
		stopAlarm()
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
									if pickup.Parent
										and (pickup:GetPivot().Position - hrp.Position).Magnitude < config.PICKUP_RADIUS then
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

	local function makeProjectileVisual()
		local template = AssetResolver.itemTemplate("BsodaProjectile")
		if template then
			return AssetResolver.preparePropClone(template)
		end
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
		return can
	end

	local function fireBsoda(player, direction)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local cfg = config.BSODA_PROJECTILE

		local blast = makeProjectileVisual()
		local position = hrp.Position + direction * 2.5 + Vector3.new(0, 0.5, 0)
		blast:PivotTo(CFrame.new(position, position + direction))
		blast.Parent = ctx.map.projectilesFolder

		-- exclude the shooter so the blast doesn't pop on their own body
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
			while traveled < cfg.RANGE and blast.Parent do
				local dt = task.wait()
				local step = direction * cfg.SPEED * dt
				local wallHit = workspace:Raycast(position, step, params)
				if wallHit then
					break
				end
				position = position + step
				traveled = traveled + step.Magnitude
				blast:PivotTo(CFrame.new(position, position + direction))

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
			blast:Destroy()
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
		elseif itemId == "ALARM" then
			-- drop a ringing clock at your feet; ChatRevive investigates it
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				return
			end
			state.slots[1] = state.slots[2]
			state.slots[2] = nil
			syncInventory(player)
			placeAlarm(hrp.Position + Vector3.new(0, -1.5, 0))
		elseif itemId == "SCISSORS" then
			-- only useful mid-grab (the minigame fires SilverEscape); don't
			-- waste the item on an empty snip
			ctx.remotes.PickupFailed:FireClient(player, "Scissors only work while grabbed!")
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
	  - Condition: a player is moving faster than SPEED_THRESHOLD *and* LP has
	    line of sight. Only sight = no reaction. Only speed = no reaction.
	  - Once provoked he chases via continuous re-pathing to your live
	    position (he follows you through doorways), and only loses interest
	    after MEMORY_SECONDS out of sight.
	  - Speeds up while you keep breaking the rule: as long as you're running
	    he moves at RULEBREAK_CHASE_SPEED (faster than a sprint, so you can't
	    just outrun him) — slow to a walk and he eases back to CHASE_SPEED, so
	    the smart escape is to stop running and break his line of sight.
	  - On catch: hands the player to DetentionSystem (teleport + lock).

	Server-side speed check: a client-side WalkSpeed change does NOT
	replicate to the server, so we measure the character's actual horizontal
	velocity instead — same threshold, but it can't be spoofed. Sprinting
	(24) trips it, walking (16) never does.

	Custom rig: ReplicatedStorage/BaldiAssets/Npcs/LP
	Alert sound: AssetConfig.SOUNDS.whistle (else a built-in ping)
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

	local model = NpcFactory.create({
		name = cfg.NAME,
		bodyColor = COLOR_BODY,
		headColor = COLOR_HEAD,
		tagColor = Color3.fromRGB(120, 150, 255),
	}, ctx.map.npcFolder)
	local base = NpcBase.new(ctx, model, ctx.map.npcSpawns.LP,
		(cfg.ROAM_SPEED + cfg.CHASE_SPEED) / 2)
	self.base = base
	self.model = model

	local whistleSoundId = ctx.assets.SOUNDS.whistle
	local whistle = Instance.new("Sound")
	whistle.Name = "Whistle"
	whistle.SoundId = (whistleSoundId ~= "" and whistleSoundId) or "rbxasset://sounds/electronicpingshort.wav"
	whistle.Volume = 0.9
	whistle.PlaybackSpeed = whistleSoundId ~= "" and 1 or 0.6
	whistle.RollOffMaxDistance = 80
	whistle.Parent = base.root

	-- ---------- helpers ----------

	local function targetRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	local function horizontalSpeed(hrp)
		local velocity = hrp.AssemblyLinearVelocity
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	end

	local function isBreakingRule(hrp)
		return hrp ~= nil and horizontalSpeed(hrp) > cfg.SPEED_THRESHOLD
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
				if isBreakingRule(hrp) then
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
		local lastKnown = nil
		pcall(function()
			whistle:Play()
		end)

		base:pursue(
			function()
				if not ctx.manager.isRoundActive() then
					return nil
				end
				local hrp = targetRoot(player)
				if not hrp or not ctx.manager.isTargetable(player) or ctx.detention.isDetained(player) then
					return nil
				end
				-- once agitated, LP keeps coming whether or not you slow down;
				-- only losing line of sight for MEMORY_SECONDS calms him
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
				-- faster while the target is actively breaking the speed rule
				if isBreakingRule(targetRoot(player)) then
					return cfg.RULEBREAK_CHASE_SPEED
				end
				return cfg.CHASE_SPEED
			end
		)
	end

	-- ---------- main brain loop ----------

	task.spawn(function()
		while true do
			if not base:canAct() then
				task.wait(0.2)
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
		local silver = ctx.npcs.Silver
		for _, player in ipairs(ctx.manager.getTargetablePlayers()) do
			if not ctx.detention.hasImmunity(player)
				and not ctx.detention.isDetained(player)
				and not (silver and silver.isGrabbing(player)) then -- Silver's victim is Silver's
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
		name = "MapResolver",
		class = "ModuleScript",
		source = [=====[
--[[
	MapResolver (ModuleScript, ServerScriptService.BaldiGame.MapResolver)

	Reads YOUR hand-built map from Workspace/BaldiMap. If no BaldiMap
	exists, PlaceholderMap generates the stand-in school (same structure),
	so the resolver treats both identically.

	Expected structure (see STUDIO_SETUP.md for the full guide):

	  Workspace/BaldiMap
	  ├── Geometry        your walls/floors/furniture. Must contain a Part
	  │                   named "ExitDoor" and a SpawnLocation named
	  │                   "LobbySpawn" (anywhere inside, nesting is fine).
	  │                   Optional: parts/models named VendingMachine_BSODA
	  │                   and VendingMachine_ZESTY (prompts auto-added).
	  ├── Markers         invisible parts marking positions:
	  │                   RoundSpawn (players start here, facing its front),
	  │                   DetentionSpot, ChatReviveSpawn, LpSpawn,
	  │                   FrostySpawn, SilverSpawn
	  ├── SweepRoutes     optional; one folder per sweeper (Guidelines, Sai)
	  │                   holding ordered parts (1, 2, 3...) it sweeps along
	  ├── Waypoints       parts the NPCs roam between (8+ recommended)
	  ├── NotebookSpawns  parts where notebooks may appear (10+ recommended;
	  │                   parts you tag "NotebookSpawn" elsewhere also count)
	  ├── NickelSpawns    optional parts; starter coins appear here
	  └── ItemSpawns      optional parts named BSODA / ZESTY; one free
	                      pickup of each appears there per round

	Anything missing gets a clear warning and a sensible fallback, so a
	half-built map still runs.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local PlaceholderMap = require(script.Parent.PlaceholderMap)

local MapResolver = {}

local function ensureFolder(root, name)
	local folder = root:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
	end
	return folder
end

-- Marker part -> spawn CFrame (lifted so a humanoid stands on the floor,
-- keeping the marker's orientation so RoundSpawn controls facing).
local function markerCFrame(markersFolder, name, lift, fallbackCFrame)
	local part = markersFolder and markersFolder:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part.CFrame + Vector3.new(0, lift, 0)
	end
	warn(string.format(
		"[BaldiGame] BaldiMap/Markers/%s not found — using the default position. Add an invisible Part with that name to control it.",
		name))
	return fallbackCFrame
end

local function firstBasePart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function MapResolver.resolve(ctx)
	local config = ctx.config

	-- Players never physically collide with NPCs, so a roaming character
	-- can never wedge a player into a doorway.
	pcall(function()
		PhysicsService:RegisterCollisionGroup("BaldiNpc")
		PhysicsService:RegisterCollisionGroup("BaldiPlayer")
		PhysicsService:CollisionGroupSetCollidable("BaldiNpc", "BaldiPlayer", false)
	end)

	local root = workspace:FindFirstChild("BaldiMap")
	if not root then
		print("[BaldiGame] No Workspace/BaldiMap found — generating the placeholder school. "
			.. "Build your own map in a folder named BaldiMap to replace it (see STUDIO_SETUP.md).")
		root = PlaceholderMap.generate(config)
	end

	local geometry = ensureFolder(root, "Geometry")
	local markers = root:FindFirstChild("Markers")
	local waypoints = ensureFolder(root, "Waypoints")
	local notebookSpawns = ensureFolder(root, "NotebookSpawns")
	local nickelSpawnsFolder = root:FindFirstChild("NickelSpawns")
	local itemSpawnsFolder = root:FindFirstChild("ItemSpawns")

	-- runtime containers (created empty; filled during play)
	local notebooks = ensureFolder(root, "Notebooks")
	local pickups = ensureFolder(root, "Pickups")
	local npcFolder = ensureFolder(root, "Npcs")
	local projectiles = ensureFolder(root, "Projectiles")

	-- ---------- notebook spawn nodes ----------
	-- Children of NotebookSpawns are tagged automatically; any part you
	-- tagged "NotebookSpawn" by hand elsewhere already counts.
	for _, node in ipairs(notebookSpawns:GetChildren()) do
		if node:IsA("BasePart") and not CollectionService:HasTag(node, "NotebookSpawn") then
			CollectionService:AddTag(node, "NotebookSpawn")
		end
	end
	local taggedCount = 0
	for _, node in ipairs(CollectionService:GetTagged("NotebookSpawn")) do
		if node:IsDescendantOf(workspace) then
			taggedCount = taggedCount + 1
		end
	end
	if taggedCount < config.NOTEBOOK_SPAWN_COUNT then
		warn(string.format(
			"[BaldiGame] Only %d notebook spawn points found (want %d+). Add more parts to BaldiMap/NotebookSpawns.",
			taggedCount, config.NOTEBOOK_SPAWN_COUNT))
	end

	if #waypoints:GetChildren() == 0 then
		warn("[BaldiGame] BaldiMap/Waypoints is empty — NPCs have nowhere to roam. Add invisible parts around your map.")
	end

	-- ---------- named geometry ----------
	local exitDoor = geometry:FindFirstChild("ExitDoor", true)
	if exitDoor and not exitDoor:IsA("BasePart") then
		exitDoor = firstBasePart(exitDoor)
	end
	if not exitDoor then
		warn("[BaldiGame] No Part named ExitDoor inside BaldiMap/Geometry — players cannot win until you add one.")
	end

	local lobbySpawn = geometry:FindFirstChild("LobbySpawn", true)
	if not (lobbySpawn and lobbySpawn:IsA("SpawnLocation")) then
		lobbySpawn = geometry:FindFirstChildWhichIsA("SpawnLocation", true)
	end
	if not lobbySpawn then
		warn("[BaldiGame] No SpawnLocation named LobbySpawn in BaldiMap/Geometry — players will spawn at the world origin.")
	end

	-- ---------- vending machines ----------
	-- Any part or model named VendingMachine_<ITEMID>; a ProximityPrompt is
	-- attached automatically unless you already put one on it.
	local vendingMachines = {}
	for _, child in ipairs(geometry:GetDescendants()) do
		local itemId = child.Name:match("^VendingMachine_(%u+)$")
		if itemId and (child:IsA("BasePart") or child:IsA("Model")) and config.ITEMS[itemId] then
			local part = firstBasePart(child)
			if part then
				local prompt = child:FindFirstChildOfClass("ProximityPrompt")
					or part:FindFirstChildOfClass("ProximityPrompt")
				if not prompt then
					prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Browse"
					prompt.ObjectText = config.ITEMS[itemId].displayName .. " Machine"
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 5
					prompt.RequiresLineOfSight = false
					prompt.Parent = part
				end
				table.insert(vendingMachines, { part = part, prompt = prompt, itemId = itemId })
			end
		end
	end
	if #vendingMachines == 0 then
		print("[BaldiGame] No vending machines found. Name a part VendingMachine_BSODA or VendingMachine_ZESTY to add one.")
	end

	-- ---------- pickup spawn points ----------
	local nickelSpawns = {}
	if nickelSpawnsFolder then
		for _, node in ipairs(nickelSpawnsFolder:GetChildren()) do
			if node:IsA("BasePart") then
				table.insert(nickelSpawns, node.Position)
			end
		end
	end

	local itemSpawns = {}
	if itemSpawnsFolder then
		for _, node in ipairs(itemSpawnsFolder:GetChildren()) do
			if node:IsA("BasePart") and config.ITEMS[node.Name] then
				itemSpawns[node.Name] = node.Position
			end
		end
	end

	-- ---------- sweep routes ----------
	-- SweepRoutes/<SweeperName> is a folder of parts walked in name order
	-- (1, 2, 3...), so a route can turn corners.
	local sweepRoutes = {}
	local routesFolder = root:FindFirstChild("SweepRoutes")
	if routesFolder then
		for _, routeFolder in ipairs(routesFolder:GetChildren()) do
			local parts = {}
			for _, child in ipairs(routeFolder:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
			table.sort(parts, function(a, b)
				return a.Name < b.Name
			end)
			if #parts >= 2 then
				local points = {}
				for _, part in ipairs(parts) do
					table.insert(points, part.Position)
				end
				sweepRoutes[routeFolder.Name] = points
			else
				warn(string.format(
					"[BaldiGame] BaldiMap/SweepRoutes/%s needs at least 2 parts to be a route.",
					routeFolder.Name))
			end
		end
	end

	ctx.map = {
		root = root,
		geometry = geometry,
		waypointsFolder = waypoints,
		spawnNodesFolder = notebookSpawns,
		notebooksFolder = notebooks,
		pickupsFolder = pickups,
		npcFolder = npcFolder,
		projectilesFolder = projectiles,
		exitDoor = exitDoor,
		lobbySpawn = lobbySpawn,
		roundSpawnCFrame = markerCFrame(markers, "RoundSpawn", 2.5,
			CFrame.lookAt(Vector3.new(0, 3.5, -58), Vector3.new(0, 3.5, -30))),
		detentionCFrame = markerCFrame(markers, "DetentionSpot", 2.5,
			CFrame.lookAt(Vector3.new(0, 3.5, -24), Vector3.new(0, 3.5, -36))),
		npcSpawns = {
			CHATREVIVE = markerCFrame(markers, "ChatReviveSpawn", 2, CFrame.new(90, 3, 0)),
			LP = markerCFrame(markers, "LpSpawn", 2, CFrame.new(-75, 3, 0)),
			FROSTY = markerCFrame(markers, "FrostySpawn", 2, CFrame.new(0, 3, 42)),
			SILVER = markerCFrame(markers, "SilverSpawn", 2, CFrame.new(30, 3, -60)),
		},
		vendingMachines = vendingMachines,
		nickelSpawns = nickelSpawns,
		itemSpawns = itemSpawns,
		sweepRoutes = sweepRoutes,
	}
	return ctx.map
end

return MapResolver
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

	Random notebook generation:
	  1. Your map provides spawn points (BaldiMap/NotebookSpawns children,
	     plus anything you tagged "NotebookSpawn" yourself).
	  2. CollectionService:GetTagged("NotebookSpawn") collects them.
	  3. Fisher-Yates shuffle, take the first NOTEBOOK_SPAWN_COUNT (10).
	  4. Clone the notebook model at each chosen node — YOUR model from
	     ReplicatedStorage/BaldiAssets/Items/Notebook if it exists, else a
	     placeholder built in code.
	  5. ProximityPrompt collect -> destroy model, bump the server counter,
	     fire NotebookCollected to all clients.

	Also runs a gentle spin/bob animation so notebooks read as pickups.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetResolver = require(script.Parent.AssetResolver)

local NotebookSpawner = {}

local function buildPlaceholderTemplate()
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
	pages.CFrame = cover.CFrame * CFrame.new(0, 0.23, 0)
	pages.Parent = model

	model.PrimaryPart = cover
	model.Parent = folder
	return model
end

function NotebookSpawner.init(ctx)
	local self = {}
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

		-- resolved fresh each round so you can drop your model in and just
		-- press Retry to see it
		local template = AssetResolver.itemTemplate("Notebook") or buildPlaceholderTemplate()

		-- 2. collect every tagged node
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
			local notebook = AssetResolver.preparePropClone(template)
			local baseCFrame = CFrame.new(node.Position + Vector3.new(0, 0.8, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			notebook:PivotTo(baseCFrame)

			-- 5. collect interaction
			local promptParent = notebook:IsA("BasePart") and notebook
				or notebook.PrimaryPart
				or notebook:FindFirstChildWhichIsA("BasePart", true)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Collect"
			prompt.ObjectText = "Notebook"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = ctx.config.NOTEBOOK_PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptParent

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
		name = "NpcAnimator",
		class = "ModuleScript",
		source = [=====[
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

	Produces the character models the AIs drive.

	If you made a rig (ReplicatedStorage/BaldiAssets/Npcs/<Name>, any rig
	type, must contain a Humanoid + HumanoidRootPart, optional Animations
	folder) it is cloned and prepared. Otherwise a simple placeholder rig
	is built in code so the game runs before your characters exist.
]]

local AssetResolver = require(script.Parent.AssetResolver)

local NpcFactory = {}

-- ===================== placeholder rig =====================

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

local function buildPlaceholderRig(spec)
	local model = Instance.new("Model")
	model.Name = spec.name
	model:SetAttribute("BaldiPlaceholderRig", true)

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
	humanoid.Parent = model

	if spec.glowColor then
		local glow = Instance.new("PointLight")
		glow.Color = spec.glowColor
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Parent = torso
	end

	model.PrimaryPart = hrp
	return model
end

-- ===================== shared preparation =====================

local function addNameTag(model, spec)
	-- only when the rig doesn't already carry its own name display
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			return
		end
	end
	local target = model:FindFirstChild("Head") or model.PrimaryPart
	if not target then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 130, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Parent = target
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.Cartoon
	tag.TextScaled = true
	tag.TextColor3 = spec.tagColor or Color3.new(1, 1, 1)
	tag.TextStrokeTransparency = 0.2
	tag.Text = spec.name
	tag.Parent = billboard
end

-- spec = { name, bodyColor, headColor, transparency?, glowColor?, tagColor? }
-- (the color fields style the placeholder only; your rig is used as-is)
function NpcFactory.create(spec, parent)
	local template = AssetResolver.npcTemplate(spec.name)
	local model
	if template then
		model = template:Clone()
		model.Name = spec.name
		for _, descendant in ipairs(model:GetDescendants()) do
			-- never run scripts that came bundled with an imported asset
			if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = false
			end
		end
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	else
		model = buildPlaceholderRig(spec)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = 0
	-- a usable jump lets pathfinding clear small thresholds/lips and lets the
	-- NPC hop free when it wedges on geometry (see NpcBase:unstickNudge)
	pcall(function()
		humanoid.UseJumpPower = true
	end)
	humanoid.JumpPower = 35
	pcall(function()
		humanoid.JumpHeight = 5
	end)
	humanoid.MaxHealth = 100000
	humanoid.Health = humanoid.MaxHealth
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayName = spec.name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	addNameTag(model, spec)

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
		name = "PlaceholderMap",
		class = "ModuleScript",
		source = [=====[
--[[
	PlaceholderMap (ModuleScript, ServerScriptService.BaldiGame.PlaceholderMap)

	Generates a complete stand-in school so the game is playable before
	your real map exists. It produces EXACTLY the folder contract that
	MapResolver reads — build your own Workspace/BaldiMap with the same
	structure and this module is never used:

	  BaldiMap
	  ├── Geometry        (walls, floors, furniture, ExitDoor, LobbySpawn,
	  │                    VendingMachine_<ITEMID> machines)
	  ├── Markers         (RoundSpawn, DetentionSpot, ChatReviveSpawn,
	  │                    LpSpawn, FrostySpawn, SilverSpawn — invisible parts)
	  ├── SweepRoutes     (Guidelines / Sai folders of ordered route parts)
	  ├── Waypoints       (invisible parts the NPCs roam between)
	  ├── NotebookSpawns  (invisible parts; 10 are picked per round)
	  ├── NickelSpawns    (invisible parts; starter coins)
	  └── ItemSpawns      (invisible parts named after item ids)

	Layout (top-down, studs). Floor top sits at Y = 0.
	  School rectangle: X -96..96, Z -72..72
	  North hall  Z -48..-36 / South hall Z 36..48 (between X -54..54)
	  West hall   X -54..-42 / East hall  X 42..54 (between Z -48..48)
	  Classrooms A/B along the north band, C/D along the south band
	  Gym west wing, Library east wing, detention room in the central block
	  Entrance corridor X -6..6, Z -72..-48 with the EXIT door at Z -72
]]

local Lighting = game:GetService("Lighting")

local PlaceholderMap = {}

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

local function invisibleNode(name, cframe, parent)
	local part = basePart({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		CFrame = cframe,
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
	label.Font = Enum.Font.Cartoon
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

-- Plain machine body; MapResolver attaches the ProximityPrompt (same path
-- it uses for hand-built machines).
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
	machine.Parent = parent
end

-- ===================== main build =====================

function PlaceholderMap.generate(config)
	local root = Instance.new("Folder")
	root.Name = "BaldiMap"

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = root
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = root
	local sweepRoutes = Instance.new("Folder")
	sweepRoutes.Name = "SweepRoutes"
	sweepRoutes.Parent = root
	local waypoints = Instance.new("Folder")
	waypoints.Name = "Waypoints"
	waypoints.Parent = root
	local spawnNodes = Instance.new("Folder")
	spawnNodes.Name = "NotebookSpawns"
	spawnNodes.Parent = root
	local nickelSpawns = Instance.new("Folder")
	nickelSpawns.Name = "NickelSpawns"
	nickelSpawns.Parent = root
	local itemSpawns = Instance.new("Folder")
	itemSpawns.Name = "ItemSpawns"
	itemSpawns.Parent = root

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
	buildVendingMachine(geometry, -16, 38.2, config.ITEMS.BSODA)
	buildVendingMachine(geometry, 16, 38.2, config.ITEMS.ZESTY)
	buildVendingMachine(geometry, -32, 38.2, config.ITEMS.SCISSORS)
	buildVendingMachine(geometry, 32, 38.2, config.ITEMS.ALARM)

	-- ---------- markers (the contract MapResolver reads) ----------
	invisibleNode("RoundSpawn", CFrame.lookAt(Vector3.new(0, 1, -58), Vector3.new(0, 1, -30)), markers)
	invisibleNode("DetentionSpot", CFrame.lookAt(Vector3.new(0, 1, -24), Vector3.new(0, 1, -36)), markers)
	invisibleNode("ChatReviveSpawn", CFrame.new(90, 1, 0), markers) -- library east end
	invisibleNode("LpSpawn", CFrame.new(-75, 1, 0), markers) -- gym center
	invisibleNode("FrostySpawn", CFrame.new(0, 1, 42), markers) -- south hall
	invisibleNode("SilverSpawn", CFrame.new(30, 1, -60), markers) -- classroom B

	-- ---------- sweep routes (Guidelines: north hall, Sai: south hall) ----------
	local guidelinesRoute = Instance.new("Folder")
	guidelinesRoute.Name = "Guidelines"
	guidelinesRoute.Parent = sweepRoutes
	invisibleNode("1", CFrame.new(-48, 1, -42), guidelinesRoute)
	invisibleNode("2", CFrame.new(48, 1, -42), guidelinesRoute)

	local saiRoute = Instance.new("Folder")
	saiRoute.Name = "Sai"
	saiRoute.Parent = sweepRoutes
	invisibleNode("1", CFrame.new(-48, 1, 42), saiRoute)
	invisibleNode("2", CFrame.new(48, 1, 42), saiRoute)

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
		invisibleNode("Waypoint" .. index, CFrame.new(spot[1], 1, spot[2]), waypoints)
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
		invisibleNode("NotebookSpawn" .. index, CFrame.new(spot[1], 1.5, spot[2]), spawnNodes)
	end

	-- ---------- nickel / item spawn points ----------
	local nickelSpots = { { -30, -42 }, { 30, 42 }, { 48, 0 }, { -48, 20 } }
	for index, spot in ipairs(nickelSpots) do
		invisibleNode("NickelSpawn" .. index, CFrame.new(spot[1], 1.5, spot[2]), nickelSpawns)
	end
	invisibleNode("BSODA", CFrame.new(-22, 1.5, -60), itemSpawns) -- classroom A
	invisibleNode("ZESTY", CFrame.new(18, 1.5, 60), itemSpawns) -- classroom D
	invisibleNode("SCISSORS", CFrame.new(-75, 1.5, -16), itemSpawns) -- gym
	invisibleNode("ALARM", CFrame.new(66, 1.5, -16), itemSpawns) -- library

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
	return root
end

return PlaceholderMap
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
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "SilverAI",
		class = "ModuleScript",
		source = [=====[
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
]=====],
	},
	{
		root = "ServerScriptService",
		folders = { "BaldiGame" },
		name = "SweeperAI",
		class = "ModuleScript",
		source = [=====[
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

	Your art: AssetConfig.IMAGES.DETENTION_BACKGROUND fills the screen
	(use a semi-transparent PNG so the player still sees the room).
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

	UiKit.backdrop(gui, ctx.assets.IMAGES.DETENTION_BACKGROUND, Color3.fromRGB(20, 8, 8), 0.45)

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.9, 0, 0, 70),
		Text = "DETENTION!",
		TextColor3 = theme.red,
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	local quoteLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 28),
		Text = '"No running in the halls."',
		TextColor3 = theme.textDim,
		Parent = gui,
	})

	local countdownLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(220, 84),
		Text = "15",
		TextStrokeTransparency = 0,
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
	  - shows an icy screen-edge vignette until the chill expires

	Your art: AssetConfig.IMAGES.FROST_OVERLAY — a full-screen transparent
	PNG with frost around the edges. Without it, four gradient strips fake
	the same effect.
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

	if UiKit.hasImage(ctx.assets.IMAGES.FROST_OVERLAY) then
		UiKit.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = ctx.assets.IMAGES.FROST_OVERLAY,
			ScaleType = Enum.ScaleType.Stretch,
			Parent = gui,
		})
	else
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
	end

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(320, 24),
		Text = "Frosty chilled you! You feel slow...",
		TextColor3 = theme.ice,
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

	The persistent in-game overlay, laid out like the original game:
	  - "Notebooks: 0/10" in the TOP LEFT, plain comic text drawn straight
	    over the 3D view, with a little notebook icon
	  - item slots in the TOP RIGHT as white squares, nickel count under
	  - stamina bar bottom center
	  - center banner for phase changes ("GET TO THE EXIT!")
	  - mobile Sprint / Use / Swap buttons when touch is enabled

	Your art (AssetConfig.IMAGES): NOTEBOOK_ICON, ITEM_SLOT, ITEMS.<id>,
	NICKEL_ICON, STAMINA_BACK, STAMINA_FILL. Everything falls back to
	plain shapes when an id is "".

	Subscribes to its own data remotes: NotebookCollected, NickelChanged,
	PickupFailed, PhaseChanged. InventoryChanged is consumed by
	ItemUseClient, which calls setSlots.
]]

local UiKit

local HudController = {}

function HudController.init(ctx)
	UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local images = ctx.assets.IMAGES
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

	-- ===================== notebook counter (top left) =====================

	local notebookFrame = UiKit.new("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(290, 44),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local notebookScale = UiKit.new("UIScale", { Parent = notebookFrame })

	local notebookIcon = UiKit.panel({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(28, 36),
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		Parent = notebookFrame,
	}, images.NOTEBOOK_ICON)
	if notebookIcon:IsA("Frame") then
		UiKit.corner(4).Parent = notebookIcon
	end

	local notebookLabel = UiKit.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = "Notebooks: 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notebookFrame,
	})

	local objectiveLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(420, 22),
		Text = "Collect 10 notebooks!",
		TextColor3 = theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = gui,
	})

	-- ===================== item slots (top right) =====================

	local slotsFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(198, 118),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local function buildSlot(xOffset, hintText, isActive)
		local slot = UiKit.panel({
			Position = UDim2.fromOffset(xOffset, 0),
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = theme.white,
			Parent = slotsFrame,
		}, images.ITEM_SLOT)
		if slot:IsA("Frame") then
			UiKit.corner(8).Parent = slot
			UiKit.stroke(isActive and theme.accent or Color3.fromRGB(40, 40, 40), isActive and 4 or 2).Parent = slot
		elseif isActive then
			UiKit.stroke(theme.accent, 4).Parent = slot
		end

		-- your item picture; hidden when the slot is empty
		local itemImage = UiKit.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(72, 72),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			Parent = slot,
		})
		-- fallback colored block + item name when no item picture exists
		local fallbackIcon = UiKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = theme.panelLight,
			Visible = false,
			Parent = slot,
			UiKit.corner(10),
		})
		local fallbackText = UiKit.label({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			Parent = fallbackIcon,
		})
		local emptyText = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 20),
			Text = "empty",
			TextColor3 = Color3.fromRGB(130, 130, 130),
			TextStrokeTransparency = 1,
			Parent = slot,
		})
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(92, 18),
			Text = hintText,
			Parent = slot,
		})
		return {
			frame = slot,
			itemImage = itemImage,
			fallbackIcon = fallbackIcon,
			fallbackText = fallbackText,
			emptyText = emptyText,
		}
	end

	local slot1 = buildSlot(0, "[E] Use", true)
	local slot2 = buildSlot(106, "[Q] Swap", false)

	-- nickel counter, under the slots
	local nickelFrame = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 134),
		Size = UDim2.fromOffset(198, 32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local nickelIcon = UiKit.panel({
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(255, 210, 70),
		Parent = nickelFrame,
	}, images.NICKEL_ICON)
	if nickelIcon:IsA("Frame") then
		UiKit.corner(14).Parent = nickelIcon
		UiKit.stroke(Color3.fromRGB(180, 140, 30), 2).Parent = nickelIcon
	end
	local nickelLabel = UiKit.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = "x 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nickelFrame,
	})

	local fullFlash = UiKit.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 170),
		Size = UDim2.fromOffset(198, 24),
		Text = "Inventory full",
		TextColor3 = theme.red,
		TextTransparency = 1,
		Parent = gui,
	})

	-- ===================== stamina bar (bottom center) =====================

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(120, 18),
		Text = "STAMINA",
		Parent = gui,
	})
	local staminaBack = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, images.STAMINA_BACK)
	if staminaBack:IsA("Frame") then
		UiKit.corner(8).Parent = staminaBack
		UiKit.stroke(Color3.fromRGB(0, 0, 0), 1, 0.5).Parent = staminaBack
	end
	local staminaFillArea = UiKit.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = staminaBack,
	})
	-- the fill is your STAMINA_FILL image (tinted by code) or a plain bar
	local fillIsImage = UiKit.hasImage(images.STAMINA_FILL)
	local staminaFill
	if fillIsImage then
		staminaFill = UiKit.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = images.STAMINA_FILL,
			ScaleType = Enum.ScaleType.Stretch,
			ImageColor3 = theme.green,
			Parent = staminaFillArea,
		})
	else
		staminaFill = UiKit.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme.green,
			Parent = staminaFillArea,
			UiKit.corner(6),
		})
	end
	local fillColorProp = fillIsImage and "ImageColor3" or "BackgroundColor3"
	local fillTransparencyProp = fillIsImage and "ImageTransparency" or "BackgroundTransparency"

	local coldTag = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(180, 18),
		Text = "COLD! Slowed...",
		TextColor3 = theme.ice,
		Visible = false,
		Parent = gui,
	})

	-- ===================== center banner =====================

	local banner = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 54),
		Text = "",
		TextColor3 = theme.accent,
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
			UiKit.tween(staminaFill, 0.2, { [fillColorProp] = color })
		end
	end

	function self.flashStaminaFull()
		staminaFill[fillColorProp] = theme.green
		staminaFill[fillTransparencyProp] = 0.6
		UiKit.tween(staminaFill, 0.4, { [fillTransparencyProp] = 0 })
	end

	local function renderSlot(slot, itemId)
		if itemId then
			local def = ctx.config.ITEMS[itemId]
			local picture = images.ITEMS[itemId]
			slot.emptyText.Visible = false
			if UiKit.hasImage(picture) then
				slot.itemImage.Image = picture
				slot.itemImage.Visible = true
				slot.fallbackIcon.Visible = false
			else
				slot.itemImage.Visible = false
				slot.fallbackIcon.Visible = true
				slot.fallbackIcon.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
				slot.fallbackText.Text = def.shortLabel
			end
		else
			slot.itemImage.Visible = false
			slot.fallbackIcon.Visible = false
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
			self.setObjective("Escape through the EXIT door!")
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
		local minigame = ctx.controllers.SilverMinigame
		if minigame and minigame.active then
			return -- this E press is a timing hit in Silver's grab minigame
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
local assets = require(shared:WaitForChild("AssetConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild(config.REMOTES_FOLDER)
local remotes = {}
for _, name in ipairs(config.REMOTE_NAMES) do
	remotes[name] = remotesFolder:WaitForChild(name)
end

local ctx = {
	player = Players.LocalPlayer,
	config = config,
	assets = assets, -- your image/sound ids from AssetConfig
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
	"SilverMinigame",
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

	Your art (AssetConfig.IMAGES): MENU_BACKGROUND, COUNTDOWN_BACKGROUND,
	WIN_BACKGROUND, LOSE_BACKGROUND fill each screen edge to edge (like the
	original game's title art); PLAY_BUTTON replaces the PLAY button; PANEL
	backs the HOW TO PLAY box.

	Also orchestrates the round lifecycle on the client: shows/hides the
	HUD, enables/disables the stamina controller, and locks the camera to
	first person during play.
]]

local MenuController = {}

function MenuController.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local images = ctx.assets.IMAGES
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

	-- imageKey: AssetConfig.IMAGES entry used as the full-screen backdrop
	local function makeScreen(name, backgroundColor, imageKey)
		local screen = UiKit.new("CanvasGroup", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0,
			Visible = false,
			Parent = gui,
		})
		if imageKey and UiKit.hasImage(images[imageKey]) then
			UiKit.backdrop(screen, images[imageKey])
		end
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

	local mainMenu = makeScreen("main", theme.chalkboard, "MENU_BACKGROUND")

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(0.9, 0, 0, 84),
		Text = ctx.config.GAME_TITLE,
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = mainMenu,
	})
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.245),
		Size = UDim2.new(0.8, 0, 0, 24),
		Text = ctx.config.GAME_SUBTITLE,
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local playButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(260, 64),
		Text = "PLAY",
		Parent = mainMenu,
	}, images.PLAY_BUTTON)

	local bestTimeLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, 22),
		Text = "Best time: --",
		TextColor3 = theme.textDim,
		Parent = mainMenu,
	})

	local controlsPanel = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.35,
		Parent = mainMenu,
	}, images.PANEL)
	if controlsPanel:IsA("Frame") then
		UiKit.corner(12).Parent = controlsPanel
	end
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
			"Collect all the notebooks, then escape through the EXIT.",
			"WASD — move   |   Shift — sprint (drains stamina)",
			"E — use item   |   Q — swap item slots",
			"ChatRevive chases on sight. Don't let it touch you.",
			"LP detains anyone he SEES moving too fast. Walk near him.",
			"Frosty is harmless... but his chill slows you down.",
		}, "\n"),
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = theme.textPrimary,
		Parent = controlsPanel,
	})

	-- ===================== countdown screen =====================

	local countdownScreen = makeScreen("countdown", theme.chalkboard, "COUNTDOWN_BACKGROUND")
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.new(0.9, 0, 0, 48),
		Text = "Get ready...",
		Parent = countdownScreen,
	})
	local countdownNumber = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(200, 120),
		Text = "3",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = countdownScreen,
	})

	-- ===================== end screens =====================

	local function makeEndScreen(name, accent, titleText, imageKey)
		local screen = makeScreen(name, theme.chalkboard, imageKey)
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
			TextStrokeTransparency = 0,
			Parent = screen,
		})
		local detailLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0.8, 0, 0, 30),
			Text = "",
			Parent = screen,
		})
		local subLabel = UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.new(0.8, 0, 0, 22),
			Text = "",
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

	local winScreen = makeEndScreen("win", theme.green, "ESCAPED!", "WIN_BACKGROUND")
	local loseScreen = makeEndScreen("lose", theme.red, "CAUGHT!", "LOSE_BACKGROUND")

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

	ctx.remotes.GameStarted.OnClientEvent:Connect(function(notebooksTotal)
		hud.resetForRound(notebooksTotal or ctx.config.NOTEBOOK_SPAWN_COUNT)
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
		name = "SilverMinigame",
		class = "ModuleScript",
		source = [=====[
--[[
	SilverMinigame (ModuleScript, StarterPlayerScripts.BaldiClient.SilverMinigame)

	Shown while Silver has you grabbed. A cube slides back and forth along
	a bar; click HIT (or press E, or tap the bar) exactly while the cube is
	inside the center zone. Land GRAB_HITS perfect hits to wriggle free.
	Each hit speeds the cube up. If you're carrying Safety Scissors, a CUT
	FREE button escapes instantly (and leaves Silver snipped).

	The server validates hits (minimum gap between them) and releases you;
	this UI closes on the SilverReleased remote.

	Your art: AssetConfig.IMAGES.SILVER_OVERLAY backs the screen.
	Tuning lives in GameConfig.NPC.SILVER (window, period, speedup).
]]

local RunService = game:GetService("RunService")

local SilverMinigame = {}

function SilverMinigame.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local cfg = ctx.config.NPC.SILVER
	local sounds = ctx.controllers.SoundController
	local stamina = ctx.controllers.StaminaController
	local self = { active = false }

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiSilverGrab",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	UiKit.backdrop(gui, ctx.assets.IMAGES.SILVER_OVERLAY, Color3.fromRGB(18, 18, 26), 0.4)

	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.new(0.9, 0, 0, 60),
		Text = "SILVER GRABBED YOU!",
		TextColor3 = Color3.fromRGB(220, 225, 235),
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.31),
		Size = UDim2.new(0.9, 0, 0, 24),
		Text = "Hit the cube in the green zone to wriggle free!",
		TextColor3 = theme.textDim,
		Parent = gui,
	})

	local progressLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(200, 40),
		Text = "0 / 5",
		TextColor3 = theme.accent,
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	-- ---------- the timing bar ----------

	local barBack = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.55, 0, 0, 34),
		BackgroundColor3 = theme.panel,
		Parent = gui,
		UiKit.corner(10),
	})
	UiKit.stroke(Color3.fromRGB(0, 0, 0), 2, 0.4).Parent = barBack

	-- the green target zone, centered, width = the timing window both ways
	local zone = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(cfg.GRAB_HIT_WINDOW * 2, 0, 1, -6),
		BackgroundColor3 = theme.green,
		BackgroundTransparency = 0.35,
		Parent = barBack,
		UiKit.corner(8),
	})

	local cube = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.white,
		ZIndex = 2,
		Parent = barBack,
		UiKit.corner(6),
	})
	UiKit.stroke(Color3.fromRGB(0, 0, 0), 2).Parent = cube

	local hitButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(220, 64),
		Text = "HIT!  [E]",
		Parent = gui,
	})

	local scissorsButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromOffset(260, 46),
		Text = "CUT FREE (use Scissors)",
		BackgroundColor3 = theme.panelLight,
		TextColor3 = theme.textPrimary,
		Visible = false,
		Parent = gui,
	})

	-- ---------- behaviour ----------

	local hits = 0
	local hitsRequired = cfg.GRAB_HITS
	local period = cfg.GRAB_CUBE_PERIOD
	local clock = 0
	local alpha = 0.5

	local function hasScissors()
		local items = ctx.controllers.ItemUseClient
		return items ~= nil and (items.slots[1] == "SCISSORS" or items.slots[2] == "SCISSORS")
	end

	RunService.RenderStepped:Connect(function(dt)
		if not self.active then
			return
		end
		clock = clock + dt
		alpha = 0.5 + 0.5 * math.sin(clock * math.pi * 2 / period)
		cube.Position = UDim2.new(alpha, 0, 0.5, 0)
	end)

	local function attemptHit()
		if not self.active then
			return
		end
		if math.abs(alpha - 0.5) <= cfg.GRAB_HIT_WINDOW then
			hits = hits + 1
			period = period / cfg.GRAB_SPEEDUP -- faster every time
			progressLabel.Text = hits .. " / " .. hitsRequired
			ctx.remotes.SilverHit:FireServer()
			sounds.play("click", 1 + hits * 0.12)
			zone.BackgroundTransparency = 0
			UiKit.tween(zone, 0.25, { BackgroundTransparency = 0.35 })
			if hits >= hitsRequired then
				progressLabel.Text = "FREE!"
				progressLabel.TextColor3 = theme.green
			end
		else
			sounds.play("error")
			UiKit.shake(barBack, 8)
		end
	end

	hitButton.Activated:Connect(attemptHit)
	barBack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			attemptHit()
		end
	end)
	-- E doubles as the hit key (ItemUseClient yields to us while active)
	ctx.controllers.InputHandler.onUse(function()
		if self.active then
			attemptHit()
		end
	end)

	scissorsButton.Activated:Connect(function()
		if self.active and hasScissors() then
			ctx.remotes.SilverEscape:FireServer()
		end
	end)

	-- ---------- open / close ----------

	ctx.remotes.SilverGrab.OnClientEvent:Connect(function(required)
		hits = 0
		hitsRequired = required or cfg.GRAB_HITS
		period = cfg.GRAB_CUBE_PERIOD
		clock = 0
		progressLabel.Text = "0 / " .. hitsRequired
		progressLabel.TextColor3 = theme.accent
		scissorsButton.Visible = hasScissors()
		self.active = true
		gui.Enabled = true
		stamina.setSprintLocked(true)
		sounds.play("grab")
	end)

	local function close()
		if not self.active then
			return
		end
		self.active = false
		gui.Enabled = false
		stamina.setSprintLocked(false)
	end

	ctx.remotes.SilverReleased.OnClientEvent:Connect(close)
	ctx.remotes.RoundEnded.OnClientEvent:Connect(close)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(close)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(close)

	-- keep the scissors button honest if inventory changes mid-grab
	ctx.remotes.InventoryChanged.OnClientEvent:Connect(function()
		if self.active then
			scissorsButton.Visible = hasScissors()
		end
	end)

	self.close = close
	return self
end

return SilverMinigame
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

	UI / feedback sounds. Each named sound checks AssetConfig.SOUNDS first —
	paste your own sound id there and it replaces the built-in placeholder
	(placeholders are rbxasset:// files that ship with the engine, so
	nothing depends on marketplace assets). Every play is wrapped in
	pcall — a missing sound never breaks gameplay.
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
	win = { id = "", speed = 1.0, volume = 0.8 }, -- placeholder is the jingle below
	grab = { id = "rbxasset://sounds/snap.mp3", speed = 0.7, volume = 0.9 }, -- Silver caught you
	swept = { id = "rbxasset://sounds/swoosh.mp3", speed = 0.8, volume = 0.8 }, -- a sweeper hit you
}

function SoundController.init(ctx)
	local self = {}
	local overrides = ctx.assets.SOUNDS

	function self.play(name, pitchOverride)
		local entry = LIBRARY[name]
		if not entry then
			return
		end
		local override = overrides[name]
		local custom = override and override ~= ""
		local id = custom and override or entry.id
		if id == "" then
			return
		end
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = entry.volume
			-- your sound plays at its natural pitch unless a pitch is forced
			sound.PlaybackSpeed = pitchOverride or (custom and 1 or entry.speed)
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 6)
		end)
	end

	-- win fanfare: your SOUNDS.win asset, or a little rising arpeggio
	function self.winJingle()
		if overrides.win and overrides.win ~= "" then
			self.play("win")
			return
		end
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
		sprintLocked = false, -- detention / Silver's grab
		debuffMultiplier = 1,
		debuffUntil = 0,
	}

	-- a sweeper carrying us: velocity applied here because the client owns
	-- its own character's physics (a server write would stutter)
	local pushVelocity = nil
	local pushUntil = 0

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

		-- being swept: override horizontal velocity along the push
		if pushVelocity and os.clock() < pushUntil then
			local character = ctx.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and not hrp.Anchored then
				hrp.AssemblyLinearVelocity = Vector3.new(
					pushVelocity.X,
					hrp.AssemblyLinearVelocity.Y,
					pushVelocity.Z
				)
			end
		end

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

	ctx.remotes.SweptPush.OnClientEvent:Connect(function(direction, speed, duration)
		if typeof(direction) ~= "Vector3" or typeof(speed) ~= "number" then
			return
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.01 then
			return
		end
		local wasPushed = pushVelocity ~= nil and os.clock() < pushUntil
		pushVelocity = flat.Unit * speed
		pushUntil = os.clock() + (typeof(duration) == "number" and duration or 0.5)
		if not wasPushed then
			ctx.controllers.SoundController.play("swept")
		end
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

	UI construction helpers + the shared theme. Every ScreenGui in the game
	is built in code through these.

	Image support: most helpers take an optional image id (from
	AssetConfig.IMAGES). With an id they build ImageLabels/ImageButtons so
	your art becomes the background; with "" they fall back to plain
	colored frames — so the UI works before any art exists.

	The default font is Cartoon (Comic Neue Angular), the closest built-in
	match to the original game's Comic Sans look.
]]

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.font = Enum.Font.Cartoon

UiKit.theme = {
	chalkboard = Color3.fromRGB(24, 40, 33),
	panel = Color3.fromRGB(18, 22, 20),
	panelLight = Color3.fromRGB(40, 48, 44),
	white = Color3.fromRGB(245, 245, 240),
	textPrimary = Color3.fromRGB(245, 245, 240),
	textDim = Color3.fromRGB(190, 195, 190),
	textDark = Color3.fromRGB(25, 25, 25),
	accent = Color3.fromRGB(255, 213, 70), -- school-bus yellow
	green = Color3.fromRGB(80, 200, 120),
	yellow = Color3.fromRGB(240, 200, 60),
	red = Color3.fromRGB(225, 70, 55),
	blue = Color3.fromRGB(90, 160, 255),
	ice = Color3.fromRGB(170, 225, 255),
}

function UiKit.hasImage(imageId)
	return type(imageId) == "string" and imageId ~= ""
end

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

-- Text label: Cartoon font, white with a black outline by default — the
-- original game draws its HUD text straight over the 3D view like this.
function UiKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UiKit.font,
		TextColor3 = UiKit.theme.textPrimary,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.25,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return UiKit.new("TextLabel", defaults)
end

-- Container that is your image when you have one, a colored frame when
-- you don't. Children parent into it either way.
function UiKit.panel(props, imageId)
	if UiKit.hasImage(imageId) then
		local imageProps = {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Stretch,
		}
		for key, value in pairs(props) do
			if key ~= "BackgroundColor3" and key ~= "BackgroundTransparency" then
				imageProps[key] = value
			end
		end
		return UiKit.new("ImageLabel", imageProps)
	end
	return UiKit.new("Frame", props)
end

-- Button: an ImageButton showing your art (any Text prop is dropped —
-- bake the text into the image), or a yellow TextButton fallback.
function UiKit.button(props, imageId)
	if UiKit.hasImage(imageId) then
		local imageProps = {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = true,
		}
		for key, value in pairs(props) do
			if key ~= "Text" and key ~= "TextColor3" and key ~= "Font"
				and key ~= "BackgroundColor3" and key ~= "TextScaled" then
				imageProps[key] = value
			end
		end
		return UiKit.new("ImageButton", imageProps)
	end
	local defaults = {
		Font = UiKit.font,
		TextColor3 = UiKit.theme.textDark,
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

-- Full-bleed background for a screen/overlay: your image, or a solid color.
function UiKit.backdrop(parent, imageId, fallbackColor, fallbackTransparency)
	if UiKit.hasImage(imageId) then
		return UiKit.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 0,
			Parent = parent,
		})
	end
	return UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fallbackColor,
		BackgroundTransparency = fallbackTransparency or 0,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = parent,
	})
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
	item name, picture, cost, your current Nickel count, and a Buy button.
	Closes on buy, on the X, or automatically when you walk away.

	Your art: AssetConfig.IMAGES.VENDING_PANEL backs the popup;
	IMAGES.ITEMS.<id> replaces the colored item block.
]]

local RunService = game:GetService("RunService")

local VendingMachineUI = {}

function VendingMachineUI.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local images = ctx.assets.IMAGES
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

	local panel = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(340, 250),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, images.VENDING_PANEL)
	if panel:IsA("Frame") then
		UiKit.corner(14).Parent = panel
		UiKit.stroke(theme.accent, 2).Parent = panel
	end

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

	-- item picture: your image, or a colored block with the short label
	local iconFrame = UiKit.new("Frame", {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = theme.blue,
		Parent = panel,
		UiKit.corner(10),
	})
	local iconImage = UiKit.new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		Parent = iconFrame,
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
		TextWrapped = true,
		TextScaled = false,
		TextSize = 15,
		TextStrokeTransparency = 1,
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
		TextStrokeTransparency = 1,
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
		if buyButton:IsA("TextButton") then
			buyButton.BackgroundColor3 = canAfford and theme.accent or Color3.fromRGB(95, 95, 90)
		end
	end

	ctx.remotes.OpenVending.OnClientEvent:Connect(function(data)
		local def = ctx.config.ITEMS[data.itemId]
		if not def then
			return
		end
		current = data
		titleLabel.Text = def.displayName
		local picture = images.ITEMS[data.itemId]
		if UiKit.hasImage(picture) then
			iconImage.Image = picture
			iconImage.Visible = true
			iconText.Visible = false
			iconFrame.BackgroundTransparency = 1
		else
			iconImage.Visible = false
			iconText.Visible = true
			iconFrame.BackgroundTransparency = 0
			iconFrame.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
			iconText.Text = def.shortLabel
		end
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
