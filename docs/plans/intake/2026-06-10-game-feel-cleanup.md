# Game feel & playability cleanup

**Date:** 2026-06-10
**Filed by:** stevets (operator-direct intake via Claude Code session, not Discord)
**Project:** chairfighter
**Card chain root:** 53YL

## What the friend asked for

"The game looks and feels bad at the end of it. For example sometimes the level built will have an overhang that makes it impossible to progress. Make the kanban tasks to fix/clean up the game."

## What we agreed on

An audit (2026-06-10) found four concrete causes, confirmed against code and the new reachability regression test:

1. **Bait geometry / the 'overhang'.** The Platform1→2→3 staircase in `TestLevel.tscn` cannot be climbed by any form: steps are 80 px and Platform1 sits 148 px above the floor, against a 39 px max jump (Basic, jump held). Platform1 is additionally outside every grapple landing zone. `tests/regression_reachability_check.gd` currently FAILS on exactly this ("BAIT GEOMETRY: surface 'Platform1' … unreachable by every form"). The grapple-marker chain itself (floor→GrappleMarker2→Platform2→GrappleMarker1→Platform3) is within range and fine.
2. **Camera never follows the player.** It is positioned once at init; `cam_smoothing` and `zoom_base` exports are unused (`scripts/player/Player.gd`).
3. **Attacks have no visual feedback.** `BasicChairForm.on_attack()` is a TODO; `_attack_extension` exists in Player.gd but drives nothing. No screenshake on taking hits.
4. **Knockback is flat.** `Health.take_damage()` normalizes knockback to a horizontal shove; hits have no arc or weight.

Scope: fix the level geometry so the reachability test passes; implement camera follow + screenshake + attack extension animation (one Player.gd feel card); add a knockback arc in Health.gd; gate everything with an integration playtest before the final playability/deploy pass.

Out of scope (deferred): audio/SFX/music (assets/audio is empty — separate intake), movement-constants consolidation (duplicated across ChairForm.gd / BasicChairForm.gd / Player.gd — would overlap the feel card's Allowed changes, file as follow-up after 53YL ships).

## Acceptance criteria

- `godot4 --headless --path . -s res://tests/regression_reachability_check.gd` exits 0: Basic route to boss, Armchair route to top platform, and no unreachable platforms.
- Every intended Basic-route vertical step is ≤ 30 px; grapple hops ≤ 280 px (per the constants table in intake-layout.md).
- Camera smoothly tracks the player with lookahead in the facing direction; standing still relative to the screen while walking no longer happens.
- Attacking visibly animates the chair body; taking a hit produces a brief screenshake; knockback pops targets in a small arc instead of a flat shove.
- Existing regression tests (`regression_level_flow_check.gd`, `regression_hitbox_overlap_check.gd`) still pass; no controller-first, silent-protagonist, or placeholder-art regressions.

## Open questions (deferred)

- Should the Platform1 staircase become a climbable Basic-route shortcut (steps ≤ 30 px) or be removed in favor of the grapple-only route? Card 53YL-A may choose either, as long as the reachability test passes and signage stays truthful.
- Audio pass (hit/jump/grapple SFX, music loop) — file as its own intake.
- Movement-constants consolidation — file as its own intake after this chain lands.

## Conversation

Operator-direct intake. Source: pipeline audit conversation in Claude Code, 2026-06-10, following the workflow upgrade that added integration gates, quantitative acceptance criteria, parent-body context injection, the adversarial reviewer mandate, and tests/regression_reachability_check.gd (chairfighter commit 8fd6524).
