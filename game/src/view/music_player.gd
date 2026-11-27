class_name MusicPlayer
extends AudioStreamPlayer
## Plays the music track on the Music bus, looping, with a short fade-in
## (P2-18). The track is made by tools/gen_music.py. View only.

const TRACK: String = "res://assets/audio/music/main_theme.ogg"
const FADE_S: float = 2.5
const LEVEL_DB: float = -6.0   ## sits under the effects


func _init() -> void:
	name = "Music"
	GameSounds.ensure_buses()
	bus = "Music"
	var track: AudioStreamOggVorbis = load(TRACK) as AudioStreamOggVorbis
	if track == null:
		push_warning("MusicPlayer: %s is missing (run tools/gen_music.py)" % TRACK)
		return
	track.loop = true
	stream = track


func _ready() -> void:
	if stream == null:
		return
	volume_db = -40.0
	play()
	create_tween().tween_property(self, "volume_db", LEVEL_DB, FADE_S)
