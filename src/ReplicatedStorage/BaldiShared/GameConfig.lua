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
