--[[
	SoundController (ModuleScript, StarterPlayerScripts.BaldiClient.SoundController)
	UI / feedback sounds built only from rbxasset:// files that ship with the
	engine, so nothing depends on marketplace assets. Every play is wrapped
	in pcall — a missing sound never breaks gameplay.
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
}

function SoundController.init(ctx)
	local self = {}

	function self.play(name, pitchOverride)
		local entry = LIBRARY[name]
		if not entry then
			return
		end
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			sound.Volume = entry.volume
			sound.PlaybackSpeed = pitchOverride or entry.speed
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 4)
		end)
	end

	-- little rising arpeggio for the win screen
	function self.winJingle()
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
