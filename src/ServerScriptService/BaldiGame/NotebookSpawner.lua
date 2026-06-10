--[[
	NotebookSpawner (ModuleScript, ServerScriptService.BaldiGame.NotebookSpawner)

	Random notebook generation, exactly per the plan:
	  1. MapBuilder placed ~23 invisible nodes tagged "NotebookSpawn"
	     (any parts you tag yourself in Studio are included too).
	  2. CollectionService:GetTagged("NotebookSpawn") collects them.
	  3. Fisher-Yates shuffle, take the first NOTEBOOK_SPAWN_COUNT (10).
	  4. Clone the Notebook model (built in code into ReplicatedStorage)
	     at each chosen node.
	  5. ProximityPrompt collect -> destroy model, bump the server counter,
	     fire NotebookCollected to all clients.

	Also runs a tiny spin/bob animation so notebooks read as pickups.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotebookSpawner = {}

local function buildNotebookTemplate()
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
	cover.CanQuery = false
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
	pages.CanQuery = false
	pages.CFrame = cover.CFrame * CFrame.new(0, 0.23, 0)
	pages.Parent = model

	model.PrimaryPart = cover
	model.Parent = folder
	return model
end

function NotebookSpawner.init(ctx)
	local self = {}
	local template = buildNotebookTemplate()
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

		-- 2. collect every tagged node (built ones + any you added in Studio)
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
			local notebook = template:Clone()
			local baseCFrame = CFrame.new(node.Position + Vector3.new(0, 0.8, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			notebook:PivotTo(baseCFrame)

			-- 5. collect interaction
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Collect"
			prompt.ObjectText = "Notebook"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = ctx.config.NOTEBOOK_PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = notebook.PrimaryPart

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
