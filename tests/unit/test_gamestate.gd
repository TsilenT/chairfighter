extends RefCounted
## GameState progression behavior.


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	var events := tree.root.get_node("/root/Events")

	gs.new_game()
	if gs.current_form != &"basic":
		fails.append("new_game should start as basic, got %s" % gs.current_form)
	if gs.unlocked_forms.size() != 1 or gs.unlocked_forms[0] != &"basic":
		fails.append("new_game should unlock only basic, got %s" % str(gs.unlocked_forms))

	# Locked form cannot be selected.
	if gs.set_form(&"office"):
		fails.append("set_form on locked form should return false")

	# Unlock emits and auto-switches.
	var unlocked: Array = []
	var cb := func(id: StringName) -> void: unlocked.append(id)
	events.form_unlocked.connect(cb)
	gs.unlock_form(&"armchair")
	events.form_unlocked.disconnect(cb)
	if unlocked != [&"armchair"]:
		fails.append("unlock_form should emit form_unlocked once, got %s" % str(unlocked))
	if gs.current_form != &"armchair":
		fails.append("unlock_form should auto-switch, current is %s" % gs.current_form)

	# Duplicate unlock is a no-op.
	gs.unlock_form(&"armchair")
	if gs.unlocked_forms.count(&"armchair") != 1:
		fails.append("duplicate unlock should not duplicate entry")

	# Cycling skips locked forms.
	gs.cycle_form(1)
	if gs.current_form != &"basic":
		fails.append("cycle from armchair with [basic, armchair] should wrap to basic, got %s" % gs.current_form)
	gs.cycle_form(-1)
	if gs.current_form != &"armchair":
		fails.append("cycle back should reach armchair, got %s" % gs.current_form)

	# Flags and checkpoint.
	if gs.has_flag("boss_recliner_defeated"):
		fails.append("flag should start unset")
	gs.set_flag("boss_recliner_defeated")
	if not gs.has_flag("boss_recliner_defeated"):
		fails.append("flag should be set")
	gs.set_checkpoint("res://scenes/zones/Lounge.tscn", "PreBoss")
	if gs.checkpoint_zone != "res://scenes/zones/Lounge.tscn" or gs.checkpoint_spawn != "PreBoss":
		fails.append("checkpoint not stored")

	gs.new_game()
	if gs.has_flag("boss_recliner_defeated") or gs.unlocked_forms.size() != 1:
		fails.append("new_game should clear flags and unlocks")
	return fails
