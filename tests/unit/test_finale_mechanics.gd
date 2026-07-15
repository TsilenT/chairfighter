extends RefCounted
## Contract test for the finale's load-bearing promise: all eight earned
## specials gate the pre-boss checkpoint, then the King requires the two
## clearly telegraphed switch responses requested by the encounter design.


func run(_tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var packed: PackedScene = load("res://scenes/zones/ThroneRoom.tscn")
	if packed == null:
		return ["ThroneRoom failed to load"]
	var zone := packed.instantiate()
	var trials_root := zone.get_node_or_null("RoyalTrials")
	if trials_root == null:
		zone.free()
		return ["ThroneRoom has no RoyalTrials"]
	var seen: Array[StringName] = []
	var stacked_escape_height := Player.ROCK_LAUNCH_HEIGHT + Player.POGO_HEIGHT + Player.STAND_HEIGHT
	for node in trials_root.get_children():
		var trial := node as RoyalTrialGate
		if trial == null:
			fails.append("RoyalTrials/%s is not a RoyalTrialGate" % node.name)
			continue
		seen.append(trial.required_form)
		if trial.required_mechanic == &"":
			fails.append("%s has no required mechanic" % trial.name)
		if trial.size.y <= stacked_escape_height:
			fails.append("%s is short enough to bypass with launch + pogo" % trial.name)
		if not trial.accepts(trial.required_form, trial.required_mechanic):
			fails.append("%s rejects its configured special" % trial.name)
	if seen != GameState.REQUIRED_FINAL_FORMS:
		fails.append("royal trial order %s != required final forms %s" % [
			seen, GameState.REQUIRED_FINAL_FORMS])
	if trials_root.get_child_count() != 8:
		fails.append("Hall of Eight contains %d trials" % trials_root.get_child_count())
	var throne_speed_gate := zone.get_node_or_null("Hazards/ThroneSpeedGate") as SpeedGate
	if throne_speed_gate == null \
			or 400.0 - throne_speed_gate.position.y <= stacked_escape_height \
			or not is_equal_approx(throne_speed_gate.position.y + throne_speed_gate.size.y, 400.0):
		fails.append("Throne dash gate is bypassable with launch + pogo")

	var checkpoint := zone.get_node_or_null("Hazards/PreBossCheckpoint") as Node2D
	var last_trial := trials_root.get_child(trials_root.get_child_count() - 1) as Node2D
	if checkpoint == null or last_trial == null or checkpoint.position.x <= last_trial.position.x:
		fails.append("pre-boss checkpoint must sit after every royal trial")

	var king := zone.get_node_or_null("Boss/UpholsteredKing")
	if king == null:
		fails.append("ThroneRoom has no Upholstered King")
	elif not king.has_method("opening_edict_forms"):
		fails.append("King exposes no opening-edict contract")
	elif king.opening_edict_forms() != [&"armchair", &"folding"]:
		fails.append("King must open with grapple then fold responses")
	else:
		# The automation hook deliberately stays closed during the cue. It opens
		# only once _run_edict has spawned the relevant live hazard.
		king._edict_form = &"armchair"
		king._edict_window_active = true
		king._edict_can_counter = false
		if king.announced_edict_form() != &"armchair":
			fails.append("King cue does not expose the form early enough to prepare")
		if king.current_edict_form() != &"":
			fails.append("King accepts an edict response before its hazard is live")
		king._edict_can_counter = true
		if king.current_edict_form() != &"armchair":
			fails.append("King does not expose the counter once its hazard is live")
		king._clear_edict()
	if zone.get_node_or_null("Props/ArenaGrappleHookWest") == null \
			or zone.get_node_or_null("Props/ArenaGrappleHookEast") == null:
		fails.append("grapple edict needs forgiving hooks on both arena sides")
	zone.free()
	return fails
