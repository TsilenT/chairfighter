## Hurtbox.gd — Melee hurtbox target.
##
## Attach to any enemy/boss node that should be hittable by Hitbox
## Area2D overlaps. Places node on layer 8 so hitboxes (layer 4)
## can detect it via mask.
##
## Layer/Mask convention (Godot 4 bit flags):
##  - Layer  1 (1) = collision world / static bodies
##  - Layer  3 (4) = hitboxes (melee attacks)
##  - Layer  4 (8) = hurtboxes (take damage targets)
##  - Layer  5 (16) = enemies
##  - Layer  6 (32) = grapple points
##  - Layer  7 (64) = ability gates

extends Area2D

class_name Hurtbox

## Width of the hurtbox area (automatically mirrored left/right).
@export var half_width: float = 48.0

## Height of the hurtbox area.
@export var half_height: float = 64.0

## Offset from the parent node's center.
@export var offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Place on hurtbox layer, receive from hitbox layer
	set_collision_layer_bit(4, true)   # Layer 4 = hurtboxes
	set_collision_mask_bit(3, true)    # Layer 3 = hitboxes

	# Create the collision shape
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half_width * 2, half_height * 2)
	var col_shape := CollisionShape2D.new()
	col_shape.position = offset
	col_shape.shape = shape
	add_child(col_shape)
