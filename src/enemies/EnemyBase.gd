class_name EnemyBase
extends CharacterBody2D
## Shared enemy chassis: Health + Hurtbox + continuous contact Hitbox,
## knockback response, death poof. Subclasses implement _ai(delta) and
## _draw_body(). Placeholder _draw visuals are replaced in Phase 4.

@export var max_health := 4.0
@export var contact_damage := 1.0
@export var move_speed := 60.0
@export var gravity_on := true
@export var skin_color := Color(0.5, 0.4, 0.3)
@export var body_size := Vector2(44, 36)

const GRAVITY := 2200.0
const KNOCKBACK_DECAY := 1400.0

var health: Health
var _kb := Vector2.ZERO
var _hurt_flash := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	collider.shape = rect
	collider.position = Vector2(0, -body_size.y / 2.0)
	add_child(collider)

	health = Health.new()
	health.max_health = max_health
	health.invuln_time = 0.25
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	add_child(health)

	var hurtbox := Hurtbox.new()
	hurtbox.faction = &"enemy"
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = rect.duplicate()
	hurt_shape.position = collider.position
	hurtbox.add_child(hurt_shape)
	hurtbox.hit_received.connect(func(hb: Hitbox) -> void:
		if health.damage(hb.damage, hb.knockback_for(self)):
			Events.hitstop_requested.emit(0.05)
			Events.sfx_requested.emit(&"hit"))
	add_child(hurtbox)

	var contact := Hitbox.new()
	contact.faction = &"enemy"
	contact.damage = contact_damage
	contact.continuous = true
	contact.knockback_strength = 300.0
	var contact_shape := CollisionShape2D.new()
	contact_shape.shape = rect.duplicate()
	contact_shape.position = collider.position
	contact.add_child(contact_shape)
	add_child(contact)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	if gravity_on:
		velocity.y += GRAVITY * delta
	if _kb != Vector2.ZERO:
		velocity.x = _kb.x
		velocity.y = _kb.y if not gravity_on else velocity.y + _kb.y * 0.5
		_kb = _kb.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	else:
		_ai(delta)
	move_and_slide()
	queue_redraw()


## Subclass hook: steer via velocity.
func _ai(_delta: float) -> void:
	pass


func _on_damaged(_amount: float, knockback: Vector2) -> void:
	_kb = knockback
	_hurt_flash = 1.0


func _on_died() -> void:
	_dead = true
	Events.sfx_requested.emit(&"enemy_down")
	Particles.poof(get_parent(), global_position + Vector2(0, -body_size.y / 2.0), skin_color)
	# Squash-out death: shrink and vanish.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 0.1), 0.18)
	tween.tween_callback(queue_free)
	collision_layer = 0
	for child in get_children():
		if child is Area2D:
			(child as Area2D).monitoring = false
			(child as Area2D).monitorable = false


func _draw() -> void:
	if _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0:
		draw_rect(Rect2(-body_size.x / 2.0, -body_size.y, body_size.x, body_size.y), Color.WHITE)
		return
	_draw_body()


## Subclass hook: placeholder body art. Origin at FEET.
func _draw_body() -> void:
	draw_rect(Rect2(-body_size.x / 2.0, -body_size.y, body_size.x, body_size.y), skin_color)
