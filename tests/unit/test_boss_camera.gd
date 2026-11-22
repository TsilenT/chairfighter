extends RefCounted
## Verify rendered camera transforms so floor visibility cannot regress when
## arena limits are shorter than the viewport or mobile controls are enabled.


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var state := tree.root.get_node("GameState")
	var previous_touch: bool = state.touch_controls
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	var actor := Node2D.new()
	viewport.add_child(actor)
	var camera: Camera2D = load("res://src/fx/CameraRig.gd").new()
	actor.add_child(camera)
	var exploration := Rect2(-5000, -5000, 10000, 10000)
	camera.set_zone_limits(exploration)
	var arenas := [
		Rect2(2480, -168, 1152, 648), # Lounge bottom extends below its floor.
		Rect2(2700, -248, 1152, 648),
		Rect2(2180, 2, 1152, 648), # Conservatory's lower service floor.
		Rect2(5650, -700, 1250, 700),
	]
	var floors := [400.0, 400.0, 650.0, 0.0]
	for touch in [false, true]:
		state.touch_controls = touch
		for view_size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960)]:
			viewport.size = view_size
			for index in arenas.size():
				var arena: Rect2 = arenas[index]
				var floor_y: float = floors[index]
				actor.position = Vector2(arena.get_center().x, floor_y)
				camera.lock_to(arena, floor_y)
				await tree.process_frame
				camera.force_update_scroll()
				var floor_on_screen := viewport.canvas_transform * Vector2(arena.get_center().x, floor_y)
				var bottom_margin := float(view_size.y) - floor_on_screen.y
				if bottom_margin < (250.0 if touch else 100.0):
					failures.append("Boss floor obscured at %s with touch=%s, floor=%s" % [view_size, touch, floor_on_screen])
				if floor_on_screen.y < 280.0:
					failures.append("Boss framing leaves too little room above the floor")
				var left := viewport.canvas_transform * Vector2(arena.position.x, floor_y)
				var right := viewport.canvas_transform * Vector2(arena.end.x, floor_y)
				if left.x < -1.0 or right.x > view_size.x + 1.0:
					failures.append("Arena horizontal bounds leave viewport at %s" % view_size)
				actor.position.y -= 240.0
				camera.set_facing(-1.0)
				await tree.process_frame
				camera.force_update_scroll()
				var floor_during_jump := viewport.canvas_transform * Vector2(arena.get_center().x, floor_y)
				if not floor_during_jump.is_equal_approx(floor_on_screen):
					failures.append("Jumping or turning shifts the locked arena view")

	var locked_center := camera.get_screen_center_position()
	camera.unlock()
	camera.force_update_scroll()
	if not camera.get_screen_center_position().is_equal_approx(locked_center):
		failures.append("Unlocking the boss camera snapped from %s to %s" % [locked_center, camera.get_screen_center_position()])
	if camera.limit_top != int(exploration.position.y) or camera.limit_bottom != int(exploration.end.y) \
			or camera.limit_left != int(exploration.position.x) or camera.limit_right != int(exploration.end.x):
		failures.append("Unlocking the boss camera did not restore exploration bounds")
	if not camera.position_smoothing_enabled or not camera.drag_vertical_enabled:
		failures.append("Boss framing disabled exploration smoothing or vertical drag")
	state.touch_controls = previous_touch
	viewport.queue_free()
	await tree.process_frame
	return failures
