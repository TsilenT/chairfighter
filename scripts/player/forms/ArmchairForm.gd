extends ChairForm
class_name ArmchairForm

func _init() -> void:
	form_name = "Armchair"
	is_unlocked = true
	max_speed = 260.0
	acceleration = 1700.0
	deceleration = 1900.0
	air_control = 0.45
	jump_velocity = -540.0
	gravity_scale = 4.0
	collision_shape = Vector2.ZERO
	body_color = Color(0.8, 0.3, 0.7, 1.0)
	label_color = Color.WHITE
	label_text = "Armchair"


func on_activate(_previous_form: ChairForm) -> void:
	print("[ArmchairForm] Armchair form activated! Grapple ready.")


func on_special() -> void:
	"""Called by Player.gd when special is pressed while in Armchair form."""
	print("[ArmchairForm] Special pressed — grapple triggered by form.")


func on_attack() -> void:
	"""Armchair punch — no special behavior in MVP."""
	pass
