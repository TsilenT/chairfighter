class_name Hurtbox
extends Area2D
## Damage receiver. Layer 5 (hurtbox), no mask (hitboxes detect us).
## Owners connect hit_received and route into their Health.

signal hit_received(hitbox: Hitbox)

@export var faction: StringName = &"enemy"


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(hitbox: Hitbox) -> void:
	hit_received.emit(hitbox)
