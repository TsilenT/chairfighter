# Zone Builder Contract (Chairfighter rebuild)

Binding contract for every zone-builder agent. Read the exemplars FIRST:
`scenes/zones/Workshop.tscn` (zone shape), `src/bosses/ReclinerBaron.gd` +
`scenes/bosses/ReclinerBaron.tscn` (boss shape), `tests/unit/test_zone_geometry.gd`
(the envelopes your geometry MUST satisfy).

## Hard rules

1. **Own only your files**: your zone .tscn, your zone script in `src/zones/`,
   your boss .tscn + script, your `tests/playthrough/seg_<zone>.json`. Never
   edit `project.godot`, autoloads, `src/` shared code, other zones, or tests.
2. **NO new `class_name` declarations** (stale-class-cache poison). Reference
   scripts via `ext_resource` paths exactly like Workshop.tscn does.
3. **Verify before finishing** (both must pass; flock serializes the engine):
   ```bash
   flock -w 900 /tmp/chairfighter_godot.lock godot --headless --path . --quit-after 3   # boots clean
   flock -w 900 /tmp/chairfighter_godot.lock bash tools/run_tests.sh                    # GATE: PASS
   ```
   If you see "Could not parse global class", run once:
   `flock -w 900 /tmp/chairfighter_godot.lock godot --headless --path . --import`
4. Numeric envelopes are hard requirements (validator enforces; see table).
5. Commit your files when green: `git add <your files> && git commit`.

## Coordinate conventions

- Zone root sits at world origin; y is DOWN. Design floors around y=400.
- Player: feet-origin, 44×56 standing, 32 dashing, 20 folded.
- `Platform.gd`: origin TOP-LEFT, `size` export. Walls = platforms with
  `decor = true` (skips reachability check). Non-decor platforms MUST be
  reachable (validator hunts bait geometry).
- `Door.gd`: origin CENTER of a 72×110 doorway → floor at y=400 ⇒ door y=345.
- Falling below `camera_limits` bottom +150 kills the player (kill floor is
  automatic; pits are fine but put a checkpoint reasonably close).

## Movement envelopes (validator-enforced; leave margin, don't max out)

| Leg mode | Constraint |
|---|---|
| walk | ascend ≤ 8px |
| jump | ascend ≤ 96px, horizontal span ≤ 170px |
| drop | descend only, span ≤ 170px |
| grapple (form=armchair) | anchor ≤ 360px from takeoff; landing ≤ 280px from anchor |
| dash_tunnel / speed_gate (form=office) | flat; span ≤ 900px; runway ≥ 400px flat before gate |
| vent (form=folding) | flat; passage height 26–28px (folded player is 20px) |
| spring (form=folding) | ascend ≤ 210px, span ≤ 130px |

Gating margins: anything meant to be UNreachable without an unlock must exceed
capability clearly (≥60px vertical beyond a 150px jump ⇒ ≥210px ledges; use
≥240px to also exceed spring where folding shouldn't trivialize it).
Dash tunnels are 40px tall (dash collider 32). Vents 26–28px (folded 20).

## Zone scene contract (structure — copy Workshop.tscn)

- Root Node2D + your `src/zones/<Zone>.gd` (2-line script `extends ZoneBase`),
  exports set in the scene: `zone_display_name`, `camera_limits`, `theme_res`
  (inline `[sub_resource]` ZoneTheme with your palette).
- `SpawnPoints/`: Marker2D children. MUST include `Default` (entry from hub)
  and one per returning door.
- `Geometry/`: Platform instances only (+ walls as decor platforms).
- `Route/`: sub-Node2D per intended route, ordered Marker2D children with
  `metadata/mode` + `metadata/form` (see envelope table; first marker mode
  `start`). Routes must cover: entrance→boss, and every ability-gated pocket.
- `Doors/`, `Hazards/` (Checkpoint, Spikes, SpeedGate, AbilityGate,
  MovingPlatform), `Enemies/`, `Boss/`, `Props/` (Labels for signage; keep it
  sparse and diegetic).
- Checkpoints: one near the entrance, one RIGHT BEFORE the boss arena
  (touching a checkpoint fully heals — that's the casual-difficulty valve).

## Boss contract (copy ReclinerBaron)

- Scene: root CharacterBody2D + your script (`extends BossBase` — path
  preload NOT needed; just `extends "res://src/bosses/BossBase.gd"` if the
  global class gives trouble). Child `TriggerZone` (Area2D + shape covering
  the arena approach). Optional `Blocker` (StaticBody2D + shapes) that
  BossBase enables during the fight.
- In `_ready()`: set `boss_id`, `display_name`, `max_health`,
  `unlock_form_id`, `body_half_width`, `body_height`, then `super._ready()`.
- Set `arena_rect` on the instance in your ZONE scene (zone coords) — size it
  ≈ one screen (1152×648) around the arena floor.
- Patterns: async Callables returned by `_patterns()`; EVERY attack starts
  with `await telegraph(0.4–0.6)`. Use helpers: `wait()`, `move_to_x()`,
  `hop()`, `spawn_projectile()`, `dir_to_player()`, `player_node()`.
  3 patterns + `_on_phase_two()` twist. Placeholder `_draw()` visual with
  personality (eyes! silhouette!) — Phase 4 re-skins.
- Casual tuning: boss deals 1 heart per hit (contact_damage 1), player has 5
  hearts + full-heal checkpoint at the door. Patterns must have clear gaps
  where a mid-range attacker (reach ~60–90px) lands 2–3 hits.
- The driver's auto_fight is a simple melee policy (approach, attack in
  range, periodic short hops, brief retreats when hit). Your boss MUST be
  beatable by that policy within ~3 respawns; avoid mandatory-dodge one-shot
  patterns and long invulnerable phases.

## Progression flags & forms (fixed vocabulary)

Forms: `basic`, `armchair`, `office`, `folding`.
Boss flags (auto from boss_id): `boss_recliner_defeated`, `boss_swivel_defeated`,
`boss_folder_defeated`, `boss_king_defeated`.
Zone scene paths: `res://scenes/zones/{Workshop,Lounge,OfficeComplex,StorageCloset,ThroneRoom}.tscn`.
Workshop return spawns (use as your exit-door target_spawn):
`FromLounge`, `FromOffice`, `FromStorage`, `FromThrone`.

## Playthrough segment (`tests/playthrough/seg_<zone>.json`)

JSON array of driver steps proving YOUR zone start→boss-dead→exit with real
input. Ops: `tap|press|release` (action), `jump` (hold=secs), `walk_until_x`
(x, tol, timeout; auto-hops small steps), `grapple` (hold-special helper),
`special_tap`, `special_hold` (secs), `transform_to` (form), `wait` (secs),
`wait_zone` (zone display name), `wait_flag` (flag), `wait_on_floor`,
`auto_fight` (boss=<boss_id>, flag=<defeat flag>), `assert_flag`,
`assert_zone`, `screenshot` (name). First steps for a segment:
```json
[{"op":"wait","secs":1.0},{"op":"tap","action":"ui_accept"},
 {"op":"wait_zone","zone":"The Workshop"},
 {"op":"cheat_setup","forms":["armchair"],"form":"armchair",
  "zone":"res://scenes/zones/OfficeComplex.tscn","spawn":"Default",
  "zone_name":"The Office Complex"}, ...]
```
Then walk/jump/fight to the boss and end with
`{"op":"assert_flag","flag":"boss_<id>_defeated"}`.
Segment test run:
```bash
flock -w 900 /tmp/chairfighter_godot.lock env CHAIRFIGHTER_DEMO=res://tests/playthrough/seg_<zone>.json \
  timeout 420 godot --headless --path . 2>&1 | tail -20   # expect "DEMO PASS"
```
(A segment that dies a couple times and retries via auto_fight is fine; one
that can't finish means your zone or boss needs retuning — fix it.)

## Quality bar

Playable > pretty > big. A tight 2500–4000px zone with 5–8 enemies, one
mid-zone mechanic showcase, readable signage, fair checkpoints, and a
characterful boss beats a sprawling maze. Silly furniture-war tone; the
player chair is silent; NPC dialogue only via existing patterns.
