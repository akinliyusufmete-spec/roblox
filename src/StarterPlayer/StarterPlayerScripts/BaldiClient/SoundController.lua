--[[
	SoundController (ModuleScript, StarterPlayerScripts.BaldiClient.SoundController)

	UI / feedback sounds. Each named sound checks AssetConfig.SOUNDS first —
	paste your own sound id there and it replaces the built-in placeholder
	(placeholders are rbxasset:// files that ship with the engine, so
	nothing depends on marketplace assets). Every play is wrapped in
	pcall — a missing sound never breaks gameplay.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundController = {}

local LIBRARY = {
	click = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.4, volume = 0.4 },
	collect = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.0, volume = 0.7 },
	nickel = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.8, volume = 0.6 },
	buy = { id = "rbxasset://sounds/snap.mp3", speed = 1.2, volume = 0.6 },
	error = { id = "rbxasset://sounds/snap.mp3", speed = 0.55, volume = 0.6 },
	exhausted = { id = "rbxasset://sounds/snap.mp3", speed = 0.4, volume = 0.5 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1.0, volume = 1 },
	detention = { id = "rbxasset://sounds/snap.mp3", speed = 0.35, volume = 0.8 },
	frost = { id = "rbxasset://sounds/swoosh.mp3", speed = 0.6, volume = 0.7 },
	use = { id = "rbxasset://sounds/swoosh.mp3", speed = 1.2, volume = 0.6 },
	win = { id = "", speed = 1.0, volume = 0.8 }, -- placeholder is the jingle below
	grab = { id = "rbxasset://sounds/snap.mp3", speed = 0.7, volume = 0.9 }, -- Silver caught you
	swept = { id = "rbxasset://sounds/swoosh.mp3", speed = 0.8, volume = 0.8 }, -- a sweeper hit you
}

function SoundController.init(ctx)
	local self = {}
	local overrides = ctx.assets.SOUNDS

	function self.play(name, pitchOverride)
		local entry = LIBRARY[name]
		if not entry then
			return
		end
		local override = overrides[name]
		local custom = override and override ~= ""
		local id = custom and override or entry.id
		if id == "" then
			return
		end
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = entry.volume
			-- your sound plays at its natural pitch unless a pitch is forced
			sound.PlaybackSpeed = pitchOverride or (custom and 1 or entry.speed)
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 6)
		end)
	end

	-- win fanfare: your SOUNDS.win asset, or a little rising arpeggio
	function self.winJingle()
		if overrides.win and overrides.win ~= "" then
			self.play("win")
			return
		end
		task.spawn(function()
			for _, pitch in ipairs({ 1.0, 1.26, 1.5 }) do
				self.play("collect", pitch)
				task.wait(0.18)
			end
		end)
	end

	return self
end

return SoundController
