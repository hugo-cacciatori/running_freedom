# Running Freedom

Run indoors and before receiving Running Shoes in **gen1recomp**, at 8 frames per tile (twice walking speed). In Gen 3 games running is a toggle: press the run button (`B` by default) once while walking around to start running, and again to walk; you do not hold anything. In Gen 1 and Gen 2 you hold `B` to run. Active whenever the mod is loaded; no settings or extra key bindings.

Supports all three generations on **gen1recomp 0.3.96** (`"games": ["all"]`):
- **Gen 3 (`firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`):** Removes the Running Shoes progression requirement everywhere, enables indoor running in Ruby, Sapphire, and Emerald (FireRed and LeafGreen already allow indoor running natively), and makes `B` a run on/off switch. A `B` press only switches when you are free to walk (not in a menu, dialogue, cutscene or on a bike), and the press that closes a menu or dialogue never switches. Running starts off each time you launch the game.
- **Gen 1 (`red`, `blue`, `yellow`) & Gen 2 (`gold`, `silver`, `crystal`):** Adds 8-frame `B`-button running indoors and outdoors from the start of the game via the engine's `movement.speed` hook, and keeps Gen 1 `stepFramesCur` synchronized on `world.stepped` so NPC escort scripts never desync.

## Installation

Download the ZIP from [Releases](https://github.com/hugo-cacciatori/running_freedom/releases), extract its `running_freedom` folder into your game's `mods/` folder, enable it in the mod manager, and launch any supported game. To remove its effects, disable it and restart the game. Save files and progression flags are never modified.

Native movement speed, collisions, scripted movement, and terrain restrictions remain in place:
- Does not allow running on Gen 3 long grass, hot springs, underwater maps, or even-elevation Fortree bridges where the engine forbids it.
- Does not alter cycling, downhill cycling, surfing, ledge-hopping, spinning tiles, or scripted player walks.
- Excludes overlapping sprint mods (`gen1_wild_qol`, `gen1_sprint`).

## Development

The repository holds the mod's source and its headless test suites. Releases are built and verified with the project's build tooling: the suites run on the packaged zip in an external engine copy, then against a staged copy of the installed game and its imported data. Install the release zip.
