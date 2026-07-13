extends RefCounted
## Form resources: ids match GameState.FORM_ORDER and derived physics hit
## the design table (spec: docs/superpowers/specs/2026-07-13-*-design.md).

const FORM_DIR := "res://src/forms/"

# id: [run_speed, jump_height, rise_gravity, jump_velocity]
const DESIGN := {
	&"basic": [340.0, 150.0, 2077.56, -789.47],
	&"armchair": [300.0, 140.0, 1939.06, -736.84],
	&"office": [380.0, 130.0, 2006.17, -722.22],
	&"folding": [320.0, 140.0, 1939.06, -736.84],
}


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	for id: StringName in gs.FORM_ORDER:
		var path := FORM_DIR + String(id) + ".tres"
		if not ResourceLoader.exists(path):
			fails.append("missing form resource %s" % path)
			continue
		var form: FormDef = load(path)
		if form.id != id:
			fails.append("%s: id mismatch (%s)" % [path, form.id])
		if form.display_name.is_empty():
			fails.append("%s: empty display_name" % path)
		var expect: Array = DESIGN[id]
		if absf(form.run_speed - expect[0]) > 0.01:
			fails.append("%s: run_speed %s != %s" % [id, form.run_speed, expect[0]])
		if absf(form.jump_height - expect[1]) > 0.01:
			fails.append("%s: jump_height %s != %s" % [id, form.jump_height, expect[1]])
		if absf(form.rise_gravity() - expect[2]) > expect[2] * 0.001:
			fails.append("%s: rise_gravity %.2f != %.2f" % [id, form.rise_gravity(), expect[2]])
		if absf(form.jump_velocity() - expect[3]) > absf(expect[3]) * 0.001:
			fails.append("%s: jump_velocity %.2f != %.2f" % [id, form.jump_velocity(), expect[3]])
		if form.fall_gravity() <= form.rise_gravity():
			fails.append("%s: fall gravity must exceed rise gravity" % id)
	return fails
