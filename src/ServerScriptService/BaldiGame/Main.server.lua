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
