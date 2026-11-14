extends Node
## Plays area and encounter scores, and keeps feedback cues legible in busy fights.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 8
const MUSIC_FADE_SECONDS := 0.8
const MUSIC_DUCK_DB := -7.0
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

const TRACK_GAIN_DB := {
	&"lounge": 2.0,
	&"office": 2.0,
	&"storage": 2.5,
	&"boiler": 1.5,
	&"night_bar": 1.5,
	&"nursery": 1.0,
	&"conservatory": 2.5,
	&"boss": 1.0,
	&"king": 3.0,
	&"boiler_boss": 3.5,
	&"bar_boss": 3.5,
	&"nursery_boss": 3.0,
	&"conservatory_boss": 4.5,
}
const ZONE_MUSIC := {
	"The Workshop": &"workshop",
	"The Lounge": &"lounge",
	"The Office Complex": &"office",
	"The Storage Closet": &"storage",
	"The Parlor": &"parlor",
	"The Boiler Room": &"boiler",
	"The Night Bar": &"night_bar",
	"The Nursery": &"nursery",
	"The Conservatory": &"conservatory",
	"The Throne Room": &"throne",
}

const BOSS_MUSIC := {
	&"boiler": &"boiler_boss",
	&"bartender": &"bar_boss",
	&"nanny": &"nursery_boss",
	&"bouncer": &"conservatory_boss",
	&"king": &"king",
}

const AMBIENT_CUES := [&"jump", &"land", &"attack", &"transform", &"fold", &"lob"]
const IMPORTANT_CUES := [
	&"telegraph", &"counter", &"hurt", &"locked", &"gate_open", &"checkpoint",
	&"boss_start", &"boss_rage", &"boss_down", &"unlock", &"death",
]
const DUCK_CUES := [&"boss_start", &"boss_down", &"unlock", &"death"]
const PITCH_VARIATION_CUES := [&"jump", &"land", &"attack", &"hit", &"break", &"boss_hit"]
const RETRIGGER_MS := {
	&"hit": 65,
	&"boss_hit": 85,
	&"land": 100,
	&"telegraph": 90,
	&"locked": 160,
}
const CUE_GAIN_DB := {
	&"attack": -5.0,
	&"jump": -5.0,
	&"land": -9.0,
	&"transform": -4.0,
	&"fold": -3.0,
	&"telegraph": 3.0,
	&"unlock": 2.0,
}

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_fade: Tween
var _music_duck: Tween
var _music_bus_index := -1
var _music_bus_volume := 0.0
var _music_duck_until_ms := 0
var _zone_track: StringName = &"title"
var _victory := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus_index = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_bus_index >= 0:
		_music_bus_volume = AudioServer.get_bus_volume_db(_music_bus_index)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for player in [_music_a, _music_b]:
		player.bus = MUSIC_BUS
		player.volume_db = -80.0
		add_child(player)
	Events.sfx_requested.connect(play_sfx)
	Events.zone_loaded.connect(_on_zone_loaded)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.player_died.connect(_play_zone_music)
	Events.game_won.connect(_on_game_won)
	return_to_title()


func return_to_title() -> void:
	_victory = false
	_zone_track = &"title"
	play_music(_zone_track)


func _on_zone_loaded(zone_name: String) -> void:
	_zone_track = ZONE_MUSIC.get(zone_name, &"workshop")
	_play_zone_music()


func _on_boss_started(boss_id: StringName, _display_name: String) -> void:
	if not _victory:
		play_music(BOSS_MUSIC.get(boss_id, &"boss"))


func _on_boss_defeated(boss_id: StringName) -> void:
	# The King has a short defeat sequence before the credits signal.
	if boss_id != &"king":
		_play_zone_music()


func _play_zone_music() -> void:
	if not _victory:
		play_music(_zone_track)


func _on_game_won() -> void:
	_victory = true
	play_music(&"victory")


func play_music(track: StringName) -> void:
	var path := MUSIC_DIR + String(track) + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null or (_music_a.stream == stream and _music_a.playing):
		return
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()

	# Reverse the crossfade when returning to the previous score mid-transition.
	# For a third score, replace the quieter voice and keep the louder one fading.
	if _music_b.stream != stream or not _music_b.playing:
		if _music_a.volume_db < _music_b.volume_db:
			_swap_music_players()
		_music_b.stream = stream
		_music_b.volume_db = -80.0
		_music_b.play()
	_swap_music_players()
	_music_fade = create_tween().set_parallel().set_ignore_time_scale()
	var gain := db_to_linear(TRACK_GAIN_DB.get(track, 0.0))
	_music_fade.tween_property(_music_a, "volume_linear", gain, MUSIC_FADE_SECONDS)
	_music_fade.tween_property(_music_b, "volume_linear", db_to_linear(-80.0), MUSIC_FADE_SECONDS)
	_music_fade.chain().tween_callback(_music_b.stop)


func _swap_music_players() -> void:
	var previous := _music_a
	_music_a = _music_b
	_music_b = previous


func play_sfx(cue: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -1000)) < int(RETRIGGER_MS.get(cue, 0)):
		return
	var stream := _get_stream(cue)
	if stream == null:
		return
	var priority := 1
	if cue in IMPORTANT_CUES:
		priority = 2
	elif cue in AMBIENT_CUES:
		priority = 0
	var player := _pick_sfx_player(priority)
	if player == null:
		return
	_last_played[cue] = now
	player.set_meta("cue_priority", priority)
	player.set_meta("cue_started", now)
	player.stream = stream
	player.volume_db = CUE_GAIN_DB.get(cue, 0.0)
	# Audio variants must not touch the gameplay random number generator.
	player.pitch_scale = [0.96, 1.0, 1.04][now % 3] if cue in PITCH_VARIATION_CUES else 1.0
	player.play()
	if cue in DUCK_CUES:
		_duck_music(stream.get_length())


func _pick_sfx_player(priority: int) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	var oldest_priority := priority
	var oldest_start := Time.get_ticks_msec() + 1
	for player in _pool:
		if not player.playing:
			return player
		var player_priority := int(player.get_meta("cue_priority"))
		var player_start := int(player.get_meta("cue_started"))
		if player_priority < oldest_priority or (
				player_priority == oldest_priority and player_start < oldest_start):
			oldest = player
			oldest_priority = player_priority
			oldest_start = player_start
	return oldest


func _duck_music(duration: float) -> void:
	if _music_bus_index < 0:
		return
	var now := Time.get_ticks_msec()
	_music_duck_until_ms = maxi(_music_duck_until_ms, now + roundi(duration * 1000.0))
	if _music_duck != null and _music_duck.is_valid():
		_music_duck.kill()
	_music_duck = create_tween().set_ignore_time_scale()
	_music_duck.tween_method(_set_music_bus_volume, AudioServer.get_bus_volume_db(_music_bus_index),
		_music_bus_volume + MUSIC_DUCK_DB, 0.06)
	_music_duck.tween_interval(maxf((_music_duck_until_ms - now) / 1000.0 - 0.2, 0.08))
	_music_duck.tween_method(_set_music_bus_volume, _music_bus_volume + MUSIC_DUCK_DB,
		_music_bus_volume, 0.35)


func _set_music_bus_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(_music_bus_index, volume)


func _get_stream(cue: StringName) -> AudioStream:
	if not _cache.has(cue):
		var path := SFX_DIR + String(cue) + ".wav"
		_cache[cue] = ResourceLoader.load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[cue]
