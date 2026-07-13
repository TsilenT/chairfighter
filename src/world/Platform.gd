@tool
class_name Platform
extends StaticBody2D
## The standard standable slab. Size is authored via export; collision and
## themed skin are derived. Origin = TOP-LEFT of the slab. Group: platforms.

@export var size := Vector2(256, 32):
	set(v):
		size = v
		_rebuild()
		queue_redraw()
## Decorative platforms are ignored by the geometry validator.
@export var decor := false
## One-way: passable from below (jump/grapple through), solid on top.
@export var one_way := false

var _theme: ZoneTheme
var _shape_node: CollisionShape2D


func _ready() -> void:
	add_to_group("platforms")
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	_resolve_theme()
	queue_redraw()


func top_rect() -> Rect2:
	return Rect2(global_position, size)


func _rebuild() -> void:
	if _shape_node == null:
		_shape_node = get_node_or_null("Shape")
		if _shape_node == null:
			_shape_node = CollisionShape2D.new()
			_shape_node.name = "Shape"
			_shape_node.shape = RectangleShape2D.new()
			add_child(_shape_node)
	var rect: RectangleShape2D = _shape_node.shape
	rect.size = size
	_shape_node.position = size / 2.0
	_shape_node.one_way_collision = one_way


func _resolve_theme() -> void:
	var node: Node = self
	while node != null:
		if node is ZoneBase and (node as ZoneBase).theme_res != null:
			_theme = (node as ZoneBase).theme_res
			return
		node = node.get_parent()
	_theme = ZoneTheme.new()


func _draw() -> void:
	if _theme == null:
		_theme = ZoneTheme.new()
	var r := Rect2(Vector2.ZERO, size)
	var radius := clampf(minf(size.x, size.y) * 0.25, 3.0, 10.0)
	# Rounded slab body with border, via StyleBoxFlat (cheap, crisp).
	var sb := StyleBoxFlat.new()
	sb.bg_color = _theme.platform_base
	sb.set_corner_radius_all(int(radius))
	sb.border_color = _theme.platform_outline
	sb.set_border_width_all(3)
	sb.draw(get_canvas_item(), r)
	# Top surface strip (the "walkable" read).
	var strip_h := minf(10.0, size.y * 0.4)
	var top := StyleBoxFlat.new()
	top.bg_color = _theme.platform_top
	top.corner_radius_top_left = int(radius)
	top.corner_radius_top_right = int(radius)
	top.draw(get_canvas_item(), Rect2(2, 2, size.x - 4, strip_h))
	# Soft inner shadow along the bottom.
	if size.y > 24.0:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.18)
		shadow.corner_radius_bottom_left = int(radius)
		shadow.corner_radius_bottom_right = int(radius)
		shadow.draw(get_canvas_item(), Rect2(2, size.y - 7, size.x - 4, 5))
	# Sparse surface detail dots (upholstery tacks / wood pegs).
	if size.x >= 96.0 and size.y >= 20.0:
		var step := 72.0
		var x := step * 0.6
		while x < size.x - 20.0:
			draw_circle(Vector2(x, strip_h + 7.0), 2.2, _theme.platform_top.darkened(0.25))
			x += step
