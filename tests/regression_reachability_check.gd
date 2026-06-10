extends SceneTree
## Reachability regression check.
##
## Builds a traversability graph over every standable surface in
## TestLevel using the *actual* movement physics (jump velocity, gravity,
## max speed read from the form scripts and the Player instance) and the
## actual grapple-point placements, then asserts:
##
##   1. BASIC ROUTE  — the boss is reachable from the player spawn using
##      Basic Chair jumps only.
##   2. ARMCHAIR ROUTE — the gated route's goal surface is reachable from
##      spawn using Armchair jumps + grapple pulls.
##   3. NO BAIT GEOMETRY — every standable platform is reachable by at
##      least one form. A platform nobody can reach reads as a path and
##      plays as a wall.
##
## A parse check proves the scene loads; this proves a player can move
## through it. Run via:
##   godot4 --headless --path . -s res://tests/regression_reachability_check.gd

const VERTICAL_MARGIN := 9.0     # usable jump = theoretical apex - body clearance
const HORIZONTAL_MARGIN := 16.0  # landing slop on horizontal gaps
const GRAPPLE_MARGIN := 20.0     # usable grapple = range - margin
const GRAPPLE_LAND_DROP := 220.0 # max fall from a grapple point onto a surface
const GRAPPLE_LAND_SLOP := 40.0  # horizontal slop when landing off a grapple point

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/levels/TestLevel.tscn")
	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame

	var surfaces := _collect_surfaces(level)
	if surfaces.is_empty():
		printerr("reachability: no standable surfaces found under Visuals")
		quit(1)
		return

	var grapple_points := _collect_grapple_points(level)
	var player := level.get_node_or_null("PlayerContainer/Player") as Node2D
	var boss := level.get_node_or_null("BossContainer") as Node2D
	if player == null or boss == null:
		printerr("reachability: missing PlayerContainer/Player or BossContainer")
		quit(1)
		return
	var base_gravity: float = player.get("gravity") if player.get("gravity") != null else 980.0

	var basic = load("res://scripts/player/forms/BasicChairForm.gd").new()
	var armchair = load("res://scripts/player/forms/ArmchairForm.gd").new()

	var spawn_idx := _surface_under(surfaces, player.global_position)
	var boss_idx := _surface_under(surfaces, boss.global_position)
	if spawn_idx < 0 or boss_idx < 0:
		printerr("reachability: could not resolve spawn/boss surface")
		quit(1)
		return

	# --- 1. Basic route: spawn -> boss, jumps only -------------------------
	var basic_reach := _reachable(
		surfaces, spawn_idx,
		absf(basic.jump_velocity), base_gravity * basic.gravity_scale,
		basic.max_speed, [],
	)
	if not basic_reach.has(boss_idx):
		_failures.append(
			"BASIC ROUTE BROKEN: boss surface '%s' unreachable from spawn '%s' with Basic Chair (max jump %.0fpx)."
			% [surfaces[boss_idx].name, surfaces[spawn_idx].name,
			   _max_jump(absf(basic.jump_velocity), base_gravity * basic.gravity_scale)]
		)

	# --- 2. Armchair route: spawn -> topmost surface, jumps + grapple ------
	var arm_reach := _reachable(
		surfaces, spawn_idx,
		absf(armchair.jump_velocity), base_gravity * armchair.gravity_scale,
		armchair.max_speed, grapple_points,
	)
	var top_idx := 0
	for i in surfaces.size():
		if surfaces[i].top < surfaces[top_idx].top:
			top_idx = i
	if not arm_reach.has(top_idx):
		_failures.append(
			"ARMCHAIR ROUTE BROKEN: topmost surface '%s' (y=%.0f) unreachable from spawn with Armchair + grapple (range %.0fpx, %d points)."
			% [surfaces[top_idx].name, surfaces[top_idx].top,
			   (grapple_points[0].range if not grapple_points.is_empty() else 0.0),
			   grapple_points.size()]
		)

	# --- 3. No bait geometry: every surface reachable by someone -----------
	for i in surfaces.size():
		if not basic_reach.has(i) and not arm_reach.has(i):
			_failures.append(
				"BAIT GEOMETRY: surface '%s' (top y=%.0f, x %.0f..%.0f) is unreachable by every form. It reads as a path and plays as a wall — move it within jump range (rise <= %.0fpx) or cover it with a grapple point, or remove it."
				% [surfaces[i].name, surfaces[i].top, surfaces[i].left, surfaces[i].right,
				   _max_jump(absf(basic.jump_velocity), base_gravity * basic.gravity_scale) - VERTICAL_MARGIN]
			)

	root.remove_child(level)
	level.free()

	if _failures.is_empty():
		print("reachability check passed: basic route, armchair route, and all %d surfaces verified" % surfaces.size())
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)


## A standable surface: a horizontal StaticBody2D slab under Visuals.
func _collect_surfaces(level: Node) -> Array:
	var out: Array = []
	var visuals := level.get_node_or_null("Visuals")
	if visuals == null:
		return out
	for child in visuals.get_children():
		if not (child is StaticBody2D):
			continue
		for sub in child.get_children():
			if not (sub is CollisionShape2D) or sub.disabled:
				continue
			var shape = sub.shape
			if not (shape is RectangleShape2D):
				continue
			var size: Vector2 = shape.size
			if size.x < size.y * 2.0:
				continue  # vertical wall, not a floor
			var center: Vector2 = child.global_position + sub.position
			out.append({
				"name": String(child.name),
				"top": center.y - size.y / 2.0,
				"left": center.x - size.x / 2.0,
				"right": center.x + size.x / 2.0,
			})
	return out


func _collect_grapple_points(level: Node) -> Array:
	var out: Array = []
	var stack: Array = [level]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var script = node.get_script()
		if script != null and String(script.resource_path).ends_with("GrapplePoint.gd"):
			out.append({
				"pos": (node as Node2D).global_position,
				"range": float(node.get("grapple_range")),
			})
	return out


func _surface_under(surfaces: Array, pos: Vector2) -> int:
	var best := -1
	var best_top := INF
	for i in surfaces.size():
		var s = surfaces[i]
		if pos.x >= s.left - GRAPPLE_LAND_SLOP and pos.x <= s.right + GRAPPLE_LAND_SLOP:
			if s.top >= pos.y - 4.0 and s.top < best_top:
				best_top = s.top
				best = i
	return best


func _max_jump(v0: float, g: float) -> float:
	return v0 * v0 / (2.0 * g)


## BFS over surfaces using jump edges (and grapple edges when points given).
func _reachable(surfaces: Array, start: int, v0: float, g: float, speed: float, grapple_points: Array) -> Dictionary:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in surfaces.size():
			if seen.has(j):
				continue
			if _jump_edge(surfaces[i], surfaces[j], v0, g, speed) \
					or _grapple_edge(surfaces[i], surfaces[j], grapple_points):
				seen[j] = true
				queue.append(j)
	return seen


func _jump_edge(a: Dictionary, b: Dictionary, v0: float, g: float, speed: float) -> bool:
	var rise: float = a.top - b.top  # positive when b is higher (y-down)
	if rise > _max_jump(v0, g) - VERTICAL_MARGIN:
		return false
	# Air time until landing at the target's height (later root of the arc).
	var disc: float = v0 * v0 - 2.0 * g * rise
	if disc < 0.0:
		return false
	var t_land: float = (v0 + sqrt(disc)) / g
	var gap: float = maxf(b.left - a.right, a.left - b.right)
	if gap <= 0.0:
		return true  # spans overlap; step up/down
	return gap <= speed * t_land - HORIZONTAL_MARGIN


func _grapple_edge(a: Dictionary, b: Dictionary, grapple_points: Array) -> bool:
	for gp in grapple_points:
		var usable: float = gp.range - GRAPPLE_MARGIN
		# Player must be able to stand somewhere on `a` within range of the point.
		var nearest_x: float = clampf(gp.pos.x, a.left, a.right)
		if Vector2(nearest_x, a.top).distance_to(gp.pos) > usable:
			continue
		# After the pull the player hangs at the point and drops onto `b`.
		var drop: float = b.top - gp.pos.y
		if drop < 0.0 or drop > GRAPPLE_LAND_DROP:
			continue
		if gp.pos.x >= b.left - GRAPPLE_LAND_SLOP and gp.pos.x <= b.right + GRAPPLE_LAND_SLOP:
			return true
	return false
