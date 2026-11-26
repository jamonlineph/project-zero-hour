class_name Minimap
extends Control
## Minimap (P1-25): terrain, fog of war, unit dots and the camera's view.
## Click or tap to move the camera there. View-only: reads the sim.

signal jump_requested(ground_point: Vector3)

const BG := Color(0.20, 0.24, 0.17)
const ROCK := Color(0.42, 0.40, 0.38)
const UNSEEN := Color(0.0, 0.0, 0.0, 1.0)
const REMEMBERED := Color(0.0, 0.0, 0.0, 0.45)
const FOG_REFRESH_SEC: float = 0.25

var world: SimWorld
var local_player_id: int = 1
var rts_camera: RtsCamera
var _terrain: ImageTexture
var _fog: ImageTexture
var _fog_timer: float = 0.0


func setup(sim_world: SimWorld, player_id: int, cam: RtsCamera) -> void:
	world = sim_world
	local_player_id = player_id
	rts_camera = cam
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_terrain()
	_refresh_fog()


func _process(delta: float) -> void:
	if world == null:
		return
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = FOG_REFRESH_SEC
		_refresh_fog()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pressed = true
		pos = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		pressed = true
		pos = (event as InputEventScreenDrag).position
	if pressed:
		jump_requested.emit(minimap_to_ground(pos))
		accept_event()


## Minimap position (pixels) -> ground point (meters).
func minimap_to_ground(pos: Vector2) -> Vector3:
	var w_m: float = Fx.to_float(world.map_width)
	var h_m: float = Fx.to_float(world.map_height)
	return Vector3(clampf(pos.x / size.x, 0.0, 1.0) * w_m, 0.0, clampf(pos.y / size.y, 0.0, 1.0) * h_m)


func _ground_to_minimap(x_m: float, z_m: float) -> Vector2:
	return Vector2(x_m / Fx.to_float(world.map_width) * size.x, z_m / Fx.to_float(world.map_height) * size.y)


func _draw() -> void:
	if world == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG)
	if _terrain != null:
		draw_texture_rect(_terrain, rect, false)
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var mine: bool = not world.are_enemies(local_player_id, e.player_id)
		if not mine and not world.can_see(local_player_id, e.x, e.y):
			continue
		var p: Vector2 = _ground_to_minimap(Fx.to_float(e.x), Fx.to_float(e.y))
		var color: Color = Color(0.85, 0.7, 0.3) if e.supply != null else TeamColors.for_player(e.player_id)
		var r: float = 3.0 if e.building != null else 1.6
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), color)
	if _fog != null:
		draw_texture_rect(_fog, rect, false)
	_draw_camera_view()
	draw_rect(rect, Color(1, 1, 1, 0.6), false, 1.0)


func _draw_camera_view() -> void:
	if rts_camera == null or rts_camera.camera == null:
		return
	var vp: Rect2 = get_viewport().get_visible_rect()
	var corners: Array[Vector2] = [vp.position, Vector2(vp.end.x, vp.position.y), vp.end, Vector2(vp.position.x, vp.end.y)]
	var points := PackedVector2Array()
	for c: Vector2 in corners:
		var g: Variant = rts_camera.screen_to_ground(c)
		if g == null:
			return
		var gp: Vector3 = g
		points.append(_ground_to_minimap(gp.x, gp.z))
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.8), 1.0)


func _build_terrain() -> void:
	var map: SimMap = world.map
	var img := Image.create(map.width_cells, map.height_cells, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cy: int in map.height_cells:
		for cx: int in map.width_cells:
			if map.is_blocked_terrain(cx, cy):
				img.set_pixel(cx, cy, ROCK)
	_terrain = ImageTexture.create_from_image(img)


func _refresh_fog() -> void:
	var v: SimVision = world.vision
	var team: int = world.team_of(local_player_id)
	var img := Image.create(v.cols, v.rows, false, Image.FORMAT_RGBA8)
	for cy: int in v.rows:
		for cx: int in v.cols:
			var x: int = cx * SimVision.CELL + SimVision.CELL / 2
			var y: int = cy * SimVision.CELL + SimVision.CELL / 2
			if v.is_visible(team, x, y):
				img.set_pixel(cx, cy, Color(0, 0, 0, 0))
			elif v.is_explored(team, x, y):
				img.set_pixel(cx, cy, REMEMBERED)
			else:
				img.set_pixel(cx, cy, UNSEEN)
	if _fog == null:
		_fog = ImageTexture.create_from_image(img)
	else:
		_fog.update(img)
