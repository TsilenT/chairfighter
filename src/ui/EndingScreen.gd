extends Control
## Victory screen. ui_accept returns to the title (reloads the Game scene).


func _process(_delta: float) -> void:
	# Polled (not event-driven) so the demo driver's synthetic input works.
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
