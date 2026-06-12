--[[
	ChaseTension (ModuleScript, StarterPlayerScripts.BaldiClient.ChaseTension)

	Proximity dread. While a round is on, this watches how close ChatRevive
	is and plays a low heartbeat thump that quickens and swells as he closes
	in (config: GameConfig.TENSION). After the exit opens the heart beats a
	little faster still.

	Your sound: set AssetConfig.SOUNDS.tension to a looping track and it is
	used instead of the thumps, its volume rising as ChatRevive approaches.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local ChaseTension = {}

function ChaseTension.init(ctx)
	local cfg = ctx.config.TENSION
	local self = {}
	local inRound = false
	local exitOpen = false
	local hunterRoot = nil

	local customLoopId = ctx.assets.SOUNDS and ctx.assets.SOUNDS.tension or ""
	local loopSound = nil
	if customLoopId ~= "" then
		loopSound = Instance.new("Sound")
		loopSound.Name = "BaldiTension"
		loopSound.SoundId = customLoopId
		loopSound.Looped = true
		loopSound.Volume = 0
		loopSound.Parent = SoundService
	end

	local function findHunterRoot()
		if hunterRoot and hunterRoot.Parent then
			return hunterRoot
		end
		hunterRoot = nil
		local map = workspace:FindFirstChild("BaldiMap")
		local npcs = map and map:FindFirstChild("Npcs")
		local model = npcs and npcs:FindFirstChild("ChatRevive")
		hunterRoot = model and model:FindFirstChild("HumanoidRootPart") or nil
		return hunterRoot
	end

	-- 0 = out of range, 1 = right on top of you
	local function getCloseness()
		local character = ctx.player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local hunter = findHunterRoot()
		if not hrp or not hunter then
			return 0
		end
		local distance = (hunter.Position - hrp.Position).Magnitude
		return math.clamp(1 - distance / cfg.RANGE, 0, 1)
	end

	local function thump(volume)
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxasset://sounds/snap.mp3"
			sound.PlaybackSpeed = 0.42
			sound.Volume = volume
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 3)
		end)
	end

	if loopSound then
		-- custom track: keep it running, breathe the volume with distance
		task.spawn(function()
			while true do
				task.wait(0.15)
				local closeness = inRound and getCloseness() or 0
				local target = cfg.MAX_VOLUME * closeness
				if target > 0 and not loopSound.IsPlaying then
					pcall(function()
						loopSound:Play()
					end)
				elseif target <= 0 and loopSound.IsPlaying then
					pcall(function()
						loopSound:Stop()
					end)
				end
				loopSound.Volume = loopSound.Volume + (target - loopSound.Volume) * 0.3
			end
		end)
	else
		-- built-in heartbeat: interval and volume scale with closeness
		task.spawn(function()
			while true do
				if not inRound then
					task.wait(0.5)
				else
					local closeness = getCloseness()
					if closeness <= 0 then
						task.wait(0.4)
					else
						local interval = cfg.MAX_INTERVAL
							+ (cfg.MIN_INTERVAL - cfg.MAX_INTERVAL) * closeness
						if exitOpen then
							interval = interval * 0.85 -- enraged: the heart races
						end
						thump(cfg.MAX_VOLUME * (0.25 + 0.75 * closeness))
						task.wait(interval)
					end
				end
			end
		end)
	end

	ctx.remotes.GameStarted.OnClientEvent:Connect(function()
		inRound = true
		exitOpen = false
		hunterRoot = nil -- rigs respawn per round; re-find
	end)
	ctx.remotes.PhaseChanged.OnClientEvent:Connect(function(phaseName)
		if phaseName == "EXIT_OPEN" then
			exitOpen = true
		end
	end)
	local function stop()
		inRound = false
		if loopSound then
			loopSound.Volume = 0
			pcall(function()
				loopSound:Stop()
			end)
		end
	end
	ctx.remotes.RoundEnded.OnClientEvent:Connect(stop)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(stop)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(stop)

	return self
end

return ChaseTension
