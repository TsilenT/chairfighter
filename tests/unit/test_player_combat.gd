extends RefCounted
## Focused gameplay coverage for chair-native contact profiles and the four
## added specials. Uses real Player input so press/release state cannot drift
## away from the public finale hooks.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const FLOOR_Y := 400.0

var _sandbox: Node2D


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	gs.new_game()
	gs.unlock_forms(gs.REQUIRED_FINAL_FORMS)

	_sandbox = Node2D.new()
	tree.root.add_child(_sandbox)
	_build_floor()
	var player: Player = load(PLAYER_SCENE).instantiate()
	_sandbox.add_child(player)

	var used_mechanics: Array[StringName] = []
	player.special_used.connect(func(_form_id: StringName, mechanic: StringName) -> void:
		used_mechanics.append(mechanic))

	# Player must actually install every authored contact profile, and every
	# profile begins over the chair body instead of floating out in whiff-space.
	for id: StringName in gs.FORM_ORDER:
		gs.set_form(id)
		await tree.physics_frame
		var hit_shape := player.get_node("PrimaryHitbox").get_child(0) as CollisionShape2D
		var hit_rect := hit_shape.shape as RectangleShape2D
		if not hit_rect.size.is_equal_approx(player.form.attack_size):
			fails.append("%s: Player primary shape does not match FormDef" % id)
		if not player.form.attack_overlaps_body():
			fails.append("%s: primary has a close-range dead zone" % id)

	# Recliner brace is held state, with a clean release edge and finale hook.
	gs.set_form(&"recliner")
	await _settle(tree, player)
	Input.action_press("special")
	for _i in 3:
		await tree.physics_frame
	if not player.is_bracing():
		fails.append("recliner: holding special did not enter brace")
	if _count_mechanic(used_mechanics, &"brace") != 1:
		fails.append("recliner: brace should emit one successful-use hook")
	Input.action_release("special")
	for _i in 2:
		await tree.physics_frame
	if player.is_bracing():
		fails.append("recliner: releasing special did not leave brace")

	# Bar-stool spin is also held state and reverses a real hostile projectile.
	gs.set_form(&"barstool")
	await _settle(tree, player)
	var hostile := Projectile.new()
	hostile.velocity = Vector2(-180.0, 0.0)
	_sandbox.add_child(hostile)
	hostile.global_position = player.global_position + Vector2(42.0, -28.0)
	await tree.physics_frame
	Input.action_press("special")
	for _i in 3:
		await tree.physics_frame
	if not player.is_spinning():
		fails.append("barstool: holding special did not enter spin")
	if hostile.is_hostile_to_player() or hostile.faction != &"player":
		fails.append("barstool: nearby hostile projectile was not reflected")
	if _count_mechanic(used_mechanics, &"spin") != 1:
		fails.append("barstool: spin should emit one successful-use hook")
	# A real overlapping enemy hit stops spin from inside an Area2D callback.
	# Hitbox.deactivate must defer its monitoring mutation during that flush.
	var enemy_hit := Hitbox.new()
	enemy_hit.faction = &"enemy"
	enemy_hit.continuous = true
	enemy_hit.rehit_interval = 5.0
	var enemy_shape := CollisionShape2D.new()
	var enemy_rect := RectangleShape2D.new()
	enemy_rect.size = Vector2(54.0, 54.0)
	enemy_shape.shape = enemy_rect
	enemy_hit.add_child(enemy_shape)
	_sandbox.add_child(enemy_hit)
	enemy_hit.global_position = player.global_position + Vector2(0, -27.0)
	for _i in 3:
		await tree.physics_frame
	Input.action_release("special")
	if player.is_spinning():
		fails.append("barstool: taking a real contact hit did not leave spin")
	var spin_hitbox := player.get_node("SpinHitbox") as Hitbox
	if spin_hitbox.monitoring:
		fails.append("barstool: stopped spin left its contact hitbox monitoring")
	enemy_hit.queue_free()
	hostile.queue_free()
	await tree.physics_frame

	# One-shot powers buffer through the short hurt state, and Office momentum
	# keeps going if another contact hit lands after the dash has begun.
	gs.set_form(&"office")
	await _settle(tree, player)
	var dash_before := _count_mechanic(used_mechanics, &"dash")
	player.state = Player.State.HURT
	player.set("_hurt_left", 0.12)
	await _tap(tree, "special")
	for _i in 8:
		await tree.physics_frame
	if _count_mechanic(used_mechanics, &"dash") != dash_before + 1 \
			or not player.is_dashing():
		fails.append("office: dash tap was lost during hurt recovery")
	else:
		var dash_sign := signf(player.velocity.x)
		player.call("_on_damaged", 1.0, Vector2(-500.0, -180.0))
		if not player.is_dashing() or signf(player.velocity.x) != dash_sign:
			fails.append("office: contact damage cancelled dash momentum")

	# High-chair tray is a genuine player-faction projectile, not a melee arc
	# with extra reach masquerading as the game's one ranged form.
	gs.set_form(&"highchair")
	await _settle(tree, player)
	await _tap(tree, "special")
	var tray := _find_player_tray(tree)
	if tray == null:
		fails.append("highchair: special did not spawn a player-faction tray")
	elif tray.damage <= 0.0 or tray.velocity.x * player.facing <= 0.0:
		fails.append("highchair: tray should be damaging and travel forward")
	if _count_mechanic(used_mechanics, &"toss") != 1:
		fails.append("highchair: toss should emit one successful-use hook")
	if tray != null:
		tray.queue_free()
	await tree.physics_frame

	# Folding is the low-profile specialist, not another high-jump form.
	gs.set_form(&"folding")
	await _settle(tree, player)
	await _tap(tree, "special")
	var folded_y := player.global_position.y
	await _begin_jump(tree)
	if not player.is_folded() or absf(player.global_position.y - folded_y) > 2.0:
		fails.append("folding: jump while folded should not spring or unfold")
	await _tap(tree, "special")

	# Rocking Chair converts an ordinary jump into a committed downward slam;
	# it must never manufacture extra upward traversal.
	gs.set_form(&"rocking")
	await _settle(tree, player)
	await _begin_jump(tree)
	var slam_before := _count_mechanic(used_mechanics, &"slam")
	Input.action_press("special")
	var slam_activated := false
	for _i in 4:
		await tree.physics_frame
		if player.get("_slam_committed"):
			slam_activated = true
			break
	Input.action_release("special")
	var slam_start_y := player.global_position.y
	if not slam_activated:
		fails.append("rocking: airborne special never committed the downward slam")
	elif player.velocity.y < Player.SLAM_FALL_SPEED:
		fails.append("rocking: airborne special manufactured upward traversal before slamming")
	var slam_min_y := player.global_position.y
	var slam_guard := 0
	while not player.is_on_floor() and slam_guard < 120:
		await tree.physics_frame
		slam_min_y = minf(slam_min_y, player.global_position.y)
		slam_guard += 1
	for _i in 2:
		await tree.physics_frame
	if _count_mechanic(used_mechanics, &"slam") != slam_before + 1:
		fails.append("rocking: committed descent did not emit one landing slam")
	if slam_min_y < slam_start_y - 1.0:
		fails.append("rocking: slam path rose above its activation point")

	# Stool pogo is available once per airtime and refreshes only on landing.
	gs.set_form(&"stool")
	await _settle(tree, player)
	var stool_h := (player.get_node("Collider").shape as RectangleShape2D).size.y
	if absf(stool_h - player.form.collider_height) > 0.1:
		fails.append("stool: standing collider should honor its 48px FormDef height")
	await _begin_jump(tree)
	var pogo_before := _count_mechanic(used_mechanics, &"pogo")
	await _tap(tree, "special")
	var pogo_once := _count_mechanic(used_mechanics, &"pogo")
	if pogo_once != pogo_before + 1 or player.velocity.y > -300.0:
		fails.append("stool: first airborne special did not pogo upward")
	await _tap(tree, "special")
	if _count_mechanic(used_mechanics, &"pogo") != pogo_once:
		fails.append("stool: pogo was usable twice in one airtime")
	var guard := 0
	while not player.is_on_floor() and guard < 240:
		await tree.physics_frame
		guard += 1
	for _i in 3:
		await tree.physics_frame
	if not player.is_on_floor():
		fails.append("stool: pogo test never returned to the floor")
	else:
		await _begin_jump(tree)
		await _tap(tree, "special")
		if _count_mechanic(used_mechanics, &"pogo") != pogo_once + 1:
			fails.append("stool: pogo did not refresh after landing")

	_release_inputs()
	player.queue_free()
	_sandbox.queue_free()
	await tree.physics_frame
	gs.new_game()
	gs.clear_save()
	return fails


func _count_mechanic(events: Array[StringName], mechanic: StringName) -> int:
	var count := 0
	for event in events:
		if event == mechanic:
			count += 1
	return count


func _find_player_tray(tree: SceneTree) -> Projectile:
	for node in tree.get_nodes_in_group("projectiles"):
		var projectile := node as Projectile
		if projectile != null and projectile.faction == &"player" \
				and projectile.visual_style == &"tray":
			return projectile
	return null


func _build_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20000, 200)
	shape.shape = rect
	body.position = Vector2(0, FLOOR_Y + 100.0)
	body.add_child(shape)
	_sandbox.add_child(body)


func _settle(tree: SceneTree, player: Player) -> void:
	_release_inputs()
	player.global_position = Vector2(0, FLOOR_Y - 260.0)
	player.velocity = Vector2.ZERO
	var guard := 0
	while guard < 240:
		await tree.physics_frame
		guard += 1
		if player.is_on_floor() and absf(player.velocity.x) < 1.0:
			break
	for _i in 4:
		await tree.physics_frame


func _begin_jump(tree: SceneTree) -> void:
	Input.action_press("jump")
	for _i in 4:
		await tree.physics_frame
	Input.action_release("jump")
	for _i in 2:
		await tree.physics_frame


func _tap(tree: SceneTree, action: String) -> void:
	Input.action_press(action)
	for _i in 3:
		await tree.physics_frame
	Input.action_release(action)
	await tree.physics_frame


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "jump", "special", "attack"]:
		Input.action_release(action)
