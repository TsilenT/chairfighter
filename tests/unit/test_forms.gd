extends RefCounted
## Form resources: ids match GameState.FORM_ORDER and derived physics hit
## the design table (spec: docs/superpowers/specs/2026-07-13-*-design.md).

const FORM_DIR := "res://src/forms/"

# id: [run_speed, jump_height, rise_gravity, jump_velocity]
const DESIGN := {
	&"basic": [340.0, 150.0, 2077.56, -789.47],
	&"armchair": [300.0, 140.0, 1939.06, -736.84],
	&"recliner": [275.0, 125.0, 1562.5, -625.0],
	&"office": [380.0, 130.0, 2006.17, -722.22],
	&"barstool": [360.0, 145.0, 2237.65, -805.56],
	&"folding": [320.0, 140.0, 1939.06, -736.84],
	&"highchair": [290.0, 150.0, 1875.0, -750.0],
	&"rocking": [300.0, 135.0, 1869.81, -710.53],
	&"stool": [400.0, 165.0, 2410.52, -891.89],
}

const ATTACK_STYLES := {
	&"basic": &"body_bash",
	&"armchair": &"arm_punch",
	&"recliner": &"footrest_kick",
	&"office": &"swivel_ram",
	&"barstool": &"stool_spin",
	&"folding": &"hinge_snap",
	&"highchair": &"tray_shove",
	&"rocking": &"rocker_sweep",
	&"stool": &"leg_kick",
}


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	var seen_attack_styles: Dictionary = {}
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
		if id != &"basic" and form.unlock_blurb.is_empty():
			fails.append("%s: earned form needs a mechanic unlock blurb" % path)
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
		if form.attack_style != ATTACK_STYLES[id]:
			fails.append("%s: attack style %s != %s" % [id, form.attack_style, ATTACK_STYLES[id]])
		if seen_attack_styles.has(form.attack_style):
			fails.append("%s: attack style duplicates %s; each chair needs its own primary" % [id, form.attack_style])
		seen_attack_styles[form.attack_style] = true
		if form.attack_size.x <= 0.0 or form.attack_size.y <= 0.0:
			fails.append("%s: attack contact size must be positive" % id)
		if not form.attack_overlaps_body():
			fails.append("%s: primary starts beyond the chair body (close-range dead zone)" % id)
		if form.attack_front_reach() <= FormDef.BODY_HALF_WIDTH:
			fails.append("%s: primary never reaches beyond the chair body" % id)
	return fails
