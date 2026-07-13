class_name Particles
extends Object
## One-shot CPUParticles2D helpers. Fire-and-forget: bursts free themselves.


static func burst(parent: Node, global_pos: Vector2, color: Color, count := 10,
		speed := 120.0, life := 0.5, up_bias := true, gravity := 500.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1) if up_bias else Vector2(0, 0)
	p.spread = 70.0 if up_bias else 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = color
	parent.add_child(p)
	p.global_position = global_pos
	var t := p.get_tree().create_timer(life + 0.3, false, true)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


static func dust(parent: Node, global_pos: Vector2, intensity := 1.0) -> void:
	burst(parent, global_pos, Color(0.75, 0.68, 0.55, 0.6),
			int(4 + 8 * intensity), 60.0 + 90.0 * intensity, 0.45, true, 160.0)


static func shards(parent: Node, global_pos: Vector2, color: Color) -> void:
	burst(parent, global_pos, color, 16, 260.0, 0.7, false, 900.0)


static func poof(parent: Node, global_pos: Vector2, color: Color) -> void:
	burst(parent, global_pos, color.lightened(0.2), 12, 140.0, 0.5, true, 60.0)


static func confetti(parent: Node, global_pos: Vector2) -> void:
	for c in [Color(0.95, 0.75, 0.3), Color(0.85, 0.3, 0.4), Color(0.4, 0.7, 0.9)]:
		burst(parent, global_pos + Vector2(randf_range(-40, 40), randf_range(-60, 0)),
				c, 12, 320.0, 1.1, true, 700.0)
