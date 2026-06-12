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
	  5. ProximityPrompt -> the Sweet Spot minigame (NOTEBOOK_MINIGAME):
	     the server picks the hidden stage angles, the client plays the
	     lock face, and completion is validated here — the session must
	     exist, the player must still be at THAT notebook, and the elapsed
	     time must be physically possible given the rotation speed. With
	     ENABLED = false the prompt collects instantly like before.

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
	local sessions = {} -- [player] = { notebook, angles, position, startedAt, minSeconds }
	local minigameCfg = ctx.config.NOTEBOOK_MINIGAME

	-- ===================== sweet-spot minigame =====================

	local function clearSession(player, tellClient)
		if not sessions[player] then
			return
		end
		sessions[player] = nil
		if tellClient and player.Parent then
			ctx.remotes.NotebookMinigame:FireClient(player, nil)
		end
	end

	local function collect(player, notebook)
		if not active[notebook] then
			return
		end
		active[notebook] = nil
		notebook:Destroy()
		ctx.manager.onNotebookCollected(player)
	end

	local function angularDistance(a, b)
		local d = math.abs(a - b) % 360
		return math.min(d, 360 - d)
	end

	local function startSession(player, notebook)
		local position = notebook:GetPivot().Position
		-- pick the hidden stage angles here so a modified client can't know
		-- them ahead of the feedback, and so completion time can be checked
		local angles = {}
		local from = 0 -- the client's pointer starts at the top
		local minSeconds = 0
		for _ = 1, minigameCfg.STAGES do
			local angle = (from + rng:NextInteger(60, 300)) % 360 -- always some travel
			table.insert(angles, angle)
			local travel = math.max(angularDistance(from, angle) - minigameCfg.HIT_WINDOW, 0)
			minSeconds = minSeconds + travel / minigameCfg.ROTATE_SPEED + minigameCfg.HOLD_SECONDS
			from = angle
		end

		local session = {
			notebook = notebook,
			angles = angles,
			position = position,
			startedAt = os.clock(),
			minSeconds = minSeconds,
		}
		sessions[player] = session
		ctx.remotes.NotebookMinigame:FireClient(player, { angles = angles, position = position })

		-- watcher: abandon the session if the notebook vanishes, the player
		-- wanders off / gets grabbed (anchored) / leaves, or it times out
		task.spawn(function()
			while sessions[player] == session do
				local character = player.Parent and player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if os.clock() - session.startedAt > minigameCfg.MAX_SECONDS
					or not active[notebook]
					or not ctx.manager.isRoundActive()
					or not ctx.manager.isParticipant(player)
					or not hrp
					or hrp.Anchored
					or (hrp.Position - position).Magnitude > minigameCfg.CANCEL_DISTANCE then
					clearSession(player, true)
					return
				end
				task.wait(0.25)
			end
		end)
	end

	ctx.remotes.NotebookMinigameAction.OnServerEvent:Connect(function(player, action)
		local session = sessions[player]
		if not session then
			return
		end
		if action == "cancel" then
			clearSession(player, false)
			return
		end
		if action ~= "done" then
			return
		end
		if not ctx.manager.isRoundActive() or not ctx.manager.isParticipant(player) then
			clearSession(player, true)
			return
		end
		-- finishing faster than the pointer can physically travel = cheating
		if os.clock() - session.startedAt < session.minSeconds * 0.75 then
			clearSession(player, true)
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - session.position).Magnitude > minigameCfg.CANCEL_DISTANCE then
			clearSession(player, true)
			return
		end
		local notebook = session.notebook
		clearSession(player, false)
		collect(player, notebook)
	end)

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
		for player in pairs(sessions) do
			clearSession(player, true)
		end
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
				if minigameCfg and minigameCfg.ENABLED then
					if not sessions[player] then -- E re-presses mid-game just rotate
						startSession(player, notebook)
					end
				else
					collect(player, notebook)
				end
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
