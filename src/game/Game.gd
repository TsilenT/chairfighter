extends Node
## Root orchestrator: title screen → zone loading/swapping → player spawn →
## respawn-on-death → pause → ending. UI lives on a CanvasLayer; the active
## zone and the (single, persistent) player live under ZoneHolder.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const TITLE_SCENE := "res://scenes/ui/TitleScreen.tscn"
const HUD_SCENE := "res://scenes/ui/HUD.tscn"
const PAUSE_SCENE := "res://scenes/ui/PauseMenu.tscn"
const UNLOCK_SCENE := "res://scenes/ui/UnlockBanner.tscn"
const ENDING_SCENE := "res://scenes/ui/EndingScreen.tscn"

@onready var _zone_holder: Node2D = $ZoneHolder
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _fade: ColorRect = $FadeLayer/Fade

var _player: CharacterBody2D = null
var _current_zone: Node = null
var _title: Node = null
var _hud: Node = null
var _pause_menu: Node = null
var _transitioning := false


func _ready() -> void:
	# Keep processing while paused so the pause toggle still works; only the
	# zone (gameplay) subtree actually pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zone_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.zone_change_requested.connect(_on_zone_change_requested)
	Events.player_died.connect(_on_player_died)
	Events.game_won.connect(_on_game_won)
	_fade.color = Color(0.07, 0.05, 0.04, 1.0)
	_fade.modulate.a = 1.0
	_show_title()


func _show_title() -> void:
	_title = load(TITLE_SCENE).instantiate()
	_ui_layer.add_child(_title)
	_title.start_requested.connect(_start_new_game)
	_fade_to(0.0, 0.6)


func _start_new_game() -> void:
	if _title != null:
		_title.queue_free()
		_title = null
	GameState.new_game()
	_hud = load(HUD_SCENE).instantiate()
	_ui_layer.add_child(_hud)
	var banner: Node = load(UNLOCK_SCENE).instantiate()
	_ui_layer.add_child(banner)
	await _load_zone(GameState.checkpoint_zone, GameState.checkpoint_spawn)


func _on_zone_change_requested(zone_path: String, spawn_name: String) -> void:
	if _transitioning:
		return
	await _load_zone(zone_path, spawn_name)


func _load_zone(zone_path: String, spawn_name: String) -> void:
	_transitioning = true
	get_tree().paused = false
	await _fade_to(1.0, 0.25)
	if _current_zone != null:
		# Reparent the player out before freeing the old zone.
		if _player != null and _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		_current_zone.queue_free()
		_current_zone = null
		await get_tree().process_frame
	var packed: PackedScene = load(zone_path)
	if packed == null:
		push_error("[Game] Cannot load zone %s" % zone_path)
		_transitioning = false
		return
	_current_zone = packed.instantiate()
	_zone_holder.add_child(_current_zone)
	if _player == null:
		_player = load(PLAYER_SCENE).instantiate()
	var spawn := _find_spawn(spawn_name)
	_current_zone.add_child(_player)
	_player.global_position = spawn
	if _player.has_method("on_spawned"):
		_player.on_spawned()
	if _current_zone.has_method("apply_camera_limits") and _player.has_method("get_camera_rig"):
		_current_zone.apply_camera_limits(_player.get_camera_rig())
	var zone_name := String(_current_zone.name)
	if "zone_display_name" in _current_zone and not String(_current_zone.zone_display_name).is_empty():
		zone_name = _current_zone.zone_display_name
	Events.zone_loaded.emit(zone_name)
	await _fade_to(0.0, 0.25)
	_transitioning = false


func _find_spawn(spawn_name: String) -> Vector2:
	var spawns := _current_zone.get_node_or_null("SpawnPoints")
	if spawns != null:
		var marker := spawns.get_node_or_null(spawn_name)
		if marker == null:
			marker = spawns.get_node_or_null("Default")
		if marker is Marker2D:
			return (marker as Marker2D).global_position
	push_error("[Game] Zone %s has no spawn '%s' (nor Default)" % [_current_zone.name, spawn_name])
	return Vector2.ZERO


func _on_player_died() -> void:
	await get_tree().create_timer(1.4, false, true).timeout
	if _player != null and _player.has_method("revive"):
		_player.revive()
	await _load_zone(GameState.checkpoint_zone, GameState.checkpoint_spawn)
	Events.player_respawned.emit()


func _on_game_won() -> void:
	await _fade_to(1.0, 1.2)
	if _hud != null:
		_hud.queue_free()
		_hud = null
	if _current_zone != null:
		_current_zone.queue_free()
		_current_zone = null
		_player = null
	var ending: Node = load(ENDING_SCENE).instantiate()
	_ui_layer.add_child(ending)
	await _fade_to(0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _title == null and not _transitioning:
		_toggle_pause()


func _toggle_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
		get_tree().paused = false
		return
	_pause_menu = load(PAUSE_SCENE).instantiate()
	_ui_layer.add_child(_pause_menu)
	get_tree().paused = true


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished
