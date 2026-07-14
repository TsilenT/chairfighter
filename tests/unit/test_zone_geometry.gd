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
##       start|walk|jump|drop|grapple|dash_tunnel|speed_gate|vent|spring|door|fight
##     form: form id required for this leg (default "basic")

const ZONES: Array[String] = [
	"res://scenes/zones/Workshop.tscn",
	"res://scenes/zones/Lounge.tscn",
	"res://scenes/zones/OfficeComplex.tscn",
	"res://scenes/zones/StorageCloset.tscn",
	"res://scenes/zones/ThroneRoom.tscn",
	"res://scenes/zones/Parlor.tscn",
]

# Envelopes (px). Jump numbers leave margin under the metric maxima.
const JUMP_UP_MAX := 96.0
const JUMP_DX_MAX := 170.0
const WALK_UP_MAX := 8.0
const DROP_DX_MAX := 170.0
const GRAPPLE_ANCHOR_MAX := 360.0
const GRAPPLE_LANDING_MAX := 280.0
const SPRING_UP_MAX := 210.0
const SPRING_DX_MAX := 130.0
const LAUNCH_UP_MAX := 240.0   # rocking charge-launch (capability 260)
const LAUNCH_DX_MAX := 220.0
const RUN_DX_MAX := 900.0
const REACH_UP_FULL := 240.0   # best vertical with all unlocks (launch)
const REACH_GAP_FULL := 240.0  # generous horizontal reach envelope


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
				var anchor := _nearest_anchor(zone, prev.global_position)
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
			"spring":
				if form_id != &"folding":
					fails.append("%s: spring leg must declare form=folding" % leg)
				if up > SPRING_UP_MAX:
					fails.append("%s: spring ascends %.0fpx (max %.0f)" % [leg, up, SPRING_UP_MAX])
				if dx > SPRING_DX_MAX:
					fails.append("%s: spring spans %.0fpx (max %.0f)" % [leg, dx, SPRING_DX_MAX])
			"launch":
				if form_id != &"rocking":
					fails.append("%s: launch leg must declare form=rocking" % leg)
				if up > LAUNCH_UP_MAX:
					fails.append("%s: launch ascends %.0fpx (max %.0f)" % [leg, up, LAUNCH_UP_MAX])
				if dx > LAUNCH_DX_MAX:
					fails.append("%s: launch spans %.0fpx (max %.0f)" % [leg, dx, LAUNCH_DX_MAX])
			"smash":
				if form_id != &"rocking":
					fails.append("%s: smash leg must declare form=rocking" % leg)
				if up > 0.0:
					fails.append("%s: smash must descend (ascends %.0fpx)" % [leg, up])
				if _nearest_cracked_floor(zone, cur.global_position) > 120.0:
					fails.append("%s: no cracked floor within 120px of the smash marker" % leg)
			_:
				fails.append("%s: unknown mode '%s'" % [leg, mode])
	return fails


func _nearest_cracked_floor(zone: Node2D, from: Vector2) -> float:
	var best := INF
	for node in zone.get_tree().get_nodes_in_group("cracked_floors"):
		if node is Node2D and zone.is_ancestor_of(node):
			var rect: Rect2 = node.top_rect() if node.has_method("top_rect") else Rect2((node as Node2D).global_position, Vector2(64, 16))
			best = minf(best, from.distance_to(rect.get_center()))
	return best


func _nearest_anchor(zone: Node2D, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in zone.get_tree().get_nodes_in_group("grapple_anchors"):
		var anchor := node as Node2D
		if anchor == null or not zone.is_ancestor_of(anchor):
			continue
		var dist := anchor.global_position.distance_to(from)
		if dist < best_dist:
			best_dist = dist
			best = anchor
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
