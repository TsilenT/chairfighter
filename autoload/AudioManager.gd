extends Node
## Autoload name: AudioManager. Plays generated SFX by name via a small
## player pool. SFX WAVs live in assets/audio/sfx/<name>.wav; missing
## files fail silently so audio can land late without breaking gameplay.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 8
const MUSIC_DB := -13.0
const SFX_DB := -4.0

## zone display name → music track
const ZONE_MUSIC := {
	"The Workshop": &"workshop",
	"The Lounge": &"lounge",
	"The Office Complex": &"office",
	"The Storage Closet": &"storage",
	"The Throne Room": &"throne",
}

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: StringName = &""
var _zone_track: StringName = &"title"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = SFX_DB
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Master"
		m.volume_db = -60.0
		add_child(m)
	Events.sfx_requested.connect(play_sfx)
	Events.zone_loaded.connect(_on_zone_loaded)
	Events.boss_started.connect(func(_id: StringName, _n: String) -> void: play_music(&"boss"))
	Events.boss_defeated.connect(func(_id: StringName) -> void: play_music(_zone_track))
	Events.player_died.connect(func() -> void: play_music(_zone_track))
	Events.game_won.connect(func() -> void: play_music(&"victory"))
	play_music(&"title")


func _on_zone_loaded(zone_name: String) -> void:
	_zone_track = ZONE_MUSIC.get(zone_name, &"workshop")
	play_music(_zone_track)


func play_music(track: StringName) -> void:
	if _music_current == track:
		return
	var path := MUSIC_DIR + String(track) + ".wav"
	if not ResourceLoader.exists(path):
		return
	_music_current = track
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2  # 16-bit mono: samples = bytes/2
	# Crossfade: b becomes the new front player.
	var front := _music_b
	var back := _music_a
	_music_a = front
	_music_b = back
	front.stream = stream
	front.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(front, "volume_db", MUSIC_DB, 1.2)
	tween.tween_property(back, "volume_db", -60.0, 1.2)
	tween.chain().tween_callback(func() -> void:
		if back.volume_db <= -59.0:
			back.stop())


func play_sfx(sfx_name: StringName) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# All busy: steal the first player.
	_pool[0].stream = stream
	_pool[0].play()


func _get_stream(sfx_name: StringName) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var path := SFX_DIR + String(sfx_name) + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	_cache[sfx_name] = stream
	return stream
