--[[
	GameManager (ModuleScript, ServerScriptService.BaldiGame.GameManager)

	The round state machine:

	  IDLE ── Play pressed ──> COUNTDOWN (3s, players anchored at entrance)
	       <── all players out ── ACTIVE (notebooks spawned, NPCs gated)

	Activation gating:
	  0 notebooks    -> all NPCs frozen
	  1 notebook     -> all NPCs activate (roam loops start)
	  last notebook  -> the main chaser enrages + the exit opens

	Per-player outcomes:
	  - Caught by ChatRevive -> lose screen, a Nickel drops at the spot.
	  - Reach the open exit  -> win screen with elapsed + session best time.
	Players pressing Play during an active round simply join it.
]]

local Players = game:GetService("Players")

local GameManager = {}

function GameManager.init(ctx)
	local self = {}
	local config = ctx.config
	local remotes = ctx.remotes

	local phase = "IDLE" -- IDLE | COUNTDOWN | ACTIVE
	local participants = {} -- [player] = true
	local notebooksCollected = 0
	local notebooksTotal = config.NOTEBOOK_SPAWN_COUNT
	local roundStartedAt = 0
	local bestTimes = {} -- [userId] = seconds (session best)
	local startDebounce = {} -- [player] = next allowed RequestStart time

	-- ===================== queries used by the AIs =====================

	function self.isRoundActive()
		return phase == "ACTIVE"
	end

	function self.isParticipant(player)
		return participants[player] == true
	end

	function self.getNotebookCounts()
		return notebooksCollected, notebooksTotal
	end

	function self.isTargetable(player)
		if not participants[player] then
			return false
		end
		local character = player.Character
		if not character then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp or humanoid.Health <= 0 then
			return false
		end
		if hrp.Anchored then -- countdown or detention...
			-- ...but a player in Silver's grasp stays fair game: getting
			-- grabbed in the open with ChatRevive nearby SHOULD be lethal
			local silver = ctx.npcs.Silver
			if not (silver and silver.isGrabbing and silver.isGrabbing(player)) then
				return false
			end
		end
		if ctx.detention.isDetained(player) then
			return false
		end
		return true
	end

	function self.getTargetablePlayers()
		local list = {}
		for player in pairs(participants) do
			if self.isTargetable(player) then
				table.insert(list, player)
			end
		end
		return list
	end

	-- ===================== helpers =====================

	local function teleportToRoundSpawn(player, anchored)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not hrp then
			return false
		end
		-- spread players a little so they don't stack
		local offset = CFrame.new(math.random(-3, 3), 0, math.random(-2, 2))
		character:PivotTo(ctx.map.roundSpawnCFrame * offset)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.Anchored = anchored
		return true
	end

	local function teleportToLobby(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if character and hrp then
			hrp.Anchored = false
			if ctx.map.lobbySpawn then
				character:PivotTo(ctx.map.lobbySpawn.CFrame * CFrame.new(math.random(-4, 4), 3, math.random(-4, 4)))
			end
		end
	end

	local function setNpcsPaused(paused)
		for _, npc in pairs(ctx.npcs) do
			npc.base:setPaused(paused)
		end
	end

	local function resetNpcs()
		for _, npc in pairs(ctx.npcs) do
			if npc.reset then
				npc.reset()
			else
				npc.base:resetToSpawn()
			end
		end
	end

	-- ===================== round flow =====================

	local function endRound()
		if phase == "IDLE" then
			return
		end
		phase = "IDLE"
		for player in pairs(participants) do
			participants[player] = nil
			teleportToLobby(player)
		end
		ctx.detention.releaseAll()
		ctx.notebookSpawner.clear()
		ctx.economy.clearPickups()
		ctx.exitDoor.close()
		resetNpcs()
		notebooksCollected = 0
		remotes.RoundEnded:FireAllClients()
	end

	local function checkRoundEnd()
		if phase ~= "ACTIVE" then
			return
		end
		if next(participants) == nil then
			endRound()
		end
	end

	local function joinActiveRound(player)
		participants[player] = true
		if not teleportToRoundSpawn(player, false) then
			participants[player] = nil
			return
		end
		remotes.GameStarted:FireClient(player, notebooksTotal)
		remotes.NotebookCollected:FireClient(player, notebooksCollected, notebooksTotal)
		if ctx.exitDoor.open then
			remotes.PhaseChanged:FireClient(player, "EXIT_OPEN")
		elseif notebooksCollected > 0 then
			remotes.PhaseChanged:FireClient(player, "CHARACTERS_ACTIVE")
		end
	end

	local function beginCountdown(firstPlayer)
		phase = "COUNTDOWN"
		notebooksCollected = 0
		resetNpcs()
		ctx.exitDoor.close()
		notebooksTotal = ctx.notebookSpawner.spawnForRound()
		ctx.economy.onRoundStart()

		participants[firstPlayer] = true
		teleportToRoundSpawn(firstPlayer, true)
		remotes.GameCountdown:FireClient(firstPlayer, config.COUNTDOWN_SECONDS)

		task.delay(config.COUNTDOWN_SECONDS, function()
			if phase ~= "COUNTDOWN" then
				return
			end
			phase = "ACTIVE"
			roundStartedAt = os.clock()
			for player in pairs(participants) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = false
				end
				remotes.GameStarted:FireClient(player, notebooksTotal)
				remotes.NotebookCollected:FireClient(player, notebooksCollected, notebooksTotal)
			end
			checkRoundEnd() -- everyone may have left during the countdown
		end)
	end

	-- ===================== notebook -> HUD + gating =====================

	function self.onNotebookCollected(byPlayer)
		notebooksCollected = notebooksCollected + 1
		remotes.NotebookCollected:FireAllClients(notebooksCollected, notebooksTotal)

		if notebooksCollected == 1 then
			-- first notebook: every character wakes up
			setNpcsPaused(false)
			remotes.PhaseChanged:FireAllClients("CHARACTERS_ACTIVE")
		end
		if notebooksCollected >= notebooksTotal then
			-- final notebook: enrage + exit phase
			if ctx.npcs.ChatRevive and ctx.npcs.ChatRevive.enrage then
				ctx.npcs.ChatRevive.enrage()
			end
			ctx.exitDoor.openDoor()
			remotes.PhaseChanged:FireAllClients("EXIT_OPEN")
		end
	end

	-- ===================== outcomes =====================

	function self.playerCaught(player, catcherName)
		if not participants[player] then
			return
		end
		participants[player] = nil

		-- ChatRevive drops a Nickel where the victim stood
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			ctx.economy.spawnNickel(hrp.Position + Vector3.new(0, -1.5, 0))
		end

		ctx.detention.releasePlayer(player)
		teleportToLobby(player)
		remotes.PlayerLost:FireClient(player, catcherName, catcherName .. " caught you in the halls.")
		checkRoundEnd()
	end

	function self.playerWon(player)
		if not participants[player] then
			return
		end
		participants[player] = nil

		local elapsed = os.clock() - roundStartedAt
		local best = bestTimes[player.UserId]
		if not best or elapsed < best then
			best = elapsed
			bestTimes[player.UserId] = best
		end

		ctx.detention.releasePlayer(player)
		teleportToLobby(player)
		remotes.PlayerWon:FireClient(player, elapsed, best)
		checkRoundEnd()
	end

	-- ===================== player lifecycle =====================

	local function onCharacterAdded(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.WalkSpeed = config.PLAYER.WALK_SPEED
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "BaldiPlayer"
			end
		end
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "BaldiPlayer"
			end
		end)
		humanoid.Died:Connect(function()
			if participants[player] then
				participants[player] = nil
				remotes.PlayerLost:FireClient(player, "the schoolhouse", "You collapsed. The school wins this time.")
				checkRoundEnd()
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		if ctx.map.lobbySpawn then
			player.RespawnLocation = ctx.map.lobbySpawn
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		ctx.economy.syncAll(player)
	end)

	-- players already present when the server script started (Play Solo race)
	for _, player in ipairs(Players:GetPlayers()) do
		if ctx.map.lobbySpawn then
			player.RespawnLocation = ctx.map.lobbySpawn
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
			teleportToLobby(player)
		end
		ctx.economy.syncAll(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		ctx.detention.forget(player)
		ctx.economy.forget(player)
		startDebounce[player] = nil
		checkRoundEnd()
	end)

	-- ===================== Play button =====================

	remotes.RequestStart.OnServerEvent:Connect(function(player)
		if (startDebounce[player] or 0) > os.clock() then
			return
		end
		startDebounce[player] = os.clock() + 1

		if participants[player] then
			return
		end
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			return
		end

		if phase == "IDLE" then
			beginCountdown(player)
		elseif phase == "COUNTDOWN" then
			participants[player] = true
			teleportToRoundSpawn(player, true)
			remotes.GameCountdown:FireClient(player, config.COUNTDOWN_SECONDS)
		else -- ACTIVE: join the round in progress
			joinActiveRound(player)
		end
	end)

	ctx.manager = self
	return self
end

return GameManager
