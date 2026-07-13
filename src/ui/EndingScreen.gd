extends Control
## Victory screen. ui_accept returns to the title (reloads the Game scene).


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
