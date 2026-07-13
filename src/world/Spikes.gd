class_name Spikes
extends Node2D
## Floor hazard: solid base + continuous damage hitbox. Origin = TOP-LEFT
## of the spike strip; spikes point up.

@export var size := Vector2(96, 24)
@export var damage := 1.0


func _ready() -> void:
	var hitbox := Hitbox.new()
	hitbox.faction = &"enemy"
	hitbox.damage = damage
	hitbox.continuous = true
	hitbox.knockback_strength = 380.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x - 8.0, size.y - 6.0)
	shape.shape = rect
	shape.position = Vector2(size.x / 2.0, size.y / 2.0 + 3.0)
	hitbox.add_child(shape)
	add_child(hitbox)


func _draw() -> void:
	var metal := Color(0.72, 0.72, 0.78)
	var dark := Color(0.18, 0.14, 0.12)
	var n := int(size.x / 16.0)
	for i in n:
		var x := i * 16.0
		var pts := PackedVector2Array([
			Vector2(x, size.y), Vector2(x + 8.0, 0.0), Vector2(x + 16.0, size.y),
		])
		draw_colored_polygon(pts, metal)
		draw_polyline(pts, dark, 2.0)
