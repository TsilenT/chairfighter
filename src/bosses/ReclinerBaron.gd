extends BossBase
## The Recliner Baron — Lounge boss, unlocks Armchair + Recliner. REFERENCE BOSS:
## other bosses follow this shape (telegraphed async patterns + phase 2).
##
## Patterns: footrest jab (lunge), cushion toss (arced projectiles),
## recline block (brief guard, punishable). Phase 2 adds ceiling-hook swings
## across the arena — foreshadowing the grapple the player is about to earn.

var _swing := false


func _ready() -> void:
	boss_id = &"recliner"
	display_name = "The Recliner Baron"
	max_health = 34.0  # first boss, casual on-ramp
	unlock_form_ids = [&"armchair", &"recliner"]
	body_half_width = 66.0
	body_height = 128.0
	super._ready()


func _patterns() -> Array[Callable]:
	var list: Array[Callable] = [_footrest_jab, _cushion_toss, _recline_block]
	if phase >= 2:
		list.append(_hook_swing)
		list.append(_hook_swing)  # weighted: swings become signature in phase 2
	return list


func _on_phase_two() -> void:
	# Rage hop announces the phase change.
	hop(Vector2(0, -700))


# ── patterns ──

func _footrest_jab() -> void:
	await telegraph(0.55)
	var lunge_dir := dir_to_player()
	var speed := 620.0 if phase == 1 else 760.0
	velocity = Vector2(lunge_dir * speed, -160.0)
	await wait(0.42)
	velocity.x = 0.0
	await wait(0.3)


func _cushion_toss() -> void:
	await telegraph(0.5)
	var p := player_node()
	if p == null:
		return
	var count := 3 if phase == 1 else 5
	for i in count:
		var t := 0.85
		var to_player := p.global_position - global_position
		var spread := (i - count / 2.0) * 90.0
		var vel := Vector2((to_player.x + spread) / t, to_player.y / t - 0.5 * 1400.0 * t)
		spawn_projectile(global_position + Vector2(0, -body_height + 20.0), vel,
				Color(0.78, 0.3, 0.32), 11.0)
		await wait(0.16)
	await wait(0.35)


func _recline_block() -> void:
	# Lean back, briefly untouchable-looking (still hittable — casual game),
	# then snap forward with a shove.
	var tween := create_tween()
	tween.tween_property(self, "rotation", -0.35, 0.3)
	await wait(0.9)
	var snap := create_tween()
	snap.tween_property(self, "rotation", 0.0, 0.12)
	velocity.x = dir_to_player() * 420.0
	await wait(0.25)
	velocity.x = 0.0


func _hook_swing() -> void:
	# Grapple the ceiling and swing to the player's side of the arena.
	await telegraph(0.4)
	_swing = true
	use_gravity = false
	var p := player_node()
	var target_x := arena_rect.position.x + arena_rect.size.x * 0.5
	if p != null:
		target_x = clampf(p.global_position.x, arena_rect.position.x + 120.0, arena_rect.end.x - 120.0)
	var apex_y := arena_rect.position.y + 140.0
	# Rise, glide across, drop.
	velocity = Vector2(0, -520.0)
	await wait(0.35)
	await move_to_x(target_x, 520.0, 2.5)
	velocity = Vector2.ZERO
	use_gravity = true
	_swing = false
	velocity.y = 300.0
	await wait(0.4)


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
	# Fat armrests.
	draw_rect(Rect2(-w / 2.0, -h * 0.55, 24, h * 0.55), dark if not flash else Color.WHITE)
	draw_rect(Rect2(w / 2.0 - 24, -h * 0.55, 24, h * 0.55), dark if not flash else Color.WHITE)
	# Body.
	draw_rect(Rect2(-w / 2.0 + 20, -h, w - 40, h), plush)
	draw_rect(Rect2(-w / 2.0 + 20, -h, w - 40, h), outline, false, 3.5)
	# Footrest (the weapon).
	draw_rect(Rect2(dir_to_player() * (w / 2.0 - 10) - 20, -26, 40, 16), dark)
	# Monocle + scowl.
	var ex := dir_to_player() * 16.0
	draw_circle(Vector2(ex - 12, -h + 30), 7.0, Color.WHITE)
	draw_circle(Vector2(ex + 14, -h + 30), 9.0, Color.WHITE)
	draw_arc(Vector2(ex + 14, -h + 30), 12.0, 0, TAU, 16, Color(0.9, 0.8, 0.4), 2.5)
	draw_circle(Vector2(ex - 11, -h + 31), 3.0, outline)
	draw_circle(Vector2(ex + 15, -h + 31), 3.5, outline)
	if _swing:
		# Extended arm to the ceiling while swinging.
		draw_line(Vector2(0, -h), Vector2(0, -h - 220), Color(0.9, 0.75, 0.35), 6.0)
