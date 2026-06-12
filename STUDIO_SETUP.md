# Studio Setup — make the game yours

The scripts never *require* any asset: anything you haven't built yet is
replaced by a placeholder (a generated school, block rigs, plain-colored UI)
and the game still runs. Each missing asset prints a one-time note in the
Output window telling you the exact path it looked at. Build things in any
order; press Play after each one to see it in game.

---

## 1. Install the scripts

### Option A — paste each file (full control)

Create this exact tree in Studio (right-click a service → Insert Object),
then copy each file's contents from `src/` into the matching script:

| Create in Studio | Class | Copy from |
|---|---|---|
| `ServerScriptService/BaldiGame` | Folder | — |
| `BaldiGame/Main` | **Script** | `src/ServerScriptService/BaldiGame/Main.server.lua` |
| `BaldiGame/RemoteSetup` | ModuleScript | `.../RemoteSetup.lua` |
| `BaldiGame/AssetResolver` | ModuleScript | `.../AssetResolver.lua` |
| `BaldiGame/MapResolver` | ModuleScript | `.../MapResolver.lua` |
| `BaldiGame/PlaceholderMap` | ModuleScript | `.../PlaceholderMap.lua` |
| `BaldiGame/NpcFactory` | ModuleScript | `.../NpcFactory.lua` |
| `BaldiGame/NpcAnimator` | ModuleScript | `.../NpcAnimator.lua` |
| `BaldiGame/NpcBase` | ModuleScript | `.../NpcBase.lua` |
| `BaldiGame/GameManager` | ModuleScript | `.../GameManager.lua` |
| `BaldiGame/NotebookSpawner` | ModuleScript | `.../NotebookSpawner.lua` |
| `BaldiGame/ChatReviveAI` | ModuleScript | `.../ChatReviveAI.lua` |
| `BaldiGame/LpAI` | ModuleScript | `.../LpAI.lua` |
| `BaldiGame/FrostyAI` | ModuleScript | `.../FrostyAI.lua` |
| `BaldiGame/SilverAI` | ModuleScript | `.../SilverAI.lua` |
| `BaldiGame/SweeperAI` | ModuleScript | `.../SweeperAI.lua` |
| `BaldiGame/DetentionSystem` | ModuleScript | `.../DetentionSystem.lua` |
| `BaldiGame/ItemEconomy` | ModuleScript | `.../ItemEconomy.lua` |
| `BaldiGame/ExitDoorManager` | ModuleScript | `.../ExitDoorManager.lua` |
| `ReplicatedStorage/BaldiShared` | Folder | — |
| `BaldiShared/GameConfig` | ModuleScript | `src/ReplicatedStorage/BaldiShared/GameConfig.lua` |
| `BaldiShared/AssetConfig` | ModuleScript | `.../AssetConfig.lua` |
| `StarterPlayer/StarterPlayerScripts/BaldiClient` | Folder | — |
| `BaldiClient/Main` | **LocalScript** | `src/.../BaldiClient/Main.client.lua` |
| `BaldiClient/UiKit` | ModuleScript | `.../UiKit.lua` |
| `BaldiClient/SoundController` | ModuleScript | `.../SoundController.lua` |
| `BaldiClient/InputHandler` | ModuleScript | `.../InputHandler.lua` |
| `BaldiClient/HudController` | ModuleScript | `.../HudController.lua` |
| `BaldiClient/StaminaController` | ModuleScript | `.../StaminaController.lua` |
| `BaldiClient/ItemUseClient` | ModuleScript | `.../ItemUseClient.lua` |
| `BaldiClient/VendingMachineUI` | ModuleScript | `.../VendingMachineUI.lua` |
| `BaldiClient/DetentionOverlay` | ModuleScript | `.../DetentionOverlay.lua` |
| `BaldiClient/FrostyVignette` | ModuleScript | `.../FrostyVignette.lua` |
| `BaldiClient/SilverMinigame` | ModuleScript | `.../SilverMinigame.lua` |
| `BaldiClient/MenuController` | ModuleScript | `.../MenuController.lua` |

Watch the class types: `Main` under BaldiGame is a **Script**, `Main` under
BaldiClient is a **LocalScript**, everything else is a **ModuleScript**.

### Option B — one-paste installer (fast)

Copy all of `installer/InstallBaldiGame.lua` into the Studio command bar
(View → Command Bar) and press Enter. It creates the whole tree above in one
go and cleanly replaces a previous install. Your map and your `BaldiAssets`
folder are never touched — but it DOES reset `BaldiShared/AssetConfig`, so
if you pasted ids in there, copy them somewhere first before re-running it.

---

## 2. Build your map

Make a Folder in **Workspace** named `BaldiMap`. The moment it exists, the
placeholder school is skipped and yours is used.

```
Workspace
└── BaldiMap
    ├── Geometry          ← everything visible: floors, walls, rooms, furniture
    │   ├── ExitDoor      ← a Part — turns green and wins the game when touched
    │   ├── LobbySpawn    ← a SpawnLocation — players wait here while in the menu
    │   │                   (put it in a separate room away from the school!)
    │   ├── VendingMachine_BSODA      ← optional Part/Model; prompt added for you
    │   ├── VendingMachine_ZESTY      ← optional Part/Model
    │   ├── VendingMachine_SCISSORS   ← optional Part/Model
    │   └── VendingMachine_ALARM      ← optional Part/Model
    ├── Markers           ← invisible anchored parts marking positions:
    │   ├── RoundSpawn        players start a round here, facing the part's front
    │   ├── DetentionSpot     where LP's victims get locked
    │   ├── ChatReviveSpawn   ┐
    │   ├── LpSpawn           ├ where each character stands at round start
    │   ├── FrostySpawn       │
    │   ├── SilverSpawn       ┘
    │   └── MENU_CAMERA       optional; the main menu's camera sits on this
    │                         part, looking the way its front face points —
    │                         move/rotate it in Studio to frame the shot
    ├── SweepRoutes       ← optional; one folder per sweeper holding its route:
    │   ├── Guidelines        parts named 1, 2, 3... walked in order, then
    │   └── Sai               reversed. 2 parts = a straight hallway run.
    ├── Waypoints         ← invisible anchored parts; NPCs roam between them.
    │                       Spread 10–20 around halls and rooms.
    ├── NotebookSpawns    ← invisible anchored parts; 10 are picked at random
    │                       each round. Place 15–25 for good variety.
    ├── NickelSpawns      ← optional; a couple of starter coins appear here
    └── ItemSpawns        ← optional; parts named exactly BSODA / ZESTY /
                            SCISSORS / ALARM give one free pickup each per round
```

Tips:

- Make marker/waypoint parts **Anchored**, CanCollide off, Transparency 1,
  and place them roughly at floor level — heights are corrected in code.
- Keep doorways at least ~5 studs wide (8+ is comfortable) so the pathfinding
  agent fits through. **Doorways that are too narrow are the #1 reason NPCs
  won't follow you into a room.** A door part set `CanCollide = false` is
  ignored by pathfinding entirely (they walk right through it) — so the gap
  in the *wall* is what matters, not the door panel. If a real door swings,
  toggle its `CanCollide` rather than relying on the panel to block.
- Spread several **Waypoints** through every room and hall. NPCs roam between
  them; a room with no nearby waypoint rarely gets patrolled.
- Anything missing prints a warning with the expected path; missing markers
  fall back to default coordinates (which suit the placeholder school, not
  yours — so add all five markers early).
- You can also tag any part `NotebookSpawn` with the Tag Editor instead of
  putting it in the NotebookSpawns folder; both are collected.

## 3. Your characters

Make a Folder in **ReplicatedStorage** named `BaldiAssets`, with a `Npcs`
folder inside:

```
ReplicatedStorage
└── BaldiAssets
    └── Npcs
        ├── ChatRevive    ← Model
        ├── LP            ← Model
        ├── Frosty        ← Model
        ├── Silver        ← Model (the grabber)
        ├── Guidelines    ← Model (hall sweeper)
        └── Sai           ← Model (hall sweeper)
```

Rig requirements (R6, R15, or a custom skinned mesh all work):

- Must contain a **Humanoid** and a part named **HumanoidRootPart**.
  (Any rig made with Studio's Rig Builder or imported from Blender with the
  avatar importer already has both.)
- Don't worry about anchoring, collision groups, WalkSpeed, or bundled
  scripts — the factory unanchors, sets collision, and strips scripts.
- A name tag is added automatically unless your rig already has a
  BillboardGui.

### Animations

Put a Folder named `Animations` **inside each rig**, containing Animation
instances with your published animation ids:

```
ChatRevive
├── Humanoid
├── HumanoidRootPart
├── ... your parts ...
└── Animations
    ├── Idle    ← Animation (played standing still)
    ├── Walk    ← Animation (played while roaming)
    └── Chase   ← Animation (played at chase speed; optional, falls back to Walk)
```

All three are optional. Tracks loop and crossfade automatically; Frosty
never plays Chase.

**If your animations don't play, check the Output window** — the loader
prints exactly what happened for each rig: `loaded N custom animation(s)`,
or a warning naming any animation whose id is blank or failed to load. The
two usual causes:

- **The AnimationId is blank.** Each `Animation` instance needs its
  `AnimationId` set to your published id (`rbxassetid://…`).
- **The id isn't published to this game's owner.** An animation only loads
  if it was published from the Animation Editor to the **same** account or
  group that owns this place. Re-export it under the right owner.

Until a rig has working animations, it still **moves**: any standard R6 rig
(and the placeholder block characters) falls back to a code-driven
limb-swing walk, so you always see motion while you wire up the real ones.
A custom skinned mesh with no `Animations` folder will stand still — give it
the folder above.

## 4. Your item models

```
ReplicatedStorage
└── BaldiAssets
    └── Items
        ├── Notebook           ← the spinning collectible
        ├── Nickel             ← the coin pickup
        ├── BSODA              ← the world pickup can
        ├── ZESTY              ← the world pickup bar
        ├── SCISSORS           ← the world pickup scissors
        ├── ALARM              ← the alarm clock (pickup AND the placed,
        │                        ringing version when used)
        └── BsodaProjectile    ← optional: the flying blast visual
```

Each is a Model or a single Part. Clones are auto-anchored and
non-colliding; the collect prompt and spin/bob effect attach automatically.
Keep them pickup-sized (1–3 studs).

## 5. UI images & sounds

Open `ReplicatedStorage/BaldiShared/AssetConfig` and paste ids:

1. Studio → **Asset Manager** → Import your PNG (Decal).
2. Right-click the uploaded image → **Copy Asset ID**.
3. Paste as `"rbxassetid://<number>"` into the matching entry.

Image slots: menu / countdown / win / lose backgrounds, detention and frost
overlays (use semi-transparent PNGs), notebook + nickel icons, item slot
background, item pictures (BSODA / ZESTY), stamina bar back + fill, PLAY
button, panels. Sound slots: every UI sound plus ChatRevive's chase noise
and LP's whistle. Anything left `""` keeps its placeholder.

Note: the stamina fill image is tinted green/yellow/red by code — draw it
white/grey so the tint reads.

---

## Suggested build order

1. Install scripts → press Play → full game with placeholders.
2. Build `BaldiMap` (geometry + the five markers + waypoints + notebook
   spawns) → Play → your school, block characters.
3. Drop in `BaldiAssets/Npcs` rigs → Play → your characters chase you.
4. Add `Animations` folders → they walk properly.
5. Add `BaldiAssets/Items` models, then AssetConfig images/sounds last.

Every number worth tuning (speeds, stamina, costs, detention time, sight
ranges) lives in `ReplicatedStorage/BaldiShared/GameConfig`.
