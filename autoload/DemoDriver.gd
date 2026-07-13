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
	_steps = parsed
	active = true
	# MovieWriter capture must run at natural speed; headless runs fast.
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		time_scale_base = HEADLESS_TIME_SCALE
		Engine.time_scale = time_scale_base
	Events.zone_loaded.connect(func(zone_name: String) -> void: _current_zone = zone_name)
	Events.game_won.connect(func() -> void: _won = true)
	Events.player_health_changed.connect(_on_player_health)
	print("DEMO START: %d steps from %s (time_scale %.1f)" % [_steps.size(), path, time_scale_base])


func _on_player_health(current: int, _maximum: int) -> void:
	if current < _player_hp and _s.has("retreat_until"):
		_s["retreat_until"] = _elapsed + 0.5
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
			if p != null and p.is_on_floor():
				_done()
		"wait_won":
			if _won:
				_done()
		"auto_fight":
			_run_auto_fight(step)
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
		if _won:
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
		_done()
		return
	var want := "move_right" if dx > 0.0 else "move_left"
	var other := "move_left" if dx > 0.0 else "move_right"
	Input.action_release(other)
	Input.action_press(want)
	_stuck_hop(p, bool(step.get("no_hop", false)))


## Auto-hop when walking into a small ledge: pressing a direction but not
## moving for a while ⇒ tap jump. Keeps walk ops robust across zones.
func _stuck_hop(p: CharacterBody2D, disabled: bool) -> void:
	if disabled:
		return
	if absf(p.velocity.x) > 12.0 or not p.is_on_floor():
		_s["stuck_since"] = _elapsed
		if _s.get("hop_pressed", false):
			Input.action_release("jump")
			_s["hop_pressed"] = false
		return
	if _elapsed - float(_s.get("stuck_since", 0.0)) > 0.35:
		if not _s.get("hop_pressed", false):
			Input.action_press("jump")
			_s["hop_pressed"] = true
			_s["hop_at"] = _elapsed
	if _s.get("hop_pressed", false) and _elapsed - float(_s.get("hop_at", 0.0)) > 0.3:
		Input.action_release("jump")
		_s["hop_pressed"] = false
		_s["stuck_since"] = _elapsed


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
	if not _s.has("retreat_until"):
		_s["retreat_until"] = 0.0
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
	if move_to == INF:
		return  # nothing to walk toward yet; timeout guards us
	var dx := move_to - p.global_position.x
	var engaged := boss != null and absf(dx) <= float(_s["engage"])
	if _elapsed < float(_s["retreat_until"]) and boss != null:
		# Back off briefly after taking a hit.
		var away := "move_left" if dx > 0.0 else "move_right"
		var toward := "move_right" if dx > 0.0 else "move_left"
		Input.action_release(toward)
		Input.action_press(away)
	elif engaged:
		for a in MOVE_ACTIONS:
			Input.action_release(a)
		if _elapsed >= float(_s["next_attack"]):
			Input.action_press("attack")
			_s["attack_down_at"] = _elapsed
			_s["next_attack"] = _elapsed + 0.36
	else:
		var want := "move_right" if dx > 0.0 else "move_left"
		var other := "move_left" if dx > 0.0 else "move_right"
		Input.action_release(other)
		Input.action_press(want)
		_stuck_hop(p, false)
	if _s.has("attack_down_at") and _elapsed - float(_s["attack_down_at"]) > TAP_TIME:
		Input.action_release("attack")
		_s.erase("attack_down_at")
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
