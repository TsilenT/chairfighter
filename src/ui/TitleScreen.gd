extends Control

signal start_requested(continue_save: bool)

const Style := preload("res://src/ui/MenuStyle.gd")

@onready var _menu: VBoxContainer = $Center
var _started := false
var _confirming := false


func _ready() -> void:
	_show_options()


func _show_options() -> void:
	var has_save := GameState.has_save()
	_add_option("Continue", _start.bind(true)).visible = has_save
	_add_option("New game" if has_save else "Start game", _request_new_game)
	_focus_first()


func _request_new_game() -> void:
	if not GameState.has_save():
		_start(false)
		return
	_confirming = true
	for child in _menu.get_children():
		if child is Button:
			child.hide()
	var warning := Style.label("Start over? Your next checkpoint will replace the current run.", 18)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(warning)
	var keep := _add_option("Keep my run", func() -> void:
		for child in _menu.get_children():
			if child is Button and child.visible or child == warning:
				child.hide()
				child.queue_free()
			elif child is Button and (child.text == "Continue" or child.text == "New game"):
				child.show()
		_confirming = false
		_focus_first())
	_add_option("Start over", _start.bind(false))
	keep.grab_focus()


func _add_option(title: String, callback: Callable) -> Button:
	var option := Style.button(title)
	option.pressed.connect(callback)
	_menu.add_child(option)
	return option


func _focus_first() -> void:
	for child in _menu.get_children():
		if child is Button and child.visible:
			child.grab_focus()
			return


func _process(_delta: float) -> void:
	# Input.action_press drives the deterministic playthrough and bypasses GUI events.
	if not _started and not _confirming and DemoDriver.active and Input.is_action_just_pressed("ui_accept"):
		_start(GameState.has_save())


func _unhandled_input(event: InputEvent) -> void:
	if not _started and not _confirming and event.is_action_pressed("restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_request_new_game()


func _start(continue_save: bool) -> void:
	if _started:
		return
	_started = true
	Events.sfx_requested.emit(&"ui_start")
	start_requested.emit(continue_save)
