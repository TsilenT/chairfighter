extends BossBase
## The Recliner Baron — Lounge boss, unlocks Armchair + Recliner. REFERENCE BOSS:
## other bosses follow this shape (telegraphed async patterns + phase 2).
##
## Patterns: footrest jab (lunge), cushion toss (arced projectiles),
## recline block (front guard and counter). Phase 2 adds ceiling-hook swings
## across the arena — foreshadowing the grapple the player is about to earn.

var _hook_attached := false
var _hook_anchor := Vector2.ZERO
var _guarding := false
var _jabbing := false
var _attack_dir := -1.0


func _ready() -> void:
	boss_id = &"recliner"
	display_name = "The Recliner Baron"
	max_health = 34.0  # first boss, casual on-ramp
	body_half_width = 66.0
	body_height = 128.0
	contact_while_idle = false
	super._ready()


func _patterns() -> Array[Callable]:
	var list: Array[Callable] = [_footrest_jab, _cushion_toss, _recline_block]
	if phase >= 2:
		list.append(_hook_swing)
		list.append(_hook_swing)  # weighted: swings become signature in phase 2
	return list


func _on_phase_two() -> void:
	Events.screenshake_requested.emit(4.0, 0.2)


func _clear_attack() -> void:
	_guarding = false
	_jabbing = false
	_hook_attached = false
	use_gravity = true
	super._clear_attack()


func _on_hit_received(hitbox: Hitbox) -> void:
	if _guarding and (hitbox.global_position.x - global_position.x) * _attack_dir >= 0.0:
		Events.sfx_requested.emit(&"locked")
		return
	super._on_hit_received(hitbox)


# ── patterns ──

func _footrest_jab() -> void:
	var token := _run_token
	_attack_dir = -1.0 if dir_to_player() < 0.0 else 1.0
	_jabbing = true
	await telegraph(0.55, "Footrest jab")
	if not is_attack_current(token):
		return
	_set_contact_active(true)
	var speed := 620.0 if phase == 1 else 760.0
	var target := clampf(global_position.x + _attack_dir * speed * 0.42,
			arena_rect.position.x + body_half_width, arena_rect.end.x - body_half_width)
	velocity.y = -160.0
	await move_to_x(target, speed, 0.42)
	if not is_attack_current(token):
		return
	_set_contact_active(false)
	_jabbing = false
	await recover(0.45)


func _cushion_toss() -> void:
	var token := _run_token
	var p := player_node()
	if p == null:
		return
	var target := p.global_position
	await telegraph(0.6, "Cushion toss", PackedVector2Array([target]))
	if not is_attack_current(token):
		return
	var count := 3 if phase == 1 else 5
	var origin := global_position + Vector2(0, -body_height + 20.0)
	for i in count:
		if not is_attack_current(token):
			return
		var t := 0.85
		var to_target := target - origin
		var spread := (float(i) - (float(count) - 1.0) * 0.5) * 74.0
		var vel := Vector2((to_target.x + spread) / t, to_target.y / t - 0.5 * Projectile.GRAVITY * t)
		spawn_projectile(origin, vel, Color(0.78, 0.3, 0.32), 12.0, &"cushion")
		await wait(0.16)
	await recover(0.4)


func _recline_block() -> void:
	var token := _run_token
	_attack_dir = -1.0 if dir_to_player() < 0.0 else 1.0
	_guarding = true
	await telegraph(0.8, "Front guard")
	if not is_attack_current(token):
		return
	_guarding = false
	_jabbing = true
	_set_contact_active(true)
	var target := clampf(global_position.x + _attack_dir * 105.0,
			arena_rect.position.x + body_half_width, arena_rect.end.x - body_half_width)
	await move_to_x(target, 420.0, 0.25)
	if not is_attack_current(token):
		return
	_set_contact_active(false)
	_jabbing = false
	await recover(0.48)


func _hook_swing() -> void:
	var token := _run_token
	var floor_y := global_position.y
	var p := player_node()
	var target_x := arena_rect.get_center().x
	if p != null:
		target_x = clampf(p.global_position.x, arena_rect.position.x + 120.0, arena_rect.end.x - 120.0)
	var midpoint := (global_position.x + target_x) * 0.5
	_hook_anchor = Vector2(midpoint, floor_y - 280.0)
	var closest_hook := INF
	for hook: Node2D in get_tree().get_nodes_in_group("grapple_anchors"):
		var position_in_arena := hook.global_position
		if not arena_rect.has_point(position_in_arena) or position_in_arena.y >= floor_y - 220.0:
			continue
		var distance := absf(position_in_arena.x - midpoint)
		if distance < closest_hook:
			closest_hook = distance
			_hook_anchor = position_in_arena
	await telegraph(0.58, "Grapple drop", PackedVector2Array([Vector2(target_x, floor_y)]))
	if not is_attack_current(token):
		return
	_hook_attached = true
	use_gravity = false
	_set_contact_active(true)
	velocity = Vector2(0, -520.0)
	await wait(0.22)
	if not is_attack_current(token):
		return
	velocity.y = 0.0
	await move_to_x(target_x, 520.0, 2.5)
	if not is_attack_current(token):
		return
	use_gravity = true
	_hook_attached = false
	velocity.y = 480.0
	await wait_for_landing(1.0)
	if not is_attack_current(token):
		return
	_set_contact_active(false)
	await recover(0.55)


# ── placeholder visual (Phase 4 re-skins) ──

func _draw() -> void:
	var plush := Color(0.62, 0.25, 0.27)
	var dark := plush.darkened(0.35)
	var outline := Color(0.14, 0.09, 0.07)
	var w := body_half_width * 2.0
	var h := body_height
	var flash := _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0
	if flash:
		plush = Color.WHITE
	if _hook_attached:
		var anchor := to_local(_hook_anchor)
		draw_line(Vector2(0, -h + 12), anchor, Color(0.92, 0.75, 0.35), 5.0, true)
		draw_arc(anchor, 9.0, 0.0, TAU, 16, Color(0.92, 0.75, 0.35), 3.0, true)
	var facing := _attack_dir if _guarding or _jabbing else dir_to_player()
	if _guarding:
		draw_set_transform(Vector2.ZERO, -_attack_dir * 0.26)
	# Fat armrests.
	draw_rect(Rect2(-w / 2.0, -h * 0.55, 24, h * 0.55), dark if not flash else Color.WHITE)
	draw_rect(Rect2(w / 2.0 - 24, -h * 0.55, 24, h * 0.55), dark if not flash else Color.WHITE)
	# Body.
	draw_rect(Rect2(-w / 2.0 + 20, -h, w - 40, h), plush)
	draw_rect(Rect2(-w / 2.0 + 20, -h, w - 40, h), outline, false, 3.5)
	# Footrest (the weapon).
	draw_rect(Rect2(facing * (w / 2.0 - 15) - 20, -26, 40, 16), dark)
	# Monocle + scowl.
	var ex := facing * 16.0
	draw_circle(Vector2(ex - 12, -h + 30), 7.0, Color.WHITE)
	draw_circle(Vector2(ex + 14, -h + 30), 9.0, Color.WHITE)
	draw_arc(Vector2(ex + 14, -h + 30), 12.0, 0, TAU, 16, Color(0.9, 0.8, 0.4), 2.5)
	draw_circle(Vector2(ex - 11, -h + 31), 3.0, outline)
	draw_circle(Vector2(ex + 15, -h + 31), 3.5, outline)
	if _guarding:
		draw_set_transform(Vector2.ZERO)
		var shield_x := _attack_dir * (w * 0.5 + 3.0)
		var shield := PackedVector2Array([Vector2(shield_x - _attack_dir * 10.0, -106),
				Vector2(shield_x, -92), Vector2(shield_x, -45),
				Vector2(shield_x - _attack_dir * 10.0, -31)])
		draw_polyline(shield, outline, 8.0, true)
		draw_polyline(shield, Color(0.97, 0.77, 0.36), 4.0, true)
