extends Node3D
## The match scene: loads content, builds the SimWorld from the scenario the
## menu chose (MatchConfig.pending), or from --scenario=<id> on the command
## line, or the sandbox, and wires the runner, view, camera, input and HUD.

## Default scenario; override with: godot --path game -- --scenario=skirmish_vs_ai
const DEFAULT_SCENARIO: String = "sandbox"
## The player on this machine: 1, or 2 when this machine joined a LAN game
## (P3-14a).
var local_player: int = 1
const ENEMY_PLAYER: int = 2
const SEED: int = 20261125   ## match seed; developer videos can pass --seed=<n>

var content: ContentDb
var map_def: MapDef
var scenario_id: String = DEFAULT_SCENARIO
var _gauntlet_step: int = -1   ## a Gauntlet match's step (P4-03), or -1
var world: SimWorld
var runner: SimRunner
var game_view: GameView
var rts_camera: RtsCamera
var hud: Hud
var selection: SelectionController
var placement: PlacementController
var pause_menu: PauseMenu
var fog: FogOfWar
var terrain: TerrainView
var pointer: PointerFeedback
var _game_over_shown: bool = false
var director: CameraDirector
## Loading a saved game (P3-22): fast-forwarding until done.
var loader: SaveLoader
var _loading_label: Label


func _ready() -> void:
	InputActions.register()
	UiTheme.apply(get_tree())
	add_child(MusicPlayer.new())
	content = ContentDb.new()
	if not content.load_all(ContentDb.INDEX_PATH, ModLoader.mod_dirs()):   # mods (P3-17)
		for message: String in content.errors:
			push_error(message)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_id = arg.trim_prefix("--scenario=")
	var scenario: Dictionary = MatchConfig.pending if not MatchConfig.pending.is_empty() \
		else content.scenarios.get(scenario_id, {})
	MatchConfig.pending = {}
	var save_data: Dictionary = MatchConfig.load_save
	MatchConfig.load_save = {}
	if not save_data.is_empty():
		scenario = save_data.get("scenario_data", {})
	scenario_id = str(scenario.get("id", scenario_id))
	_gauntlet_step = int(scenario.get("gauntlet_step", -1))
	var seed_value: int = int(DevCapture.arg("seed", str(SEED)))
	var net: NetSession = MatchConfig.net
	if net != null:
		local_player = net.local_player_id
		seed_value = MatchConfig.net_seed
	if not save_data.is_empty():
		seed_value = int(save_data.get("seed", seed_value))
	world = MatchSetup.build_from(content, scenario, seed_value) if not scenario.is_empty() else null
	if world == null:
		push_error("Sandbox: scenario '%s' failed to load; using an empty map" % scenario_id)
		world = SimWorld.new(SEED, 128, 128)
	map_def = content.get_map(str(scenario.get("map", "")))
	if map_def == null:
		map_def = MapDef.new()
		map_def.width_m = 128
		map_def.height_m = 128
	_build_environment()

	runner = SimRunner.new()
	runner.name = "SimRunner"
	runner.world = world
	runner.local_player_id = local_player
	runner.scenario_id = scenario_id
	runner.seed_value = seed_value
	runner.process_priority = -10   # step the sim before the view reads it
	add_child(runner)
	if net != null:
		# LAN (P3-14a): both humans must deliver every tick's batch.
		runner.players = [1, 2]
		runner.local_players = [local_player]
		net.attach(runner)
		net.desynced.connect(func(t: int, _m: int, _o: int) -> void:
			# NetSession kept the evidence (P3-14b): this machine's replay.
			hud.show_notice(Loc.t("Out of sync with the other player at tick %d. A replay was saved to %s: please send it with a bug report.") \
				% [t, ProjectSettings.globalize_path(net.last_desync_replay)], 15.0))
		net.peer_left.connect(func() -> void: hud.show_notice("The other player left the game.", 12.0))
	runner.add_ai_from_scenario(content, scenario)
	runner.scenario_data = scenario
	runner.start()
	if not save_data.is_empty():
		loader = SaveLoader.new()
		loader.begin(runner, save_data)
		runner.paused = true
	game_view = GameView.new()
	game_view.name = "GameView"
	game_view.setup(world, content)
	game_view.ground_height = terrain.height_at
	game_view.reveal_all = DevCapture.reveal_requested()
	game_view.local_player_id = local_player
	add_child(game_view)
	game_view.sync(0.0)

	rts_camera = RtsCamera.new()
	rts_camera.name = "RtsCamera"
	add_child(rts_camera)
	rts_camera.set_bounds(Rect2(0, 0, map_def.width_m, map_def.height_m))
	rts_camera.ground_height = terrain.height_at
	rts_camera.focus_on(_start_focus())
	# Developer screenshots: --select=<def_id> selects the local player's units
	# or buildings of that type, so the command grid shows their buttons.
	var select_def: String = DevCapture.arg("select")
	if select_def != "":
		_select_on_start.call_deferred(select_def)
	# --open=pause|settings|commander opens that screen (UI screenshots).
	match DevCapture.arg("open"):
		"pause":
			(func() -> void: pause_menu.open_paused()).call_deferred()   # pause_menu is made later in _ready
		"settings":
			(func() -> void: pause_menu.open_paused(); pause_menu.open_settings()).call_deferred()
		"commander":
			(func() -> void: if hud.power_bar != null: hud.power_bar.open_commander()).call_deferred()
	var cam: Variant = DevCapture.camera_override()
	if cam != null:
		rts_camera.focus_on(Vector3(cam.x, 0.0, cam.y))
		rts_camera.distance = cam.z
		rts_camera.zoom_by(1.0)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(runner)

	selection = SelectionController.new()
	selection.name = "SelectionController"
	selection.setup(runner, game_view, rts_camera, hud.selection_box, local_player)
	selection.selection_changed.connect(hud.on_selection_changed)
	selection.selection_changed.connect(func(ids: Array[int]) -> void:
		if not ids.is_empty():
			game_view.sounds.play_ack())
	hud.command_grid.activated.connect(func(_slot: int) -> void: game_view.sounds.play_ui("ui_click"))
	add_child(selection)

	placement = PlacementController.new()
	placement.name = "Placement"
	add_child(placement)
	placement.setup(runner, rts_camera, selection)
	selection.placement = placement
	selection.hotkey_handler = hud.command_grid.handle_key
	hud.bind_controls(selection, rts_camera, placement)

	pointer = PointerFeedback.new()
	pointer.setup(selection)
	add_child(pointer)

	GameSettings.current().apply(get_tree())
	DevCapture.attach_if_requested(self)
	_attach_director()

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.setup(runner)
	hud.add_child(pause_menu)
	hud.menu_requested.connect(pause_menu.toggle)


## F9 saves the match so far as a replay in user://replays/.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		hud.toggle_help()
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE and not placement.active:
		pause_menu.toggle()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9:
		var path: String = "user://replays/replay_%d.json" % Time.get_unix_time_from_system()
		var err: Error = runner.make_replay().save(path)
		print("Replay saved to %s (%s)" % [ProjectSettings.globalize_path(path), error_string(err)])


func _process(_delta: float) -> void:
	if loader != null:
		_continue_loading()
		return
	game_view.sync(runner.alpha)
	if world.game_over and not _game_over_shown:
		_game_over_shown = true
		var my_team: int = world.team_of(local_player)
		var won: bool = world.winner_team != 0 and world.winner_team == my_team
		pause_menu.open_game_over("Draw" if world.winner_team == 0 else ("Victory" if won else "Defeat"))
		if won and _gauntlet_step >= 0:
			Gauntlet.record_win(_gauntlet_step)   # the next commander unlocks (P4-03)
	game_view.play_events(runner.pending_events)
	_shake_for(runner.pending_events)
	if director != null:
		director.observe(runner.pending_events)
	runner.pending_events.clear()


## Big blasts near the view shake the camera (P3-20 setting): a building
## destroyed, or a hit with a wide splash (strikes, superweapons).
func _shake_for(events: Array[Dictionary]) -> void:
	var focus := Vector2(rts_camera.position.x, rts_camera.position.z)
	for ev: Dictionary in events:
		var strength: float = 0.0
		if ev["type"] == "died" and content.get_building(str(ev.get("def_id", ""))) != null:
			strength = 0.5
		elif ev["type"] == "hit" and int(ev.get("radius", 0)) >= Fx.from_int(8):
			strength = 0.35
		if strength > 0.0 and focus.distance_to(Vector2(Fx.to_float(ev["x"]), Fx.to_float(ev["y"]))) < 70.0:
			rts_camera.shake(strength)


func _select_on_start(def_id: String) -> void:
	var ids: Array[int] = []
	for id: int in world.entity_ids:
		if world.entities[id].player_id == local_player and world.entities[id].def_id == def_id:
			ids.append(id)
	selection.select_ids(ids)


## Gameplay-video tools (--director, --speed=, --shot-dir=, --shot-every=).
func _attach_director() -> void:
	if not OS.get_cmdline_user_args().has("--director"):
		return
	Engine.time_scale = clampf(float(DevCapture.arg("speed", "1")), 0.25, 8.0)
	hud.toggle_help()
	director = CameraDirector.new()
	director.shot_dir = DevCapture.arg("shot-dir")
	director.shot_every_s = float(DevCapture.arg("shot-every", "10"))
	director.setup(world, content, rts_camera)
	add_child(director)


## Fast-forwards a loaded save a chunk per frame behind a progress label.
func _continue_loading() -> void:
	if _loading_label == null:
		_loading_label = Label.new()
		_loading_label.name = "Loading"
		_loading_label.add_theme_font_size_override("font_size", 32)
		_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		hud.add_child(_loading_label)
	if not loader.advance(450):
		_loading_label.text = Loc.t("Loading saved game… %d%%") % int(loader.progress() * 100.0)
		return
	var ok: bool = loader.matches()
	loader = null
	_loading_label.queue_free()
	runner.pending_events.clear()   # don't replay the whole match's sounds
	runner.paused = false
	game_view.sync(0.0)
	rts_camera.focus_on(_start_focus())
	if not ok:
		push_warning("Loaded save differs from when it was saved (the game's data changed since).")
		hud.show_notice("This save was made with a different game version; it may play out differently.")


## Where the camera starts: the local player's HQ (or first building or
## unit), else the map's first start position, else left of center.
func _start_focus() -> Vector3:
	var fallback: SimEntity = null
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id != local_player:
			continue
		if e.def_id.ends_with("_command_hq"):
			return Vector3(Fx.to_float(e.x), 0.0, Fx.to_float(e.y))
		if fallback == null or (e.building != null and fallback.building == null):
			fallback = e
	if fallback != null:
		return Vector3(Fx.to_float(fallback.x), 0.0, Fx.to_float(fallback.y))
	if not map_def.start_positions.is_empty():
		var p: Vector2i = map_def.start_positions[0]
		return Vector3(p.x, 0.0, p.y)
	return Vector3(map_def.width_m * 0.35, 0.0, map_def.height_m * 0.5)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Checked on a real render: full sky ambient plus the sun washed every
	# color out to near white. Less ambient keeps the muted palette readable.
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 0.9
	sun.add_to_group("shadow_lights")   # GameSettings turns shadows on and off
	add_child(sun)

	# Terrain materials darken under the local player's fog of war (P1-27).
	fog = FogOfWar.new()
	fog.reveal_all = DevCapture.reveal_requested()
	fog.setup(world, local_player)
	add_child(fog)

	terrain = TerrainView.new()
	terrain.build(map_def, fog)
	add_child(terrain)
	HouseModel.biome = map_def.biome
	var features := MapFeaturesView.new()
	features.build(map_def, fog, terrain.height_at)
	add_child(features)

