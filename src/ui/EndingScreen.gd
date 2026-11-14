extends Control
## Victory screen.

const Style := preload("res://src/ui/MenuStyle.gd")


func _ready() -> void:
	var close := Style.button("Return to title")
	close.pressed.connect(_return_to_title)
	$Center.add_child(close)
	close.grab_focus()


func _return_to_title() -> void:
	get_tree().reload_current_scene()
