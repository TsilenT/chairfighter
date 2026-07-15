extends Control
## In-game HUD: hearts (top-left), form chips (bottom-left), boss bar
## (bottom-center), zone banner (top-center). Purely Events-driven.

@onready var _hearts: Control = $Hearts
@onready var _chips: GridContainer = $FormChips
@onready var _mechanic_hint: Label = $MechanicHint
@onready var _boss_box: VBoxContainer = $BossBox
@onready var _boss_name: Label = $BossBox/BossName
@onready var _boss_bar: ProgressBar = $BossBox/BossBar
@onready var _zone_banner: Label = $ZoneBanner

var _hp := 5
var _hp_max := 5
var _chip_labels: Dictionary = {}

const FORM_HINTS := {
	&"basic": "J / pad X — seat-first body bash",
	&"armchair": "K / pad B (hold) — grapple gold hooks",
	&"recliner": "K / pad B (hold) — brace and counter",
	&"office": "K / pad B — dash through cracks",
	&"barstool": "K / pad B (hold) — spin and reflect",
	&"folding": "K / pad B — fold · jump folded to spring",
	&"highchair": "K / pad B — throw the tray",
	&"rocking": "K hold/release — launch · hard landing slams",
	&"stool": "K / pad B in midair — pogo jump",
}


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
	_style_mechanic_hint()
	_hearts.draw.connect(_draw_hearts)
	_boss_box.visible = false
	_zone_banner.modulate.a = 0.0
	# Boss bar must never read as level geometry (CF-B001): top of screen,
	# clearly a UI panel — dark bordered trough, blood-red rounded fill.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.05, 0.9)
	bg.border_color = Color(0.85, 0.75, 0.5)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.16, 0.2)
	fill.set_corner_radius_all(7)
	fill.set_expand_margin_all(-1.0)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_name.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	_boss_name.add_theme_constant_override("outline_size", 6)


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
		chip.custom_minimum_size = Vector2(106, 30)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", 14)
		_chips.add_child(chip)
		_chip_labels[id] = chip
	_refresh_chips()


func _style_mechanic_hint() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.065, 0.86)
	sb.border_color = Color(0.62, 0.52, 0.32, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_mechanic_hint.add_theme_stylebox_override("normal", sb)
	_mechanic_hint.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))


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
	_mechanic_hint.text = "Q/E switch  ·  %s" % FORM_HINTS.get(
			GameState.current_form, "J / pad X — attack")


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
