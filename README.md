# Running Freedom

Run indoors and before receiving Running Shoes in **gen1recomp**. Hold the normal run button (`B` by default) to run at 8 frames per tile (twice walking speed). Both changes apply whenever the mod is loaded; there are no settings, toggles, or extra key bindings.

Supports all three generations on **gen1recomp 0.3.96** (`"games": ["all"]`):
- **Gen 3 (`firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`):** Removes the Running Shoes progression requirement everywhere and enables indoor running in Ruby, Sapphire, and Emerald (FireRed and LeafGreen already allow indoor running natively).
- **Gen 1 (`red`, `blue`, `yellow`) & Gen 2 (`gold`, `silver`, `crystal`):** Adds 8-frame `B`-button running indoors and outdoors from the start of the game via the engine's `movement.speed` hook, and keeps Gen 1 `stepFramesCur` synchronized on `world.stepped` so NPC escort scripts never desync.

## Installation

Download the ZIP from [Releases](https://github.com/hugo-cacciatori/running_freedom/releases), extract its `running_freedom` folder into your game's `mods/` folder, enable it in the mod manager, and launch any supported game. To remove its effects, disable it and restart the game. Save files and progression flags are never modified.

Native movement speed, collisions, scripted movement, and terrain restrictions remain in place:
- Does not allow running on Gen 3 long grass, hot springs, underwater maps, or even-elevation Fortree bridges where the engine forbids it.
- Does not alter cycling, downhill cycling, surfing, ledge-hopping, spinning tiles, or scripted player walks.
- Excludes overlapping sprint mods (`gen1_wild_qol`, `gen1_sprint`).

## Development

 Run the headless integration suite against the engine checkout:

```powershell
python tools/test.py --engine C:/path/to/gen1recomp-0.3.96
```

Version `0.2.0` passes 223 headless assertions across all 11 Gen 1–3 game profiles (`firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`, `red`, `blue`, `yellow`, `gold`, `silver`, `crystal`), plus standalone packaged verification against the installed `0.3.96` `.love` payload and imported `firered`, `emerald`, `red`, and `crystal` map caches.

Build the distributable bundle, ZIP, and `SHA256SUMS.txt` with `python tools/package.py`, then verify the archive outside the repository:

```powershell
python tools/test_package.py --engine C:/path/to/gen1recomp-0.3.96 --archive dist/v0.2.0/running_freedom-0.2.0.zip
python tools/test_installed.py --installation C:/Users/<you>/AppData/Roaming/pokemon-love2d --archive dist/v0.2.0/running_freedom-0.2.0.zip
```

