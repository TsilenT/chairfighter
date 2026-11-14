# Chairfighter

A 2D action platformer / mini-metroidvania where a basic chair defeats boss
furniture and unlocks chair transformations — each opening new routes through
an interconnected world. The furniture went to war. Only one chair can end it.

## The arc

The Upholstered King has taken every seat in the house. Ottoman Otto holds
the Workshop while you take the floors back, one door and one form at a time.

| Floor | Guardian | Reward |
|---|---|---|
| The Lounge | Recliner Baron | Armchair |
| The Boiler Room | Boiler Foreman | Recliner |
| The Office Complex | Swivel Executive | Office Chair |
| The Night Bar | Velvet Bartender | Bar Stool |
| The Storage Closet | Steel Folder | Folding Chair |
| The Nursery | Nursery Nanny | High Chair |
| The Parlor | Granny Tremor | Rocking Chair |
| The Conservatory | Canopy Bouncer | Spring Stool |

The Workshop doors are spread across the house. Grapple to the Boiler
catwalk, brace against the Office relief valve, and dash through the west
service baffle to the Night Bar. Reflect a shot into the Storage bell, fold
under the linen cabinet to reach the Nursery, and throw a tray into the
Parlor catch. The Conservatory is below the east hatch, which opens with
a Rocking Chair slam. From the drains, the Spring Stool can reach the
Throne landing. The royal workshop tests all eight forms before the King.
Casual difficulty: checkpoints heal, respawns keep progress, bosses retain
most damage between attempts.

| Earned form | Chair power |
|---|---|
| Armchair | Grapple gold hooks |
| Recliner | Block a frontal hit, then release and attack to counter |
| Office Chair | Dash through cracked barriers |
| Bar Stool | Spin and reflect projectiles |
| Folding Chair | Fold flat through low gaps and vents |
| High Chair | Throw its tray as a ranged attack |
| Rocking Chair | Slam downward through cracked floors |
| Spring Stool | Pogo-jump once in midair |

## Controls

| Action | Keyboard | Gamepad | Landscape touch |
|---|---|---|---|
| Move | A/D or Left/Right | Stick or D-pad | Left/right pad |
| Enter door | W, Up, or F | Y or D-pad Up | Enter appears at an open door |
| Jump higher | Hold Space | Hold A | Hold Jump |
| Attack | J or Z | X | Attack |
| Chair power | K or X | B | Button named for the equipped power |
| Quick switch | Q/E | LB/RB | Forms opens the direct selector |
| Form selector | Tab | Select/View | Forms |
| Pause | Esc | Start/Menu | Pause |

## Run it

1. Install Godot 4.6+: https://godotengine.org/download/
2. `godot --path .` (or open in the editor and press F5). This Windows
   checkout also has the local launcher `.\bin\godot.cmd`.

For the mobile browser build, export the Web preset and serve the export
directory over HTTP. Open it in landscape and tap Play. For the desktop
touch-layout preview, run `godot --path . -- --touch-preview`.

## Verify it

```bash
tools/run_tests.sh                      # unit + physics-metrics + zone-geometry gate
tools/capture_playthrough.sh check     # full title→ending playthrough, headless
tools/capture_playthrough.sh video     # same run, recorded to build/playthrough/
```

The playthrough driver plays the entire game through the real input path —
if it prints `DEMO PASS`, the game is beatable start to finish.

## Structure

- `autoload/` — Events bus, GameState, AudioManager, DemoDriver
- `src/` — player, forms, components, world objects, enemies, bosses, zones, UI, fx
- `scenes/` — zone/boss/player/UI scenes
- `assets/audio/` — generated SFX + music (see `tools/gen_sfx.py`, `tools/gen_music.py`)
- `tests/` — test harness, geometry validator, playthrough scripts
- `docs/ZONE_CONTRACT.md` — binding rules for building zones

All art is code-drawn (`_draw()` + StyleBoxFlat); all audio is generated.
No external assets.
