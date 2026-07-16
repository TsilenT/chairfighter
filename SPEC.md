# Chairfighter Game Specification

> **For Hermes:** Use the `writing-plans` skill to turn this game specification into bite-sized implementation plans. For task-by-task coding, use `subagent-driven-development` after a Godot project skeleton exists.

**Goal:** Build a 2D Godot platformer where the player starts as a basic chair, defeats boss chairs, and unlocks chair transformations that open new traversal routes and combat options across an interconnected map.

**High Concept:** A cartoony, silly, kinetic platform adventure: ordinary furniture has gone to war, and one basic chair must evolve into increasingly absurd specialized chair forms to survive.

**Genre:** 2D action platformer / interconnected metroidvania.

**Engine Target:** Godot 4.x.

**Primary Inspirations:** Mega Man boss-power progression, metroidvania ability gates, expressive 2D platforming, compact boss arenas.

**Working Title:** `Chairfighter` is a placeholder title.

**Current Design Decisions:** Cartoony/silly tone, interconnected metroidvania map, mostly fixed boss/transform order, melee-first combat with exactly one silly ranged chair form, free/instant transformations, silent-object protagonist, mostly environmental storytelling with one central flavor NPC, all forms combat-viable, casual difficulty, controller-first support with keyboard support, simple placeholder art for the first prototype, and an unresolved final title.

---

## 1. Core Pitch

The player controls a small basic chair in a side-scrolling world full of hostile furniture. The player begins with simple movement and a basic attack. Each major area ends with a boss chair. Defeating that boss unlocks a new chair transformation.

Each transformation has:

1. A unique movement or traversal mechanic.
2. A combat identity.
3. A map-gating use that unlocks new areas or shortcuts.
4. A visual silhouette that is readable instantly.

The game loop is:

1. Explore an area.
2. Encounter obstacles the current chair form cannot bypass.
3. Fight enemies and platform through hazards.
4. Defeat a boss chair.
5. Unlock a new transformation.
6. Return to earlier map branches and access new routes.

---

## 2. Player Fantasy

The player should feel like a scrappy piece of furniture becoming progressively more ridiculous and powerful.

Tone targets:

- Silly premise, mechanically serious.
- Fast, readable, responsive controls.
- Transformations feel like toys with clear rules.
- Bosses are memorable chair archetypes, not generic enemies.
- Unlocking a form should immediately make the player think: “Oh, now I can reach that place I saw earlier.”

---

## 3. Core Mechanics

### 3.1 Basic Chair Form

The player starts as a plain wooden chair.

Core abilities:

- Move left/right.
- Jump.
- Short hop / full hop based on button hold.
- Basic melee attack: leg swipe or chair bash.
- Take damage.
- Interact with save points, doors, pickups, and boss doors.

Design role:

- Neutral baseline.
- No special traversal.
- Teaches core platforming and combat before transformations complicate the control scheme.

### 3.2 Transformation System

Transformations are unlocked by defeating bosses.

Rules:

- The player can switch between unlocked forms.
- Only one form is active at a time.
- Switching should be quick, ideally via radial menu, shoulder-button cycle, or number hotkeys on keyboard.
- Forms should share basic health unless a later design decision introduces form-specific armor.
- Each form has one primary special mechanic.
- Each form must have at least one obvious map-gating use.

Open design question:

- Should transformations consume energy, or should they be free once unlocked?

Initial recommendation:

- Do **not** make traversal transformations consume energy. Traversal gating should not require grinding resources.
- Combat specials may use cooldowns or stamina if needed.

---

## 4. Initial Transformation Set

These are candidate forms for the first vertical slice. Names can change later.

### 4.1 Basic Chair

**Unlocked:** Start of game.

**Traversal:** Standard walk and jump.

**Combat:** Short-range bash.

**Map Gates:** None.

**Purpose:** Baseline for all comparisons.

### 4.2 Armchair Form

**Boss Source:** The Recliner Baron.

**Fantasy:** A plush chair with big padded arms.

**Unique Mechanic:** Extendable arms.

Traversal uses:

- Grab ledges from farther away.
- Pull the player toward hook points.
- Push heavy objects or pressure blocks.
- Hang briefly from arm-grapple anchors.

Combat uses:

- Longer-range punch.
- Grab light enemies and throw them.
- Block weak frontal projectiles with padded arms.

Map gates:

- Cross gaps with arm-grapple points.
- Move heavy furniture blocking paths.
- Reach ledges too far for Basic Chair.

### 4.3 Office Chair Form

**Boss Source:** The Swivel Executive.

**Fantasy:** Rolling chair with wheels and corporate menace.

**Unique Mechanic:** Wheels and momentum.

Traversal uses:

- Roll quickly across flat ground.
- Build speed down slopes.
- Cross crumbling floors before they collapse.
- Dash through low tunnels.
- Wall-bump off special rubberized surfaces if desired later.

Combat uses:

- High-speed ram attack.
- Spin attack while moving.
- Knock enemies backward.

Map gates:

- Speed gates that require enough rolling momentum.
- Low passages only the Office Chair can fit through while rolling.
- Long conveyor or slope challenges.

### 4.4 Folding Chair Form

**Boss Source:** The Steel Folder.

**Fantasy:** A metal folding chair, compact and slapstick dangerous.

**Unique Mechanic:** Fold/unfold state.

Traversal uses:

- Fold flat to slip through narrow gaps.
- Stay planted while folded; unfold before jumping.

Combat uses:

- Fast metal slap attack.
- Parry with a snap-open timing window.
- Briefly flatten to avoid high attacks.

Map gates:

- Narrow vents.
- Timed crusher passages.

### 4.5 Rocking Chair Form

**Boss Source:** Granny Tremor.

**Fantasy:** An old rocking chair with uncanny rhythm.

**Unique Mechanic:** Airborne downward slam.

Traversal uses:

- Jump normally, then commit straight downward with the chair power.
- Break cracked floors with the landing impact.

Combat uses:

- Committed downward slam.
- Ground shockwave.
- Better damage against armored enemies.

Map gates:

- Cracked floors.
- Downward smash routes and impact switches.

### 4.6 Spring Stool Form

**Boss Source:** Granny Tremor.

**Fantasy:** A compact spring-loaded stool that turns a normal jump into one airborne pogo.

**Unique Mechanic:** One midair pogo, refreshed on landing.

Traversal uses:

- Gain extra vertical reach after committing to a normal jump.
- Reach high ledges and ascending routes that no other chair can clear.

Combat uses:

- Pogo impact damages enemies beneath the stool.

Map gates:

- High ledges and pogo staircases.

---

## 5. World Structure

### 5.1 Map Style

Use a connected 2D metroidvania world with discrete areas rather than isolated Mega Man stages.

Recommended structure:

- Central hub: The Workshop.
- 4-6 themed zones branching from the hub.
- Each zone contains at least one visible obstacle for a future transformation.
- Defeating a boss opens a transformation and a shortcut back toward the hub.

### 5.2 Candidate Areas

#### The Workshop

Starting hub and tutorial area.

Features:

- Save point.
- Basic movement tutorial.
- First locked routes visible but inaccessible.
- NPC or environmental storytelling if desired.

#### The Lounge

Armchair-themed area.

Features:

- Soft platforms.
- Hook points.
- Heavy ottomans to push.
- Boss: The Recliner Baron.

#### The Office Complex

Office Chair-themed area.

Features:

- Slopes.
- Conveyor belts.
- Speed gates.
- Cubicle maze shortcuts.
- Boss: The Swivel Executive.

#### The Storage Closet

Folding Chair-themed area.

Features:

- Tight vents.
- Stacked hazards.
- Timed crushers.
- Metal platforms.
- Boss: The Steel Folder.

#### The Parlor

Rocking Chair-themed area.

Features:

- Pendulum hazards.
- Rhythm plates.
- Breakable floors.
- Old-house creaks and timing puzzles.
- Boss: Granny Tremor.

#### The Throne Room

Late-game heavy-form area.

Features:

- Wind/current hazards.
- Heavy switches.
- Guards.
- Weak floors.
- Boss: The Upholstered King.

---

## 6. Progression and Ability Gates

### 6.1 Gate Types

Armchair gates:

- Grapple hooks.
- Heavy movable blocks.
- Distant ledges.

Office Chair gates:

- Speed ramps.
- Momentum doors.
- Low rolling tunnels.

Folding Chair gates:

- Narrow vents.
- Timed crusher gaps.

Rocking Chair gates:

- Cracked floors.
- Downward smash routes.

Spring Stool gates:

- High ledges.
- Pogo staircases.

### 6.2 Recommended Unlock Order

The implemented paired-reward order is:

1. Basic Chair.
2. Armchair + Recliner.
3. Office Chair + Bar Stool.
4. Folding Chair + High Chair.
5. Rocking Chair + Spring Stool.

Reasoning:

- Armchair teaches deliberate traversal first, while Recliner teaches defense.
- Office Chair adds speed and Bar Stool adds projectile reflection.
- Folding Chair adds low-profile state switching; High Chair adds ranged combat.
- Rocking Chair adds committed downward traversal; Spring Stool exclusively adds enhanced vertical reach.

---

## 7. Combat Design

### 7.1 Combat Goals

Combat should be simple enough not to overwhelm platforming, but varied enough that transformations matter. The default assumption is melee-first combat. The game should include exactly one ranged-focused chair form, justified by a silly physical chair gag such as buttons, studs, or upholstery bits popping off as projectiles.

Principles:

- Every enemy should have a readable tell.
- Contact damage should be used carefully.
- Bosses should be pattern-based.
- Transformations should provide advantages but not instantly trivialize all fights.
- Every form should remain combat-viable, though some forms may be weaker or more situational in combat than others.
- Ranged combat is not required for the first prototype, but should be reserved as the unique identity of one later form.

### 7.2 Basic Attacks

Every form should have:

- A primary attack.
- A movement profile.
- A special utility or special attack.

Example mapping:

| Form | Primary Attack | Special | Combat Role |
|---|---|---|---|
| Basic Chair | Short bash | None | Baseline |
| Armchair | Long punch | Grab/throw | Range/control |
| Office Chair | Ram | Spin | Speed/burst |
| Folding Chair | Metal slap | Parry | Precision/defense |
| Rocking Chair | Rock slam | Shockwave | Charged damage |
| Throne | Heavy smash | Armor stance | Tank/control |

### 7.3 Ranged Form Placeholder

The project should eventually include exactly one ranged chair form. Current best placeholder concept:

#### Button-Tufted Chair / Fancy Upholstered Chair

**Fantasy:** A fancy upholstered chair covered in buttons, studs, or decorative upholstery pieces.

**Ranged Gimmick:** The chair pops off buttons or studs as short-range projectiles. This should feel silly and physical, not like a generic gun.

Possible constraints:

- Projectiles have limited range.
- Fire rate is moderate.
- Buttons bounce slightly or arc downward.
- The form remains viable in melee, but its unique advantage is safe poking at distance.

Open naming ideas:

- Buttonback Chair.
- Tufted Chair.
- Fancy Chair.
- Studded Chair.

---

## 8. Boss Design

Each boss should teach or preview the transformation it unlocks.

### 8.1 Boss Requirements

Each boss needs:

- Clear silhouette.
- 3-5 attack patterns.
- At least one attack that foreshadows the unlocked mechanic.
- A phase change at roughly 50% health.
- Defeat animation that communicates transformation unlock.

### 8.2 Example Bosses

#### The Recliner Baron

Unlocks: Armchair.

Patterns:

- Extends footrest as a long-range strike.
- Throws cushions as projectiles.
- Leans back to block frontal attacks.
- Phase 2: grapples ceiling hooks and swings across arena.

#### The Swivel Executive

Unlocks: Office Chair.

Patterns:

- Rolls rapidly across arena.
- Spins to deflect attacks.
- Calls down stapler hazards or falling paperwork.
- Phase 2: uses slope ramps for faster charges.

#### The Steel Folder

Unlocks: Folding Chair.

Patterns:

- Snaps open as a parry.
- Folds flat and slides under attacks.
- Drops from above as a metal slam.
- Phase 2: bounces between walls while folded.

---

## 9. Controls

Initial keyboard controls:

| Action | Key |
|---|---|
| Move | A/D or Left/Right |
| Jump | Space |
| Attack | J / Left Mouse |
| Special | K / Right Mouse |
| Transform Next | E |
| Transform Previous | Q |
| Transform Wheel | Tab hold |
| Interact | F |
| Pause | Escape |

Controller support is a first-class requirement, with keyboard support included for development and PC play. The prototype can start keyboard-friendly during early iteration, but input actions should be designed through Godot's Input Map so controller bindings can exist from the beginning.

---

## 10. Camera and Feel

Camera requirements:

- Smooth follow with lookahead in movement direction.
- Slight vertical deadzone to avoid jitter while jumping.
- Boss arenas can lock the camera.
- Camera should reveal upcoming hazards early enough for speed-based Office Chair sections.

Movement feel requirements:

- Coyote time.
- Jump buffering.
- Variable jump height.
- Clear acceleration/deceleration values per form.
- Form-specific movement should feel different but not clumsy unless intentionally heavy.

---

## 11. Art Direction

Style target:

- Readable 2D sprites.
- Exaggerated silhouettes.
- Furniture-themed enemies and environments.
- Slightly goofy, not gross or horror-first.

Recommended prototype art approach:

- Use simple colored rectangles and placeholder sprites first.
- Give each form a distinct color and shape.
- Do not block implementation on final art.

Storytelling target:

- Mostly environmental storytelling.
- The silent chair protagonist should not speak.
- Start with one NPC in the central hub area.
- The NPC can sit in the central area between unlocks and provide flavor commentary as the player gains new transformations.
- Additional NPCs should be deferred until the first hub NPC proves useful.
- Signs, background gags, arena dressing, and enemy behavior should carry most of the worldbuilding.

Potential form colors:

| Form | Color |
|---|---|
| Basic Chair | Brown |
| Armchair | Red/plush |
| Office Chair | Black/gray/blue |
| Folding Chair | Silver |
| Rocking Chair | Dark wood |
| Throne | Gold/purple |

---

## 12. Audio Direction

Audio should emphasize physical comedy and readable feedback.

Examples:

- Wooden clacks for Basic Chair movement and attacks.
- Soft thumps for Armchair punches.
- Wheel squeaks and rolling acceleration for Office Chair.
- Metallic snaps for Folding Chair.
- Creaking rhythm sounds for Rocking Chair.
- Heavy royal impacts for Throne.

Music:

- Energetic platformer music.
- Each area gets a furniture/environment flavor.
- Boss music should be intense but playful.

---

## 13. Prototype Scope

### 13.1 Minimum Playable Prototype

Build the smallest version that proves the concept:

1. Godot 4 project boots into a test level.
2. Basic Chair can move, jump, and attack.
3. One transformation exists: Armchair.
4. Player can switch between Basic Chair and Armchair.
5. Armchair can extend arms to grapple/pull to a hook point.
6. One blocked route requires Armchair to access.
7. One simple boss or miniboss unlocks Armchair.
8. One save/checkpoint or restart flow exists.

### 13.2 Vertical Slice

After the minimum prototype:

1. Add Office Chair form.
2. Add one larger connected map with two gated routes.
3. Add two bosses: Recliner Baron and Swivel Executive.
4. Add health, damage, death, respawn.
5. Add placeholder UI for health and current form.
6. Add rough sound effects.
7. Add pause menu and restart.

---

## 14. Suggested Godot Project Architecture

This is the proposed file structure once implementation begins:

```text
chairfighter/
  project.godot
  SPEC.md
  scenes/
    main/Main.tscn
    player/Player.tscn
    levels/TestLevel.tscn
    levels/Workshop.tscn
    bosses/ReclinerBaron.tscn
    ui/HUD.tscn
  scripts/
    player/Player.gd
    player/ChairForm.gd
    player/forms/BasicChairForm.gd
    player/forms/ArmchairForm.gd
    components/Health.gd
    components/Hitbox.gd
    components/Hurtbox.gd
    bosses/ReclinerBaron.gd
    world/AbilityGate.gd
    world/GrapplePoint.gd
    ui/HUD.gd
  assets/
    sprites/placeholders/
    audio/sfx/
    audio/music/
  tests/
```

### 14.1 Core Code Concepts

Recommended architecture:

- `Player.gd` owns movement state, health, input, current form, and form switching.
- `ChairForm.gd` is a base resource or node defining a form interface.
- Individual forms implement movement modifiers, attack behavior, and special mechanics.
- `AbilityGate.gd` checks whether the current unlocked forms satisfy a gate requirement.
- Boss defeat emits an unlock event.
- A simple game state/autoload tracks unlocked forms.

Initial form interface idea:

```gdscript
class_name ChairForm
extends Resource

var id: StringName
var display_name: String
var move_speed: float
var jump_velocity: float

func enter(player: Node) -> void:
    pass

func exit(player: Node) -> void:
    pass

func handle_primary(player: Node) -> void:
    pass

func handle_special(player: Node) -> void:
    pass
```

---

## 15. Implementation Plan Draft

This section is intentionally high-level. Create a separate implementation plan with bite-sized tasks before coding.

### Task 1: Create Godot Project Skeleton

**Objective:** Create a Godot 4 project with standard folders and a bootable main scene.

**Files:**

- Create: `project.godot`
- Create: `scenes/main/Main.tscn`
- Create: `scenes/levels/TestLevel.tscn`
- Create: folder structure listed in Section 14.

**Verification:**

- Run the project in Godot.
- Expected: main scene loads without errors.

### Task 2: Implement Basic Chair Movement

**Objective:** Add responsive 2D platformer movement for Basic Chair.

**Files:**

- Create: `scenes/player/Player.tscn`
- Create: `scripts/player/Player.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Player moves left/right.
- Player jumps.
- Coyote time and jump buffering exist.
- Camera follows player.

### Task 3: Add Basic Combat Stub

**Objective:** Add a simple melee attack with hitbox/hurtbox foundations.

**Files:**

- Create: `scripts/components/Hitbox.gd`
- Create: `scripts/components/Hurtbox.gd`
- Create: `scripts/components/Health.gd`
- Modify: `scripts/player/Player.gd`

**Acceptance Criteria:**

- Attack button spawns/enables a short-range hitbox.
- A dummy enemy can take damage.

### Task 4: Add Transformation State System

**Objective:** Allow the player to switch between Basic Chair and placeholder Armchair.

**Files:**

- Create: `scripts/player/ChairForm.gd`
- Create: `scripts/player/forms/BasicChairForm.gd`
- Create: `scripts/player/forms/ArmchairForm.gd`
- Modify: `scripts/player/Player.gd`
- Create: `scripts/state/GameState.gd`

**Acceptance Criteria:**

- Player starts with Basic Chair.
- Armchair can be marked unlocked.
- Player can switch to Armchair after unlock.
- Current form is visible in debug UI or HUD.

### Task 5: Implement Armchair Grapple

**Objective:** Give Armchair a unique arm extension/grapple mechanic.

**Files:**

- Create: `scripts/world/GrapplePoint.gd`
- Modify: `scripts/player/forms/ArmchairForm.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Armchair can target a grapple point within range.
- Special button pulls player toward the point.
- Basic Chair cannot use grapple points.

### Task 6: Add First Ability Gate

**Objective:** Create a route that requires Armchair grapple to access.

**Files:**

- Create: `scripts/world/AbilityGate.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- A visible route is inaccessible as Basic Chair.
- The same route is accessible with Armchair.

### Task 7: Add Recliner Baron Miniboss

**Objective:** Add a simple boss encounter that unlocks Armchair on defeat.

**Files:**

- Create: `scenes/bosses/ReclinerBaron.tscn`
- Create: `scripts/bosses/ReclinerBaron.gd`
- Modify: `scripts/state/GameState.gd`
- Modify: `scenes/levels/TestLevel.tscn`

**Acceptance Criteria:**

- Boss has health.
- Boss uses at least two simple attack patterns.
- Defeating boss unlocks Armchair.
- Unlock is communicated clearly to the player.

---

## 16. Acceptance Criteria for the Concept

The prototype succeeds if:

- The player can describe the difference between Basic Chair and Armchair after 30 seconds of play.
- The player sees a blocked route before unlocking Armchair.
- After unlocking Armchair, the player remembers that route and can access it.
- Movement feels responsive enough to continue iterating.
- The core joke remains funny after the first few minutes.

---

## 17. Open Questions

Decide these later, after the first prototype exists:

1. Which later boss should unlock the ranged Button-Tufted/Fancy Chair form?
2. Should the ranged projectile be buttons, studs, upholstery tufts, or another pop-off chair part?
3. Who or what is the central hub NPC, and what is their comedic role?
4. What should the final title become if `Chairfighter` remains only a placeholder?

---

## 18. Immediate Next Step

Create a Godot 4 project in this folder, then write a separate implementation plan for the minimum playable prototype.

Recommended next command from `/home/stevets/projects/chairfighter` once ready:

```bash
git init
mkdir -p scenes/main scenes/player scenes/levels scenes/bosses scenes/ui \
  scripts/player/forms scripts/components scripts/bosses scripts/world scripts/ui scripts/state \
  assets/sprites/placeholders assets/audio/sfx assets/audio/music tests
```

Then create the Godot project file and begin with Basic Chair movement.
