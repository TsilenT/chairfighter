# CF-04R Review combat foundations — t_27bceabf

Status: approved yes after tiny direct fixes.

Summary:
Combat foundation is reusable enough for player/enemy/boss, damage flow is understandable, melee hitboxes deactivate on a 0.15s active window / 0.3s cooldown, DummyEnemy proves damage/removal, and no ranged combat was added.

Fixes made during review:
- Replaced obsolete collision_layer_bit/collision_mask_bit usage with Godot 4 set_collision_layer_value/set_collision_mask_value in Hitbox/Hurtbox.
- Connected Hitbox/Hurtbox area_entered signals and used typed Area2D checks instead of invalid property probing.
- Added runtime CollisionShape2D rectangles for Player melee hitbox and player hurtbox so overlaps can actually occur.
- Made Player respect Hitbox.activate() returning false during cooldown and update facing direction for left/right attacks.
- Initialized DummyEnemy health listeners/current_hp after applying its 5 HP max_health.
- Fixed Player form cycling reference to GameState.form_order and corrected Health layer comments.
- Removed trailing whitespace in modified GDScript files.

Commands/checks run:
- kanban_show t_27bceabf
- git status --short
- read SPEC/implementation plan CF-04 and CF-04R sections
- read combat component scripts and relevant player/enemy/level scenes
- search_files static scans for obsolete combat APIs and ranged/projectile terms
- git diff --check
- custom Python static assertions for hitbox/hurtbox wiring, player collision shapes, DummyEnemy HP initialization, no obsolete combat API, no ranged/projectile terms
- checked for godot4/godot CLI; none found

Verification:
- git diff --check: pass
- static assertions: pass
- Godot CLI: not available in this environment
- manual playtest: not run; no Godot CLI/editor available

Risks for next task:
- Runtime parse/manual combat behavior still needs validation in a Godot-installed environment.
- Implementation changes remain uncommitted in the shared workspace; review fixes are included in the current working tree with the CF-04 implementation changes.

Board completion failure:
Attempted kanban_complete for t_27bceabf, but the kanban tools began returning `database disk image is malformed`. A follow-up kanban_show produced the same error. HERMES_KANBAN_DB was `/home/stevets/.hermes/kanban/boards/chairfighter/kanban.db`; sqlite3 CLI was not installed for an integrity_check from this shell.
