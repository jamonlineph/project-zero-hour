extends TestCase
# Audio (P1-29, P2-18): buses, weapon sound choice, rate limiting, volume
# settings, alerts and music.


func test_buses_exist_after_setup() -> void:
	GameSounds.ensure_buses()
	GameSounds.ensure_buses()   # twice is fine
	for bus: String in ["Master", "Music", "SFX", "UI", "Voice"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "missing bus " + bus)
	var count: int = 0
	for i: int in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == "SFX":
			count += 1
	assert_eq(count, 1)


func test_volume_setting_changes_the_bus() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := GameSettings.new()
	s.volumes["SFX"] = 0.5
	s.apply(tree)
	var db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	assert_true(absf(db - linear_to_db(0.5)) < 0.01, "SFX at %f dB" % db)
	s.volumes["SFX"] = 0.0
	s.apply(tree)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	GameSettings.new().apply(tree)


func test_weapon_sounds_follow_the_weapon() -> void:
	var db := ContentDb.new()
	assert_true(db.load_all())
	assert_eq(GameSounds.weapon_sound(db.get_weapon("tank_cannon_120")), "cannon")
	assert_eq(GameSounds.weapon_sound(db.get_weapon("us_rocket_pod")), "missile")   # guided rockets since P2-04
	assert_eq(GameSounds.weapon_sound(db.get_weapon("kp_howitzer_152")), "artillery")
	assert_eq(GameSounds.weapon_sound(db.get_weapon("us_at_missile")), "missile")
	assert_eq(GameSounds.weapon_sound(db.get_weapon("us_cuas_laser")), "laser")
	assert_eq(GameSounds.weapon_sound(null), "rifle")


func test_every_sound_file_exists() -> void:
	var names: Array = GameSounds.BY_DAMAGE.values() + GameSounds.BY_PROJECTILE.values()
	names.append_array(["explosion_small", "explosion_large", "ui_click", "build_complete", "aps_intercept",
		"power_alert", "strike_incoming", "upgrade_complete", "rank_up", "under_attack", "jam_static"])
	names.append_array(GameSounds.ACKS)
	for n: Variant in names:
		assert_true(ResourceLoader.exists(GameSounds.SFX_DIR + str(n) + ".wav"), "missing sound " + str(n))


func test_same_sound_is_rate_limited() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := GameSounds.new()
	tree.root.add_child(s)
	assert_true(s.play_at("rifle", Vector3.ZERO, 1000))
	assert_false(s.play_at("rifle", Vector3.ZERO, 1000 + GameSounds.MIN_GAP_MS - 1))
	assert_true(s.play_at("cannon", Vector3.ZERO, 1001))
	assert_true(s.play_at("rifle", Vector3.ZERO, 1000 + GameSounds.MIN_GAP_MS))
	assert_false(s.play_at("no_such_sound", Vector3.ZERO, 5000))
	assert_eq(s.played, 3)
	s.free()


func test_alerts_follow_events_and_have_longer_gaps() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := GameSounds.new()
	tree.root.add_child(s)
	var w := SimWorld.new(1, 64, 64)
	s.play_alert({"type": "rank_up", "player": 2, "rank": 2}, w, 1)
	assert_eq(s.played, 0, "another player's promotion played our fanfare")
	s.play_alert({"type": "rank_up", "player": 1, "rank": 2}, w, 1)
	assert_eq(s.played, 1)
	s.play_alert({"type": "strike_launched", "player": 1}, w, 1)
	assert_eq(s.played, 1, "our own strike played the incoming warning")
	s.play_alert({"type": "strike_launched", "player": 2}, w, 1)
	assert_eq(s.played, 2)
	# Losing units: one alarm, then quiet for the alert's gap.
	assert_true(s.play_ui("under_attack", 50000))
	assert_false(s.play_ui("under_attack", 50000 + GameSounds.MIN_GAP_MS * 10))
	assert_true(s.play_ui("under_attack", 50000 + int(GameSounds.GAPS_MS["under_attack"])))
	s.free()


func test_music_loads_and_loops() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var m := MusicPlayer.new()
	tree.root.add_child(m)
	assert_true(m.stream is AudioStreamOggVorbis, "the music track did not load")
	assert_true((m.stream as AudioStreamOggVorbis).loop, "the music does not loop")
	assert_eq(str(m.bus), "Music")
	assert_true(m.stream.get_length() > 60.0, "the track is shorter than a minute")
	m.free()
