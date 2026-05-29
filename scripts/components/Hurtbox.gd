## Hurtbox.gd — Area2D damage receiver (hurtbox).
##
## Detects incoming hitboxes via mutual-layer area collision.
## When a hitbox enters, emits hitbox_entered(hitbox) with the hitbox Area2D.
##
## Layer 4 (bit 3) for hurtboxes; Layer 5 (bit 4) for hitboxes.

extends Area2D

class_name Hurtbox

signal hitbox_entered(hitbox: Area2D)

# Collision layer numbers (Godot's set_collision_*_value API is 1-indexed)
const LAYER_HURTBOX := 4  # bit 3 — damage receiver areas
const LAYER_HITBOX  := 5  # bit 4 — melee attack areas


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER_HURTBOX, true)
	set_collision_mask_value(LAYER_HITBOX, true)
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	"""Pass through hitbox areas."""
	if area is Hitbox:
		hitbox_entered.emit(area)
