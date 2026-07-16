# Chairfighter Backlog

This is a collection of bugs, polish items, and design concerns. Entries here are not yet implementation plans and should not be dispatched automatically.

> **Status 2026-07-13 (post-rebuild backlog pass):**
> - **CF-B001 resolved** — health is heart icons (top-left); boss bar moved top-center and styled as unmistakable UI.
> - **CF-B002 resolved for known cases** — every speed gate and all eight royal trial seals are 760px tall, above the Spring Stool's normal-jump + pogo envelope. Grapple spans are widened beyond ordinary running jumps; vents/tunnels are ceiling-bound and unbypassable; the throne pit is hatch-gated against softlock. The Throne door requires all four guardian flags, and the King independently requires all eight durable trial flags.
> - **CF-B003/B005 improved** — all bosses now pop a "!" cue + flash on every wind-up (BossBase.telegraph); hitstop/shake/knockback arcs cover impact feedback. Deeper per-boss animation is future work.
> - **CF-B004 open** — tells improved; distinctive-mechanic redesign per boss remains future work.

## UI / HUD

### CF-B001 — Health bar resembles a platform

- The health bar's current placement and appearance make it look like part of the level geometry.
- Move it to the top of the screen.
- Consider a different color or visual treatment so it is clearly distinct from platforms and scenery.

## Level Progression / Ability Gates

### CF-B002 — Stage gates can be bypassed

Progression barriers need stronger enforcement so areas cannot be reached before acquiring their intended chair abilities.

Known examples:

- The starting speed gate on the left can be jumped over before unlocking the wheelchair.
- The folding chair can be used to cross gaps intended to require the grapple ability.
- Other stage gates should be audited for similar movement- or chair-based bypasses.

Possible eventual approaches include revised geometry, collision barriers, larger traversal margins, or explicit ability checks. No implementation choice has been made yet.

## Bosses

### CF-B003 — Boss attacks need clearer tells

- Improve anticipation cues before attacks.
- Make attack timing and danger areas easier to understand.
- Keep tells readable during visually busy encounters.

### CF-B004 — Boss mechanics need refinement

- Give bosses cleaner and more distinctive encounter mechanics.
- Improve transitions between attacks or phases.
- Reduce behavior that feels abrupt, unclear, or mechanically unfinished.

### CF-B005 — Boss animations need polish

- Improve attack windups, recoveries, reactions, and phase transitions.
- Better synchronize animations with hitboxes and damage timing.
- Add visual feedback where an action currently occurs without enough motion or explanation.
