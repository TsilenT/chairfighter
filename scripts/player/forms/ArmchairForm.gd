## ArmchairForm.gd — Placeholder armchair form, unlocked by defeating
## the Recliner Baron miniboss.
##
## Placeholder implementation for CF-03. Visuals are distinct from Basic
## Chair (magenta instead of brown) so the player knows they switched
## forms. Grapple special is stubbed and will be implemented in CF-05.

extends ChairForm


func _init() -> void:
	form_name = "Armchair"
	## Stubbed as locked at this point — GameState unlocks it via
	## the boss defeat or the test-unlock function.
	is_unlocked = false
	max_speed = 260.0
	acceleration = 1700.0
	deceleration = 1900.0
	air_control = 0.45
	jump_velocity = -540.0
	gravity_scale = 4.0
	collision_shape = Vector2.ZERO
	body_color = Color(0.8, 0.3, 0.7, 1.0)
	label_text = "Armchair"


func on_activate(_previous_form: ChairForm) -> void:
	print("[ArmchairForm] Armchair form activated! Grapple will be available in CF-05.")


func on_special() -> void:
	## Stub — actual grapple logic is implemented in ArmchairForm.gd in CF-05.
	print("[ArmchairForm] Special (grapple) stubbed — grapple mechanic added in CF-05.")


func on_attack() -> void:
	## Longer-range punch than Basic Chair — damage range handled by Player.gd
	pass
