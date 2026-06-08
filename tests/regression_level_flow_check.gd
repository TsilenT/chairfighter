extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/levels/TestLevel.tscn")
	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame

	var gap_col := level.get_node_or_null("Visuals/GapWall/GapWallCol") as CollisionShape2D
	if gap_col == null:
		printerr("Missing GapWallCol")
		quit(1)
		return
	if not gap_col.disabled:
		printerr("GapWallCol is still enabled; Basic Chair ground path remains blocked")
		quit(1)
		return

	var npc_label := level.get_node_or_null("Visuals/DirectionLabel1") as Label
	var arena_label := level.get_node_or_null("Visuals/DirectionLabel2") as Label
	if npc_label == null or not npc_label.text.contains("BASIC PATH"):
		printerr("NPC route label does not identify Basic path: %s" % ("<missing>" if npc_label == null else npc_label.text))
		quit(1)
		return
	if arena_label == null or not arena_label.text.contains("BASIC PATH"):
		printerr("Arena route label does not identify Basic path")
		quit(1)
		return

	var player := level.get_node("PlayerContainer/Player") as Node2D
	var npc_container := level.get_node("HubNpcContainer") as Node2D
	var boss_container := level.get_node("BossContainer") as Node2D
	if player.global_position.x >= npc_container.global_position.x or npc_container.global_position.x >= boss_container.global_position.x:
		printerr("Expected left-to-right flow Player -> NPC -> Boss")
		quit(1)
		return

	print("level flow check passed: Basic path is Player -> NPC -> Boss; Armchair route remains later")
	root.remove_child(level)
	level.free()
	quit(0)
