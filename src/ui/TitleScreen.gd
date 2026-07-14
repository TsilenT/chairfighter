extends Control
## Title screen. ui_accept/jump continues a save when one exists (or starts
## fresh); R always starts a new game.

signal start_requested(continue_save: bool)

@onready var _prompt: Label = $Center/Prompt

var _started := false
var _pulse := 0.0


func _ready() -> void:
	if GameState.has_save():
		_prompt.text = "SPACE (pad A) — continue        R — new game"


func _process(delta: float) -> void:
	_pulse += delta * 2.2
	_prompt.modulate.a = 0.55 + 0.45 * sin(_pulse)
	# Poll action STATE (not events) so both real presses and the demo
	# driver's synthetic Input.action_press start the game.
	if _started:
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		_started = true
		Events.sfx_requested.emit(&"ui_start")
		start_requested.emit(GameState.has_save())
	elif Input.is_action_just_pressed("restart"):
		_started = true
		Events.sfx_requested.emit(&"ui_start")
		start_requested.emit(false)
