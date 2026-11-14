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
	var workshop: Node = load(gs.START_ZONE).instantiate()
	var door_by_zone := {}
	for node in workshop.get_node("Doors").get_children():
		var door := node as Door
		if door != null:
			door_by_zone[door.target_zone_path.get_file().get_basename()] = door
	for index in gs.CAMPAIGN.size():
		var floor: Dictionary = gs.CAMPAIGN[index]
		var id: StringName = floor["form"]
		var flag := "boss_%s_defeated" % floor["boss"]
		if flag != gs.FINAL_GUARDIAN_FLAGS[index] or id in authored_rewards:
			fails.append("each floor needs its own guardian and form")
		authored_rewards.append(id)
		var door: Door = door_by_zone.get(floor["zone"])
		if door == null or not door.grounded_entry:
			fails.append("%s needs its own physical doorway" % floor["title"])
	if authored_rewards != gs.REQUIRED_FINAL_FORMS:
		fails.append("the eight floor rewards should match final/cycling order")
	var throne_door := workshop.get_node("Doors/ThroneDoor") as Door
	if throne_door.is_open():
		fails.append("the Throne should be locked until all eight guardians are defeated")

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

	# Victories award forms. Mechanical latches are separate world state.
	gs.new_game()
	unlocked.clear()
	events.form_unlocked.connect(cb)
	for index in gs.CAMPAIGN.size():
		var floor: Dictionary = gs.CAMPAIGN[index]
		var id: StringName = floor["form"]
		gs.defeat_boss(floor["boss"])
		gs.defeat_boss(floor["boss"])
		if unlocked.size() != index + 1 or unlocked.back() != id or gs.current_form != id:
			fails.append("%s must award only %s once" % [floor["boss"], id])
		if gs.next_floor_index() != index + 1:
			fails.append("next floor did not advance after %s" % floor["boss"])
		if index == 0:
			gs.new_game()
			if not gs.load_game() or not gs.is_unlocked(&"armchair") or gs.is_unlocked(&"recliner"):
				fails.append("continuing immediately after the Baron should restore only Armchair")
	events.form_unlocked.disconnect(cb)
	if gs.unlocked_forms.size() != 9 or not gs.has_all_final_forms() or not gs.has_defeated_all_guardians():
		fails.append("eight guardians should yield eight unique forms and final access")
	if not throne_door.is_open():
		fails.append("the Throne should open after the eighth guardian")
	for zone: String in ["OfficeComplex", "StorageCloset", "Parlor"]:
		var door: Door = door_by_zone[zone]
		if door.is_open() or door.required_flag.is_empty():
			fails.append("%s should remain latched after all bosses" % zone)
		gs.set_flag(door.required_flag)
		if not door.is_open():
			fails.append("%s did not open when its mechanism released" % zone)
	workshop.free()
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
	if not gs.is_unlocked(&"armchair") or gs.is_unlocked(&"recliner") \
			or not gs.has_flag("boss_recliner_defeated") \
			or gs.checkpoint_spawn != "PreBoss":
		fails.append("load_game should restore the single reward, flag and checkpoint")

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
	for flag: String in gs.LEGACY_REWARDS:
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
		legacy_file.close()
		gs.new_game()
		if not gs.load_game():
			fails.append("complete version-1 Throne fixture should load")
		elif gs.checkpoint_zone != gs.START_ZONE or gs.checkpoint_spawn != gs.START_SPAWN:
			fails.append("version-1 PreBoss checkpoint should relocate before the Hall of Eight")
		elif gs.unlocked_forms.size() != 9 or gs.has_defeated_all_guardians():
			fails.append("legacy forms should survive without granting new victories")
		legacy_data["version"] = 2
		legacy_data["checkpoint_zone"] = "res://scenes/zones/Parlor.tscn"
		legacy_file = FileAccess.open(gs._save_path(), FileAccess.WRITE)
		if legacy_file != null:
			legacy_file.store_string(JSON.stringify(legacy_data))
			legacy_file.close()
			gs.new_game()
			if not gs.load_game() or gs.checkpoint_zone != gs.START_ZONE or gs.next_floor_index() != 1:
				fails.append("legacy later-floor checkpoint should resume before the first new guardian")

	# A version-2 save could already be past the newly installed Workshop
	# hatch. Continuing there must leave a way out of the basement.
	for zone_path: String in [gs.FINAL_ZONE, gs.START_ZONE]:
		gs.new_game()
		for flag: String in gs.FINAL_GUARDIAN_FLAGS:
			gs.flags[flag] = true
		var spawn := "Default" if zone_path == gs.FINAL_ZONE else "FromThrone"
		gs.set_checkpoint(zone_path, spawn)
		gs.new_game()
		if not gs.load_game() or gs.checkpoint_zone != zone_path or gs.checkpoint_spawn != spawn \
				or not gs.has_flag("workshop_throne_hatch_broken"):
			fails.append("save past the Workshop hatch must restore its return path")

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
