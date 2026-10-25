# Running Freedom

Run indoors and before receiving Running Shoes in **gen1recomp**. Hold the normal run button (B by default). Both changes apply whenever the mod is loaded; there are no settings, toggles or extra key bindings.

Targets FireRed, LeafGreen, Ruby, Sapphire and Emerald on gen1recomp 0.3.96. FireRed and LeafGreen already allow indoor running; the mod removes their shoe requirement. Hoenn games also gain indoor running. Other engine versions are deliberately excluded until checked.

## Installation

Download the ZIP from [Releases](https://github.com/hugo-cacciatori/running_freedom/releases), extract its `running_freedom` folder into your game's `mods/` folder, enable it in the mod manager, and launch a supported game. To remove its effects, disable it and restart the game. Your shoe ownership and progression flags are unchanged.

Native movement speed, collisions, scripted movement and terrain restrictions remain in place. This mod does not add running to long grass, hot springs or other terrain where the engine forbids it. It does not change cycling or surfing speeds.

Do not combine this with Gen1WildQOL's overlapping sprint implementation. Other mods that replace `Player.canDash` may conflict. This mod declares engine-internals access because the engine does not expose a native dash-eligibility hook.

## Development

Install Python and `lupa==2.6`, then run:

```powershell
python tools/test.py --engine C:/path/to/gen1recomp-0.3.96
```

Tests use LuaJIT and the real mod loader/player, with synthetic map data. They run without windows or ROMs. Full visual playthroughs are not implied by these checks.

Version 0.1.0 passes 143 native-loader/player assertions across all five targets, including input, speed, walls, script locks, terrain, save flags and removal/reload. The packaged mod also passes headless checks against the installed 0.3.96 game payload and actual FireRed/Emerald indoor and outdoor maps, outside the repository. Red and Crystal correctly skip it. LeafGreen, Ruby and Sapphire have synthetic-data native-profile coverage; full visual playthroughs and arbitrary mod combinations are not covered.

Build the mod folder, ZIP and checksums with `python tools/package.py`. The ZIP includes only the mod's manifest, entry script, README and license. Test its contents outside the repository with:

```powershell
python tools/test_package.py --engine C:/path/to/gen1recomp-0.3.96 --archive dist/v0.1.0/running_freedom-0.1.0.zip
```

For installed-data verification, use `tools/test_installed.py --installation <game-data-folder> --archive <zip>`. This copies the installed 0.3.96 `.love` and FireRed/Emerald data into a temporary directory, tests native movement without opening windows, and retains the temporary copy for inspection. User saves/options are not used.
