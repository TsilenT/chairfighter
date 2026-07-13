# Chairfighter Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Deviation note:** This plan specifies complete code for *shared contracts* (the drift-fatal pieces) and precise acceptance criteria + verification commands for everything else, rather than full inline code per step. Executed overnight autonomously per operator brief; spec: `docs/superpowers/specs/2026-07-13-chairfighter-rebuild-design.md`.

**Goal:** Rip down the MVP and rebuild Chairfighter as a complete, verified-playable 4-form / 4-boss / 5-zone metroidvania with real visuals and an automated full playthrough.

**Architecture:** Godot 4.6 (`gl_compatibility`), zone scenes swapped by a `Game` root, signal-bus autoloads, component-based damage, resource-driven chair forms, declarative playthrough driver as the acceptance gate.

**Tech Stack:** GDScript only; SVG sprites (Godot-native import); `_draw()` terrain skins; Python-stdlib WAV generation; MovieWriter for capture.

**Branch:** `rebuild/full-arc`, merged to `master` only when Phase 3 gate is green. Never pushed to remotes tonight.

---

## Verification commands (used throughout)

```bash
# Parse/boot check
godot --headless --path . --quit-after 2

# Full test suite (physics metrics + geometry validator + unit checks)
godot --headless --path . -s res://tests/run_all.gd

# Full playthrough (headless gate)
CHAIRFIGHTER_DEMO=res://tests/playthrough/full_run.json godot --headless --path . --quit-after 100000

# Rendered capture (video + frames)
CHAIRFIGHTER_DEMO=res://tests/playthrough/full_run.json godot --path . --write-movie build/playthrough/run.avi --resolution 1280x720
```

## Shared contracts (LOCKED — all tasks conform to these)

### Collision layers

| Bit | Value | Use |
|---|---|---|
| 1 | 1 | World geometry |
| 2 | 2 | Player body |
| 3 | 4 | Enemy body |
| 4 | 8 | Hitboxes (damage dealers) |
| 5 | 16 | Hurtboxes (damage receivers) |
| 6 | 32 | Sensors (doors, gates, checkpoints, arena triggers) |

Player body collides with 1. Enemies collide with 1. Hitbox (Area2D, layer 8, mask 16) → Hurtbox (Area2D, layer 16, mask 8). Sensors (layer 32) mask player body (2).

### `autoload/Events.gd` (complete)

```gdscript
extends Node
## Global signal bus. Autoload name: Events.

signal form_unlocked(form_id: StringName)
signal form_changed(form_id: StringName)
signal player_health_changed(current: int, maximum: int)
signal player_died
signal player_respawned
signal boss_started(boss_id: StringName, display_name: String)
signal boss_health_changed(boss_id: StringName, current: float, maximum: float)
signal boss_defeated(boss_id: StringName)
signal zone_change_requested(zone_path: String, spawn_name: String)
signal zone_loaded(zone_name: String)
signal checkpoint_activated(zone_path: String, spawn_name: String)
signal game_won
signal hitstop_requested(duration: float)
signal screenshake_requested(strength: float, duration: float)
signal sfx_requested(sfx_name: StringName)
signal unlock_banner_requested(form_id: StringName, display_name: String, blurb: String)
```

### `autoload/GameState.gd` API (signatures locked)

```gdscript
extends Node
## Autoload name: GameState. Truth for progression. Emits via Events.

const FORM_ORDER: Array[StringName] = [&"basic", &"armchair", &"office", &"folding"]

var unlocked_forms: Array[StringName]      # starts [&"basic"]
var current_form: StringName               # starts &"basic"
var flags: Dictionary                      # e.g. {"boss_recliner_defeated": true}
var checkpoint_zone: String                # zone scene path
var checkpoint_spawn: String               # spawn marker name

func new_game() -> void                    # reset all, checkpoint = Workshop/Default
func unlock_form(id: StringName) -> void   # adds + emits form_unlocked, auto-switches
func is_unlocked(id: StringName) -> bool
func set_form(id: StringName) -> bool      # false if locked; emits form_changed
func cycle_form(dir: int) -> void
func set_flag(key: String) -> void
func has_flag(key: String) -> bool
func set_checkpoint(zone_path: String, spawn: String) -> void
```

### `src/player/FormDef.gd` (complete)

```gdscript
class_name FormDef
extends Resource
## One resource per chair form: src/forms/<id>.tres

@export var id: StringName
@export var display_name: String
@export var run_speed: float
@export var accel: float = 2600.0
@export var decel: float = 3000.0
@export var air_control: float = 0.65
@export var jump_height: float            # px, design metric — velocities DERIVED
@export var time_to_apex: float = 0.38
@export var fall_gravity_mult: float = 1.6
@export var attack_damage: float = 2.0
@export var attack_range: float = 52.0    # hitbox reach from center
@export var attack_cooldown: float = 0.3
@export var collider_height: float = 56.0
@export var body_color: Color             # placeholder tint until Phase 4
@export var sprite_path: String = ""      # SVG, Phase 4

func rise_gravity() -> float: return 2.0 * jump_height / (time_to_apex * time_to_apex)
func jump_velocity() -> float: return -rise_gravity() * time_to_apex
```

Form values (from spec): basic 340/150px · armchair 300/140px · office 380/130px (dash 700 px/s 0.35s, dash collider 32px) · folding 320/140px (folded walk 140, folded collider 20px, spring jump 230px).

### Zone scene contract (every zone conforms)

- Root `Node2D`, script `src/zones/<Zone>.gd` extending `src/zones/ZoneBase.gd`; exports `zone_display_name: String`, `camera_limits: Rect2`, `theme: ZoneTheme`.
- `SpawnPoints/` — `Marker2D` children; every zone has `Default`; doors reference spawn names.
- `Geometry/` — `Platform.tscn` instances only (auto-group `platforms`) + `Spikes`, `MovingPlatform`.
- `Route/` — ordered `Marker2D`s; each has metadata `mode` (`walk|jump|grapple|dash_tunnel|speed_gate|vent|spring`) and `form` — the intended path; consumed by geometry validator.
- `Doors/`, `Enemies/`, `Boss/` (optional), `Props/` (decor, ignored by validator).
- Player is NOT in zone scenes — `Game.gd` spawns it at the named spawn.

### Playthrough driver step schema (`tests/playthrough/*.json`)

Array of steps; ops: `tap|press|release` (action), `walk_until_x` (x, tol=8, timeout), `jump`, `hold_jump` (secs), `transform_to` (form), `special_tap`, `special_hold` (secs), `dash`, `wait` (secs), `wait_flag` (flag, timeout), `wait_zone` (zone, timeout), `wait_on_floor`, `auto_fight` (boss, timeout — built-in casual combat policy, retries through respawn), `assert_flag`, `assert_zone`, `assert_form`, `screenshot` (name — no-op headless), `interact`.
Driver: `autoload/DemoDriver.gd`, inert unless env `CHAIRFIGHTER_DEMO=<script path>`. On failure: print `DEMO FAIL: <step> <reason>`, exit code 1. On completion after `game_won`: print `DEMO PASS`, exit 0.

### Geometry validator rules (headless, per zone)

For each consecutive Route pair by `mode`: walk Δy≤4px · jump Δy≤96 & gap≤160 (per-form envelope from FormDef math) · grapple: anchor within 360px of leg start · dash_tunnel: tunnel height 40±2px, runway≥400px · vent: height 26–28px · spring: Δy 170–220px. Also: every non-decor platform reachable from some other standable surface with full unlocks; gated legs exceed prior-form capability by ≥60px vertical / ≥120px horizontal.

---

## Phase 0 — Teardown & scaffold

### Task 0.1: Teardown
**Files:** Delete `scenes/`, `scripts/`, `tests/` (old), `intake-layout.md` stays (historical), keep `SPEC.md`, `docs/`, `assets/` (empty anyway).
- [ ] `git checkout -b rebuild/full-arc`
- [ ] `git rm -r scenes scripts tests` — commit `chore: tear down MVP implementation for rebuild`

### Task 0.2: Scaffold + project.godot
**Files:** Create dir skeleton (`autoload/ scenes/{game,ui,player,zones,bosses,enemies,world} src/{player,forms,components,world,enemies,bosses,ui,fx,zones,game} assets/{sprites,audio/sfx} tests/playthrough tools build/`); Modify `project.godot`: main scene `res://scenes/game/Game.tscn`; autoloads `Events, GameState, AudioManager, DemoDriver`; keep input map; add layer names.
- [ ] Write stub autoloads (Events complete per contract; others minimal) so project boots
- [ ] Verify: parse/boot check passes · Commit

## Phase 1 — Core engine (sequential, inline)

### Task 1.1: GameState + Events + tests harness
**Files:** `autoload/GameState.gd`, `tests/run_all.gd` (SceneTree script: collects `tests/unit/*.gd`, runs `run(tree) -> Array[String]` failures, prints PASS/FAIL, exit code), `tests/unit/test_gamestate.gd` (unlock/cycle/flags/checkpoint behavior).
- [ ] Failing test → implement → green → commit

### Task 1.2: Components
**Files:** `src/components/Health.gd` (max_health, damage(amount, knockback: Vector2), heal, invuln window 0.6s, signals `changed(cur,max)`, `died`), `src/components/Hitbox.gd` (Area2D; damage, knockback_force, active window via `activate(duration)`, one-hit-per-activation-per-target), `src/components/Hurtbox.gd` (Area2D; signal `hit_received(hitbox)`), `tests/unit/test_components.gd` (damage flow, invuln, single-hit).
- [ ] Failing test → implement → green → commit

### Task 1.3: FormDef + 4 form resources
**Files:** `src/player/FormDef.gd` (contract above), `src/forms/{basic,armchair,office,folding}.tres`, `tests/unit/test_forms.gd` (derived gravity/velocity match design table ±0.1%).
- [ ] Failing test → implement → green → commit

### Task 1.4: Player controller + placeholder visual
**Files:** `scenes/player/Player.tscn`, `src/player/Player.gd` (state machine: MOVE/DASH/GRAPPLE/FOLDED/HURT/DEAD; coyote 0.1, buffer 0.15, variable jump 40% cut, fall mult from form; special dispatch per form; attack via Hitbox; collider height per form/state), `src/player/PlayerVisual.gd` (tinted rounded rect via `_draw()` + squash/stretch hooks — replaced in Phase 4).
Form specials: armchair grapple (scan `grapple_anchors` group ≤380px, facing/up arc; pull 900 px/s; release keeps momentum) · office dash (700 px/s, 0.35s, cooldown 0.5s, collider 32px, `is_dashing()` for SpeedGate) · folding fold toggle (collider 20px, speed 140; jump while folded = spring: velocity from 230px height, unfolds).
- [ ] Implement · boot with a bare test floor scene · commit

### Task 1.5: Physics metrics test (the anti-regression keystone)
**Files:** `tests/unit/test_physics_metrics.gd` — builds flat-floor scene, spawns Player, drives via `Input.action_press/action_release`, simulates frames via physics ticks; asserts per form: max jump height ±5%, run speed ±2%, dash distance 220–280px, folded collider ≤20px, spring jump 230px ±5%.
- [ ] Test red on wrong constants (sanity-check by perturbing) → green → commit

### Task 1.6: CameraRig + HitStop
**Files:** `src/fx/CameraRig.gd` (Camera2D: smoothed follow, 90px facing lookahead, vertical deadzone 40px, arena-lock API `lock_to(rect)` / `unlock()`, shake via Events.screenshake_requested), `src/fx/HitStop.gd` (Engine.time_scale dip on Events.hitstop_requested, safe re-entrant).
- [ ] Wire into Player.tscn · commit

### Task 1.7: Game root + Door/Checkpoint + zone loading
**Files:** `scenes/game/Game.tscn`, `src/game/Game.gd` (loads TitleScreen first; `zone_change_requested` → fade out, swap zone child, spawn player at named marker, fade in; pause menu; respawn on player_died → checkpoint), `src/zones/ZoneBase.gd`, `src/world/Door.gd` (sensor; `target_zone_path`, `target_spawn`; optional `required_flag` else shows locked shimmer), `src/world/Checkpoint.gd` (sensor → set_checkpoint + Events).
- [ ] Boot: title → new game → placeholder Workshop stub zone · commit

### Task 1.8: UI suite
**Files:** `scenes/ui/{TitleScreen,HUD,PauseMenu,UnlockBanner,EndingScreen}.tscn` + `src/ui/*.gd`. HUD: 5 hearts, form chips (locked greyed, active highlighted), boss bar (on boss_started/health/defeated), zone banner on zone_loaded. UnlockBanner: full-width fanfare on form_unlocked. EndingScreen on game_won: crowned chair + stats + "Thanks for playing".
- [ ] Wire to Events only (no direct refs) · commit

### Task 1.9: World objects
**Files:** `scenes/world/*.tscn`, `src/world/{Platform.gd,GrappleAnchor.gd,AbilityGate.gd,SpeedGate.gd,Spikes.gd,MovingPlatform.gd}`. Platform: StaticBody2D, `size: Vector2` export, `_draw()` themed slab, group `platforms`, `decor` metadata flag. GrappleAnchor: Marker2D + ring visual, group `grapple_anchors`. AbilityGate: solid until `required_flag`/form condition; shows form icon + color. SpeedGate: breakable wall, breaks if body impact speed >450 px/s (Events sfx + particles later). Spikes: hurtbox, 1 heart. MovingPlatform: AnimatableBody2D on Path2D or two-point lerp.
- [ ] Commit

### Task 1.10: Enemies
**Files:** `src/enemies/EnemyBase.gd` (Health+Hurtbox+contact Hitbox, knockback, death poof, `skin_color`/`skin` export), + `Footstool.gd` (patrol walker, ledge-turn), `LampWisp.gd` (sine flyer, swoop at player ≤200px), `CoatRack.gd` (stationary, lob projectile arc every 2.2s; `src/enemies/Projectile.gd`), scenes for each. HP 4/3/5, all deal 1 heart.
- [ ] Commit

### Task 1.11: BossBase
**Files:** `src/bosses/BossBase.gd` — phases array of pattern callables, 50% phase switch, arena lock (camera + doors shut), Events boss_* wiring, `unlock_form_id` + flag on death, defeat slow-mo + door open. `scenes/bosses/BossArena.tscn` helper (trigger + door blockers).
- [ ] Commit

### Task 1.12: DemoDriver + geometry validator frameworks
**Files:** `autoload/DemoDriver.gd` (schema above; combat policy: hold toward boss until |dx|<attack_range·0.8, tap attack each cooldown, hop on incoming hitbox ≤90px, re-approach after knockback; per-boss hint table; respawn-retry), `tests/geometry/validate_zones.gd` (rules above; zone list constant), `tests/run_all.gd` extended to include validator once zones exist.
- [ ] Driver smoke test on stub zone (walk_until_x + assert) headless green · commit

**Phase 1 gate:** parse + run_all green (metrics test included). Commit tag comment `phase-1-core-green`.

## Phase 2 — Zones & bosses (parallel workflow agents; strict file ownership)

Each zone agent owns ONLY: `scenes/zones/<Zone>.tscn`, `src/zones/<Zone>.gd`, its boss scene+script, its playthrough segment `tests/playthrough/seg_<zone>.json`. Shared files are read-only to agents; integration fixes happen inline afterward.

### Task 2.1: Workshop (hub)
Tutorial-by-design (safe pit for jump, dummy footstool for attack), Ottoman Otto NPC (one-liner per unlock state, `src/npc/OttomanOtto.gd` — agent-owned), 3 exits: Lounge door (open), Office door (AbilityGate: armchair + grapple gap 250px), Storage door (SpeedGate + dash tunnel), Throne door (vent 27px + AbilityGate folding). Shortcut landings from each zone.
### Task 2.2: Lounge + Recliner Baron (unlocks armchair)
Soft plush platforms, wisps + footstools, ceiling-hook props foreshadowing grapple, boss arena; patterns per spec; HP 40. Checkpoint pre-boss.
### Task 2.3: Office Complex + Swivel Executive (unlocks office)
Entry uses grapple (anchors), slopes/conveyor feel via moving platforms, speed-gate practice wall, cubicle maze with lobbers; boss HP 50; paperwork hazards.
### Task 2.4: Storage Closet + Steel Folder (unlocks folding)
Entry dash tunnel from hub, crusher timing (MovingPlatform vertical), stacked crates, vents preview (locked side pocket), boss HP 50.
### Task 2.5: Throne Room + Upholstered King + ending
Entry vent 27px; interior gauntlet: grapple chasm → speed gate → vent maze → spring shaft; King HP 90 with all-mechanic P2; on defeat → game_won → EndingScreen.

Each task: `- [ ]` build zone conforming to contract · Route markers authored · validator green for that zone · driver segment green headless · commit.

### Task 2.6: Integration
- [ ] Door graph wired both directions + shortcuts; full validator suite green; `full_run.json` = concatenated segments + transforms; headless full playthrough **green** (respawn-retries allowed, must reach DEMO PASS).
- [ ] Commit `feat: full game arc playable end to end (headless verified)`

**Phase 2/3 gate = the acceptance gate:** headless full playthrough DEMO PASS.

## Phase 4 — Visual pass (parallel agents + style guide)

### Task 4.1: Style guide + palette resources — `assets/sprites/STYLE.md`, `src/game/ZoneTheme.gd` + 5 `.tres` themes (bg gradient, platform base/top/outline, parallax tints, particle color).
### Task 4.2: Player form SVGs ×4 (idle pose; folded variant; wheel child node for office) — expressive eyes, thick outline; PlayerVisual swaps to Sprite2D skins + squash/stretch/rock-walk/fold-hinge/dash-lean code anim.
### Task 4.3: Boss SVGs ×4 + enemy SVGs ×3 + props (hooks, gates icons, anchors, doors, Otto, throne, crates, cubicles).
### Task 4.4: Platform `_draw()` skins from ZoneTheme + parallax layers (2–3 per zone, big soft furniture silhouettes) + WorldEnvironment glow/vignette + dust/impact/break particles.
### Task 4.5: Screenshot review — rendered capture at fixed milestones, I review every zone visually; fix list; re-capture.
Verification each: parse green + capture frames show intended look. Commit per task.

## Phase 5 — Feel & SFX

### Task 5.1: `tools/gen_sfx.py` (stdlib) → WAVs: jump_boing, land_thump, wood_clack, plush_thump, wheel_roll, metal_snap, fold, spring, hit, hurt, break, unlock_jingle, ui_blip, boss_down, checkpoint. `autoload/AudioManager.gd` plays via sfx_requested; hooks in player/enemies/bosses/UI.
### Task 5.2: hitstop tuning, shake clamps, landing dust, attack arcs, knockback arcs, unlock slow-mo. Re-run metrics test (feel changes must not alter physics numbers).
- [ ] Commit each.

## Phase 6 — Final verification & delivery

- [ ] Full headless playthrough ×3 consecutive DEMO PASS (flake check)
- [ ] Rendered capture: AVI + milestone PNGs to `build/playthrough/`
- [ ] Codex second-opinion review on Player.gd, BossBase.gd, DemoDriver.gd; code-review skill on full diff; fix confirmed findings; re-run gates
- [ ] Merge `rebuild/full-arc` → `master` (no push)
- [ ] Morning report + memory notes

## Self-review (done at write time)

Spec coverage: teardown✓ physics-from-metrics (T1.3/1.5)✓ 4 forms (T1.4)✓ 5 zones/4 bosses (P2)✓ gates/rules (validator)✓ visuals (P4)✓ audio/feel (P5)✓ playthrough+capture (T1.12/2.6/P6)✓ NPC✓ shortcuts✓ title/ending (T1.7/1.8)✓. Type consistency: form ids `&"basic"|&"armchair"|&"office"|&"folding"` everywhere; flags `boss_<id>_defeated`; spawn `Default` guaranteed. No TBDs. Remaining intentional openness: boss pattern tuning values live in their scripts, reviewed at Phase 2 integration.
