class_name PlacementController
extends Node3D
## Building placement (P1-26): a ghost of the building follows the cursor (or
## the last touch), snapped to the map grid and tinted green where it can be
## built and red where it can't. Mouse: left-click places, right-click or Esc
## cancels. Touch: tap or drag moves the ghost; the HUD's Place / Cancel
## buttons confirm or cancel.

signal placement_changed(active: bool)

const OK_COLOR := Color(0.3, 1.0, 0.4, 0.45)
const BAD_COLOR := Color(1.0, 0.25, 0.2, 0.45)

var runner: SimRunner
var rts_camera: RtsCamera
var selection: SelectionController
var active: bool = false
var building_id: String = ""
var valid: bool = false
var center: Vector2i = Vector2i.ZERO   ## fixed-point meters, snapped
var _ghost: MeshInstance3D
var _mat: StandardMaterial3D
var _touch_mode: bool = false


func setup(sim_runner: SimRunner, cam: RtsCamera, sel: SelectionController) -> void:
	runner = sim_runner
	rts_camera = cam
	selection = sel


func begin(id: String) -> void:
	var def: BuildingDef = runner.world.content.get_building(id) if runner.world.content != null else null
	if def == null:
		return
	cancel()
	building_id = id
	active = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box := BoxMesh.new()
	box.size = Vector3(def.footprint_w * 2.0, 3.0, def.footprint_h * 2.0)
	_ghost = MeshInstance3D.new()
	_ghost.name = "PlacementGhost"
	_ghost.mesh = box
	_ghost.material_override = _mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	var view_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	set_screen_point(get_viewport().get_mouse_position() if not _touch_mode else view_center)
	placement_changed.emit(true)


func cancel() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	var was_active: bool = active
	active = false
	building_id = ""
	if was_active:
		placement_changed.emit(false)


## Places the building with the selected builders if the spot is valid.
func confirm() -> bool:
	if not active or not valid:
		return false
	runner.submit(SimCommand.make_build(selection.selected, building_id, center.x, center.y))
	cancel()
	return true


## Moves the ghost to the ground under a screen position.
func set_screen_point(screen_pos: Vector2) -> void:
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if ground != null:
		var g: Vector3 = ground
		set_ground_point(Fx.from_float(g.x), Fx.from_float(g.z))


## Moves the ghost to a ground point (fixed-point meters), snapped to cells.
func set_ground_point(x: int, y: int) -> void:
	if not active:
		return
	var world: SimWorld = runner.world
	var def: BuildingDef = world.content.get_building(building_id)
	var origin: Vector2i = SimWorld.footprint_origin(def, x, y)
	center = Vector2i(origin.x * SimMap.CELL + (def.footprint_w * SimMap.CELL) / 2,
		origin.y * SimMap.CELL + (def.footprint_h * SimMap.CELL) / 2)
	var player: SimPlayer = world.get_player(selection.local_player_id)
	valid = world.can_place(def, origin) and player.credits >= def.cost \
		and world.has_requirements(selection.local_player_id, def.requires) and _has_builder()
	var gx: float = Fx.to_float(center.x)
	var gz: float = Fx.to_float(center.y)
	var gy: float = rts_camera.ground_height.call(gx, gz) if rts_camera.ground_height.is_valid() else 0.0
	_ghost.position = Vector3(gx, gy + 1.5, gz)
	_mat.albedo_color = OK_COLOR if valid else BAD_COLOR


## Returns true if the event was used by placement (so selection ignores it).
func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		_touch_mode = false
		set_screen_point((event as InputEventMouseMotion).position)
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			set_screen_point(mb.position)
			confirm()
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			return true
	if event is InputEventScreenTouch:
		_touch_mode = true
		set_screen_point((event as InputEventScreenTouch).position)
		return true
	if event is InputEventScreenDrag:
		_touch_mode = true
		set_screen_point((event as InputEventScreenDrag).position)
		return true
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			cancel()
			return true
		if (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER]:
			confirm()
			return true
	return false


func _has_builder() -> bool:
	for id: int in selection.selected:
		var e: SimEntity = runner.world.get_entity(id)
		if e != null and e.builder != null:
			return true
	return false
