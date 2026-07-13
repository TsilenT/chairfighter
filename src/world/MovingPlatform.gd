class_name MovingPlatform
extends AnimatableBody2D
## Two-point oscillating platform (crushers, lifts, conveyor stand-ins).
## Origin = TOP-LEFT of the slab at its rest position.

@export var size := Vector2(160, 24)
@export var travel := Vector2(0, -120)
@export var period := 3.0
@export var phase := 0.0

var _origin := Vector2.ZERO
var _t := 0.0
var _theme: ZoneTheme


func _ready() -> void:
	add_to_group("platforms")
	set_meta("decor", true)  # validator: not part of static reachability
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	_origin = global_position
	_t = phase
	var node: Node = self
	while node != null and not (node is ZoneBase):
		node = node.get_parent()
	_theme = (node as ZoneBase).theme_res if node != null else ZoneTheme.new()


func _physics_process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos(TAU * _t / period)
	global_position = _origin + travel * k


func _draw() -> void:
	if _theme == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _theme.platform_base.lightened(0.08))
	draw_rect(Rect2(0, 0, size.x, 8), _theme.accent.darkened(0.2))
	draw_rect(Rect2(Vector2.ZERO, size), _theme.platform_outline, false, 3.0)
