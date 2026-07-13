extends Node2D
## Code-drawn parallax silhouette: a skyline of soft furniture shapes
## (wardrobes, lamps, chair backs) spanning the zone width. Deterministic
## via the RNG handed in by ZoneBase.

var _shapes: Array = []   # [{rect, kind, color}]
var _color := Color(0.2, 0.15, 0.11)


func setup(rng: RandomNumberGenerator, limits: Rect2, floor_y: float,
		color: Color, scale_mult: float) -> void:
	_color = color
	var x := limits.position.x - 200.0
	var end_x := limits.end.x + 200.0
	while x < end_x:
		var kind := rng.randi_range(0, 3)
		var w := rng.randf_range(120.0, 340.0) * scale_mult
		var h := rng.randf_range(140.0, 420.0) * scale_mult
		_shapes.append({
			"rect": Rect2(x, floor_y - h, w, h),
			"kind": kind,
			"shade": rng.randf_range(-0.06, 0.06),
		})
		x += w + rng.randf_range(40.0, 220.0)
	queue_redraw()


func _draw() -> void:
	for s in _shapes:
		var r: Rect2 = s["rect"]
		var c := Color(_color.r + s["shade"], _color.g + s["shade"], _color.b + s["shade"], 1.0)
		match int(s["kind"]):
			0:  # wardrobe / bookcase block
				_rounded(r, c, 12.0)
				draw_line(r.position + Vector2(r.size.x / 2.0, 20), r.position + Vector2(r.size.x / 2.0, r.size.y - 10), c.darkened(0.12), 4.0)
			1:  # chair-back silhouette
				_rounded(Rect2(r.position.x, r.position.y, r.size.x * 0.28, r.size.y), c, 14.0)
				_rounded(Rect2(r.position.x, r.end.y - r.size.y * 0.3, r.size.x, r.size.y * 0.3), c, 10.0)
			2:  # standing lamp
				var cx := r.position.x + r.size.x / 2.0
				draw_rect(Rect2(cx - 5, r.position.y + r.size.y * 0.3, 10, r.size.y * 0.7), c)
				_rounded(Rect2(cx - r.size.x * 0.3, r.position.y, r.size.x * 0.6, r.size.y * 0.28), c, 16.0)
			_:  # sofa lump
				_rounded(Rect2(r.position.x, r.end.y - r.size.y * 0.55, r.size.x, r.size.y * 0.55), c, 22.0)
				_rounded(Rect2(r.position.x + r.size.x * 0.1, r.position.y + r.size.y * 0.2, r.size.x * 0.8, r.size.y * 0.4), c, 18.0)


func _rounded(r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.draw(get_canvas_item(), r)
