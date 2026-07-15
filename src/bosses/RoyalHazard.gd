class_name RoyalHazard
extends Node2D
## A slow, screen-readable final-boss attack strip. Unlike lobbed cushions it
## does not fall under gravity, which lets the King author exact "grapple
## above this" and "fold below this" response windows.

var velocity := Vector2.ZERO
var size := Vector2(120.0, 22.0)
var color := Color(0.96, 0.72, 0.2)
var lifetime := 3.0
var damage := 1.0
## Visible reaction beat between spawning and dealing damage. The King uses
## this flash to let a prepared chair begin grappling/folding on a real input.
var warmup := 0.25

var _age := 0.0
var _armed := false
var _hitbox: Hitbox


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.faction = &"enemy"
	_hitbox.damage = damage
	_hitbox.continuous = false
	_hitbox.rehit_interval = lifetime + 1.0  # one honest hit per sweep
	_hitbox.knockback_strength = 280.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	_hitbox.add_child(shape)
	add_child(_hitbox)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if not _armed and _age >= warmup:
		_armed = true
		_hitbox.continuous = true
		_hitbox.monitoring = true
		queue_redraw()
	elif not _armed:
		queue_redraw()
	global_position += velocity * delta


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	var pulse := 0.35 + 0.25 * sin(_age * 48.0) if not _armed else 1.0
	draw_rect(rect.grow(7.0), Color(color.r, color.g, color.b, 0.14 + pulse * 0.08))
	draw_rect(rect, color.darkened(0.42), _armed)
	if not _armed:
		draw_rect(rect, Color(color.r, color.g, color.b, 0.18 + pulse * 0.18))
	draw_rect(rect, color.lightened(0.25), false, 4.0)
	# Chevrons expose direction even before the strip starts moving.
	var facing := signf(velocity.x) if velocity.x != 0.0 else 1.0
	for x in [-size.x * 0.25, 0.0, size.x * 0.25]:
		draw_line(Vector2(x - facing * 6.0, -6), Vector2(x + facing * 4.0, 0), Color.WHITE, 2.0)
		draw_line(Vector2(x + facing * 4.0, 0), Vector2(x - facing * 6.0, 6), Color.WHITE, 2.0)
