extends Node3D
## The match scene: loads content, builds the SimWorld from the scenario the
## menu chose (MatchConfig.pending), or from --scenario=<id> on the command
## line, or the sandbox, and wires the runner, view, camera, input and HUD.

## Default scenario; override with: godot --path game -- --scenario=skirmish_vs_ai
const DEFAULT_SCENARIO: String = "sandbox"
const LOCAL_PLAYER: int = 1
const ENEMY_PLAYER: int = 2
const SEED: int = 20261125

var content: ContentDb
var map_def: MapDef
var scenario_id: String = DEFAULT_SCENARIO
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


func _ready() -> void:
	InputActions.register()
	content = ContentDb.new()
	if not content.load_all():
		for message: String in content.errors:
			push_error(message)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_id = arg.trim_prefix("--scenario=")
	var scenario: Dictionary = MatchConfig.pending if not MatchConfig.pending.is_empty() \
		else content.scenarios.get(scenario_id, {})
	MatchConfig.pending = {}
	scenario_id = str(scenario.get("id", scenario_id))
	world = MatchSetup.build_from(content, scenario, SEED) if not scenario.is_empty() else null
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
	runner.local_player_id = LOCAL_PLAYER
	runner.scenario_id = scenario_id
	runner.seed_value = SEED
	runner.process_priority = -10   # step the sim before the view reads it
	add_child(runner)
	runner.add_ai_from_scenario(content, scenario)
	runner.scenario_data = scenario
	runner.start()

	game_view = GameView.new()
	game_view.name = "GameView"
	game_view.setup(world, content)
	game_view.ground_height = terrain.height_at
	game_view.local_player_id = LOCAL_PLAYER
	add_child(game_view)
	game_view.sync(0.0)

	rts_camera = RtsCamera.new()
	rts_camera.name = "RtsCamera"
	add_child(rts_camera)
	rts_camera.set_bounds(Rect2(0, 0, map_def.width_m, map_def.height_m))
	rts_camera.ground_height = terrain.height_at
	rts_camera.focus_on(_start_focus())
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
	selection.setup(runner, game_view, rts_camera, hud.selection_box, LOCAL_PLAYER)
	selection.selection_changed.connect(hud.on_selection_changed)
	selection.selection_changed.connect(func(ids: Array[int]) -> void:
		if not ids.is_empty():
			game_view.sounds.play_ui("ack"))
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
	game_view.sync(runner.alpha)
	if world.game_over and not _game_over_shown:
		_game_over_shown = true
		var my_team: int = world.team_of(LOCAL_PLAYER)
		pause_menu.open_game_over("Draw" if world.winner_team == 0 else ("Victory" if world.winner_team == my_team else "Defeat"))
	game_view.play_events(runner.pending_events)
	runner.pending_events.clear()


## Where the camera starts: the local player's HQ (or first building or
## unit), else the map's first start position, else left of center.
func _start_focus() -> Vector3:
	var fallback: SimEntity = null
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id != LOCAL_PLAYER:
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
	fog.setup(world, LOCAL_PLAYER)
	add_child(fog)

	terrain = TerrainView.new()
	terrain.build(map_def, fog)
	add_child(terrain)
	var features := MapFeaturesView.new()
	features.build(map_def, fog, terrain.height_at)
	add_child(features)

	# Rocks are drawn from the map's obstacles, so what you see is what blocks
	# movement. Heights are view-only decoration, so ordinary random numbers are
	# fine here (never in the sim).
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var rock_mat: ShaderMaterial = fog.make_material(Color(0.45, 0.43, 0.40))
	for o: PackedInt32Array in map_def.obstacles_m:
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(o[2], rng.randf_range(1.5, 4.0), o[3])
		rock.mesh = box
		rock.material_override = rock_mat
		var cx: float = o[0] + o[2] * 0.5
		var cz: float = o[1] + o[3] * 0.5
		rock.position = Vector3(cx, map_def.height_at_m(cx, cz) + box.size.y * 0.5 - 0.3, cz)
		add_child(rock)
