extends Control
## Full-width fanfare shown when a new chair form is unlocked.

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _blurb: Label = $Panel/VBox/Blurb

var _pending: Array[Dictionary] = []
var _showing := false
var _announced_progress := 0


func _ready() -> void:
	Events.unlock_banner_requested.connect(_show_banner)
	_panel.visible = false
	for id: StringName in GameState.REQUIRED_FINAL_FORMS:
		if GameState.is_unlocked(id):
			_announced_progress += 1


func _show_banner(form_id: StringName, display_name: String, blurb: String) -> void:
	var progress := 0
	if form_id in GameState.REQUIRED_FINAL_FORMS:
		_announced_progress = mini(_announced_progress + 1, GameState.REQUIRED_FINAL_FORMS.size())
		progress = _announced_progress
	_pending.append({"id": form_id, "name": display_name, "blurb": blurb, "progress": progress})
	if not _showing:
		_drain_queue.call_deferred()


func _drain_queue() -> void:
	if _showing:
		return
	_showing = true
	while not _pending.is_empty():
		var reward: Dictionary = _pending.pop_front()
		await _present(reward)
	_showing = false


func _present(reward: Dictionary) -> void:
	var form_id := StringName(String(reward["id"]))
	var def := load("res://src/forms/%s.tres" % form_id) as FormDef
	var reward_number := int(reward.get("progress", 0))
	if reward_number > 0:
		_title.text = "UNLOCK %d / 8 — %s" % [reward_number, String(reward["name"]).to_upper()]
	else:
		_title.text = "NEW FORM — %s" % String(reward["name"]).to_upper()
	_blurb.text = String(reward["blurb"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = def.body_color.darkened(0.45) if def != null else Color(0.2, 0.2, 0.2)
	sb.bg_color.a = 0.92
	sb.border_color = Color(0.98, 0.85, 0.4)
	sb.border_width_bottom = 4
	sb.border_width_top = 4
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = true
	_panel.modulate.a = 0.0
	Events.sfx_requested.emit(&"unlock")
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.1)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.45)
	await tween.finished
	_panel.visible = false
