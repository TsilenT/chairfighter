extends Node
## Autoload name: AudioManager. Plays generated SFX by name via a small
## player pool. SFX WAVs live in assets/audio/sfx/<name>.wav; missing
## files fail silently so audio can land late without breaking gameplay.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	Events.sfx_requested.connect(play_sfx)


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
