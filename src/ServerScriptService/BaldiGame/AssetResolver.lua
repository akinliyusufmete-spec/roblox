--[[
	AssetResolver (ModuleScript, ServerScriptService.BaldiGame.AssetResolver)

	Looks up the hand-made models you place under:

	  ReplicatedStorage
	  └── BaldiAssets
	      ├── Npcs
	      │   ├── ChatRevive   (Model with Humanoid + HumanoidRootPart)
	      │   ├── LP
	      │   └── Frosty
	      └── Items
	          ├── Notebook     (Model or Part)
	          ├── Nickel
	          ├── BSODA
	          ├── ZESTY
	          └── BsodaProjectile  (optional — the flying blast visual)

	Everything is optional: a missing asset gets a one-time console note and
	the game uses its built-in placeholder instead, so you can replace
	pieces one at a time while you build.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetResolver = {}

local noted = {}

local function noteOnce(key, message)
	if noted[key] then
		return
	end
	noted[key] = true
	print("[BaldiGame] " .. message)
end

local function assetsFolder(childName)
	local root = ReplicatedStorage:FindFirstChild("BaldiAssets")
	if not root then
		return nil
	end
	return root:FindFirstChild(childName)
end

-- Your NPC rig, validated; nil -> caller builds the placeholder rig.
function AssetResolver.npcTemplate(name)
	local folder = assetsFolder("Npcs")
	local model = folder and folder:FindFirstChild(name)
	if not model then
		noteOnce("npc_" .. name, string.format(
			"No custom rig at ReplicatedStorage/BaldiAssets/Npcs/%s — using the placeholder rig.", name))
		return nil
	end
	if not model:IsA("Model") or not model:FindFirstChildOfClass("Humanoid")
		or not model:FindFirstChild("HumanoidRootPart") then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Npcs/%s must be a Model containing a Humanoid and a HumanoidRootPart — using the placeholder rig instead.",
			name))
		return nil
	end
	return model
end

-- Your item/pickup model; nil -> caller builds the placeholder.
function AssetResolver.itemTemplate(name)
	local folder = assetsFolder("Items")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		noteOnce("item_" .. name, string.format(
			"No custom model at ReplicatedStorage/BaldiAssets/Items/%s — using the placeholder.", name))
		return nil
	end
	if not (template:IsA("Model") or template:IsA("BasePart")) then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Items/%s must be a Model or a Part — using the placeholder instead.", name))
		return nil
	end
	if template:IsA("Model") and not template:FindFirstChildWhichIsA("BasePart", true) then
		warn(string.format(
			"[BaldiGame] BaldiAssets/Items/%s has no parts inside — using the placeholder instead.", name))
		return nil
	end
	return template
end

-- Clone helper for pickups/props: anchored, non-colliding, script-free.
function AssetResolver.preparePropClone(template)
	local clone = template:Clone()
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		elseif descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
	elseif clone:IsA("Model") and not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	return clone
end

return AssetResolver
