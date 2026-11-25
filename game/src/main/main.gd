extends Node3D
## Development sandbox: loads content, creates a SimWorld, spawns a few units
## per side, and wires the runner, view, camera, input and HUD together.
## P1-32 replaces this with a real menu and match setup (tasks/BACKLOG.md).

const MAP_ID: String = "sandbox"
const LOCAL_PLAYER: int = 1
const ENEMY_PLAYER: int = 2
const SEED: int = 20261125

var content: ContentDb
var map_def: MapDef
var world: SimWorld
var runner: SimRunner
var game_view: GameView
var rts_camera: RtsCamera
var hud: Hud
var selection: SelectionController


func _ready() -> void:
	InputActions.register()
	content = ContentDb.new()
	if not content.load_all():
		for message: String in content.errors:
			push_error(message)
	map_def = content.get_map(MAP_ID)
	if map_def == null:
		push_error("Sandbox: map '%s' is missing; using an empty 128 m map" % MAP_ID)
		map_def = MapDef.new()
		map_def.id = MAP_ID
		map_def.width_m = 128
		map_def.height_m = 128
	world = SimWorld.from_map(SEED, map_def)
	_spawn_sandbox_units()
	_build_environment()

	runner = SimRunner.new()
	runner.name = "SimRunner"
	runner.world = world
	runner.local_player_id = LOCAL_PLAYER
	runner.process_priority = -10   # step the sim before the view reads it
	add_child(runner)

	game_view = GameView.new()
	game_view.name = "GameView"
	game_view.setup(world, content)
	add_child(game_view)
	game_view.sync(0.0)

	rts_camera = RtsCamera.new()
	rts_camera.name = "RtsCamera"
	add_child(rts_camera)
	rts_camera.set_bounds(Rect2(0, 0, map_def.width_m, map_def.height_m))
	rts_camera.focus_on(Vector3(map_def.width_m * 0.35, 0.0, map_def.height_m * 0.5))

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(runner)

	selection = SelectionController.new()
	selection.name = "SelectionController"
	selection.setup(runner, game_view, rts_camera, hud.selection_box, LOCAL_PLAYER)
	selection.selection_changed.connect(hud.on_selection_changed)
	add_child(selection)


func _process(_delta: float) -> void:
	game_view.sync(runner.alpha)


func _spawn_sandbox_units() -> void:
	_spawn_group("us_mbt", LOCAL_PLAYER, 30, 56, 3)
	_spawn_group("us_rifle_squad", LOCAL_PLAYER, 24, 70, 2)
	_spawn_group("ru_mbt", ENEMY_PLAYER, 98, 56, 3)
	_spawn_group("ru_motor_rifle_squad", ENEMY_PLAYER, 104, 70, 2)


## Spawns `count` units in a column starting at (x_m, y_m), in meters.
func _spawn_group(def_id: String, player_id: int, x_m: int, y_m: int, count: int) -> void:
	var def: UnitDef = content.get_unit(def_id)
	if def == null:
		push_error("Sandbox: unknown unit '%s'" % def_id)
		return
	# Each side starts facing the other: player 1 looks toward +X, others toward -X.
	var facing: int = 0 if player_id == LOCAL_PLAYER else Fx.ANGLE_HALF
	for i: int in count:
		world.spawn_unit(def, player_id, Fx.from_int(x_m), Fx.from_int(y_m + i * 8), facing)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2(map_def.width_m, map_def.height_m)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.36, 0.42, 0.28)
	ground_mat.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = ground_mat
	ground.position = Vector3(map_def.width_m * 0.5, 0.0, map_def.height_m * 0.5)
	add_child(ground)

	# Rocks are drawn from the map's obstacles, so what you see is what blocks
	# movement. Heights are view-only decoration, so ordinary random numbers are
	# fine here (never in the sim).
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.43, 0.40)
	for o: PackedInt32Array in map_def.obstacles_m:
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(o[2], rng.randf_range(1.5, 4.0), o[3])
		rock.mesh = box
		rock.material_override = rock_mat
		rock.position = Vector3(o[0] + o[2] * 0.5, box.size.y * 0.5, o[1] + o[3] * 0.5)
		add_child(rock)
