# SCHOOLHOUSE SURVIVAL

A complete, working Roblox game inspired by **Baldi's Basics**: collect all 10
notebooks scattered around a school, manage your stamina, buy items with
Nickels, dodge three very different AI characters, and escape through the
EXIT door.

**The code is built for YOUR assets.** You hand-build the map, the character
rigs, the animations, the item models, and the UI art in Studio — the scripts
find them by name and folder. Anything you haven't made yet falls back to a
code-generated placeholder (a full stand-in school, block rigs, plain-colored
UI), so the game runs out of the box and you replace pieces one at a time.

**→ [STUDIO_SETUP.md](STUDIO_SETUP.md) is the guide for plugging in your
map, characters, animations, models, images and sounds.**

---

## How to install (pick one)

### Option A — paste each script (recommended while developing)

Follow the table in [STUDIO_SETUP.md](STUDIO_SETUP.md#1-install-the-scripts):
create the folders, paste each `src/` file into a matching
Script/LocalScript/ModuleScript.

### Option B — one-paste installer

1. Open **Roblox Studio** → any place (an empty Baseplate works).
2. **View → Command Bar**.
3. Copy the **entire** [`installer/InstallBaldiGame.lua`](installer/InstallBaldiGame.lua),
   paste into the command bar, press **Enter**.
4. `[BaldiGame] Installed 29 scripts.` → press **Play** (F5).

Re-running it replaces the previous install (your map/assets are untouched,
but your `AssetConfig` ids get reset — save them first).
Regenerate after editing `src/` with `python3 tools/build_installer.py`.

### Option C — Rojo (live file sync)

`rojo serve` in the repo root, connect the Studio plugin. `default.project.json`
maps `src/` into the right services.

---

## How to play

| Input | Action |
|---|---|
| WASD / left stick | Move |
| **Shift** (hold) / mobile **RUN** toggle | Sprint (drains stamina) |
| **E** / mobile **USE** | Use item in slot 1 — also collects notebooks / opens vending machines when prompted |
| **Q** / mobile **SWAP** | Swap item slots |

**Goal:** PLAY → collect all **10 notebooks** (E near a notebook) → the EXIT
door turns green → touch it to escape. Your time is tracked; beat your best.

**The cast:**

| Character | Archetype | Behaviour |
|---|---|---|
| **ChatRevive** | Relentless hunter | **Knows where you are from anywhere** and continuously re-paths to your live position — round a corner and he follows you in, he doesn't forget. Keep distance only by sprinting (24 vs his 19), stun him (BSODA), chill him (Frosty), or reach the exit. Catch = game over + drops a Nickel. **Enrages at 10/10 notebooks** (speed 23). |
| **LP** | Rule enforcer | Ignores you until he **sees** you moving **faster than 20** (sprint = 24, walk = 16). Once provoked he chases your live position and **speeds up while you keep running** (25 — faster than a sprint), easing back to 18 when you walk. Escape = stop running *and* break his line of sight. Caught = **15s detention**, not game over. |
| **Frosty** | Passive roamer | Never chases. Within 7 studs you're chilled: 0.4× speed for 4s (chills ChatRevive and LP too — lead them through him!). |

**Items** (2 slots, slot 1 active): **BSODA** knocks a character back 20 studs
and stuns 3s. **Zesty Bar** refills stamina instantly. **Nickels** are
currency for the two vending machines.

**Stamina:** sprint drains 10/s, regen 6/s; at 0 you're exhausted and sprint
locks until 30.

Activation gating: 0 notebooks = everyone frozen → 1st notebook = everyone
wakes ("You hear footsteps...") → 10th = ChatRevive enrages + exit opens.

---

## The Roblox structure

```
ServerScriptService
└── BaldiGame                  (Folder)
    ├── Main                   (Script)        — bootstrap, init order, ctx wiring
    ├── RemoteSetup            (ModuleScript)  — creates the RemoteEvents folder
    ├── AssetResolver          (ModuleScript)  — finds YOUR models, warns once if missing
    ├── MapResolver            (ModuleScript)  — reads YOUR Workspace/BaldiMap
    ├── PlaceholderMap         (ModuleScript)  — stand-in school when you have no map yet
    ├── NpcFactory             (ModuleScript)  — clones YOUR rigs (or builds block rigs)
    ├── NpcAnimator            (ModuleScript)  — plays YOUR Idle/Walk/Chase animations
    ├── NpcBase                (ModuleScript)  — pathfinding/LoS/stun/slow shared base
    ├── GameManager            (ModuleScript)  — round state machine, win/lose, gating
    ├── NotebookSpawner        (ModuleScript)  — Fisher-Yates pick of YOUR spawn points
    ├── ChatReviveAI           (ModuleScript)  — on-sight chaser
    ├── LpAI                   (ModuleScript)  — condition chaser (speed + LoS)
    ├── FrostyAI               (ModuleScript)  — passive roamer + proximity debuff
    ├── DetentionSystem        (ModuleScript)  — teleport, anchor, countdown, release
    ├── ItemEconomy            (ModuleScript)  — inventory, nickels, vending, BSODA
    └── ExitDoorManager        (ModuleScript)  — locked/open door, win trigger

ReplicatedStorage
├── BaldiShared                (Folder)
│   ├── GameConfig             (ModuleScript)  — every tunable number
│   └── AssetConfig            (ModuleScript)  — PASTE YOUR image/sound ids here
├── BaldiAssets                (Folder)        — YOU create this (see STUDIO_SETUP.md)
│   ├── Npcs                   — ChatRevive / LP / Frosty rigs (+ Animations folders)
│   └── Items                  — Notebook / Nickel / BSODA / ZESTY models
├── BaldiRemotes               (Folder)        — 20 RemoteEvents (created at runtime)
└── BaldiModels                (Folder)        — placeholder notebook (runtime, fallback only)

StarterPlayer
└── StarterPlayerScripts
    └── BaldiClient            (Folder)
        ├── Main               (LocalScript)   — client bootstrap
        ├── UiKit              (ModuleScript)  — UI helpers; ImageLabel slots for your art
        ├── SoundController    (ModuleScript)  — your sounds via AssetConfig, else built-ins
        ├── InputHandler       (ModuleScript)  — Shift/E/Q + mobile button routing
        ├── HudController      (ModuleScript)  — Baldi-style HUD (counter top-left, slots top-right)
        ├── StaminaController  (ModuleScript)  — drain/regen/exhaustion/debuff
        ├── ItemUseClient      (ModuleScript)  — slot mirror, use/swap input
        ├── VendingMachineUI   (ModuleScript)  — buy popup
        ├── DetentionOverlay   (ModuleScript)  — countdown overlay
        ├── FrostyVignette     (ModuleScript)  — icy screen edges
        └── MenuController     (ModuleScript)  — menu, countdown, win/lose screens

Workspace
└── BaldiMap                   (Folder)        — YOUR map (or the generated placeholder)
    ├── Geometry               — your school; ExitDoor, LobbySpawn, vending machines
    ├── Markers                — RoundSpawn, DetentionSpot, 3 NPC spawn points
    ├── Waypoints              — parts the NPCs roam between
    ├── NotebookSpawns         — parts where notebooks may appear (10 picked/round)
    ├── NickelSpawns           — optional starter-coin points
    ├── ItemSpawns             — optional free BSODA/ZESTY points
    └── Notebooks / Pickups / Npcs / Projectiles   — runtime containers
```

## Design notes

- **UI mimics the original game**: Comic-style font (Cartoon), notebook
  counter as plain outlined text top-left, white item squares top-right —
  and every background/icon/button is an ImageLabel slot fed from
  `AssetConfig`, so your art drops straight in.
- **NPC movement is built for hand-made maps** (`NpcBase`): chasers
  continuously re-path to your *live* position so they follow you through
  doorways instead of stalling at the threshold; a small jump-capable
  pathfinding agent (radius 2) fits normal doorways and clears small lips;
  stuck detection + an unstick nudge recover from wedging on geometry rather
  than grinding into it; and an NPC never blindly straight-lines into a wall.
  Keep doorways ~5+ studs wide for clean paths. Tune in `GameConfig.NPC.AGENT`.
- **Animations always show something** (`NpcAnimator`): your `Animations`
  folder (Idle/Walk/Chase) is used when present, with clear Output warnings if
  an id is blank or unpublished; otherwise a procedural limb-swing walk drives
  any standard R6 rig (including the placeholder block characters).
- **LP checks horizontal velocity, not WalkSpeed** — client WalkSpeed never
  replicates, so the velocity check is both possible and cheat-proof, and it
  doubles as the "are you still breaking the rule?" test that ramps his speed.
- **Catches use a 4-stud radius check, not `Touched`** — deterministic on
  welded rigs.
- **Server-authoritative everything**: inventory, nickels, vending, BSODA
  trajectory, detention, win/lose all validated server-side.
- A couple of starter Nickels + one free BSODA/Zesty spawn per round so a
  tester can try the economy without dying first
  (`GameConfig.NICKELS_AT_ROUND_START` / `WORLD_ITEMS_AT_ROUND_START`).

## Testing checklist

- [ ] Menu appears; PLAY → 3-2-1 countdown → first-person spawn.
- [ ] HUD: notebooks top-left, item squares top-right, stamina bottom.
- [ ] Sprint drains the bar; at 0 it flashes red, shakes, locks until 30.
- [ ] Notebook #1 wakes all three NPCs ("You hear footsteps...").
- [ ] ChatRevive chases on sight; catch shows CAUGHT! + drops a Nickel.
- [ ] Sprinting in LP's sight → detention with a 15s countdown, then release.
- [ ] Frosty's chill: icy vignette + slow (and slows other NPCs).
- [ ] Vending machines: prompt → popup → buying with 0 Nickels fails politely.
- [ ] BSODA knocks a character back 20 studs and stuns (white flash).
- [ ] Zesty refills stamina mid-exhaustion.
- [ ] 10/10: "GET TO THE EXIT!", door green, ChatRevive enraged.
- [ ] Green door → ESCAPED! with time + session best; Retry restarts.
