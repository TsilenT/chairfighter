extends RefCounted


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var state := tree.root.get_node("GameState")
	state.new_game()
	var sandbox := Node2D.new()
	tree.root.add_child(sandbox)
	var scene: PackedScene = load("res://scenes/bosses/ReclinerBaron.tscn")
	var baron: BossBase = scene.instantiate()
	sandbox.add_child(baron)
	var hit := Hitbox.new()
	hit.faction = &"player"
	sandbox.add_child(hit)

	baron.active = true
	baron.call("_recline_block")
	var health_before := baron.health.current
	var guard_facing: float = baron.get("_attack_dir")
	hit.global_position = baron.global_position + Vector2(guard_facing * 48.0, -30)
	baron._on_hit_received(hit)
	if baron.health.current != health_before:
		failures.append("Baron front guard should block a frontal hit")
	hit.global_position = baron.global_position + Vector2(-guard_facing * 48.0, -30)
	baron._on_hit_received(hit)
	if baron.health.current >= health_before:
		failures.append("Baron front guard should leave his back exposed")

	baron.spawn_projectile(Vector2(300, -55), Vector2.RIGHT)
	var hostile: Projectile = baron._projectiles[0]
	baron.spawn_projectile(Vector2(500, -55), Vector2.RIGHT)
	var reflected: Projectile = baron._projectiles[1]
	reflected.deflect(-1.0)
	var old_token := baron._run_token
	baron._on_player_died()
	await tree.physics_frame
	await tree.physics_frame
	if baron.is_attack_current(old_token) or baron.get("_guarding") or baron._warn_label.visible:
		failures.append("A retry should interrupt the guard and remove its cue")
	if baron._contact_hitbox.monitoring or not is_zero_approx(baron.velocity.x):
		failures.append("A cancelled wind-up should never launch its contact attack")
	if is_instance_valid(hostile) or not is_instance_valid(reflected):
		failures.append("A retry should clear hostile shots while preserving reflected ones")
	sandbox.queue_free()
	await tree.process_frame
	state.new_game()
	return failures
