# 0.2.0

- Extend B-button running freedom to Gen 1 (`red`, `blue`, `yellow`) and Gen 2 (`gold`, `silver`, `crystal`) via `"games": ["all"]` and the engine's `movement.speed` hook.
- Synchronize Gen 1 `player.stepFramesCur` on `world.stepped` when idle so NPC escort scripts stay aligned at 16 frames after a B-run step.
- Preserve bicycle, downhill cycling, surfing, ledge-hop, spinner, and scripted movement speeds across all generations.
- Automatically clean temporary staging directories in `tools/test_package.py` and `tools/test_installed.py`.
- Verify 223 headless assertions across all 11 Gen 1–3 profiles plus installed indoor/outdoor map checks on `firered`, `emerald`, `red`, and `crystal`.

# 0.1.0

- Run before receiving Running Shoes in FireRed, LeafGreen, Ruby, Sapphire and Emerald.
- Run indoors in the Hoenn games; FireRed and LeafGreen already permit indoor running.
- Both features are active whenever the mod is loaded, with normal B-button controls and no settings.
- Preserve native movement speed, terrain restrictions and progression flags.
- Require gen1recomp 0.3.96; exclude the overlapping Gen1WildQOL mod.

Validation: 143 headless assertions across all five Gen 3 profiles. Packaged-mod checks also pass against the installed 0.3.96 payload and actual imported FireRed/Emerald indoor/outdoor maps, including complete eight-frame steps and rollback. Red/Crystal reject the manifest. The other three targets have synthetic-data coverage; graphical playthroughs and arbitrary mod combinations were not tested.

Install by extracting the ZIP's `running_freedom` folder into the game's `mods/` directory, enabling it in the mod manager, and launching a supported game. The ZIP and SHA256SUMS.txt match the local release artifacts.
