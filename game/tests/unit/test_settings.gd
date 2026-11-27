extends TestCase
# Settings (P1-35): persistence, battery saver, key rebinding, live apply.

const SCRATCH: String = "user://test_settings_roundtrip.cfg"


func test_save_and_load_round_trip() -> void:
	var a := GameSettings.new()
	a.render_scale = 0.75
	a.fps_cap = 30
	a.shadows = false
	a.ui_scale = 1.3
	a.edge_pan = false
	a.battery_saver = true
	a.volumes["Music"] = 0.25
	a.rebind("cmd_stop", KEY_X)
	assert_eq(a.save_to(SCRATCH), OK)
	var b := GameSettings.new()
	b.load_from(SCRATCH)
	assert_eq(b.render_scale, 0.75)
	assert_eq(b.fps_cap, 30)
	assert_false(b.shadows)
	assert_eq(b.ui_scale, 1.3)
	assert_false(b.edge_pan)
	assert_true(b.battery_saver)
	assert_eq(b.volumes["Music"], 0.25)
	assert_eq(b.key_for("cmd_stop"), KEY_X)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func test_missing_file_keeps_defaults() -> void:
	var s := GameSettings.new()
	s.load_from("user://does_not_exist.cfg")
	assert_eq(s.fps_cap, 60)
	assert_eq(s.render_scale, 1.0)
	assert_true(s.bindings.is_empty())


func test_bad_values_are_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fps_cap", 144)
	cfg.set_value("video", "render_scale", 9.0)
	cfg.set_value("keys", "not_an_action", KEY_Q)
	cfg.save(SCRATCH)
	var s := GameSettings.new()
	s.load_from(SCRATCH)
	assert_eq(s.fps_cap, 60)
	assert_eq(s.render_scale, 1.0)
	assert_false(s.bindings.has("not_an_action"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func test_battery_saver_overrides_video() -> void:
	var s := GameSettings.new()
	s.fps_cap = 0
	s.render_scale = 1.0
	s.shadows = true
	s.battery_saver = true
	assert_eq(s.effective_fps(), GameSettings.SAVER_FPS)
	assert_eq(s.effective_render_scale(), GameSettings.SAVER_RENDER_SCALE)
	assert_false(s.effective_shadows())


func test_rebinding_swaps_a_key_already_in_use() -> void:
	var s := GameSettings.new()
	var hold_key: int = s.key_for("cmd_hold")
	var stop_key: int = s.key_for("cmd_stop")
	s.rebind("cmd_stop", hold_key)
	assert_eq(s.key_for("cmd_stop"), hold_key)
	assert_eq(s.key_for("cmd_hold"), stop_key)


func test_apply_changes_engine_and_input_map() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var old_fps: int = Engine.max_fps
	var old_scale: float = tree.root.scaling_3d_scale
	var s := GameSettings.new()
	s.fps_cap = 30
	s.render_scale = 0.5
	s.rebind("cmd_attack_move", KEY_K)
	s.apply(tree)
	assert_eq(Engine.max_fps, 30)
	assert_eq(tree.root.scaling_3d_scale, 0.5)
	var events: Array[InputEvent] = InputMap.action_get_events("cmd_attack_move")
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_K)
	# Put everything back for the other tests.
	GameSettings.new().apply(tree)
	Engine.max_fps = old_fps
	tree.root.scaling_3d_scale = old_scale


func test_quality_presets() -> void:
	var s := GameSettings.new()
	s.apply_preset("low")
	assert_eq(s.preset_name(), "low")
	assert_false(s.shadows)
	assert_eq(s.fps_cap, 30)
	s.apply_preset("high")
	assert_eq(s.preset_name(), "high")
	s.render_scale = 0.5
	assert_eq(s.preset_name(), "custom")


func test_low_end_detection() -> void:
	assert_true(GameSettings.is_low_end("gl_compatibility", 8 * 1024 * 1024 * 1024))
	assert_true(GameSettings.is_low_end("mobile", 3 * 1024 * 1024 * 1024))
	assert_false(GameSettings.is_low_end("mobile", 8 * 1024 * 1024 * 1024))
	assert_false(GameSettings.is_low_end("forward_plus", -1), "unknown memory is not low end")


func test_colorblind_colors_persist_and_change_the_palette() -> void:
	# P3-20: the setting saves, and applying it swaps the team palette.
	var path: String = "user://test_settings_colorblind.cfg"
	var s := GameSettings.new()
	s.colorblind_colors = true
	s.save_to(path)
	var loaded := GameSettings.new()
	loaded.load_from(path)
	assert_true(loaded.colorblind_colors)
	var tree := Engine.get_main_loop() as SceneTree
	var normal_red: Color = TeamColors.for_player(2)
	loaded.apply(tree)
	assert_true(TeamColors.colorblind)
	assert_ne(TeamColors.for_player(2), normal_red, "the palette did not change")
	assert_eq(TeamColors.for_player(2), TeamColors.COLORBLIND[2])
	GameSettings.new().apply(tree)
	assert_false(TeamColors.colorblind, "default settings did not restore the normal palette")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
