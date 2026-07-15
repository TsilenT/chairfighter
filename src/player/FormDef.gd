class_name FormDef
extends Resource
## One resource per chair form (src/forms/<id>.tres). Movement is authored
## as design metrics (jump height in px, time to apex); velocities and
## gravity are DERIVED so levels and physics can never drift apart.

@export var id: StringName
@export var display_name: String = ""
@export var run_speed: float = 340.0
@export var accel: float = 2600.0
@export var decel: float = 3000.0
@export var air_control: float = 0.65
@export var jump_height: float = 150.0
@export var time_to_apex: float = 0.38
@export var fall_gravity_mult: float = 1.6
@export var attack_damage: float = 2.0
@export var attack_cooldown: float = 0.3
## Primary attacks are authored as chair-shaped contact zones rather than a
## generic box floating in front of the player. `attack_offset.x` is measured
## in the chair's facing direction; the other values are world-space pixels.
@export var attack_style: StringName = &"body_bash"
@export var attack_size: Vector2 = Vector2(72.0, 52.0)
@export var attack_offset: Vector2 = Vector2(10.0, -27.0)
@export var attack_active_time: float = 0.12
@export var attack_knockback: float = 300.0
@export var attack_impulse: float = 0.0
@export var collider_height: float = 56.0
@export var body_color: Color = Color(0.55, 0.36, 0.2)
@export var sprite_path: String = ""
@export_multiline var unlock_blurb: String = ""


func rise_gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


func fall_gravity() -> float:
	return rise_gravity() * fall_gravity_mult


func jump_velocity() -> float:
	return -rise_gravity() * time_to_apex


## Furthest point of the primary attack in front of the chair's origin. This
## feeds the demo combat policy and stays correct for centred spin/sweep moves.
func attack_front_reach() -> float:
	return maxf(BODY_HALF_WIDTH, attack_offset.x + attack_size.x * 0.5)


## Every melee profile should begin on the body, so close enemies cannot sit
## in a dead zone while the visible chair passes through them.
func attack_overlaps_body() -> bool:
	return attack_offset.x - attack_size.x * 0.5 <= BODY_HALF_WIDTH


const BODY_HALF_WIDTH := 22.0
