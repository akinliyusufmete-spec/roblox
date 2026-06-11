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

DetentionSystem.init(ctx) -- before LpAI, which reads ctx.detention

ChatReviveAI.init(ctx)
LpAI.init(ctx)
FrostyAI.init(ctx)

ItemEconomy.init(ctx)
NotebookSpawner.init(ctx)
ExitDoorManager.init(ctx)
GameManager.init(ctx)

print("[BaldiGame] Server ready. Map resolved, NPCs spawned, remotes live.")
