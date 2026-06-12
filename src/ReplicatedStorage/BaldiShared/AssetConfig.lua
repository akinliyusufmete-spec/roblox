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
--   tension = optional looping dread track that swells as ChatRevive
--             closes in (blank = a built-in heartbeat thump instead)
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
	tension = "",
}

return AssetConfig
