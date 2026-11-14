extends RefCounted
## Geometry validator: every zone's intended routes must satisfy the movement
## envelopes derived from FormDef metrics, and every non-decor platform must
## be reachable. This is the institutional memory of the old repo's #1 bug
## class (levels authored against imagined physics).
##
## Zone contract (Route):
##   Route/ children are either Marker2D (single route) or Node2D sub-routes
##   containing ordered Marker2D children. Marker metadata:
##     mode: how you ARRIVE here from the previous marker —
##       start|walk|jump|drop|grapple|dash_tunnel|speed_gate|vent|pogo|
##       smash|royal_trial|door|fight
##     form: form id required for this leg (default "basic")

const ZONES: Array[String] = [
	"res://scenes/zones/Workshop.tscn",
	"res://scenes/zones/Lounge.tscn",
	"res://scenes/zones/BoilerRoom.tscn",
	"res://scenes/zones/OfficeComplex.tscn",
	"res://scenes/zones/NightBar.tscn",
	"res://scenes/zones/StorageCloset.tscn",
	"res://scenes/zones/Nursery.tscn",
	"res://scenes/zones/Parlor.tscn",
	"res://scenes/zones/Conservatory.tscn",
	"res://scenes/zones/ThroneRoom.tscn",
]

# Envelopes (px). Jump numbers leave margin under the metric maxima.
const JUMP_UP_MAX := 96.0
const JUMP_DX_MAX := 170.0
const WALK_UP_MAX := 8.0
const DROP_DX_MAX := 170.0
const GRAPPLE_ANCHOR_MAX := 360.0
const GRAPPLE_LANDING_MAX := 285.0
const GRAPPLE_LEG_MIN := 350.0
const GRAPPLE_PHYSICAL_GAP_MIN := 300.0  # ordinary running jumps must not clear it
const POGO_UP_MAX := 210.0
const POGO_DX_MAX := 220.0
const RUN_DX_MAX := 900.0
const REACH_UP_FULL := 420.0   # Spring Stool normal jump + one pogo
const REACH_GAP_FULL := 240.0  # generous horizontal reach envelope
const SPEED_GATE_MIN_HEIGHT := 500.0
const SPEED_GATE_FLOOR_Y := 400.0
const SPEED_GATE_CEILING_MAX_Y := -100.0
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	for zone_path in ZONES:
		if not ResourceLoader.exists(zone_path):
			continue  # zone not built yet; playthrough gate will catch absences
		var packed: PackedScene = load(zone_path)
		if packed == null:
			fails.append("%s: failed to load" % zone_path)
			continue
		var zone: Node2D = packed.instantiate()
		tree.root.add_child(zone)
		await tree.process_frame
		var zone_fails := _validate_zone(zone)
		for msg in zone_fails:
			fails.append("%s: %s" % [zone_path.get_file(), msg])
		zone.queue_free()
		await tree.process_frame
	fails.append_array(await _exercise_storage_gate(tree))
	fails.append_array(await _exercise_throne_landing(tree))
	return fails


func _validate_zone(zone: Node2D) -> Array[String]:
	var fails: Array[String] = []
	var route_root := zone.get_node_or_null("Route")
	if route_root == null or route_root.get_child_count() == 0:
		fails.append("no Route markers (zone contract violation)")
	else:
		var routes := _collect_routes(route_root)
		for route_name: String in routes:
			var markers: Array = routes[route_name]
			fails.append_array(_validate_route(zone, route_name, markers))
	fails.append_array(_validate_platform_reachability(zone))
	fails.append_array(_validate_speed_gates(zone))
	fails.append_array(_validate_progression_geometry(zone))
	return fails


func _collect_routes(route_root: Node) -> Dictionary:
	var routes := {}
	var direct_markers: Array = []
	for child in route_root.get_children():
		if child is Marker2D:
			direct_markers.append(child)
		else:
			var markers: Array = []
			for sub in child.get_children():
				if sub is Marker2D:
					markers.append(sub)
			if not markers.is_empty():
				routes[String(child.name)] = markers
	if not direct_markers.is_empty():
		routes["Route"] = direct_markers
	return routes


func _validate_route(zone: Node2D, route_name: String, markers: Array) -> Array[String]:
	var fails: Array[String] = []
	for i in range(1, markers.size()):
		var prev: Marker2D = markers[i - 1]
		var cur: Marker2D = markers[i]
		var mode := String(cur.get_meta("mode", "walk"))
		var form_id := StringName(String(cur.get_meta("form", "basic")))
		var d := cur.global_position - prev.global_position
		var up := -d.y  # positive = ascending
		var dx := absf(d.x)
		var leg := "%s[%d→%d] (%s)" % [route_name, i - 1, i, mode]
		match mode:
			"start", "door", "fight":
				pass
			"walk":
				if up > WALK_UP_MAX:
					fails.append("%s: walk ascends %.0fpx (max %.0f)" % [leg, up, WALK_UP_MAX])
			"jump":
				if up > JUMP_UP_MAX:
					fails.append("%s: jump ascends %.0fpx (max %.0f)" % [leg, up, JUMP_UP_MAX])
				if dx > JUMP_DX_MAX:
					fails.append("%s: jump spans %.0fpx (max %.0f)" % [leg, dx, JUMP_DX_MAX])
			"drop":
				if up > 0.0:
					fails.append("%s: drop must descend (ascends %.0fpx)" % [leg, up])
				if dx > DROP_DX_MAX:
					fails.append("%s: drop spans %.0fpx (max %.0f)" % [leg, dx, DROP_DX_MAX])
			"grapple":
				if form_id != &"armchair":
					fails.append("%s: grapple leg must declare form=armchair" % leg)
				if absf(d.y) < 100.0 and dx < GRAPPLE_LEG_MIN:
					fails.append("%s: grapple span %.0fpx is short enough for an ordinary running jump" % [leg, dx])
				if absf(d.y) < 100.0:
					var takeoff_platform := _platform_beneath_marker(zone, prev.global_position)
					var landing_platform := _platform_beneath_marker(zone, cur.global_position)
					if takeoff_platform == null or landing_platform == null:
						fails.append("%s: cannot resolve physical takeoff/landing platforms" % leg)
					else:
						var physical_gap := _horizontal_gap(takeoff_platform.top_rect(), landing_platform.top_rect())
						if physical_gap < GRAPPLE_PHYSICAL_GAP_MIN:
							fails.append("%s: physical platform gap %.0fpx remains ordinary-jumpable" % [leg, physical_gap])
				var anchor := _best_anchor_for_leg(zone, prev.global_position, cur.global_position)
				if anchor == null:
					fails.append("%s: no grapple anchor in zone" % leg)
				else:
					var a_dist := anchor.global_position.distance_to(prev.global_position)
					if a_dist > GRAPPLE_ANCHOR_MAX:
						fails.append("%s: nearest anchor %.0fpx from takeoff (max %.0f)" % [leg, a_dist, GRAPPLE_ANCHOR_MAX])
					var l_dist := anchor.global_position.distance_to(cur.global_position)
					if l_dist > GRAPPLE_LANDING_MAX:
						fails.append("%s: landing %.0fpx from anchor (max %.0f)" % [leg, l_dist, GRAPPLE_LANDING_MAX])
			"dash_tunnel", "speed_gate":
				if form_id != &"office":
					fails.append("%s: %s leg must declare form=office" % [leg, mode])
				if up > WALK_UP_MAX:
					fails.append("%s: %s ascends %.0fpx (must be flat)" % [leg, mode, up])
				if dx > RUN_DX_MAX:
					fails.append("%s: %s spans %.0fpx (max %.0f)" % [leg, mode, dx, RUN_DX_MAX])
			"vent":
				if form_id != &"folding":
					fails.append("%s: vent leg must declare form=folding" % leg)
				if up > WALK_UP_MAX:
					fails.append("%s: vent ascends %.0fpx (must be flat)" % [leg, up])
			"pogo":
				if form_id != &"stool":
					fails.append("%s: pogo leg must declare form=stool" % leg)
				if up > POGO_UP_MAX:
					fails.append("%s: pogo ascends %.0fpx (max %.0f)" % [leg, up, POGO_UP_MAX])
				if dx > POGO_DX_MAX:
					fails.append("%s: pogo spans %.0fpx (max %.0f)" % [leg, dx, POGO_DX_MAX])
			"smash":
				if form_id != &"rocking":
					fails.append("%s: smash leg must declare form=rocking" % leg)
				if up > 0.0:
					fails.append("%s: smash must descend (ascends %.0fpx)" % [leg, up])
				if _nearest_cracked_floor(zone, cur.global_position) > 120.0:
					fails.append("%s: no cracked floor within 120px of the smash marker" % leg)
			"royal_trial":
				var gate := _nearest_royal_trial(zone, cur.global_position)
				if gate == null:
					fails.append("%s: no RoyalTrialGate near marker" % leg)
				elif gate.required_form != form_id:
					fails.append("%s: nearby trial requires %s, marker declares %s" % [
						leg, gate.required_form, form_id])
				elif StringName(gate.required_mechanic) == &"":
					fails.append("%s: trial has no required mechanic" % leg)
			_:
				fails.append("%s: unknown mode '%s'" % [leg, mode])
	return fails


func _validate_speed_gates(zone: Node2D) -> Array[String]:
	var fails: Array[String] = []
	for node in zone.find_children("*", "", true, false):
		var gate := node as SpeedGate
		if gate == null:
			continue
		if gate.size.y < SPEED_GATE_MIN_HEIGHT:
			fails.append("speed gate '%s' is only %.0fpx tall; enhanced jumps can bypass it" % [gate.name, gate.size.y])
		if not is_equal_approx(gate.global_position.y + gate.size.y, SPEED_GATE_FLOOR_Y):
			fails.append("speed gate '%s' does not meet the %.0fpx floor" % [gate.name, SPEED_GATE_FLOOR_Y])
		if gate.global_position.y > SPEED_GATE_CEILING_MAX_Y:
			fails.append("speed gate '%s' leaves a jumpable opening above it" % gate.name)
	return fails


func _validate_progression_geometry(zone: Node2D) -> Array[String]:
	var fails: Array[String] = []
	match zone.scene_file_path.get_file():
		"NightBar.tscn":
			var clearance := _passage_clearance(zone, "Geometry/Counter", "Geometry/Floor")
			if clearance <= Player.DASH_HEIGHT or clearance >= Player.STAND_HEIGHT:
				fails.append("night bar counter must fit a dash but block the standing chair")
		"StorageCloset.tscn":
			var clearance := _passage_clearance(zone, "Geometry/TunnelCeiling", "Geometry/Floor")
			if clearance <= Player.DASH_HEIGHT or clearance >= Player.STAND_HEIGHT:
				fails.append("storage shelf must fit a dash but block the standing chair")
		"Nursery.tscn":
			var clearance := _passage_clearance(zone, "Geometry/SleepingCrib", "Geometry/Floor")
			if clearance <= Player.FOLD_HEIGHT or clearance >= Player.DASH_HEIGHT:
				fails.append("nursery crib must fit a folded chair but block a dash")
		"Parlor.tscn":
			var clearance := _passage_clearance(zone, "Geometry/Dresser", "Geometry/EntryFloor")
			if clearance <= Player.FOLD_HEIGHT or clearance >= Player.DASH_HEIGHT:
				fails.append("parlor dresser must fit a folded chair but block a dash")
		"Conservatory.tscn":
			var hatch := zone.get_node_or_null("Hazards/ServiceHatch") as CrackedFloor
			var mezzanine := zone.get_node_or_null("Geometry/Mezzanine") as Platform
			var divider := zone.get_node_or_null("Geometry/LoadingDivider") as Platform
			if hatch == null or mezzanine == null or divider == null:
				return ["conservatory needs a cracked hatch between the mezzanine and divider"]
			var slab := hatch.top_rect()
			var upper := mezzanine.top_rect()
			var wall := divider.top_rect()
			if not slab.position.is_equal_approx(Vector2(upper.end.x, upper.position.y)) \
					or not is_equal_approx(slab.end.x, wall.position.x) \
					or wall.position.y > upper.position.y - REACH_UP_FULL \
					or wall.end.y < slab.end.y:
				fails.append("conservatory hatch must seal the shaft beneath the loading divider")
		"Workshop.tscn":
			var vent := _passage_clearance(zone, "Geometry/NurseryVent", "Geometry/Floor")
			if vent <= Player.FOLD_HEIGHT or vent >= Player.DASH_HEIGHT:
				fails.append("Workshop linen cabinet must fit a folded chair but block a dash")
			var boiler := zone.get_node("Doors/BoilerDoor") as Door
			if boiler.position.y + boiler.doorway_size.y * 0.5 > 400.0 - 210.0:
				fails.append("Boiler catwalk is low enough to reach with an ordinary jump")
			var hatch := zone.get_node_or_null("Hazards/ThroneHatch") as CrackedFloor
			var main_floor := zone.get_node_or_null("Geometry/Floor") as Platform
			var east_wall := zone.get_node_or_null("Geometry/RightWall") as Platform
			if hatch == null or main_floor == null or east_wall == null:
				return ["throne access needs a cracked hatch, main floor, and adjoining wall"]
			var slab := hatch.top_rect()
			var upper := main_floor.top_rect()
			if not slab.position.is_equal_approx(Vector2(upper.end.x, upper.position.y)) \
					or not is_equal_approx(slab.end.x, east_wall.top_rect().position.x) \
					or east_wall.top_rect().position.y > slab.position.y - REACH_UP_FULL:
				fails.append("throne hatch must fill the well between the upper floor and outer wall")
	return fails


func _passage_clearance(zone: Node2D, ceiling_path: NodePath, floor_path: NodePath) -> float:
	var ceiling := zone.get_node_or_null(ceiling_path) as Platform
	var floor := zone.get_node_or_null(floor_path) as Platform
	if ceiling == null or floor == null:
		return 0.0
	var overhead := ceiling.top_rect()
	var base := floor.top_rect()
	if ceiling.one_way or overhead.position.y > base.position.y - REACH_UP_FULL \
			or overhead.position.x < base.position.x or overhead.end.x > base.end.x:
		return 0.0
	return base.position.y - overhead.end.y


func _exercise_storage_gate(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var state := tree.root.get_node("GameState")
	state.new_game()
	state.unlock_form(&"office")
	var zone: Node2D = load("res://scenes/zones/StorageCloset.tscn").instantiate()
	tree.root.add_child(zone)
	# Exercise a real wall in isolation from the combat room around it.
	zone.get_node("Enemies").free()
	var player := PLAYER_SCENE.instantiate() as Player
	var gate := zone.get_node("Hazards/StorageMidGate") as SpeedGate
	player.position = Vector2(gate.position.x - 70.0, 400)
	player.facing = -1.0
	zone.add_child(player)
	await tree.physics_frame
	Input.action_press("special")
	for _step in 28:
		await tree.physics_frame
	Input.action_release("special")
	if state.has_flag(gate.break_flag):
		fails.append("a dash moving away from the storage wall broke it")
	Input.action_press("move_right")
	for _step in 90:
		await tree.physics_frame
	Input.action_release("move_right")
	if state.has_flag(gate.break_flag) or player.position.x > gate.position.x:
		fails.append("walking bypassed the storage wall")
	Input.action_press("special")
	for _step in 22:
		await tree.physics_frame
	Input.action_release("special")
	if not state.has_flag(gate.break_flag) or player.position.x <= gate.position.x + gate.size.x:
		fails.append("a dash into the storage wall did not break it and cross")
	zone.queue_free()
	await tree.process_frame
	state.new_game()
	return fails


func _exercise_throne_landing(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var state := tree.root.get_node("GameState")
	state.new_game()
	state.unlock_form(&"stool")
	for flag: String in state.FINAL_GUARDIAN_FLAGS:
		state.set_flag(flag)
	var zone: Node2D = load("res://scenes/zones/Workshop.tscn").instantiate()
	tree.root.add_child(zone)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(2290, 700)
	zone.add_child(player)
	for _step in 8:
		await tree.physics_frame
	Input.action_press("jump")
	for _step in 18:
		await tree.physics_frame
	Input.action_release("jump")
	Input.action_press("special")
	for _step in 4:
		await tree.physics_frame
	Input.action_release("special")
	Input.action_press("move_left")
	for _step in 90:
		await tree.physics_frame
		if player.position.x < 2140.0:
			break
	Input.action_release("move_left")
	for _step in 48:
		await tree.physics_frame
	if player.position.y > 492.0 or player.position.x > 2180.0 or not player.is_on_floor():
		fails.append("Spring Stool could not pogo onto the throne landing: %s" % player.position)
	var requests: Array[String] = []
	var on_door := func(zone_path: String, _spawn: String) -> void: requests.append(zone_path)
	Events.zone_change_requested.connect(on_door)
	Input.action_press("move_left")
	for _step in 30:
		await tree.physics_frame
		if player.position.x < 2080.0:
			break
	Input.action_release("move_left")
	Input.action_press("interact")
	for _step in 6:
		await tree.physics_frame
	Input.action_release("interact")
	Events.zone_change_requested.disconnect(on_door)
	if requests != [state.FINAL_ZONE]:
		fails.append("interacting on the royal landing should request only the Throne Room: %s" % str(requests))
	zone.queue_free()
	await tree.process_frame
	state.new_game()
	return fails


func _platform_beneath_marker(zone: Node2D, point: Vector2) -> Node2D:
	for node in zone.get_tree().get_nodes_in_group("platforms"):
		var platform := node as Node2D
		if platform == null or not zone.is_ancestor_of(platform) or not platform.has_method("top_rect"):
			continue
		var rect: Rect2 = platform.top_rect()
		if point.x >= rect.position.x - 24.0 and point.x <= rect.end.x + 24.0 \
				and absf(point.y - rect.position.y) <= 48.0:
			return platform
	return null


func _nearest_cracked_floor(zone: Node2D, from: Vector2) -> float:
	var best := INF
	for node in zone.get_tree().get_nodes_in_group("cracked_floors"):
		if node is Node2D and zone.is_ancestor_of(node):
			var rect: Rect2 = node.top_rect() if node.has_method("top_rect") else Rect2((node as Node2D).global_position, Vector2(64, 16))
			best = minf(best, from.distance_to(rect.get_center()))
	return best


func _best_anchor_for_leg(zone: Node2D, from: Vector2, landing: Vector2) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for node in zone.get_tree().get_nodes_in_group("grapple_anchors"):
		var anchor := node as Node2D
		if anchor == null or not zone.is_ancestor_of(anchor):
			continue
		var score := anchor.global_position.distance_to(from) \
				+ anchor.global_position.distance_to(landing)
		if score < best_score:
			best_score = score
			best = anchor
	return best


func _nearest_royal_trial(zone: Node2D, from: Vector2) -> RoyalTrialGate:
	var best: RoyalTrialGate = null
	var best_dist := 120.0
	for node in zone.get_tree().get_nodes_in_group("royal_trials"):
		if not (node is Node2D) or not zone.is_ancestor_of(node):
			continue
		var dist := (node as Node2D).global_position.distance_to(from)
		if dist < best_dist:
			best_dist = dist
			best = node as RoyalTrialGate
	return best


## Bait-geometry check: every non-decor platform must be plausibly reachable
## from another standable surface with the full unlock set.
func _validate_platform_reachability(zone: Node2D) -> Array[String]:
	var fails: Array[String] = []
	var platforms: Array = []
	for node in zone.get_tree().get_nodes_in_group("platforms"):
		if node is Node2D and zone.is_ancestor_of(node) and not _is_decor(node):
			platforms.append(node)
	var anchors: Array = []
	for node in zone.get_tree().get_nodes_in_group("grapple_anchors"):
		if node is Node2D and zone.is_ancestor_of(node):
			anchors.append(node)
	for p in platforms:
		var rect: Rect2 = p.top_rect() if p.has_method("top_rect") else Rect2(p.global_position, Vector2(64, 16))
		var reachable := false
		# A platform containing a declared spawn is reachable by definition.
		var spawn_root := zone.get_node_or_null("SpawnPoints")
		if spawn_root != null:
			for spawn in spawn_root.get_children():
				if spawn is Node2D and rect.grow(24.0).has_point((spawn as Node2D).global_position):
					reachable = true
					break
		# Reachable from another platform's top?
		for q in platforms:
			if q == p:
				continue
			var qr: Rect2 = q.top_rect() if q.has_method("top_rect") else Rect2(q.global_position, Vector2(64, 16))
			var rise := qr.position.y - rect.position.y  # >0: p is above q
			if rise > REACH_UP_FULL:
				continue
			var gap := _horizontal_gap(rect, qr)
			if gap <= REACH_GAP_FULL:
				reachable = true
				break
		# Or via a grapple anchor near its top edge?
		if not reachable:
			for a in anchors:
				var top_center: Vector2 = rect.position + Vector2(rect.size.x / 2.0, 0)
				if a.global_position.distance_to(top_center) <= GRAPPLE_LANDING_MAX:
					reachable = true
					break
		if not reachable:
			fails.append("BAIT GEOMETRY: platform '%s' at %s unreachable by every form (mark decor=true if intentional)" % [p.name, rect.position])
	return fails


func _is_decor(p: Node) -> bool:
	if p.get("decor") == true:
		return true
	if p.has_meta("decor") and p.get_meta("decor") == true:
		return true
	return false


func _horizontal_gap(a: Rect2, b: Rect2) -> float:
	if a.position.x > b.end.x:
		return a.position.x - b.end.x
	if b.position.x > a.end.x:
		return b.position.x - a.end.x
	return 0.0
