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
