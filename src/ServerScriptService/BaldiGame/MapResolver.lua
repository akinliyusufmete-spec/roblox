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
					prompt.ActionText = "Buy"
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
