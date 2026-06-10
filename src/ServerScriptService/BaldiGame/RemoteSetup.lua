--[[
	RemoteSetup (ModuleScript, ServerScriptService.BaldiGame.RemoteSetup)
	Creates the RemoteEvents folder in ReplicatedStorage at server startup.
	Building remotes in code means the project works identically whether it
	was synced with Rojo or pasted in with the installer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteSetup = {}

function RemoteSetup.init(ctx)
	local config = ctx.config

	local folder = ReplicatedStorage:FindFirstChild(config.REMOTES_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = config.REMOTES_FOLDER
		folder.Parent = ReplicatedStorage
	end

	ctx.remotes = {}
	for _, name in ipairs(config.REMOTE_NAMES) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		ctx.remotes[name] = remote
	end

	return ctx.remotes
end

return RemoteSetup
