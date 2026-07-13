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
	# Body with soft corner illusion via inset strips.
	draw_rect(r, _theme.platform_base)
	# Top surface strip.
	draw_rect(Rect2(0, 0, size.x, minf(10.0, size.y * 0.4)), _theme.platform_top)
	# Inner shadow at the bottom.
	draw_rect(Rect2(0, size.y - 5, size.x, 5), _theme.platform_outline.lightened(0.08))
	# Outline.
	draw_rect(r, _theme.platform_outline, false, 3.0)
