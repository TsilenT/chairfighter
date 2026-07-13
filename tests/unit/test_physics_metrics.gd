extends RefCounted
## THE keystone test: simulates real input against the real Player scene and
## asserts the design-table movement metrics hold (spec §Physics from metrics).
## If someone tunes a constant, this fails before any level can silently break.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const FLOOR_Y := 400.0
const EPS_JUMP := 0.05     # ±5%
const EPS_SPEED := 0.02    # ±2%

var _sandbox: Node2D


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	gs.new_game()
	for id in [&"armchair", &"office", &"folding"]:
		gs.unlock_form(id)

	_sandbox = Node2D.new()
	tree.root.add_child(_sandbox)
	_build_floor()

	var player: CharacterBody2D = load(PLAYER_SCENE).instantiate()
	_sandbox.add_child(player)

	# Jump heights per form.
	for id: StringName in gs.FORM_ORDER:
		gs.set_form(id)
		await _settle(tree, player)
		var form: FormDef = player.form
		var height := await _measure_jump(tree, player, true)
		if absf(height - form.jump_height) > form.jump_height * EPS_JUMP:
			fails.append("%s: held jump height %.1f, expected %.1f ±5%%" % [id, height, form.jump_height])
		# Early-release hop must be meaningfully shorter.
		await _settle(tree, player)
		var hop := await _measure_jump(tree, player, false)
		if hop > height * 0.55 or hop < 20.0:
			fails.append("%s: early-release hop %.1f should be 20..%.1f" % [id, hop, height * 0.55])

	# Run speed per form.
	for id: StringName in gs.FORM_ORDER:
		gs.set_form(id)
		await _settle(tree, player)
		var form: FormDef = player.form
		Input.action_press("move_right")
		for _i in 45:  # 0.75s: plenty to reach max speed
			await tree.physics_frame
		var speed: float = player.velocity.x
		Input.action_release("move_right")
		if absf(speed - form.run_speed) > form.run_speed * EPS_SPEED:
			fails.append("%s: run speed %.1f, expected %.1f ±2%%" % [id, speed, form.run_speed])
		await _settle(tree, player)

	# Office dash distance and low profile.
	gs.set_form(&"office")
	await _settle(tree, player)
	var x0: float = player.global_position.x
	await _tap(tree, "special")
	if not player.is_dashing():
		fails.append("office: dash did not start on special")
	var dash_h: float = (player.get_node("Collider").shape as RectangleShape2D).size.y
	if absf(dash_h - 32.0) > 0.5:
		fails.append("office: dash collider height %.1f, expected 32" % dash_h)
	var guard := 0
	while player.is_dashing() and guard < 120:
		await tree.physics_frame
		guard += 1
	var dash_dist: float = player.global_position.x - x0
	if dash_dist < 220.0 or dash_dist > 300.0:
		fails.append("office: dash distance %.1f, expected 220..300" % dash_dist)

	# Folding: fold collider + spring jump height.
	gs.set_form(&"folding")
	await _settle(tree, player)
	await _tap(tree, "special")
	if not player.folded:
		fails.append("folding: special tap did not fold")
	var fold_h: float = (player.get_node("Collider").shape as RectangleShape2D).size.y
	if absf(fold_h - 20.0) > 0.5:
		fails.append("folding: folded collider height %.1f, expected 20" % fold_h)
	var spring := await _measure_jump(tree, player, true)
	if absf(spring - 230.0) > 230.0 * EPS_JUMP:
		fails.append("folding: spring jump %.1f, expected 230 ±5%%" % spring)
	await tree.physics_frame
	if player.folded:
		fails.append("folding: spring jump should unfold")

	player.queue_free()
	_sandbox.queue_free()
	await tree.physics_frame
	gs.new_game()
	return fails


func _build_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20000, 200)
	shape.shape = rect
	body.position = Vector2(0, FLOOR_Y + 100.0)
	shape.position = Vector2.ZERO
	body.add_child(shape)
	_sandbox.add_child(body)


## Realistic tap: hold for 3 physics ticks (a 1-tick tap can vanish into
## input-stamp boundaries; real presses are never that short).
func _tap(tree: SceneTree, action: String) -> void:
	Input.action_press(action)
	for _i in 3:
		await tree.physics_frame
	Input.action_release(action)
	await tree.physics_frame


## Wait until the player is resting on the floor with no input held.
func _settle(tree: SceneTree, player: CharacterBody2D) -> void:
	for a in ["move_left", "move_right", "jump", "special", "attack"]:
		Input.action_release(a)
	player.global_position = Vector2(0, FLOOR_Y - 300.0)
	player.velocity = Vector2.ZERO
	var guard := 0
	while guard < 240:
		await tree.physics_frame
		guard += 1
		if player.is_on_floor() and absf(player.velocity.x) < 1.0:
			break
	for _i in 5:
		await tree.physics_frame


## Press jump (optionally holding) and return the apex height above start.
func _measure_jump(tree: SceneTree, player: CharacterBody2D, hold: bool) -> float:
	var start_y: float = player.global_position.y
	var min_y := start_y
	Input.action_press("jump")
	var frames := 0
	var released := not hold
	if not hold:
		# Release after ~4 ticks (~0.07s) for the minimal hop.
		pass
	while frames < 300:
		await tree.physics_frame
		frames += 1
		if not hold and frames == 4:
			Input.action_release("jump")
		min_y = minf(min_y, player.global_position.y)
		if frames > 8 and player.is_on_floor():
			break
	Input.action_release("jump")
	released = released
	return start_y - min_y
