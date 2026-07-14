extends Node
## Autoload name: DemoDriver. Scripted-input playthrough driver.
##
## Inert unless the environment variable CHAIRFIGHTER_DEMO (or user arg
## --demo=<path>) names a JSON step script. Drives the game exclusively
## through Input.action_press/release so a passing run proves the game is
## beatable through the real input path. Prints "DEMO PASS" / "DEMO FAIL:"
## and exits with code 0/1.
##
## Step schema: see docs/superpowers/plans/2026-07-13-chairfighter-rebuild.md.
## In headless runs, Engine.time_scale is raised so a full playthrough takes
## minutes, not the real-time duration; per-tick simulation is unchanged.

var active := false
## Base engine time scale; HitStop multiplies against this instead of 1.0.
var time_scale_base := 1.0

var _steps: Array = []
var _idx := -1
var _elapsed := 0.0            # sim-seconds inside the current step
var _s: Dictionary = {}        # per-step scratch state
var _current_zone := ""
var _won := false
var _player_hp := 999
var _pending_screenshot := ""
var _shot_counter := 0

const TAP_TIME := 0.06
const MOVE_ACTIONS := ["move_left", "move_right"]
const ALL_ACTIONS := ["move_left", "move_right", "jump", "attack", "special", "interact", "transform_next", "transform_prev", "ui_accept"]
const HEADLESS_TIME_SCALE := 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path := OS.get_environment("CHAIRFIGHTER_DEMO")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			path = arg.substr("--demo=".length())
	if path.is_empty():
		set_physics_process(false)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DEMO FAIL: cannot open step script %s" % path)
		get_tree().quit(1)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Array):
		push_error("DEMO FAIL: step script is not a JSON array: %s" % path)
		get_tree().quit(1)
		return
	for i in (parsed as Array).size():
		if not (parsed[i] is Dictionary):
			push_error("DEMO FAIL: step %d is not an object: %s" % [i, str(parsed[i])])
			get_tree().quit(1)
			return
	_steps = parsed
	active = true
	# Deterministic runs: never continue a leftover save.
	GameState.clear_save.call_deferred()
	# MovieWriter capture must run at natural speed; headless runs fast.
	# CRITICAL: time_scale alone scales the physics DELTA (bigger per-tick
	# displacement → sensor skips, arrive-window tunneling). Raising the
	# tick rate by the same factor keeps delta at exactly 1/60 — the sim is
	# tick-identical to real play, just 6× wall speed.
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		time_scale_base = HEADLESS_TIME_SCALE
		Engine.time_scale = time_scale_base
		Engine.physics_ticks_per_second = int(60 * HEADLESS_TIME_SCALE)
		Engine.max_physics_steps_per_frame = int(8 * HEADLESS_TIME_SCALE)
	Events.zone_loaded.connect(func(zone_name: String) -> void: _current_zone = zone_name)
	Events.game_won.connect(func() -> void: _won = true)
	Events.player_health_changed.connect(_on_player_health)
	print("DEMO START: %d steps from %s (time_scale %.1f)" % [_steps.size(), path, time_scale_base])


func _on_player_health(current: int, _maximum: int) -> void:
	if current < _player_hp and _s.has("next_hop"):
		# Queue a hop — the hurt-state stun (0.25s) outlives both the jump
		# buffer and an immediate press, so the hop fires once control
		# returns (see _run_auto_fight).
		_s["pending_hop_at"] = _elapsed + 0.3
	_player_hp = current


func _physics_process(delta: float) -> void:
	if not active:
		return
	if _idx == -1:
		_advance()
		return
	if _idx >= _steps.size():
		return
	_elapsed += delta
	var step: Dictionary = _steps[_idx]
	var op := String(step.get("op", ""))
	var timeout := float(step.get("timeout", _default_timeout(op)))
	if timeout > 0.0 and _elapsed > timeout:
		_fail("step %d (%s) timed out after %.1fs" % [_idx, op, timeout])
		return
	match op:
		"wait":
			if _elapsed >= float(step.get("secs", 1.0)):
				_done()
		"tap":
			_run_timed_press(String(step.get("action", "ui_accept")), TAP_TIME)
		"press":
			Input.action_press(String(step.get("action", "")))
			_done()
		"release":
			Input.action_release(String(step.get("action", "")))
			_done()
		"jump":
			_run_timed_press("jump", float(step.get("hold", 0.42)))
		"hold_jump":
			_run_timed_press("jump", float(step.get("secs", 0.42)))
		"special_tap", "dash":
			_run_timed_press("special", TAP_TIME)
		"special_hold":
			_run_timed_press("special", float(step.get("secs", 0.5)))
		"interact":
			_run_timed_press("interact", TAP_TIME)
		"walk_until_x":
			_run_walk_until_x(step)
		"grapple":
			_run_grapple(step)
		"transform_to":
			_run_transform_to(step)
		"wait_flag":
			if GameState.has_flag(String(step.get("flag", ""))):
				_done()
		"assert_flag":
			if GameState.has_flag(String(step.get("flag", ""))):
				_done()
			else:
				_fail("assert_flag: %s not set" % step.get("flag", ""))
		"wait_zone":
			if _current_zone == String(step.get("zone", "")):
				_done()
		"assert_zone":
			if _current_zone == String(step.get("zone", "")):
				_done()
			else:
				_fail("assert_zone: in '%s', expected '%s'" % [_current_zone, step.get("zone", "")])
		"assert_form":
			if GameState.current_form == StringName(String(step.get("form", ""))):
				_done()
			else:
				_fail("assert_form: %s, expected %s" % [GameState.current_form, step.get("form", "")])
		"wait_on_floor":
			var p := _player()
			if p != null and p.is_on_floor() \
					and (not p.has_method("is_alive") or p.is_alive()):
				_done()
		"wait_won":
			if _won:
				_done()
		"auto_fight":
			_run_auto_fight(step)
		"cheat_setup":
			_run_cheat_setup(step)
		"screenshot":
			_run_screenshot(step)
		_:
			_fail("unknown op '%s' at step %d" % [op, _idx])


func _default_timeout(op: String) -> float:
	match op:
		"auto_fight":
			return 420.0
		"wait_flag", "wait_zone", "wait_won":
			return 30.0
		"walk_until_x", "grapple":
			return 15.0
		_:
			return 20.0


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _advance() -> void:
	_idx += 1
	_elapsed = 0.0
	_s = {}
	if _idx >= _steps.size():
		_release_all()
		# Full runs must actually win; zone segments just need all steps green.
		var requires_win := false
		for s in _steps:
			if String(s.get("op", "")) == "wait_won":
				requires_win = true
				break
		if _won or not requires_win:
			print("DEMO PASS")
			get_tree().quit(0)
		else:
			_fail("script finished but game_won never fired")
		return
	var step: Dictionary = _steps[_idx]
	print("DEMO STEP %d/%d: %s" % [_idx + 1, _steps.size(), JSON.stringify(step)])


func _done() -> void:
	_advance()


func _fail(reason: String) -> void:
	_release_all()
	var p := _player()
	if p != null:
		reason += " [player id=%d at %s, vel %s, floor=%s, zone='%s', form=%s]" % [
			p.get_instance_id(), p.global_position.round(), p.velocity.round(),
			p.is_on_floor(), _current_zone, GameState.current_form]
	push_error("DEMO FAIL: " + reason)
	print("DEMO FAIL: " + reason)
	active = false
	get_tree().quit(1)


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


# ── op implementations ──

func _run_timed_press(action: String, hold: float) -> void:
	if not _s.has("pressed"):
		_s["pressed"] = true
		Input.action_press(action)
	if _elapsed >= hold:
		Input.action_release(action)
		_done()


func _run_walk_until_x(step: Dictionary) -> void:
	var p := _player()
	if p == null:
		return
	var target := float(step.get("x", 0.0))
	var tol := float(step.get("tol", 8.0))
	var dx := target - p.global_position.x
	if absf(dx) <= tol:
		for a in MOVE_ACTIONS:
			Input.action_release(a)
		if _s.get("hop_pressed", false):
			Input.action_release("jump")  # never leak a held hop across steps
		_done()
		return
	var want := "move_right" if dx > 0.0 else "move_left"
	var other := "move_left" if dx > 0.0 else "move_right"
	Input.action_release(other)
	Input.action_press(want)
	_stuck_hop(p, bool(step.get("no_hop", false)))


## Auto-hop when walking into a small ledge: pressing a direction but not
## actually MOVING (position delta, not velocity — move_and_slide can leave
## velocity nonzero while pinned against a wall) ⇒ hold a jump.
func _stuck_hop(p: CharacterBody2D, disabled: bool) -> void:
	if disabled:
		return
	var x := p.global_position.x
	var moved := absf(x - float(_s.get("stuck_x", x))) > 2.0
	if moved or not _s.has("stuck_x"):
		_s["stuck_x"] = x
		_s["stuck_since"] = _elapsed
	if _s.get("hop_pressed", false):
		if _elapsed - float(_s.get("hop_at", 0.0)) > 0.35:
			Input.action_release("jump")
			_s["hop_pressed"] = false
			_s["stuck_x"] = x
			_s["stuck_since"] = _elapsed
		return
	if p.is_on_floor() and _elapsed - float(_s.get("stuck_since", 0.0)) > 0.3:
		Input.action_press("jump")
		_s["hop_pressed"] = true
		_s["hop_at"] = _elapsed


func _run_grapple(step: Dictionary) -> void:
	var p := _player()
	if p == null:
		return
	if not _s.has("pressed"):
		_s["pressed"] = true
		Input.action_press("special")
		return
	var grappling: bool = p.has_method("is_grappling") and p.is_grappling()
	if grappling:
		_s["was_grappling"] = true
	if _s.get("was_grappling", false) and not grappling:
		Input.action_release("special")
		_done()
		return
	if not _s.get("was_grappling", false) and _elapsed > float(step.get("attach_by", 1.0)):
		Input.action_release("special")
		_fail("grapple never attached (step %d)" % _idx)


func _run_transform_to(step: Dictionary) -> void:
	var target := StringName(String(step.get("form", "basic")))
	if GameState.current_form == target:
		Input.action_release("transform_next")
		_done()
		return
	if not GameState.is_unlocked(target):
		_fail("transform_to: form '%s' is locked" % target)
		return
	# Cycle with spaced taps through the real input action.
	var next_tap := float(_s.get("next_tap", 0.0))
	if _elapsed >= next_tap:
		if _s.get("tap_down", false):
			Input.action_release("transform_next")
			_s["tap_down"] = false
			_s["next_tap"] = _elapsed + 0.12
		else:
			Input.action_press("transform_next")
			_s["tap_down"] = true
			_s["next_tap"] = _elapsed + TAP_TIME
		_s["taps"] = int(_s.get("taps", 0)) + (1 if _s["tap_down"] else 0)
	if int(_s.get("taps", 0)) > 12:
		_fail("transform_to: cycled 12 times without reaching '%s'" % target)


func _run_auto_fight(step: Dictionary) -> void:
	var flag := String(step.get("flag", ""))
	if flag.is_empty():
		_fail("auto_fight requires 'flag'")
		return
	if GameState.has_flag(flag):
		_release_all()
		_done()
		return
	var p := _player()
	if p == null or (p.has_method("is_alive") and not p.is_alive()):
		# Dead/mid-respawn: release everything and wait.
		_release_all()
		_s["retreat_until"] = 0.0
		return
	if not _s.has("next_hop"):
		_s["next_attack"] = 0.0
		_s["next_hop"] = 0.6
		_s["engage"] = 48.0
		if p.has_method("attack_reach"):
			_s["engage"] = maxf(40.0, p.attack_reach() * 0.9)
	var boss := _find_boss(step)
	var move_to := INF
	if boss != null:
		_s["arena_x"] = boss.global_position.x
		move_to = boss.global_position.x
	elif _s.has("arena_x"):
		move_to = float(_s["arena_x"])
	if _elapsed >= float(_s.get("next_log", 0.0)):
		_s["next_log"] = _elapsed + 5.0
		var hp := "?"
		var bactive := "?"
		if boss != null and "health" in boss and boss.health != null:
			hp = "%.0f/%.0f" % [boss.health.current, boss.health.max_health]
			bactive = str(boss.active)
		print("DEMO FIGHT t=%.0fs boss=%s hp=%s active=%s player=%s php=%d" % [
			_elapsed, boss.global_position.round() if boss != null else "none",
			hp, bactive, p.global_position.round(), _player_hp])
	if move_to == INF:
		return  # nothing to walk toward yet; timeout guards us
	var dx := move_to - p.global_position.x
	var engaged := boss != null and absf(dx) <= float(_s["engage"])
	if engaged:
		for a in MOVE_ACTIONS:
			Input.action_release(a)
	else:
		var want := "move_right" if dx > 0.0 else "move_left"
		var other := "move_left" if dx > 0.0 else "move_right"
		Input.action_release(other)
		Input.action_press(want)
		_stuck_hop(p, false)
	# Opportunistic swings: fast bosses (slides, charges, ricochets) mostly
	# pass THROUGH the policy's reach — attack on cooldown whenever close,
	# regardless of movement state.
	if boss != null and absf(dx) <= float(_s["engage"]) * 1.6 \
			and _elapsed >= float(_s["next_attack"]):
		Input.action_press("attack")
		_s["attack_down_at"] = _elapsed
		_s["next_attack"] = _elapsed + 0.36
	if _s.has("attack_down_at") and _elapsed - float(_s["attack_down_at"]) > TAP_TIME:
		Input.action_release("attack")
		_s.erase("attack_down_at")
	# Deferred hop-on-hit: fire once the hurt stun has released control.
	if _s.has("pending_hop_at") and _elapsed >= float(_s["pending_hop_at"]):
		_s.erase("pending_hop_at")
		if not _s.has("hop_release") and p.is_on_floor():
			Input.action_press("jump")
			_s["hop_release"] = _elapsed + 0.18
	# Anticipatory dodge: boss closing in fast at ground level ⇒ full hop NOW.
	if boss != null and boss is CharacterBody2D and not _s.has("hop_release"):
		var bvel: Vector2 = (boss as CharacterBody2D).velocity
		var closing := bvel.x * signf(p.global_position.x - boss.global_position.x)
		if closing > 380.0 and absf(dx) < 360.0 and absf(boss.global_position.y - p.global_position.y) < 80.0:
			Input.action_press("jump")
			_s["hop_release"] = _elapsed + 0.32
			_s["next_hop"] = _elapsed + 0.6
	# Periodic short hop to slip ground-level patterns.
	if engaged and _elapsed >= float(_s["next_hop"]):
		Input.action_press("jump")
		_s["hop_release"] = _elapsed + 0.15
		_s["next_hop"] = _elapsed + float(step.get("hop_interval", 1.1))
	if _s.has("hop_release") and _elapsed >= float(_s["hop_release"]):
		Input.action_release("jump")
		_s.erase("hop_release")


func _find_boss(step: Dictionary) -> Node2D:
	var want_id := String(step.get("boss", ""))
	for node in get_tree().get_nodes_in_group("boss"):
		if not (node is Node2D):
			continue
		if want_id.is_empty():
			return node
		if "boss_id" in node and String(node.boss_id) == want_id:
			return node
	return null


## Test-only shortcut for zone-segment scripts: grant forms and warp to a
## zone. NEVER used by full_run.json — the full playthrough earns everything
## through real play. Requires the game to be started (tap ui_accept first).
func _run_cheat_setup(step: Dictionary) -> void:
	# Already in the target zone (same-zone setup): grant forms and finish.
	if not _s.has("requested") and String(step.get("zone_name", "")) == _current_zone \
			and _player() != null:
		for f in step.get("forms", []):
			GameState.unlock_form(StringName(String(f)))
		if step.has("form"):
			GameState.set_form(StringName(String(step.get("form"))))
		_done()
		return
	if not _s.has("requested"):
		_s["requested"] = true
		for f in step.get("forms", []):
			GameState.unlock_form(StringName(String(f)))
		if step.has("form"):
			GameState.set_form(StringName(String(step.get("form"))))
		if step.has("zone"):
			GameState.set_checkpoint(String(step.get("zone")), String(step.get("spawn", "Default")))
			Events.zone_change_requested.emit(String(step.get("zone")), String(step.get("spawn", "Default")))
		return
	var want_zone := String(step.get("zone_name", ""))
	if not want_zone.is_empty() and _current_zone != want_zone:
		return
	var p := _player()
	if p != null and p.is_on_floor():
		_done()


func _run_screenshot(step: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		_done()
		return
	if _pending_screenshot.is_empty():
		_shot_counter += 1
		_pending_screenshot = String(step.get("name", "shot_%02d" % _shot_counter))
		_capture_screenshot.call_deferred()
	# _done() is called by _capture_screenshot when the image is saved.


func _capture_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://build/playthrough/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := "%s/%02d_%s.png" % [dir, _shot_counter, _pending_screenshot]
	img.save_png(file)
	print("DEMO SHOT: %s" % file)
	_pending_screenshot = ""
	_done()
