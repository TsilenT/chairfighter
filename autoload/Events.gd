extends Node
## Global signal bus. Autoload name: Events.
## Everything cross-system flows through here; no direct node references
## between player, UI, bosses, and world systems.

@warning_ignore_start("unused_signal")

signal form_unlocked(form_id: StringName)
signal form_changed(form_id: StringName)
signal player_health_changed(current: int, maximum: int)
signal player_died
signal player_respawned
signal boss_started(boss_id: StringName, display_name: String)
signal boss_health_changed(boss_id: StringName, current: float, maximum: float)
signal boss_defeated(boss_id: StringName)
signal zone_change_requested(zone_path: String, spawn_name: String)
signal zone_loaded(zone_name: String)
signal checkpoint_activated(zone_path: String, spawn_name: String)
signal game_won
signal hitstop_requested(duration: float)
signal screenshake_requested(strength: float, duration: float)
signal sfx_requested(sfx_name: StringName)
signal unlock_banner_requested(form_id: StringName, display_name: String, blurb: String)
