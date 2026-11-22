extends Node
## Autoload « Sfx » : effets sonores, musique en boucle, vibrations.
## Sons générés pour le prototype (assets/audio), remplaçables par de vrais sons plus tard.

const SOUNDS := {
	"click": preload("res://assets/audio/click.wav"),
	"shot": preload("res://assets/audio/shot.wav"),
	"cannon": preload("res://assets/audio/cannon.wav"),
	"missile": preload("res://assets/audio/missile.wav"),
	"explosion": preload("res://assets/audio/explosion.wav"),
	"built": preload("res://assets/audio/built.wav"),
	"error": preload("res://assets/audio/error.wav"),
	"wave": preload("res://assets/audio/wave.wav"),
	"orbital": preload("res://assets/audio/orbital.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
}
const MUSIC := preload("res://assets/audio/music.wav")

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var stream: AudioStreamWAV = MUSIC.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2 # 16 bits mono : 2 octets par échantillon
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	add_child(_music)
	_apply_volumes()
	Save.changed.connect(_apply_volumes)
	_music.play()


func play(name: String, volume_db := 0.0, min_gap := 0.05) -> void:
	if not SOUNDS.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < min_gap:
		return
	_last_played[name] = now
	var sfx: float = Save.setting("sfx")
	if sfx <= 0.01:
		return
	for p in _players:
		if not p.playing:
			p.stream = SOUNDS[name]
			p.volume_db = volume_db + linear_to_db(sfx)
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return


func vibrate(ms := 40) -> void:
	if Save.setting("vibration"):
		Input.vibrate_handheld(ms)


func _apply_volumes() -> void:
	var music: float = Save.setting("music")
	_music.volume_db = linear_to_db(maxf(music, 0.0001)) - 8.0
	_music.stream_paused = music <= 0.01
