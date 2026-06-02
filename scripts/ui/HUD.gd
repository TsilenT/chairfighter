## HUD.gd — Simple HUD that shows the current chair form and player health.
##
## Reads the active form from GameState and updates a label and color box.
## Also displays player health via the GameState signal.
## Connects to Player's player_died signal to show death overlay.

extends CanvasLayer

@onready var form_label := $FormLabel as Label
@onready var form_color_box := $FormColorBox as ColorRect
@onready var health_label := $HealthLabel as Label
@onready var health_bar_bg := $HealthBarBG as ColorRect
@onready var health_bar_fill := $HealthBarFill as ColorRect
@onready var unlock_hint := $UnlockHint as Label
@onready var death_overlay := $DeathOverlay as ColorRect
@onready var death_text := $DeathText as Label


func _ready() -> void:
	add_to_group("hud")

	var form_def : ChairForm = GameState.get_current_form_def()
	if form_def:
		_update_display(form_def.form_name, form_def.body_color, form_def.label_text)

	GameState.form_unlocked.connect(_on_form_unlocked)
	GameState.player_died.connect(_on_player_died)
	GameState.game_restart.connect(_on_game_restart)


func _process(_delta: float) -> void:
	## Update display each frame so it stays in sync with GameState.
	var form_def : ChairForm = GameState.get_current_form_def()
	if form_def and form_label:
		if form_label.text != form_def.label_text:
			_update_display(form_def.form_name, form_def.body_color, form_def.label_text)

	## Update health bar width based on current HP
	if health_bar_fill and health_bar_bg:
		var pct = clampf(GameState.player_current_health / GameState.player_max_health, 0.0, 1.0)
		health_bar_fill.position = health_bar_bg.position
		health_bar_fill.size = Vector2(190.0 * pct, health_bar_bg.size.y)
		health_bar_fill.color = _green_color(pct)
		if health_label:
			health_label.text = "HP: %d / %d" % [
				max(0, int(GameState.player_current_health)),
				int(GameState.player_max_health)
			]


func _on_player_health_changed(current: float, max_hp: float) -> void:
	# Health bar width is updated in _process() which runs every frame
	pass


func _update_display(name: String, color: Color, label: String) -> void:
	if form_label:
		form_label.text = label
	if form_color_box:
		form_color_box.color = color * 0.8


func _on_form_unlocked(form_name: String) -> void:
	if unlock_hint:
		unlock_hint.text = form_name + " unlocked!"
		unlock_hint.visible = true


func _on_player_died() -> void:
	if death_overlay:
		death_overlay.visible = true
	if death_text:
		death_text.visible = true


func _on_game_restart() -> void:
	if death_overlay:
		death_overlay.visible = false
	if death_text:
		death_text.visible = false
	if unlock_hint:
		unlock_hint.visible = false
		unlock_hint.text = ""


func _green_color(pct: float) -> Color:
	# Smooth transition from red to yellow to green
	var r = 0.0 if pct > 0.5 else 0.6 + 0.4 * (pct * 2)
	var g = 0.2 + 0.6 * min(pct, 1.0)
	var b = 0.2
	return Color(r, g, b, 1)
