## GrapplePoint.gd — A valid armchair-grapple anchor point.
##
## Visible circular placeholder with an invisible Area2D for range detection.
## When the player (Armchair form) is within range and presses special, this
## point becomes the grapple target.

extends Area2D
class_name GrapplePoint


## Maximum range at which this point can be detected by the player.
@export var grapple_range: float = 300.0

## How large the visible placeholder circle is.
@export var visible_radius: float = 20.0

## Emitted when the player starts grappling to this point.
signal grapple_started(point: GrapplePoint)

## Emitted when the player releases the grapple from this point.
signal grapple_ended(point: GrapplePoint)


func _ready() -> void:
	# Register this node in the grapple_points group so Player can scan.
	add_to_group("grapple_points")

	# Set up the detection collision circle.
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = grapple_range
	var col := CollisionShape2D.new()
	col.shape = circle_shape
	add_child(col)
	col.position = Vector2.ZERO

	# Connect bodyEntered / bodyExited for debugging (optional).
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _draw() -> void:
	# Visible placeholder: hollow circle with pulsing ring.
	var color := Color(1.0, 0.85, 0.0, 0.8)  # golden yellow
	draw_circle(Vector2.ZERO, visible_radius, color)
	# Inner highlight to indicate "grapple target".
	draw_circle(Vector2.ZERO, visible_radius * 0.4, Color(1.0, 1.0, 0.2, 0.6))
	# Outer ring.
	draw_arc(Vector2.ZERO, visible_radius, 0, TAU, 32, color, 2.0)


func _physics_process(delta: float) -> void:
	# Pulse the visible radius for feedback.
	visible_radius = 20.0 + sin(_get_tick() * 3.0) * 4.0
	queue_redraw()


func _get_tick() -> float:
	return float(Engine.get_process_frames())


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("[GrapplePoint] Player detected within grapple range.")


func _on_body_exited(body: Node) -> void:
	pass


## Check if a given body (player) is within range of this grapple point.
func is_within_range(body: Node2D) -> bool:
	var dist := global_position.distance_to(body.global_position)
	return dist <= grapple_range


## Called by the player to start grappling this point.
func start_grapple(player: Node2D) -> void:
	print("[GrapplePoint] Grapple started! Target: %s" % str(global_position))
	grapple_started.emit(self)


## Called by the player to release the grapple.
func end_grapple(player: Node2D) -> void:
	print("[GrapplePoint] Grapple released.")
	grapple_ended.emit(self)
