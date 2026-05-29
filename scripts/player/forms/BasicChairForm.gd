## BasicChairForm.gd — Default starting chair form.
##
## Standard wooden chair with basic movement and melee attack.
## No special mechanics — pure baseline platformer form.

extends ChairForm
class_name BasicChairForm

func _init() -> void:
	form_name = "BasicChair"
	is_unlocked = true
	max_speed = 280.0
	acceleration = 1800.0
	deceleration = 2000.0
	air_control = 0.5
	jump_velocity = -520.0
	gravity_scale = 3.5
	collision_shape = Vector2.ZERO
	body_color = Color(0.55, 0.45, 0.3, 1)
	label_color = Color.WHITE
	label_text = "Basic Chair"

## Called when the player's attack (Melee) is performed.
func on_attack() -> void:
	"""Extend body forward for a short animation frame."""
	## TODO: animate the ChairBody extending forward (scale.x temporarily)
	pass
