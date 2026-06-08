extends SceneTree

const HitboxClass = preload("res://scripts/components/Hitbox.gd")
const HurtboxClass = preload("res://scripts/components/Hurtbox.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var attacker := Node2D.new()
	attacker.name = "Attacker"
	root.add_child(attacker)

	var target := Node2D.new()
	target.name = "Target"
	root.add_child(target)

	var hitbox := HitboxClass.new()
	hitbox.name = "TestHitbox"
	hitbox.damage = 2.0
	attacker.add_child(hitbox)
	var hit_col := CollisionShape2D.new()
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = Vector2(50, 50)
	hit_col.shape = hit_shape
	hitbox.add_child(hit_col)

	var hurtbox := HurtboxClass.new()
	hurtbox.name = "TestHurtbox"
	target.add_child(hurtbox)
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = Vector2(50, 50)
	hurt_col.shape = hurt_shape
	hurtbox.add_child(hurt_col)

	var hits := [0]
	hurtbox.hitbox_entered.connect(func(_hitbox: Area2D) -> void:
		hits[0] += 1
	)

	await physics_frame
	await physics_frame
	hitbox.activate()
	await physics_frame
	await physics_frame
	await process_frame

	if hits[0] != 1:
		printerr("Expected exactly one hit from already-overlapping hurtbox, got %d" % hits[0])
		quit(1)
		return

	print("hitbox overlap check passed")
	root.remove_child(attacker)
	root.remove_child(target)
	attacker.free()
	target.free()
	quit(0)
