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
	"NotebookMinigame",
	"ChaseTension",
	"MenuController",
}

for _, moduleName in ipairs(INIT_ORDER) do
	local module = require(script.Parent:WaitForChild(moduleName))
	ctx.controllers[moduleName] = module.init(ctx)
end

print("[BaldiGame] Client ready.")
