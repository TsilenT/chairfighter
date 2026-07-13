extends EnemyBase
## Patrolling walker. Turns at walls and ledges. The rank-and-file grunt.

var _dir := -1.0


func _ready() -> void:
	max_health = 4.0
	move_speed = 70.0
	super._ready()


func _ai(_delta: float) -> void:
	velocity.x = _dir * move_speed
	if is_on_wall():
		_dir = -_dir
		return
	# Ledge check: probe just ahead of the feet.
	if is_on_floor():
		var space := get_world_2d().direct_space_state
		var probe := PhysicsRayQueryParameters2D.create(
			global_position + Vector2(_dir * (body_size.x / 2.0 + 8.0), -4.0),
			global_position + Vector2(_dir * (body_size.x / 2.0 + 8.0), 30.0), 1)
		if space.intersect_ray(probe).is_empty():
			_dir = -_dir


func _draw_body() -> void:
	var w := body_size.x
	var h := body_size.y
	var top := skin_color.lightened(0.15)
	var outline := Color(0.15, 0.1, 0.08)
	# Cushion top.
	draw_rect(Rect2(-w / 2.0, -h, w, h * 0.45), top)
	draw_rect(Rect2(-w / 2.0, -h, w, h * 0.45), outline, false, 2.5)
	# Body.
	draw_rect(Rect2(-w / 2.0 + 4, -h * 0.55, w - 8, h * 0.3), skin_color)
	# Stubby legs.
	draw_rect(Rect2(-w / 2.0 + 4, -h * 0.25, 7, h * 0.25), skin_color.darkened(0.3))
	draw_rect(Rect2(w / 2.0 - 11, -h * 0.25, 7, h * 0.25), skin_color.darkened(0.3))
	# Angry little eyes, facing walk direction.
	var ex := _dir * 8.0
	draw_circle(Vector2(ex - 4, -h + 9), 3.5, Color.WHITE)
	draw_circle(Vector2(ex + 5, -h + 9), 3.5, Color.WHITE)
	draw_circle(Vector2(ex - 3, -h + 9.5), 1.7, outline)
	draw_circle(Vector2(ex + 6, -h + 9.5), 1.7, outline)
