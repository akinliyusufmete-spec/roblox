--[[
	DetentionSystem (ModuleScript, ServerScriptService.BaldiGame.DetentionSystem)

	LP's punishment: teleport the offender to the detention room, anchor them
	for DETENTION_SECONDS while the client shows the countdown overlay, then
	release with a short immunity window so LP can't instantly re-detain.
]]

local DetentionSystem = {}

function DetentionSystem.init(ctx)
	local self = {}
	local detained = {} -- [player] = { releaseAt = t }
	local immunityUntil = {} -- [player] = t

	local function release(player)
		local info = detained[player]
		if not info then
			return
		end
		detained[player] = nil
		immunityUntil[player] = os.clock() + ctx.config.NPC.LP.RELEASE_IMMUNITY_SECONDS

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
		if player.Parent then
			ctx.remotes.DetentionReleased:FireClient(player)
		end
	end

	function self.detain(player, seconds, byName)
		if detained[player] then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		detained[player] = { releaseAt = os.clock() + seconds }
		character:PivotTo(ctx.map.detentionCFrame)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.Anchored = true
		ctx.remotes.SendToDetention:FireClient(player, seconds, byName)

		task.delay(seconds, function()
			release(player)
		end)
	end

	function self.isDetained(player)
		return detained[player] ~= nil
	end

	function self.hasImmunity(player)
		return (immunityUntil[player] or 0) > os.clock()
	end

	function self.releasePlayer(player)
		release(player)
	end

	function self.releaseAll()
		for player in pairs(detained) do
			release(player)
		end
	end

	function self.forget(player)
		detained[player] = nil
		immunityUntil[player] = nil
	end

	ctx.detention = self
	return self
end

return DetentionSystem
