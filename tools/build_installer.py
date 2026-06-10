#!/usr/bin/env python3
"""
Generates installer/InstallBaldiGame.lua from the src/ tree.

The output is a single Lua file you paste into Roblox Studio's command bar.
It recreates the exact instance tree Rojo would sync:

    ServerScriptService/BaldiGame/...   (Script + ModuleScripts)
    ReplicatedStorage/BaldiShared/...   (ModuleScripts)
    StarterPlayer/StarterPlayerScripts/BaldiClient/...  (LocalScript + ModuleScripts)

File-name conventions (same as Rojo):
    *.server.lua -> Script        *.client.lua -> LocalScript
    *.lua        -> ModuleScript
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "installer", "InstallBaldiGame.lua")

# bracket level for embedding sources; asserted collision-free below
LEVEL = "=" * 5
OPEN = "[" + LEVEL + "["
CLOSE = "]" + LEVEL + "]"

# maps the first src/ path segment(s) to the installer root key
ROOTS = {
    "ServerScriptService": "ServerScriptService",
    "ReplicatedStorage": "ReplicatedStorage",
    "StarterPlayer/StarterPlayerScripts": "StarterPlayerScripts",
}


def classify(filename):
    if filename.endswith(".server.lua"):
        return filename[: -len(".server.lua")], "Script"
    if filename.endswith(".client.lua"):
        return filename[: -len(".client.lua")], "LocalScript"
    return filename[: -len(".lua")], "ModuleScript"


def collect_files():
    entries = []
    for dirpath, _dirnames, filenames in os.walk(SRC):
        for filename in sorted(filenames):
            if not filename.endswith(".lua"):
                continue
            full = os.path.join(dirpath, filename)
            rel = os.path.relpath(full, SRC).replace(os.sep, "/")

            root_key = None
            remainder = None
            for prefix, key in ROOTS.items():
                if rel.startswith(prefix + "/"):
                    root_key = key
                    remainder = rel[len(prefix) + 1 :]
                    break
            if root_key is None:
                sys.exit(f"unmapped source path: {rel}")

            parts = remainder.split("/")
            folders = parts[:-1]
            name, classname = classify(parts[-1])

            with open(full, "r", encoding="utf-8") as handle:
                source = handle.read()
            if CLOSE in source or OPEN in source:
                sys.exit(f"bracket collision in {rel}; raise LEVEL")

            entries.append(
                {
                    "root": root_key,
                    "folders": folders,
                    "name": name,
                    "class": classname,
                    "source": source,
                }
            )
    # load order inside the installer doesn't matter (everything is created
    # before play), but a stable order keeps diffs clean
    entries.sort(key=lambda e: (e["root"], e["folders"], e["class"] != "Script", e["name"]))
    return entries


def emit(entries):
    lines = []
    lines.append("--[[")
    lines.append("\tInstallBaldiGame.lua  (GENERATED — do not edit; run tools/build_installer.py)")
    lines.append("")
    lines.append("\tHOW TO USE:")
    lines.append("\t  1. Open Roblox Studio with any place (an empty Baseplate is fine).")
    lines.append("\t  2. View -> Command Bar.")
    lines.append("\t  3. Paste this ENTIRE file into the command bar and press Enter.")
    lines.append("\t  4. Press Play. The school builds itself at runtime.")
    lines.append("")
    lines.append("\tRe-running the installer replaces any previous install.")
    lines.append("]]")
    lines.append("")
    lines.append("local function getRoot(rootName)")
    lines.append('\tif rootName == "StarterPlayerScripts" then')
    lines.append('\t\treturn game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")')
    lines.append("\tend")
    lines.append("\treturn game:GetService(rootName)")
    lines.append("end")
    lines.append("")
    lines.append("local function ensureFolder(parent, name)")
    lines.append("\tlocal existing = parent:FindFirstChild(name)")
    lines.append('\tif existing then')
    lines.append("\t\treturn existing")
    lines.append("\tend")
    lines.append('\tlocal folder = Instance.new("Folder")')
    lines.append("\tfolder.Name = name")
    lines.append("\tfolder.Parent = parent")
    lines.append("\treturn folder")
    lines.append("end")
    lines.append("")
    lines.append("-- wipe any previous install")
    lines.append("for _, target in ipairs({")
    lines.append('\t{ "ServerScriptService", "BaldiGame" },')
    lines.append('\t{ "ReplicatedStorage", "BaldiShared" },')
    lines.append('\t{ "StarterPlayerScripts", "BaldiClient" },')
    lines.append("}) do")
    lines.append("\tlocal root = getRoot(target[1])")
    lines.append("\tlocal old = root and root:FindFirstChild(target[2])")
    lines.append("\tif old then")
    lines.append("\t\told:Destroy()")
    lines.append("\tend")
    lines.append("end")
    lines.append("")
    lines.append("local files = {")

    for entry in entries:
        folders = ", ".join(f'"{name}"' for name in entry["folders"])
        lines.append("\t{")
        lines.append(f'\t\troot = "{entry["root"]}",')
        lines.append(f"\t\tfolders = {{ {folders} }},")
        lines.append(f'\t\tname = "{entry["name"]}",')
        lines.append(f'\t\tclass = "{entry["class"]}",')
        # the newline right after OPEN is consumed by Lua's long-string rule
        lines.append(f"\t\tsource = {OPEN}\n{entry['source']}{CLOSE},")
        lines.append("\t},")

    lines.append("}")
    lines.append("")
    lines.append("for _, file in ipairs(files) do")
    lines.append("\tlocal parent = getRoot(file.root)")
    lines.append("\tfor _, folderName in ipairs(file.folders) do")
    lines.append("\t\tparent = ensureFolder(parent, folderName)")
    lines.append("\tend")
    lines.append("\tlocal instance = Instance.new(file.class)")
    lines.append("\tinstance.Name = file.name")
    lines.append("\tinstance.Source = file.source")
    lines.append("\tinstance.Parent = parent")
    lines.append("end")
    lines.append("")
    lines.append(f'print("[BaldiGame] Installed " .. #files .. " scripts. Press Play to test!")')
    return "\n".join(lines) + "\n"


def main():
    entries = collect_files()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write(emit(entries))
    print(f"wrote {OUT} ({len(entries)} scripts embedded)")


if __name__ == "__main__":
    main()
