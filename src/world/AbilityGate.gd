class_name AbilityGate
extends StaticBody2D
## Solid barrier that opens permanently once a form is unlocked (or a flag is
## set). Renders the required form's color + name so gating is explicit.
## Origin = TOP-LEFT.

@export var size := Vector2(48, 160)
@export var required_form: StringName = &"armchair"
@export var required_flag: String = ""

var _open := false
var _form_def: FormDef


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	_form_def = load("res://src/forms/%s.tres" % required_form)
	Events.form_unlocked.connect(func(_id: StringName) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var satisfied: bool
	if required_flag.is_empty():
		satisfied = GameState.is_unlocked(required_form)
	else:
		satisfied = GameState.has_flag(required_flag)
	if satisfied and not _open:
		_open = true
		$Shape.set_deferred("disabled", true)
		Events.sfx_requested.emit(&"gate_open")
	queue_redraw()


func _draw() -> void:
	var color: Color = _form_def.body_color if _form_def != null else Color(0.5, 0.5, 0.5)
	if _open:
		# Ghost outline of the retracted gate.
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 14.0)), Color(color.r, color.g, color.b, 0.5))
		return
	draw_rect(Rect2(Vector2.ZERO, size), color.darkened(0.5))
	draw_rect(Rect2(Vector2.ZERO, size), color, false, 4.0)
	# Form emblem: small chair pictogram block in the middle.
	var c := size / 2.0
	draw_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 6)), color.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-12, -18), Vector2(6, 15)), color.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-9, 2), Vector2(4, 9)), color.lightened(0.3))
	draw_rect(Rect2(c + Vector2(5, 2), Vector2(4, 9)), color.lightened(0.3))
