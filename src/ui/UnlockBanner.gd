extends Control
## Shows guardian rewards together with the route they open.

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _blurb: Label = $Panel/VBox/Blurb

var _tween: Tween


func _ready() -> void:
	_panel.hide()
	if GameState.touch_controls:
		_panel.offset_top -= 112.0
		_panel.offset_bottom -= 112.0
	Events.boss_defeated.connect(_show_reward)


func _show_reward(boss_id: StringName) -> void:
	var floor := GameState.floor_for_boss(boss_id)
	if floor.is_empty():
		return
	var form := load("res://src/forms/%s.tres" % floor["form"]) as FormDef
	_title.text = "%s unlocked" % form.display_name
	_blurb.text = GameState.current_objective()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.show()
	_panel.modulate.a = 0.0
	Events.sfx_requested.emit(&"unlock")
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(4.0)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(_panel.hide)
