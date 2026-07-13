# Chairfighter

A 2D action platformer / mini-metroidvania where a basic chair defeats boss
furniture and unlocks chair transformations — each opening new routes through
an interconnected world. The furniture went to war. Only one chair can end it.

## The arc

**Workshop hub** → The Lounge (**Recliner Baron** → Armchair grapple) →
The Office Complex (**Swivel Executive** → Office Chair dash) →
The Storage Closet (**Steel Folder** → Folding Chair fold/spring) →
The Throne Room gauntlet (**The Upholstered King** → the credits).

Every form has a traversal verb, a combat identity, and map gates it opens.
Casual difficulty: checkpoints heal, respawns keep progress, bosses retain
most damage between attempts.

## Controls (keyboard · controller-first bindings included)

| Action | Key |
|---|---|
| Move | A/D or ←/→ |
| Enter door | W / ↑ (in doorway) |
| Jump (hold = higher) | Space |
| Attack | J |
| Chair power (grapple / dash / fold) | K |
| Switch form | Q / E |
| Pause | Esc |

## Run it

1. Install Godot 4.6+: https://godotengine.org/download/
2. `godot --path .` (or open in the editor and press F5)

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
