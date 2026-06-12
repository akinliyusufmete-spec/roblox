--[[
	NotebookMinigame (ModuleScript, StarterPlayerScripts.BaldiClient.NotebookMinigame)

	The Sweet Spot lock face. Pressing E on a notebook opens a circular
	dial with a pointer and a HIDDEN sweet spot (the server picked the
	angles). Hold E to rotate clockwise, Q counter-clockwise; as the
	pointer nears the spot the face shakes harder and the ring warms from
	grey to orange to green. Hold the pointer on the spot to click the
	stage; clear every stage and the server collects the notebook.

	F (or the X button) gives up. Walking away, getting grabbed, detention
	or the round ending all abort it too. You are NOT protected while
	picking — keep one eye on the hall.

	While the face is open, ProximityPrompts are disabled (so E rotates
	instead of re-triggering the prompt) and ItemUseClient ignores E / Q.
]]

local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local NotebookMinigame = {}

function NotebookMinigame.init(ctx)
	local UiKit = require(script.Parent:WaitForChild("UiKit"))
	local theme = UiKit.theme
	local sounds = ctx.controllers.SoundController
	local cfg = ctx.config.NOTEBOOK_MINIGAME
	local self = { active = false }

	local COLD = Color3.fromRGB(120, 120, 120)
	local WARM = Color3.fromRGB(235, 150, 40)
	local FACE_POSITION = UDim2.fromScale(0.5, 0.52)

	-- ===================== UI =====================

	local playerGui = ctx.player:WaitForChild("PlayerGui")
	local gui = UiKit.new("ScreenGui", {
		Name = "BaldiNotebookMinigame",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		Enabled = false,
		Parent = playerGui,
	})

	local face = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = FACE_POSITION,
		Size = UDim2.fromOffset(230, 230),
		BackgroundColor3 = theme.panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	UiKit.corner(115).Parent = face
	local ring = UiKit.stroke(COLD, 6)
	ring.Parent = face

	local titleLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -46),
		Size = UDim2.fromOffset(420, 30),
		Text = "Find the sweet spot!",
		TextColor3 = theme.accent,
		Parent = face,
	})
	local hintLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -18),
		Size = UDim2.fromOffset(460, 22),
		Text = "[E] rotate right   [Q] rotate left   [F] give up",
		TextColor3 = theme.textDim,
		TextStrokeTransparency = 1,
		Parent = face,
	})

	-- the rotating needle: a full-size container spun by Rotation, with the
	-- visible needle drawn only on its top half
	local needlePivot = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = face,
	})
	UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 6, 0.5, -34),
		BackgroundColor3 = theme.white,
		Parent = needlePivot,
		UiKit.corner(3),
	})

	-- center hub with the stage counter
	local hub = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(74, 74),
		BackgroundColor3 = theme.panelLight,
		Parent = face,
		UiKit.corner(37),
	})
	local stageLabel = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = "1 / 2",
		Parent = hub,
	})

	-- hold-to-click progress, filling along the bottom of the face
	local holdBack = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 14),
		Size = UDim2.fromOffset(190, 12),
		BackgroundColor3 = theme.panel,
		Parent = face,
		UiKit.corner(6),
	})
	local holdFill = UiKit.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.green,
		Parent = holdBack,
		UiKit.corner(6),
	})

	local closeButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		BackgroundColor3 = theme.red,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = face,
	})

	-- ===================== state =====================

	local angles = nil -- the server-picked sweet spots, in stage order
	local notebookPosition = nil
	local stageIndex = 1
	local pointer = 0
	local holdTime = 0
	local keyE, keyQ, touchE, touchQ = false, false, false, false
	local rng = Random.new()

	local function angularDistance(a, b)
		local d = math.abs(a - b) % 360
		return math.min(d, 360 - d)
	end

	local function setStageLabel()
		stageLabel.Text = stageIndex .. " / " .. (angles and #angles or 0)
	end

	local function close(tellServer)
		if not self.active then
			return
		end
		self.active = false
		angles = nil
		gui.Enabled = false
		ProximityPromptService.Enabled = true
		if tellServer then
			ctx.remotes.NotebookMinigameAction:FireServer("cancel")
		end
	end

	local function open(data)
		if typeof(data) ~= "table" or typeof(data.angles) ~= "table" or #data.angles == 0
			or typeof(data.position) ~= "Vector3" then
			return
		end
		angles = data.angles
		notebookPosition = data.position
		stageIndex = 1
		pointer = 0
		holdTime = 0
		keyE, keyQ, touchE, touchQ = false, false, false, false
		needlePivot.Rotation = 0
		holdFill.Size = UDim2.fromScale(0, 1)
		ring.Color = COLD
		setStageLabel()
		self.active = true
		gui.Enabled = true
		-- E must rotate, not re-trigger the notebook's prompt behind the face
		ProximityPromptService.Enabled = false
		sounds.play("click")
	end

	-- ===================== the dial =====================

	RunService.RenderStepped:Connect(function(dt)
		if not self.active or not angles then
			return
		end

		-- abandon if we've wandered off the notebook
		local character = ctx.player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - notebookPosition).Magnitude > cfg.CANCEL_DISTANCE then
			close(true)
			return
		end

		local direction = ((keyE or touchE) and 1 or 0) - ((keyQ or touchQ) and 1 or 0)
		pointer = (pointer + direction * cfg.ROTATE_SPEED * dt) % 360
		needlePivot.Rotation = pointer

		local distance = angularDistance(pointer, angles[stageIndex])
		local hot = distance <= cfg.HIT_WINDOW
		local heat = hot and 1
			or math.clamp(1 - (distance - cfg.HIT_WINDOW) / math.max(cfg.WARM_RANGE - cfg.HIT_WINDOW, 1), 0, 1)

		-- the only tells: the ring warms up and the face trembles
		ring.Color = hot and theme.green or COLD:Lerp(WARM, heat)
		ring.Thickness = hot and 8 or 6
		local amplitude = hot and 5 or heat * 3
		face.Position = FACE_POSITION
			+ UDim2.fromOffset(rng:NextInteger(-amplitude, amplitude), rng:NextInteger(-amplitude, amplitude))

		if hot then
			holdTime = holdTime + dt
		else
			holdTime = 0
		end
		holdFill.Size = UDim2.fromScale(math.clamp(holdTime / cfg.HOLD_SECONDS, 0, 1), 1)

		if holdTime >= cfg.HOLD_SECONDS then
			holdTime = 0
			if stageIndex >= #angles then
				-- every spot clicked: the server validates and collects
				-- (the HUD's NotebookCollected handler plays the fanfare)
				ctx.remotes.NotebookMinigameAction:FireServer("done")
				close(false)
			else
				stageIndex = stageIndex + 1
				setStageLabel()
				sounds.play("click", 1.7)
				UiKit.shake(face, 6)
			end
		end
	end)

	-- ===================== input =====================

	ctx.controllers.InputHandler.onUseHeld(function(held)
		keyE = held
	end)
	ctx.controllers.InputHandler.onSwapHeld(function(held)
		keyQ = held
	end)
	ctx.controllers.InputHandler.onCancel(function()
		if self.active then
			close(true)
		end
	end)
	closeButton.Activated:Connect(function()
		close(true)
	end)

	-- mobile: hold-to-rotate buttons flanking the face
	if ctx.controllers.InputHandler.touchEnabled then
		local function holdButton(text, xScale, setHeld)
			local button = UiKit.button({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(xScale, 0.78),
				Size = UDim2.fromOffset(86, 86),
				Text = text,
				Parent = gui,
			})
			button.MouseButton1Down:Connect(function()
				setHeld(true)
			end)
			button.MouseButton1Up:Connect(function()
				setHeld(false)
			end)
			button.MouseLeave:Connect(function()
				setHeld(false)
			end)
			return button
		end
		holdButton("<", 0.28, function(held)
			touchQ = held
		end)
		holdButton(">", 0.72, function(held)
			touchE = held
		end)
		hintLabel.Text = "hold < > to rotate   X gives up"
	end

	-- ===================== remotes =====================

	ctx.remotes.NotebookMinigame.OnClientEvent:Connect(function(data)
		if data == nil then
			close(false)
		else
			open(data)
		end
	end)

	-- anything that takes control of the player ends the attempt
	ctx.remotes.SilverGrab.OnClientEvent:Connect(function()
		close(true)
	end)
	ctx.remotes.SendToDetention.OnClientEvent:Connect(function()
		close(true)
	end)
	ctx.remotes.RoundEnded.OnClientEvent:Connect(function()
		close(false)
	end)
	ctx.remotes.PlayerLost.OnClientEvent:Connect(function()
		close(false)
	end)
	ctx.remotes.PlayerWon.OnClientEvent:Connect(function()
		close(false)
	end)

	return self
end

return NotebookMinigame
