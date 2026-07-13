class_name Checkpoint
extends Area2D
## Respawn beacon. Requires a same-named Marker2D under the zone's
## SpawnPoints (contract), which is what the player respawns at.

@export var spawn_name: String = "Default"

var _lit := false


func _ready() -> void:
	collision_layer = 32
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 130)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	Events.checkpoint_activated.connect(_on_any_checkpoint)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Checkpoints are also the healing valve (casual difficulty): every touch
	# restores full health, even when already active.
	if body.has_method("heal_full"):
		body.heal_full()
	if _lit:
		return
	var zone := _find_zone()
	if zone == null or zone.scene_file_path.is_empty():
		push_error("[Checkpoint] Can't resolve owning zone scene path")
		return
	_lit = true
	GameState.set_checkpoint(zone.scene_file_path, spawn_name)
	Events.sfx_requested.emit(&"checkpoint")
	queue_redraw()


func _on_any_checkpoint(zone_path: String, spawn: String) -> void:
	# Un-light when a different checkpoint becomes active.
	var zone := _find_zone()
	var mine: bool = zone != null and zone.scene_file_path == zone_path and spawn == spawn_name
	if _lit != mine:
		_lit = mine
		queue_redraw()


func _find_zone() -> Node:
	var node: Node = self
	while node != null and not node.is_in_group("zone"):
		node = node.get_parent()
	return node


func _draw() -> void:
	# A cozy floor cushion: lit = warm, unlit = grey.
	var base := Color(0.95, 0.7, 0.3) if _lit else Color(0.45, 0.42, 0.4)
	draw_rect(Rect2(-26, -14, 52, 14), base)
	draw_rect(Rect2(-26, -14, 52, 14), Color(0.15, 0.1, 0.08), false, 3.0)
	draw_rect(Rect2(-20, -20, 40, 6), base.lightened(0.2))
	if _lit:
		draw_circle(Vector2(0, -40), 7.0, Color(1.0, 0.85, 0.4, 0.85))
