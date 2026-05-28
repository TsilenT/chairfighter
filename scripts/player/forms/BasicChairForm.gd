## BasicChairForm.gd — Default starting chair form.
##
## Standard wooden chair with basic movement and melee attack.
## No special mechanics — pure baseline platformer form.

extends ChairForm


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
	body_color = Color(0.55, 0.45, 0.3, 1.0)
	label_text = "Basic Chair"


func on_attack() -> void:
	## Short-range leg swipe — damage handled by Player.gd
	pass
