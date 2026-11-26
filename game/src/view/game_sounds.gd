class_name GameSounds
extends Node3D
## Sound effects (P1-29): audio buses, a pool of 3D players for battle sounds
## and one 2D player for the interface. Driven by sim events through
## GameView.play_events(); view only.
##
## Buses: Master, Music, SFX, UI, Voice (volumes from GameSettings). Each
## sound plays at most once per MIN_GAP_MS, so 300 rifles firing together
## don't turn into noise or run out of players.

const BUSES: Array[String] = ["Music", "SFX", "UI", "Voice"]
const POOL: int = 24
const MIN_GAP_MS: int = 60
const SFX_DIR: String = "res://assets/audio/sfx/"
## Weapon sound by projectile, then by damage type.
const BY_PROJECTILE: Dictionary = {"ballistic": "artillery", "guided": "missile"}
const BY_DAMAGE: Dictionary = {
	"small_arms": "rifle", "autocannon": "autocannon", "anti_tank": "cannon",
	"high_explosive": "artillery", "anti_air": "missile", "counter_drone": "laser",
	"thermobaric": "artillery",
}

var _streams: Dictionary[String, AudioStream] = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _ui: AudioStreamPlayer
var _last_ms: Dictionary[String, int] = {}
var played: int = 0          ## sounds started (for tests)


## Creates the game's audio buses once (safe to call again).
static func ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")


func _ready() -> void:
	name = "GameSounds"
	_build()


## Creates the players once (lazily too, so it also works before _ready).
func _build() -> void:
	if not _players.is_empty():
		return
	ensure_buses()
	for i: int in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 25.0
		p.max_distance = 220.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players.append(p)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "UI"
	add_child(_ui)


## Plays a named battle sound at a world position. Returns false if it was
## skipped (unknown sound, or the same sound played a moment ago).
func play_at(sound: String, at: Vector3, now_ms: int = -1) -> bool:
	var stream: AudioStream = _stream(sound)
	if stream == null or not _ready_to_play(sound, now_ms):
		return false
	_build()
	var p: AudioStreamPlayer3D = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.position = at
	if p.is_inside_tree():
		p.play()
	played += 1
	return true


## Plays an interface sound (not positioned).
func play_ui(sound: String, now_ms: int = -1) -> bool:
	var stream: AudioStream = _stream(sound)
	if stream == null or not _ready_to_play(sound, now_ms):
		return false
	_build()
	_ui.stream = stream
	if _ui.is_inside_tree():
		_ui.play()
	played += 1
	return true


static func weapon_sound(weapon: WeaponDef) -> String:
	if weapon == null:
		return "rifle"
	if BY_PROJECTILE.has(weapon.projectile):
		return BY_PROJECTILE[weapon.projectile]
	return BY_DAMAGE.get(weapon.damage_type, "rifle")


func _ready_to_play(sound: String, now_ms: int) -> bool:
	var now: int = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	if now - _last_ms.get(sound, -100000) < MIN_GAP_MS:
		return false
	_last_ms[sound] = now
	return true


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path: String = SFX_DIR + sound + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sound] = stream
	return stream
