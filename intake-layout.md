# Chairfighter — Intake Layout

> This file is read verbatim by Big Al (the intake bot) every time a friend files a feature for chairfighter. The quality of the cards he creates scales with the quality of this file. Operator-maintained.

## Project basics

- **Workspace:** `/home/stevets/projects/chairfighter`
- **Source spec:** `/home/stevets/projects/chairfighter/SPEC.md` (authoritative product vision; do not contradict)
- **Implementation plan (current MVP):** `/home/stevets/projects/chairfighter/docs/plans/2026-05-28-chairfighter-mvp-implementation-plan.md`
- **Engine:** Godot 4.x, GDScript only
- **Art:** placeholder shapes/sprites only; no final art

## Verification command

Every implementer and reviewer card runs this exact command to verify its work:

```bash
cd /home/stevets/projects/chairfighter && godot4 --headless --path . --quit
```

If `godot4` is unavailable, the fallback is `godot --headless --path . --quit`. If neither exists, the card is expected to document that clearly and run static checks appropriate to the touched files.

**Additionally**, any card that touches level geometry, platform/grapple-point placement, movement parameters, or progression routes must also run the reachability regression test and pass it:

```bash
cd /home/stevets/projects/chairfighter && godot4 --headless --path . -s res://tests/regression_reachability_check.gd
```

The parse check alone is **never** sufficient verification for those cards — it proves the scene loads, not that a player can traverse it.

## Movement / traversal constants (single source of truth for card authors)

Big Al pastes the relevant rows into every card that places or sizes anything the player must traverse, fight, or reach. Verified against source 2026-06-10; if code and this table disagree, trust code and flag the drift.

| Constant | Basic Chair | Armchair | Source |
|---|---|---|---|
| `jump_velocity` | -520 | -540 | `scripts/player/forms/*.gd` |
| `gravity` (base × scale, jump held) | 980 × 3.5 = 3430 | 980 × 4.0 = 3920 | `scripts/player/Player.gd` |
| **Max jump height** (jump held) | **≈ 39 px** | **≈ 37 px** | derived: v²/(2g) |
| `max_speed` (horizontal) | 280 px/s | 260 px/s | `scripts/player/forms/*.gd` |
| `grapple_range` | n/a | 300 px | `scripts/world/GrapplePoint.gd`, `Player.gd` |

Placement rules that follow from the table:
- Vertical steps on any **intended** route: ≤ 30 px (39 px max jump minus margin for ledge collision).
- Grapple points on an Armchair route: ≤ 280 px from the nearest standable position (300 px range minus margin).
- Anything meant to be **unreachable** without an unlock must exceed the capability by a clear margin (≥ 60 px vertical for jumps), so near-miss exploits don't blur the gate.

## Deploy command

The final reviewer/deployer card runs this from the project root after the feature is approved and the working tree is clean:

```bash
scripts/deploy_itch.sh
git push origin master
```

If deploy fails, the final card blocks instead of completing, with the exact failing command and the shortest useful error.

## Strategy rules block (verbatim — paste into every implementer card body)

```
Qwen-local strategy rules:
- One card = exactly the scope named in this card: one artifact (code work) or one coherent playable slice (content work). Do not expand it; do not do less than the whole slice.
- Make the smallest correct change that satisfies this card's acceptance criteria — all of them, including the quantitative ones.
- Numeric constraints in this card (jump heights, ranges, distances) are hard requirements. Check your placements against them before completing.
- Read only the files named below unless an error message names another file.
- Do not expand scope, refactor architecture, or add unrelated features.
- Use Godot 4.x GDScript and placeholder art.
- Controller-first input, keyboard support too when input is involved.
- Commit after implementation tasks if git is available.
```

## Lifecycle / failure protocol (verbatim — paste into every implementer card body)

```
Lifecycle / failure protocol:
- Before editing, inspect prior parent summaries/comments.
- Run the exact verification command listed below if available.
- If the same verification command fails with the same error twice, stop and call kanban_block with the exact failing command and shortest useful error.
- If fixing requires files outside Allowed changes, stop and call kanban_block naming the file and reason.
- Do not retry the same failed approach more than twice.
- On success, call kanban_complete with changed_files, commands_run, verification_result, and known_limitations.
```

## Reviewer block (verbatim — paste into every reviewer card body)

```
Adversarial review gate for Qwen-local implementation.

Instructions:
- Inspect the parent implementation card body (its spec and acceptance criteria), the diff, and parent summary/comments.
- Run the verification command listed below. If the parent card touched geometry/placement/movement/progression, also run the reachability test: godot4 --headless --path . -s res://tests/regression_reachability_check.gd
- Verify EVERY acceptance criterion on the parent card individually. Recompute quantitative criteria (jump heights, distances, ranges) against the actual values in the scene/script files — do not trust the implementer's summary.
- A passing parse check is the floor, not approval. For content cards, approval requires verified traversability/behavior.
- Prefer tiny direct fixes for parse/import mistakes.
- Before approving, run git status: the parent's work must be committed. If the implementer left its diff uncommitted, commit it with the card's suggested commit message before completing. Commit your own review fixes too. Never approve over a dirty tree.
- Do not add new feature scope.
- If substantial design/implementation work remains, create a new narrow remediation card assigned to implementer-worker and link it before downstream work if possible. The remediation card must quote concrete evidence (file, node, measured value vs required value).
- Leave a review comment on the card even when approving: what you checked, what you ran, residual risks. Silent approvals fail review policy.
- Complete only when approved or sufficiently fixed for downstream work.

Completion summary must include: approved yes/no, criteria verified (with measured values where quantitative), fixes made, commands run, risks for next task.
```

## Code conventions

These are the things implementer cards should *not* re-litigate; encode them in every card's "Read first" or "Acceptance criteria" as appropriate.

- **GDScript class_name + type hints.** In Godot 4 headless startup, a `class_name`-declared type used as a type hint elsewhere must be `preload()`-ed at the top of the consuming file. Otherwise the parser cannot resolve it and you get warnings/errors at `godot --headless --path . --quit`. Cards that introduce or rename `class_name` types must update consumers.
- **`CharacterBody2D` for the player**, not the deprecated `KinematicBody2D`. Use `move_and_slide()` with `velocity` (Godot 4 form), not the Godot 3 form.
- **Input is action-driven.** Use `Input.is_action_pressed("move_left")` etc. Never check raw key codes directly. Action names live in `project.godot` under `[input]`.
- **Coyote time and jump buffering** are non-negotiable for any player movement work — they're already implemented; new movement code must preserve them.
- **Forms are resources/scripts, not duplicated player nodes.** New chair forms inherit from `ChairForm` (`scripts/player/ChairForm.gd`) and follow the `BasicChairForm`/`ArmchairForm` pattern.
- **Game state is via the `GameState` autoload** (`scripts/state/GameState.gd`), registered in `project.godot`. New unlockables/flags go there; do not invent a parallel state store.
- **Health / Hitbox / Hurtbox are reusable components.** Bosses, enemies, and the player share them. Do not write custom damage code per actor.
- **Placeholder art only.** ColorRect, simple shapes, plain labels. No imported sprite assets in this phase.
- **Controller-first.** Every input change must verify gamepad bindings before keyboard.

## File-layout hints

Where things live in this codebase. Implementer cards should follow these locations exactly (no "I'll just put it here for now").

```
chairfighter/
  project.godot                          # global config; rarely edited
  SPEC.md                                # product spec
  scenes/
    main/Main.tscn                       # boot scene
    player/Player.tscn                   # the player rig
    levels/<Name>.tscn                   # individual levels
    bosses/<Name>.tscn                   # boss scenes
    enemies/<Name>.tscn                  # enemy scenes
    ui/HUD.tscn                          # heads-up display
    world/<Name>.tscn                    # reusable world objects (GrapplePoint, AbilityGate)
    npc/<Name>.tscn                      # NPC scenes (when added)
  scripts/
    player/Player.gd                     # owns input, movement, health, form switching
    player/ChairForm.gd                  # base form class
    player/forms/<Name>Form.gd           # one file per chair form
    components/Health.gd                 # reusable: health pool, signals
    components/Hitbox.gd                 # reusable: deals damage
    components/Hurtbox.gd                # reusable: takes damage
    enemies/<Name>.gd                    # enemy logic
    bosses/<Name>.gd                     # boss logic
    world/<Name>.gd                      # world-object logic
    npc/<Name>.gd                        # NPC logic
    state/GameState.gd                   # autoload; tracks unlocks, checkpoints
    ui/HUD.gd                            # HUD logic
  tests/                                 # currently sparse
  assets/                                # placeholders only for now
```

When in doubt: new entity goes under `scenes/<category>/` for the scene file and `scripts/<category>/` for the script.

## Default forbidden changes

These files appear on the **Forbidden changes** list of every card unless the card's specific scope explicitly requires touching them:

- `project.godot` (global engine config; touching it requires the operator's attention)
- `SPEC.md` (product spec; only the operator edits this)
- `docs/plans/**` (planning artifacts; only the operator or Big Al's own intake writes here)
- Anything under `assets/` not added by the same card
- `.git/`, `.godot/`, `.import/`, `*.import`, build artifacts (generally)
- Any file owned by another card in the same chain

## Reviewer expectations beyond the per-card checklist

When the reviewer card runs against a parent implementer's diff, it should additionally watch for:

- **Controller-first regressions.** A new input path that only works on keyboard fails review.
- **Ranged combat creep.** The MVP is melee-only; the one allowed ranged form is reserved for later. Any pop-off-buttons/studs/projectile work for the prototype gets blocked.
- **Energy-cost creep on traversal forms.** Per the spec, traversal transformations do *not* consume energy. A card that adds an energy meter to grapple/grind/etc. fails review.
- **Silent-protagonist regressions.** The player chair never speaks. Dialogue is fine for NPCs.
- **Placeholder art regressions.** No card should import "final" art into `assets/`.
- **Autoload re-invention.** State that should live in `GameState.gd` showing up in a new singleton fails review.
- **Damage code that bypasses Health/Hitbox/Hurtbox.** Should be re-routed through the components.

## Card chain shape (per the SDD breakdown)

The standard shape for a feature is:

```
<HASH>-A    Implementer: implementer-worker  (artifact / mechanic / wiring)
<HASH>-AR   Reviewer: review-worker
<HASH>-B    Implementer: implementer-worker  (next coherent piece)
<HASH>-BR   Reviewer: review-worker
...
<HASH>-IG   Integration gate: review-worker  (combined-behavior playtest where subsystems meet)
...
<HASH>-FR   Final reviewer/deployer: review-worker (full-feature playability pass, deploy, push)
```

Code work is sliced one artifact per card; content/gameplay work is sliced one **playable slice** per card (gate + placement + verification together — never split). Every implementer has a paired reviewer. Wherever two subsystems must work together at runtime (movement ↔ geometry, combat ↔ boss placement, unlocks ↔ gated routes), an integration-gate card assigned to review-worker verifies the combination before anything builds on it. Content cards too big for the local implementer go to review-worker instead of being sliced thinner. The chain ends with a final reviewer/deployer that checks the feature as a whole, deploys it with the command above, pushes the final commit, and relies on the intake-created notification subscription to report completion back to the originating Discord thread.

> Historical note: the CF-06A..CF-08FR chain was previously cited here as the gold standard. It artifact-sliced content work (gate logic, route placement, and movement physics in mutually-forbidden cards with parse-only verification) and shipped a route requiring an 80 px jump against a 39 px max jump height. Do **not** match its granularity for content work.

## Holistic acceptance criteria (every feature, enforced at gates and final review)

1. **Progression clarity:** the player's path forward is always reachable with currently-unlocked chair forms. Gates by locked abilities must be visually explicit ("later" content), never silent dead ends.
2. **Level geometry integrity:** every intended route satisfies the placement rules in the constants table above — verified by the reachability test, not by inspection.
3. **Unlock timing:** abilities are presented to the player only after unlock (tutorial foreshadowing must be clearly marked as future content).
4. **Tutorial coherence:** prompts and signposts point only at goals achievable with current unlocks.

## Notes for Big Al specifically

- The `SPEC.md` is authoritative for "what the game is." If a friend asks for something that contradicts the spec (e.g., "make the chair talk"), ask one clarifying question to see if they really mean it. If yes, file it anyway with a note in the spec doc; the operator will decide.
- The MVP is currently mid-implementation (chain CF-06A..CF-08FR pending in `todo`). Avoid filing features that depend on un-built MVP scaffolding. If a friend asks for something downstream of the MVP, file it but note the dependency in the spec doc.
- Friends are not engineers. The conversation in Discord must stay plain-language. The spec doc and the card bodies, however, *do* use the technical conventions in this file.
