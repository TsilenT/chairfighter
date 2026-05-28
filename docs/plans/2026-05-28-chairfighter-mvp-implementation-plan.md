# Chairfighter Minimum Playable Prototype Implementation Plan

> **For Hermes:** This plan is intended for Kanban execution. Implementation cards should be assigned to the local Qwen profile `discord-bot`. Review cards should be assigned to `discord-bot-smart` using GPT-5.5 unless local Qwen review is explicitly requested later. Every card lists explicit dependencies; do not start a child card until all parent cards are done.

**Goal:** Build the first playable Godot 4 prototype for `Chairfighter`: a cartoony 2D metroidvania platformer where a silent basic chair defeats a miniboss, unlocks Armchair form, and uses Armchair grapple to access a previously blocked route.

**Architecture:** Use a lightweight Godot 4 project with clear scene/script separation. `Player.gd` owns input, movement, health, combat, form switching, and delegates form-specific behavior to chair form resources/scripts. A `GameState.gd` autoload tracks unlocked forms and simple checkpoint state. Prototype scenes use placeholder shapes/sprites first.

**Tech Stack:** Godot 4.x, GDScript, Godot Input Map, 2D scenes, placeholder art, Git for checkpoints.

**Source Spec:** `/home/stevets/projects/chairfighter/SPEC.md`

**Execution Rules:**

- Make autonomous decisions. The user is unavailable.
- Favor simple, working Godot 4 code over elaborate architecture.
- Keep the game controller-first, with keyboard support too.
- Keep combat melee-first; do not implement ranged combat in this MVP.
- Use placeholder art only.
- Commit after each implementation task when possible.
- Review tasks must run after every implementation task.
- If a review finds small issues, the reviewer may fix them directly to keep the plane-mode workflow moving. If the fix is substantial, create/link a remediation card assigned to `discord-bot` before allowing downstream work to proceed.

---

## Task Graph

Use these dependencies exactly:

1. `CF-01 Implement project skeleton` — no parents.
2. `CF-01R Review project skeleton` — parent: CF-01.
3. `CF-02 Implement controller-first input and Basic Chair movement` — parent: CF-01R.
4. `CF-02R Review movement` — parent: CF-02.
5. `CF-03 Implement form architecture and instant switching` — parent: CF-02R.
6. `CF-03R Review form architecture` — parent: CF-03.
7. `CF-04 Implement combat foundations and dummy enemy` — parent: CF-03R.
8. `CF-04R Review combat foundations` — parent: CF-04.
9. `CF-05 Implement Armchair grapple mechanic` — parent: CF-04R.
10. `CF-05R Review Armchair grapple` — parent: CF-05.
11. `CF-06 Implement metroidvania gate and test-level route` — parent: CF-05R.
12. `CF-06R Review ability gate and route` — parent: CF-06.
13. `CF-07 Implement Recliner Baron miniboss and Armchair unlock` — parent: CF-06R.
14. `CF-07R Review boss unlock flow` — parent: CF-07.
15. `CF-08 Implement hub NPC, HUD, checkpoint/restart polish` — parent: CF-07R.
16. `CF-08R Final review and playability pass` — parent: CF-08.

---

## CF-01: Implement Godot Project Skeleton

**Objective:** Create a bootable Godot 4 project in `/home/stevets/projects/chairfighter` with folders, main scene, test level, autoload placeholder, and Git initialized.

**Files:**

- Create: `project.godot`
- Create: `.gitignore`
- Create: `scenes/main/Main.tscn`
- Create: `scenes/levels/TestLevel.tscn`
- Create: `scripts/state/GameState.gd`
- Create folders:
  - `scenes/player/`
  - `scenes/bosses/`
  - `scenes/enemies/`
  - `scenes/ui/`
  - `scripts/player/forms/`
  - `scripts/components/`
  - `scripts/bosses/`
  - `scripts/enemies/`
  - `scripts/world/`
  - `scripts/ui/`
  - `assets/sprites/placeholders/`
  - `assets/audio/sfx/`
  - `assets/audio/music/`
  - `tests/`

**Implementation Notes:**

- Use Godot 4 format.
- Set `application/run/main_scene="res://scenes/main/Main.tscn"`.
- Configure `GameState.gd` as an autoload named `GameState`.
- `Main.tscn` should instance or include `TestLevel.tscn`.
- Use placeholder Node2D structure only; gameplay comes later.

**Verification:**

- Run any available headless Godot check if installed:
  - `godot4 --headless --path /home/stevets/projects/chairfighter --quit` or `godot --headless --path /home/stevets/projects/chairfighter --quit`
- If Godot is not installed/CLI not available, verify files are syntactically plausible and document that runtime verification is pending.
- `git status` should show created files.
- Commit: `chore: create Godot project skeleton`

---

## CF-01R: Review Godot Project Skeleton

**Objective:** Verify CF-01 produced a valid, bootable project skeleton and did not skip required folders/files.

**Review Checklist:**

- `project.godot` exists and points to `res://scenes/main/Main.tscn`.
- `GameState` autoload is configured.
- Required directories exist.
- Main scene and test level load paths are coherent.
- `.gitignore` excludes Godot/editor/import/cache noise but not source files.
- If Godot CLI exists, project opens headlessly without parse errors.
- If a small fix is needed, apply it directly; otherwise create a remediation card.

**Output:** Complete only when skeleton is approved.

---

## CF-02: Implement Controller-First Input and Basic Chair Movement

**Objective:** Add a playable Basic Chair character with controller-first input, keyboard fallback, responsive platformer movement, and camera follow.

**Files:**

- Create: `scenes/player/Player.tscn`
- Create: `scripts/player/Player.gd`
- Modify: `project.godot` input map
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Player appears in test level.
- Move left/right works with gamepad left stick/D-pad and keyboard A/D or arrows.
- Jump works with gamepad South button and keyboard Space.
- Movement includes coyote time, jump buffering, acceleration/deceleration, and variable jump height.
- Camera follows player smoothly enough for a prototype.
- Placeholder collision floor exists.

**Suggested Input Actions:**

- `move_left`, `move_right`, `jump`, `attack`, `special`, `transform_next`, `transform_prev`, `transform_wheel`, `interact`, `pause`.

**Verification:**

- Run headless Godot parse check if possible.
- If GUI/manual play unavailable, inspect scene paths and script parse output.
- Commit: `feat: add basic chair movement`

---

## CF-02R: Review Basic Chair Movement

**Objective:** Verify the Basic Chair movement is responsive, controller-first, and does not hardcode keyboard-only controls.

**Review Checklist:**

- Input uses Godot Input Map actions, not raw key checks only.
- Keyboard and controller bindings both exist.
- Player uses `CharacterBody2D` or equivalent Godot 4-safe movement.
- Coyote time and jump buffer are implemented and readable.
- Player cannot fall forever without restart path unless test level intentionally allows it temporarily.
- Camera is attached or otherwise follows.
- No transform/combat complexity was prematurely added here.

---

## CF-03: Implement Chair Form Architecture and Instant Switching

**Objective:** Add an extensible form system with Basic Chair and placeholder Armchair, plus free/instant switching after unlock.

**Files:**

- Create: `scripts/player/ChairForm.gd`
- Create: `scripts/player/forms/BasicChairForm.gd`
- Create: `scripts/player/forms/ArmchairForm.gd`
- Modify: `scripts/player/Player.gd`
- Modify: `scripts/state/GameState.gd`
- Modify/Create: `scenes/ui/HUD.tscn`, `scripts/ui/HUD.gd` if useful for showing current form

**Acceptance Criteria:**

- Player starts in Basic Chair.
- `GameState` tracks unlocked forms.
- For testing, Armchair can be unlocked via debug variable/function or boss later.
- Transform next/previous actions switch instantly among unlocked forms.
- Current form changes visible placeholder color/label.
- Movement values can differ by form.

**Verification:**

- Headless parse check.
- Confirm switching ignores locked forms.
- Commit: `feat: add chair form switching`

---

## CF-03R: Review Form Architecture

**Objective:** Verify form switching is clean, extensible, and faithful to the spec.

**Review Checklist:**

- No energy/cooldown cost for traversal forms.
- Locked forms cannot be selected.
- Form code is not an unmaintainable pile of conditionals if a small abstraction can avoid it.
- Basic and Armchair placeholders have distinct visuals or labels.
- Future forms can be added without rewriting all player code.

---

## CF-04: Implement Combat Foundations and Dummy Enemy

**Objective:** Add minimal melee combat foundation with health, hitbox/hurtbox, damage, knockback, and a dummy enemy.

**Files:**

- Create: `scripts/components/Health.gd`
- Create: `scripts/components/Hitbox.gd`
- Create: `scripts/components/Hurtbox.gd`
- Create: `scenes/enemies/DummyEnemy.tscn`
- Create: `scripts/enemies/DummyEnemy.gd`
- Modify: `scripts/player/Player.gd`
- Modify: `scripts/player/forms/BasicChairForm.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Attack action performs a short melee hit.
- Dummy enemy takes damage and can be defeated/hidden/removed.
- Player has health component, even if enemy damage is minimal.
- Hitbox/hurtbox layers/masks are documented in comments or named constants.
- Combat remains simple and melee-first.

**Verification:**

- Headless parse check.
- Optional manual play: hit dummy enemy until defeated.
- Commit: `feat: add melee combat foundation`

---

## CF-04R: Review Combat Foundations

**Objective:** Verify the combat foundation is reusable and not overbuilt.

**Review Checklist:**

- Components are generic enough for player, enemies, and boss.
- Damage flow is understandable.
- Melee attack timing does not leave permanent hitboxes active.
- Dummy enemy proves damage without becoming a full AI project.
- No ranged system added yet.

---

## CF-05: Implement Armchair Grapple Mechanic

**Objective:** Give Armchair its unique extendable-arm grapple/pull mechanic.

**Files:**

- Create: `scripts/world/GrapplePoint.gd`
- Create/Modify: `scenes/world/GrapplePoint.tscn` if using a reusable scene
- Modify: `scripts/player/forms/ArmchairForm.gd`
- Modify: `scripts/player/Player.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Grapple points are visible placeholder markers.
- Only Armchair can use grapple.
- Special button targets a valid grapple point within range.
- Player is pulled toward the grapple point with simple, controllable motion.
- Basic Chair special does nothing or gives debug feedback.
- Grapple mechanic is reliable enough for a test route.

**Verification:**

- Headless parse check.
- Optional manual play: switch to Armchair, grapple across a gap.
- Commit: `feat: add armchair grapple`

---

## CF-05R: Review Armchair Grapple

**Objective:** Verify Armchair grapple is usable, form-gated, and prototype-stable.

**Review Checklist:**

- Grapple cannot be used as Basic Chair.
- Range checks work.
- Pull motion does not fling player uncontrollably.
- Grapple points are readable in placeholder art.
- Implementation leaves room for later arm punch/grab combat.

---

## CF-06: Implement Metroidvania Gate and Test-Level Route

**Objective:** Create a small test level route that visibly requires Armchair grapple to access.

**Files:**

- Create: `scripts/world/AbilityGate.gd`
- Modify: `scenes/levels/TestLevel.tscn`
- Modify: `scripts/state/GameState.gd` if needed

**Acceptance Criteria:**

- Test level includes central/start area and a visible blocked route.
- Basic Chair can see but not access the route.
- Armchair can access the route using grapple.
- Gate is readable via placeholder shapes/sign text.
- This demonstrates the core metroidvania loop.

**Verification:**

- Headless parse check.
- Optional manual play: route inaccessible before Armchair, accessible after Armchair.
- Commit: `feat: add armchair ability gate route`

---

## CF-06R: Review Ability Gate and Route

**Objective:** Verify the test route clearly demonstrates the “see obstacle, unlock form, return, access” loop.

**Review Checklist:**

- The route is visible before unlock.
- The route is not reachable through unintended Basic Chair jumping.
- Armchair access relies on the grapple mechanic, not a generic open door.
- Gate logic is simple and data-driven enough for future forms.

---

## CF-07: Implement Recliner Baron Miniboss and Armchair Unlock

**Objective:** Add a simple boss/miniboss encounter that unlocks Armchair when defeated.

**Files:**

- Create: `scenes/bosses/ReclinerBaron.tscn`
- Create: `scripts/bosses/ReclinerBaron.gd`
- Modify: `scripts/state/GameState.gd`
- Modify: `scenes/levels/TestLevel.tscn`
- Modify: HUD if needed for unlock feedback

**Acceptance Criteria:**

- Boss has health and can be damaged by player melee.
- Boss has at least two simple attacks/patterns:
  - long footrest/leg strike or lunge
  - cushion/projectile-like hazard or simple area attack; keep it silly and easy
- Boss defeat unlocks Armchair in `GameState`.
- Unlock feedback appears via text/HUD/banner or obvious visual cue.
- Player can then use Armchair to access the gated route.

**Verification:**

- Headless parse check.
- Optional manual play: defeat boss, Armchair unlocks, use grapple route.
- Commit: `feat: add recliner baron armchair unlock`

---

## CF-07R: Review Boss Unlock Flow

**Objective:** Verify the boss encounter is fair, casual, and correctly unlocks Armchair.

**Review Checklist:**

- Boss is beatable with Basic Chair only.
- Boss attacks are readable and casual-difficulty appropriate.
- Defeat reliably unlocks Armchair exactly once.
- Unlock persists long enough to use the form after leaving arena/restarting level if implemented.
- Unlock feedback is clear.
- Boss code reuses health/hurtbox patterns rather than special-casing everything.

---

## CF-08: Implement Hub NPC, HUD, Checkpoint/Restart Polish

**Objective:** Add the first central flavor NPC, visible HUD state, and enough restart/checkpoint polish for the MVP to feel coherent.

**Files:**

- Create: `scenes/npc/HubNpc.tscn`
- Create: `scripts/npc/HubNpc.gd`
- Create/Modify: `scenes/ui/HUD.tscn`
- Create/Modify: `scripts/ui/HUD.gd`
- Modify: `scripts/state/GameState.gd`
- Modify: `scenes/levels/TestLevel.tscn`
- Modify: `scripts/player/Player.gd`

**Acceptance Criteria:**

- One NPC sits in the central/hub area.
- NPC provides flavor lines that can change after Armchair unlock.
- The silent chair protagonist does not speak.
- HUD shows health and current form.
- Player can restart/respawn after death or falling.
- Test level can be played from start → boss → unlock → Armchair route.

**Verification:**

- Headless parse check.
- Optional manual playthrough of full MVP loop.
- Commit: `feat: add hub npc and mvp polish`

---

## CF-08R: Final Review and Playability Pass

**Objective:** Review the complete MVP against `SPEC.md` and this plan, fix small issues, and leave a clear handoff.

**Review Checklist:**

- Full loop works: start as Basic Chair → fight Recliner Baron → unlock Armchair → grapple to gated route.
- Controller and keyboard actions are present.
- Difficulty is casual.
- Placeholder art is readable.
- Story is mostly environmental with one NPC.
- The player character remains silent.
- No extra ranged form was implemented prematurely.
- Files are organized according to the architecture.
- Godot parse check passes if Godot CLI is available.
- `git status` is clean or clearly documented.

**Output:**

- Final summary of what works.
- Known issues.
- Commands run.
- Suggested next plan for Office Chair / second area.
