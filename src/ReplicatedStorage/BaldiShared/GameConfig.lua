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

-- Menu camera: instead of a flat image, the main menu shows a slow orbit
-- of the school (the 3D scene shows through the transparent menu unless you
-- set IMAGES.MENU_BACKGROUND). Tune FOCUS to whatever you want it circling
-- — the map center, the exit door, a character statue, etc.
GameConfig.MENU_CAMERA = {
	FOCUS = Vector3.new(0, 4, 0), -- the point the camera looks at and orbits
	RADIUS = 70, -- horizontal distance from FOCUS
	HEIGHT = 34, -- how far above FOCUS the camera sits
	ORBIT_SPEED = 0.06, -- radians/sec; 0 holds a still shot
	FIELD_OF_VIEW = 70,
}

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
