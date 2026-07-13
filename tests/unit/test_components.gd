extends RefCounted
## Health / Hitbox / Hurtbox damage flow, invulnerability, single-hit-per-burst.

const HealthScript := preload("res://src/components/Health.gd")
const HitboxScript := preload("res://src/components/Hitbox.gd")
const HurtboxScript := preload("res://src/components/Hurtbox.gd")


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var sandbox := Node2D.new()
	tree.root.add_child(sandbox)

	# ── Health basics ──
	var health: Health = HealthScript.new()
	health.max_health = 5.0
	health.invuln_time = 0.05
	sandbox.add_child(health)
	if not health.is_alive() or health.current != 5.0:
		fails.append("health should start full")
	if not health.damage(2.0):
		fails.append("first damage should land")
	if health.current != 3.0:
		fails.append("expected 3.0 hp, got %s" % health.current)
	if health.damage(2.0):
		fails.append("damage during invuln window should be rejected")
	for _i in 8:
		await tree.physics_frame
	if not health.damage(1.0):
		fails.append("damage after invuln expiry should land")
	var died := [false]
	health.died.connect(func() -> void: died[0] = true)
	health.damage(99.0)
	# 2.0 remaining minus 99 → dead… but invuln blocks immediately after prior hit.
	for _i in 8:
		await tree.physics_frame
	health.damage(99.0)
	if not died[0] or health.is_alive():
		fails.append("health should die at 0")

	# ── Hitbox → Hurtbox flow ──
	var hitbox: Hitbox = HitboxScript.new()
	hitbox.faction = &"player"
	hitbox.damage = 2.0
	var hit_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	hit_shape.shape = rect
	hitbox.add_child(hit_shape)
	sandbox.add_child(hitbox)

	var hurtbox: Hurtbox = HurtboxScript.new()
	hurtbox.faction = &"enemy"
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = rect.duplicate()
	hurtbox.add_child(hurt_shape)
	sandbox.add_child(hurtbox)

	var hits := [0]
	hurtbox.hit_received.connect(func(_hb: Hitbox) -> void: hits[0] += 1)
	# Let areas register in the physics space.
	for _i in 3:
		await tree.physics_frame
	hitbox.activate(0.1)
	for _i in 3:
		await tree.physics_frame
	if hits[0] != 1:
		fails.append("burst hitbox should hit exactly once, got %d" % hits[0])
	# Same activation must not re-hit while overlapping.
	for _i in 3:
		await tree.physics_frame
	if hits[0] != 1:
		fails.append("burst hitbox re-hit within one activation, got %d" % hits[0])
	# New activation hits again.
	hitbox.activate(0.1)
	for _i in 3:
		await tree.physics_frame
	if hits[0] != 2:
		fails.append("second activation should hit again, got %d" % hits[0])

	# Same-faction immunity.
	var friendly: Hurtbox = HurtboxScript.new()
	friendly.faction = &"player"
	var fr_shape := CollisionShape2D.new()
	fr_shape.shape = rect.duplicate()
	friendly.add_child(fr_shape)
	sandbox.add_child(friendly)
	var friendly_hits := [0]
	friendly.hit_received.connect(func(_hb: Hitbox) -> void: friendly_hits[0] += 1)
	for _i in 3:
		await tree.physics_frame
	hitbox.activate(0.1)
	for _i in 3:
		await tree.physics_frame
	if friendly_hits[0] != 0:
		fails.append("same-faction hurtbox must not be hit")

	sandbox.queue_free()
	await tree.physics_frame
	return fails
