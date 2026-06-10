--[[
	ExitDoorManager (ModuleScript, ServerScriptService.BaldiGame.ExitDoorManager)

	The big red door at the end of the entrance corridor. Locked while
	notebooks remain; when all are collected it turns green and a proximity
	loop awards the win to any participant who reaches it.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ExitDoorManager = {}

local COLOR_LOCKED = Color3.fromRGB(140, 30, 30)
local COLOR_OPEN = Color3.fromRGB(40, 170, 70)

function ExitDoorManager.init(ctx)
	local self = { open = false }
	local door = ctx.map.exitDoor

	local function setLabel(text)
		if not door then
			return
		end
		local gui = door:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = text
		end
	end

	function self.close()
		self.open = false
		if door then
			door.Color = COLOR_LOCKED
			local glow = door:FindFirstChild("ExitGlow")
			if glow then
				glow:Destroy()
			end
			setLabel("EXIT")
		end
	end

	function self.openDoor()
		if self.open or not door then
			return
		end
		self.open = true
		door.Color = COLOR_OPEN
		setLabel("EXIT - OPEN!")
		local glow = Instance.new("PointLight")
		glow.Name = "ExitGlow"
		glow.Color = COLOR_OPEN
		glow.Range = 16
		glow.Brightness = 2
		glow.Parent = door
	end

	if door then
		RunService.Heartbeat:Connect(function()
			if not self.open or not ctx.manager or not ctx.manager.isRoundActive() then
				return
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if ctx.manager.isParticipant(player) then
					local character = player.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - door.Position).Magnitude < 6 then
						ctx.manager.playerWon(player)
					end
				end
			end
		end)
	else
		warn("[BaldiGame] No ExitDoor found in the map; wins cannot trigger.")
	end

	ctx.exitDoor = self
	return self
end

return ExitDoorManager
