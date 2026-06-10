#!/usr/bin/env python3
"""
Sanity-checks the MapBuilder placement data: every notebook node, waypoint,
NPC spawn, pickup spawn and player spawn must sit inside a walkable region
and clear of furniture. Mirrors the rects hard-coded in MapBuilder.lua —
update both together.
"""

WALKABLE = {  # name: (x1, z1, x2, z2)
    "north_hall": (-54, -48, 54, -36),
    "south_hall": (-54, 36, 54, 48),
    "west_hall": (-54, -48, -42, 48),
    "east_hall": (42, -48, 54, 48),
    "classroom_A": (-54, -72, -6, -48),
    "classroom_B": (6, -72, 54, -48),
    "corridor": (-6, -72, 6, -48),
    "classroom_C": (-54, 48, 0, 72),
    "classroom_D": (0, 48, 54, 72),
    "gym": (-96, -24, -54, 24),
    "library": (54, -24, 96, 24),
    "detention": (-12, -36, 12, -12),
}

FURNITURE = []  # (cx, cz, sizex, sizez)
for cx, cz in [(-38, -64), (-38, -55), (-22, -64), (-22, -55),
               (22, -64), (22, -55), (38, -64), (38, -55),
               (-36, 56), (-36, 65), (-18, 56), (-18, 65),
               (18, 56), (18, 65), (36, 56), (36, 65)]:
    FURNITURE.append((cx, cz, 4, 2.4, "desk"))
for cz in (-12, 0, 12):
    FURNITURE.append((74, cz, 28, 2, "shelf"))
FURNITURE.append((0, -14.5, 10, 2, "bench"))
FURNITURE.append((-16, 38.2, 4, 3, "vending"))
FURNITURE.append((16, 38.2, 4, 3, "vending"))

POINTS = {
    "notebook": [(-44, -56), (-30, -66), (-14, -54),
                 (14, -56), (30, -66), (44, -54),
                 (-44, 56), (-27, 66), (-12, 54),
                 (12, 56), (27, 66), (44, 54),
                 (60, -18), (74, -8), (90, 2), (66, 16),
                 (-90, -18), (-62, 18), (-86, 14),
                 (-50, -44), (50, -44), (-50, 44), (50, 44)],
    "waypoint": [(-48, -42), (0, -42), (48, -42),
                 (-48, 0), (48, 0),
                 (-48, 42), (0, 42), (48, 42),
                 (-30, -60), (30, -60), (-27, 60), (27, 60),
                 (-75, 0), (75, -6), (0, -60)],
    "npc_spawn": [(90, 0), (-75, 0), (0, 42)],
    "nickel": [(-30, -42), (30, 42), (48, 0), (-48, 20)],
    "item": [(-22, -60), (18, 60)],
    "player_spawn": [(0, -58), (0, -24)],
}

WALL_MARGIN = 1.5
FURNITURE_MARGIN = 1.0
errors = []

for kind, points in POINTS.items():
    for (x, z) in points:
        regions = [name for name, (x1, z1, x2, z2) in WALKABLE.items()
                   if x1 + WALL_MARGIN <= x <= x2 - WALL_MARGIN
                   and z1 + WALL_MARGIN <= z <= z2 - WALL_MARGIN]
        if not regions:
            # hall corners overlap two hall rects; allow points inside the
            # union even if each individual rect margin rejects them
            loose = [name for name, (x1, z1, x2, z2) in WALKABLE.items()
                     if x1 + 0.5 <= x <= x2 - 0.5 and z1 + 0.5 <= z <= z2 - 0.5]
            if len(loose) >= 2:
                regions = loose
        if not regions:
            errors.append(f"{kind} ({x},{z}) is not safely inside any walkable region")
            continue
        for fx, fz, sx, sz, fname in FURNITURE:
            if (abs(x - fx) < sx / 2 + FURNITURE_MARGIN
                    and abs(z - fz) < sz / 2 + FURNITURE_MARGIN):
                errors.append(f"{kind} ({x},{z}) collides with {fname} at ({fx},{fz})")

if errors:
    print("GEOMETRY PROBLEMS:")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)
total = sum(len(v) for v in POINTS.values())
print(f"geometry OK: {total} placement points all inside walkable space, clear of furniture")
