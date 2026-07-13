# Chairfighter Rebuild — Design

**Date:** 2026-07-13 (overnight autonomous rebuild)
**Author:** Claude, from stevets' brief: "rip down and redo; playable throughout; nice visuals; full playthrough."
**Supersedes:** the 2026-05-28 MVP implementation (kept in git history). SPEC.md remains the product vision; this doc scopes and re-architects the build.

## Why rebuild

The MVP's root defect was physics chosen before level metrics: `jump_velocity -520` against effective gravity 3430 gave a **39px max jump**, and every geometry bug (bait platforms, unreachable routes, the "overhang" complaint) flowed from levels authored against imagined physics. Visuals were ColorRects; camera, attack feedback, and knockback were patched late. The salvageable assets are the spec, the input map, the component architecture concepts, and the reachability-test culture. The code itself is not worth preserving.

## Scope: the whole game

A complete, finishable arc, target 15–25 minutes casual playtime:

1. **Title screen** → new game.
2. **The Workshop** (hub) — tutorial-by-level-design, flavor NPC (Ottoman Otto), three gated exits with visible form-icon locks.
3. **The Lounge** → boss **Recliner Baron** → unlock **Armchair** (grapple).
4. **The Office Complex** — entry requires Armchair grapple → boss **Swivel Executive** → unlock **Office Chair** (dash/momentum).
5. **The Storage Closet** — entry requires Office dash tunnel → boss **Steel Folder** → unlock **Folding Chair** (fold flat + spring jump).
6. **The Throne Room** — entry requires Folding vent; interior gauntlet uses all three abilities → final boss **The Upholstered King** (multi-phase) → **ending screen**.

4 playable forms, 4 bosses, 5 areas + title/ending. Each unlock opens the next zone's gate **and** a shortcut back to the hub (metroidvania re-traversal without backtrack tedium). Stretch only after full verification passes: Rocking Chair zone (The Parlor), disk save.

## Physics from metrics (the core fix)

Tile unit: 32px. Player body ≈ 44×56px. Targets first, constants derived:

| Metric | Basic | Armchair | Office | Folding |
|---|---|---|---|---|
| Max jump height (held) | 150px | 140px | 130px | 140px (spring: 230px) |
| Time to apex | 0.38s | 0.38s | 0.36s | 0.38s |
| Run speed | 340 | 300 | 380 (dash burst 700) | 320 (folded walk 140) |
| Derived: rise gravity | ≈2078 | ≈1939 | ≈2006 | ≈1939 |
| Derived: jump velocity | ≈-790 | ≈-737 | ≈-722 | ≈-737 |

Fall gravity = 1.6× rise gravity. Early jump release cuts vertical velocity to 40% (min hop ≈ 40px). Coyote 0.1s, jump buffer 0.15s, air control 0.65.

**Level authoring rules** (enforced by automated validator, not inspection):

- Intended vertical steps ≤ 96px (3 tiles). Intended gaps ≤ 160px (5 tiles).
- Ability-gated ledges ≥ 210px vertical; gated gaps ≥ 288px — clear margin, no near-miss exploits.
- Grapple anchors ≤ 360px from a standable position (range 380px).
- Speed-gate runways ≥ 400px of flat approach. Dash tunnels 40px tall (dash collider 32px vs normal 56px).
- Folding vents 26–28px tall (folded collider 20px). Spring-jump shafts: steps 170–220px.
- Every gate is visually explicit (form icon + color); no silent dead ends.

## Mechanics

**Shared controls** (existing input map kept, controller-first): move, jump, attack, **special = the active form's unique verb**, transform next/prev, interact, pause, restart.

- **Basic Chair** — bash (short hitbox). Baseline traversal. Brown.
- **Armchair** — special (hold): grapple to nearest anchor in facing/up arc ≤380px, pulls player, release keeps momentum; works airborne. Attack: long punch. Plush red.
- **Office Chair** — special: dash burst (700 px/s, 0.35s), collider shrinks to 32px, breaks speed gates (impact >450 px/s), crosses dash tunnels; ram damages enemies. Black/teal.
- **Folding Chair** — special (tap): fold toggle (20px collider, slow walk, fits vents); jump while folded = spring jump (230px). Fast slap attack. Silver.

Transformations are free and instant (spec rule); all forms combat-viable. Health: 5 hearts shared across forms; death → respawn at last checkpoint, unlocks kept, in-session only.

**Enemies** (3 reusable types, reskinned per zone): Footstool walker (patrol, contact damage), Lamp Wisp flyer (sine hover + swoop), Coat-Rack lobber (stationary arc projectile). Enemy projectiles are fine; *player* ranged forms remain reserved per spec.

**Bosses** — pattern-based, phase change at 50%, each foreshadows its unlock, arena-locked camera, boss health bar:

- **Recliner Baron:** footrest jab, cushion toss (arcs), recline block; P2 swings on ceiling hooks (foreshadows grapple).
- **Swivel Executive:** wall-to-wall roll charge, deflecting spin, falling paperwork; P2 ramp-boosted charges (foreshadows momentum).
- **Steel Folder:** ceiling snap-slam, folded low slide (jump over it), wall ricochet; P2 diagonal folded bouncing (foreshadows fold).
- **Upholstered King:** heavy smash + ground shockwave, footstool summons, cushion barrage; P2 arena crumble (grapple to safety), charge (dash away), low sweep (fold under). Requires all forms.

## Architecture

Root scene `Game.tscn` owns zone loading (fade transitions), pause, and UI layers. Zones are separate scenes connected by `Door` nodes (target zone + spawn id).

```
autoload/   GameState.gd (unlocks, checkpoint, current zone) · Events.gd (signal bus) · AudioManager.gd
game/       Game.tscn/gd (zone swap, transitions, pause)
player/     Player.tscn/gd (state machine: Move/Dash/Grapple/Fold/Hurt/Dead)
            FormDef.gd (Resource) + 4 .tres · PlayerVisual.gd (skin, squash/stretch)
components/ Health.gd · Hitbox.gd · Hurtbox.gd  (shared by player/enemies/bosses; fixed layer map)
world/      Door · Checkpoint · GrappleAnchor · AbilityGate · SpeedGate · MovingPlatform · Spikes · Platform (themed skin)
enemies/    EnemyBase + Footstool/Wisp/Lobber
bosses/     BossBase (phases, arena lock, health-bar hookup) + 4 bosses
ui/         TitleScreen · HUD (hearts, form chips, boss bar, zone banner) · PauseMenu · UnlockBanner · EndingScreen
fx/         CameraRig (follow+lookahead+shake) · HitStop · particle scenes (dust, impact, sparks)
tests/      physics metrics · geometry validator · zone flow · full playthrough driver
tools/      playthrough step scripts, capture helpers
```

Collision layers: 1 world · 2 player body · 3 enemy body · 4 hitboxes · 5 hurtboxes · 6 gates/sensors. Damage flows only through Hitbox→Hurtbox→Health.

## Verification (the acceptance gate)

1. **Physics metrics test** (headless): simulate jumps/dashes on a flat test scene; assert measured heights/distances match the table ±5%. Catches constant drift before it poisons levels.
2. **Geometry validator** (headless): walks each zone's platforms/anchors/gates; asserts the authoring rules above per intended route, and that gated routes exceed capability margins.
3. **Full playthrough driver**: autoload enabled by `CHAIRFIGHTER_DEMO=1`; executes a declarative step script (`walk_until_x`, `jump`, `grapple`, `fight_boss_until_dead`, `expect_zone`, `expect_unlock`, …) using `Input.action_press/release`; asserts the ending screen is reached. Runs headless in CI fashion **and** rendered with `--write-movie` to produce the playthrough video + milestone screenshots. The same script that proves beatability records the demo.

Nothing ships to master without all three green.

## Visual direction

Cartoony-bold, zero external dependencies:

- **Actors/props:** hand-authored SVG sprites (Godot imports natively). Thick warm-dark outlines, flat two-tone shading, rounded shapes, expressive eyes on the player chair (silent but emotive). One SVG per form/boss/enemy/prop; animation is code-driven (squash/stretch on jump/land, walk-rock scuttle, wheel spin, fold hinge) — no frame sheets.
- **Platforms/terrain:** themed `_draw()` skins (rounded slabs, top-surface strip, subtle inner shadow) driven by a per-zone palette resource — crisp at any size, no tile-alignment pain.
- **Zone palettes:** Workshop warm wood/amber · Lounge burgundy/gold · Office cool slate/teal · Storage steel/hazard-yellow · Throne purple/gold.
- **Depth:** 2–3 parallax layers per zone (furniture silhouettes, wall panels, windows) + vignette + light particles (dust motes, office paper, storage sparks).
- **Feel:** hitstop on hits, screenshake (clamped), knockback arcs, landing dust, attack swipe arcs, unlock fanfare banner.

## Audio

Generated WAVs via Python stdlib (no deps): wood clacks, plush thumps, wheel squeak, metal snaps, hit/hurt impacts, jump boing, unlock jingle, UI blips, boss defeat sting. Zone music loops are a stretch goal.

## Execution notes

Built overnight in phases, each gated by tests + commit: core engine → zones/bosses (parallel agents, one zone per agent, strict file ownership) → visuals (parallel SVG agents against a style guide, screenshot-reviewed) → feel/SFX → playthrough hardening. Codex used for independent review of load-bearing systems; final morning report includes screenshots and the playthrough video.
