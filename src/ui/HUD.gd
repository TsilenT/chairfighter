extends Control
## In-game HUD: hearts (top-left), form chips (bottom-left), boss bar
## (bottom-center), zone banner (top-center). Purely Events-driven.

@onready var _hearts: Control = $Hearts
@onready var _chips: HBoxContainer = $FormChips
@onready var _boss_box: VBoxContainer = $BossBox
@onready var _boss_name: Label = $BossBox/BossName
@onready var _boss_bar: ProgressBar = $BossBox/BossBar
@onready var _zone_banner: Label = $ZoneBanner

var _hp := 5
var _hp_max := 5
var _chip_labels: Dictionary = {}


func _ready() -> void:
	Events.player_health_changed.connect(_on_health)
	Events.form_changed.connect(func(_id: StringName) -> void: _refresh_chips())
	Events.form_unlocked.connect(func(_id: StringName) -> void: _refresh_chips())
	Events.boss_started.connect(_on_boss_started)
	Events.boss_health_changed.connect(_on_boss_health)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _boss_box.visible = false)
	Events.zone_loaded.connect(_on_zone_loaded)
	Events.player_died.connect(func() -> void: _boss_box.visible = false)
	_build_chips()
	_hearts.draw.connect(_draw_hearts)
	_boss_box.visible = false
	_zone_banner.modulate.a = 0.0


func _on_health(current: int, maximum: int) -> void:
	_hp = current
	_hp_max = maximum
	_hearts.queue_redraw()


func _draw_hearts() -> void:
	for i in _hp_max:
		var x := 20.0 + i * 42.0
		var filled := i < _hp
		_draw_heart(Vector2(x, 24), 15.0, filled)


func _draw_heart(center: Vector2, r: float, filled: bool) -> void:
	var fill := Color(0.9, 0.22, 0.28) if filled else Color(0.28, 0.24, 0.24)
	var outline := Color(0.12, 0.08, 0.08)
	var pts := PackedVector2Array()
	# Simple heart: two lobes + point.
	pts.append(center + Vector2(0, r))
	pts.append(center + Vector2(-r, -r * 0.2))
	pts.append(center + Vector2(-r * 0.55, -r * 0.75))
	pts.append(center + Vector2(0, -r * 0.3))
	pts.append(center + Vector2(r * 0.55, -r * 0.75))
	pts.append(center + Vector2(r, -r * 0.2))
	_hearts.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_hearts.draw_polyline(pts, outline, 2.0)


func _build_chips() -> void:
	for id: StringName in GameState.FORM_ORDER:
		var chip := Label.new()
		chip.text = ""
		chip.custom_minimum_size = Vector2(120, 34)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_chips.add_child(chip)
		_chip_labels[id] = chip
	_refresh_chips()


func _refresh_chips() -> void:
	for id: StringName in GameState.FORM_ORDER:
		var chip: Label = _chip_labels[id]
		var def: FormDef = load("res://src/forms/%s.tres" % id)
		var unlocked := GameState.is_unlocked(id)
		var active := GameState.current_form == id
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		if not unlocked:
			chip.text = "???"
			sb.bg_color = Color(0.14, 0.13, 0.12, 0.75)
			chip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.4))
		else:
			chip.text = def.display_name
			sb.bg_color = def.body_color.darkened(0.25 if active else 0.55)
			sb.bg_color.a = 0.95 if active else 0.6
			chip.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.75, 0.72, 0.7))
			if active:
				sb.border_width_bottom = 3
				sb.border_width_top = 3
				sb.border_width_left = 3
				sb.border_width_right = 3
				sb.border_color = Color(0.98, 0.85, 0.4)
		chip.add_theme_stylebox_override("normal", sb)


func _on_boss_started(_id: StringName, display_name: String) -> void:
	_boss_name.text = display_name
	_boss_bar.value = 100.0
	_boss_box.visible = true


func _on_boss_health(_id: StringName, current: float, maximum: float) -> void:
	_boss_bar.value = 100.0 * current / maxf(maximum, 0.001)


func _on_zone_loaded(zone_name: String) -> void:
	_zone_banner.text = zone_name
	var tween := create_tween()
	tween.tween_property(_zone_banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(_zone_banner, "modulate:a", 0.0, 0.8)
