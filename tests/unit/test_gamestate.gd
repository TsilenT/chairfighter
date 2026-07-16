extends RefCounted
## GameState progression behavior.


func run(tree: SceneTree) -> Array:
	var fails: Array[String] = []
	var gs := tree.root.get_node("/root/GameState")
	var events := tree.root.get_node("/root/Events")
	if gs._save_path() != gs.TEST_SAVE_PATH:
		fails.append("unit suite must never read or delete the real Continue save")

	gs.new_game()
	if gs.current_form != &"basic":
		fails.append("new_game should start as basic, got %s" % gs.current_form)
	if gs.unlocked_forms.size() != 1 or gs.unlocked_forms[0] != &"basic":
		fails.append("new_game should unlock only basic, got %s" % str(gs.unlocked_forms))
	if gs.FORM_ORDER.size() != 9 or gs.REQUIRED_FINAL_FORMS.size() != 8:
		fails.append("progression should contain basic + exactly 8 earned forms")
	var authored_rewards: Array[StringName] = []
	for flag: String in gs.FINAL_GUARDIAN_FLAGS:
		var pair: Array = gs.BOSS_FORM_REWARDS.get(flag, [])
		if pair.size() != 2:
			fails.append("%s should grant exactly two forms" % flag)
		for id: StringName in pair:
			if id not in gs.REQUIRED_FINAL_FORMS or id in authored_rewards:
				fails.append("guardian rewards should cover 8 unique final forms; bad id %s" % id)
			authored_rewards.append(id)
	if authored_rewards != gs.REQUIRED_FINAL_FORMS:
		fails.append("guardian reward order should match final/cycling order")
	var workshop: Node = load("res://scenes/zones/Workshop.tscn").instantiate()
	var throne_door := workshop.get_node("Doors/ThroneDoor") as Door
	if throne_door.required_flags != gs.FINAL_GUARDIAN_FLAGS:
		fails.append("Workshop Throne door should require all four guardian flags")
	var storage_speed_gate := workshop.get_node("Hazards/StorageSpeedGate") as SpeedGate
	var stacked_escape_height := 420.0 + Player.STAND_HEIGHT
	if 400.0 - storage_speed_gate.position.y <= stacked_escape_height \
			or not is_equal_approx(storage_speed_gate.position.y + storage_speed_gate.size.y, 400.0):
		fails.append("Workshop dash gate is bypassable with Stool jump + pogo")
	workshop.free()

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

	# Paired boss rewards arrive atomically and keep the canonical first form
	# active, while still announcing both for the queued unlock UI.
	gs.new_game()
	unlocked.clear()
	events.form_unlocked.connect(cb)
	var baron_pair: Array[StringName] = [&"armchair", &"recliner"]
	gs.unlock_forms(baron_pair)
	events.form_unlocked.disconnect(cb)
	if unlocked != baron_pair:
		fails.append("paired unlock should announce both in order, got %s" % str(unlocked))
	if gs.current_form != &"armchair" or not gs.is_unlocked(&"recliner"):
		fails.append("paired unlock should select armchair and also unlock recliner")
	if gs.has_all_final_forms():
		fails.append("one guardian pair must not satisfy final progression")
	for flag: String in gs.FINAL_GUARDIAN_FLAGS:
		var rewards: Array[StringName] = []
		for reward: StringName in gs.BOSS_FORM_REWARDS[flag]:
			rewards.append(reward)
		gs.unlock_forms(rewards)
		gs.set_flag(flag)
	if gs.unlocked_forms.size() != 9 or not gs.has_all_final_forms() \
			or not gs.has_defeated_all_guardians():
		fails.append("four guardian pairs should yield all 8 earned forms and final access")
	if gs.has_completed_final_trials():
		fails.append("unlocking forms must not counterfeit the Hall of Eight proofs")
	for id: StringName in gs.REQUIRED_FINAL_FORMS:
		gs.set_flag("final_trial_%s" % id)
	if not gs.has_completed_final_trials():
		fails.append("all eight trial flags should satisfy final trial progression")
	gs.clear_save()
	gs.new_game()

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

	# Save / load round-trip.
	gs.clear_save()
	gs.unlock_form(&"armchair")  # autosaves; also switches form first
	if gs.current_form != &"armchair":
		fails.append("unlock_form should switch before announcing")
	gs.set_flag("boss_recliner_defeated")  # set_flag autosaves durable state
	gs.set_checkpoint("res://scenes/zones/Lounge.tscn", "PreBoss")
	if not gs.has_save():
		fails.append("progression events should have autosaved")
	# new_game does NOT clear the save (accidental-new-game safety); it is
	# overwritten by the first checkpoint autosave, or explicitly cleared.
	gs.new_game()
	if not gs.has_save():
		fails.append("new_game should leave the existing save intact")
	# Restore from disk into wiped memory.
	gs.unlocked_forms.clear()
	gs.unlocked_forms.append(&"basic")
	gs.flags = {}
	gs.checkpoint_zone = gs.START_ZONE
	if not gs.load_game():
		fails.append("load_game should succeed with a save present")
	if not gs.is_unlocked(&"armchair") or not gs.is_unlocked(&"recliner") \
			or not gs.has_flag("boss_recliner_defeated") \
			or gs.checkpoint_spawn != "PreBoss":
		fails.append("load_game should restore unlocks, migrate boss rewards, flags, and checkpoint")

	# Legacy saves could be parked beyond the old three-form Throne entrance.
	# They must return to the hub until the newly-required fourth guardian falls.
	gs.clear_save()
	gs.new_game()
	gs.set_checkpoint(gs.FINAL_ZONE, "PreBoss")
	gs.unlocked_forms.clear()
	gs.unlocked_forms.append(&"basic")
	gs.flags = {}
	if not gs.load_game():
		fails.append("legacy Throne checkpoint fixture should load")
	elif gs.checkpoint_zone != gs.START_ZONE or gs.checkpoint_spawn != gs.START_SPAWN:
		fails.append("incomplete legacy Throne checkpoint should relocate to safe Workshop start")

	# Even a fully-complete version-1 route used the old PreBoss marker, which
	# now resolves after the Hall of Eight. Relocate it before companion-form
	# repair so an old save cannot wake up beyond the new trials.
	gs.clear_save()
	var legacy_flags := {}
	for flag: String in gs.FINAL_GUARDIAN_FLAGS:
		legacy_flags[flag] = true
	var legacy_data := {
		"version": 1,
		"unlocked_forms": ["basic", "armchair", "office", "folding", "rocking"],
		"current_form": "rocking",
		"flags": legacy_flags,
		"checkpoint_zone": gs.FINAL_ZONE,
		"checkpoint_spawn": "PreBoss",
	}
	var legacy_file := FileAccess.open(gs._save_path(), FileAccess.WRITE)
	if legacy_file == null:
		fails.append("could not create version-1 migration fixture")
	else:
		legacy_file.store_string(JSON.stringify(legacy_data))
		legacy_file = null
		gs.new_game()
		if not gs.load_game():
			fails.append("complete version-1 Throne fixture should load")
		elif gs.checkpoint_zone != gs.START_ZONE or gs.checkpoint_spawn != gs.START_SPAWN:
			fails.append("version-1 PreBoss checkpoint should relocate before the Hall of Eight")
		elif gs.unlocked_forms.size() != 9:
			fails.append("version-1 guardian flags should still repair all companion rewards")

	# The durable King flag closes the tiny save-before-ending crash window.
	gs.clear_save()
	gs.new_game()
	gs.set_flag("boss_king_defeated")
	var recovered_victory: Array[bool] = [false]
	var victory_cb := func() -> void: recovered_victory[0] = true
	events.game_won.connect(victory_cb)
	gs.new_game()
	if not gs.load_game():
		fails.append("saved King victory fixture should load")
	for _i in 2:
		await tree.process_frame
	if events.game_won.is_connected(victory_cb):
		events.game_won.disconnect(victory_cb)
	if not recovered_victory[0]:
		fails.append("loading boss_king_defeated should recover the ending")
	gs.new_game()
	# Explicit clear works.
	gs.clear_save()
	if gs.has_save():
		fails.append("clear_save should remove the save file")
	gs.new_game()
	gs.clear_save()
	return fails
