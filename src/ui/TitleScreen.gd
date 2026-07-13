extends Control
## Title screen. Emits start_requested on jump/ui_accept.

signal start_requested

@onready var _prompt: Label = $Center/Prompt

var _started := false
var _pulse := 0.0


func _process(delta: float) -> void:
	_pulse += delta * 2.2
	_prompt.modulate.a = 0.55 + 0.45 * sin(_pulse)


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_started = true
		Events.sfx_requested.emit(&"ui_start")
		start_requested.emit()
