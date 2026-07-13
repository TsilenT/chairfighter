extends Control
## Full-width fanfare shown when a new chair form is unlocked.

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _blurb: Label = $Panel/VBox/Blurb


func _ready() -> void:
	Events.unlock_banner_requested.connect(_show_banner)
	_panel.visible = false


func _show_banner(form_id: StringName, display_name: String, blurb: String) -> void:
	var def: FormDef = load("res://src/forms/%s.tres" % form_id)
	_title.text = "NEW FORM — %s" % display_name.to_upper()
	_blurb.text = blurb
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
	tween.tween_interval(3.0)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void: _panel.visible = false)
