class_name RtsCamera
extends Node3D
## Strategy camera rig. This node is the focus point on the ground; the Camera3D
## child orbits it at a fixed pitch.
##
## Handled here: arrow keys, zoom/rotate keys, mouse wheel, middle-mouse drag,
## Space + left-drag (trackpads without a middle button), edge panning (once a
## real mouse moves), trackpad gestures, and camera bookmarks (Ctrl+F5–F8 to
## save, F5–F8 to jump). Touch gestures come from SelectionController through
## pan_screen(), zoom_by() and rotate_by().

@export var pitch_degrees: float = 55.0
@export var fov_degrees: float = 45.0
@export var min_distance: float = 14.0
@export var max_distance: float = 90.0
@export var key_pan_speed: float = 40.0    ## meters per second at distance 40
@export var rotate_speed: float = 1.8      ## radians per second
@export var edge_pan_margin: float = 12.0  ## pixels from the window edge

var camera: Camera3D
var distance: float = 40.0
## Turned on when a real mouse moves (touch does not emulate the mouse here).
var edge_pan_enabled: bool = false
## Terrain height at (x, z) in meters, for picking on hills; flat if unset.
var ground_height: Callable
var _bounds: Rect2 = Rect2(0, 0, 256, 256)   ## x/z rectangle the focus stays in
var _middle_dragging: bool = false
var _space_dragging: bool = false
## F5–F8 -> {"position", "yaw", "distance"}
var _bookmarks: Dictionary[int, Dictionary] = {}
var _shake: float = 0.0   ## meters of camera shake left (P3-20 setting scales it)


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov_degrees
	camera.near = 0.5
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	_apply_zoom()


func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_clamp_focus()


func focus_on(ground_point: Vector3) -> void:
	position = Vector3(ground_point.x, 0.0, ground_point.z)
	_clamp_focus()


## Drag-to-pan: the ground under the finger or cursor follows it.
func pan_screen(screen_delta: Vector2) -> void:
	var mpp: float = _meters_per_pixel()
	var right: Vector3 = global_transform.basis.x
	var forward: Vector3 = -global_transform.basis.z
	position += (-right * screen_delta.x + forward * screen_delta.y) * mpp
	_clamp_focus()


## factor < 1 zooms in, > 1 zooms out.
func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)
	_apply_zoom()


func rotate_by(radians: float) -> void:
	rotation.y = wrapf(rotation.y + radians, -PI, PI)


## True while Space is held: a left-drag then pans instead of box-selecting.
func space_pan_held() -> bool:
	return _space_dragging or Input.is_physical_key_pressed(KEY_SPACE)


## Saves the current view in bookmark slot `slot` (F5–F8 use 5–8).
func save_bookmark(slot: int) -> void:
	_bookmarks[slot] = {"position": position, "yaw": rotation.y, "distance": distance}


## Restores a saved view. Returns false if the slot is empty.
func jump_to_bookmark(slot: int) -> bool:
	if not _bookmarks.has(slot):
		return false
	var b: Dictionary = _bookmarks[slot]
	position = b["position"]
	rotation.y = b["yaw"]
	distance = b["distance"]
	_apply_zoom()
	_clamp_focus()
	return true


func has_bookmark(slot: int) -> bool:
	return _bookmarks.has(slot)


## The point on the ground under a screen position, or null. With terrain,
## the ray is intersected with the plane at the ground's height, refined a
## few times (plenty for the gentle slopes units can drive on).
func screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var level: float = 0.0
	var hit := Vector3.ZERO
	for i: int in 4:
		var t: float = (level - origin.y) / dir.y
		if t < 0.0:
			return null
		hit = origin + dir * t
		if not ground_height.is_valid():
			break
		level = ground_height.call(hit.x, hit.z)
	hit.y = level
	return hit


## Shakes the view a little (big explosions), scaled by the Camera shake
## setting: full, reduced (a third) or off.
func shake(strength_m: float) -> void:
	_shake = maxf(_shake, strength_m * shake_factor(GameSettings.current().camera_shake))


static func shake_factor(level: int) -> float:
	return [0.0, 0.35, 1.0][clampi(level, 0, 2)]


func _process(delta: float) -> void:
	if _shake > 0.0 and camera != null:
		_shake = maxf(0.0, _shake - delta * 2.5)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake
		camera.v_offset = randf_range(-1.0, 1.0) * _shake
	var move := Vector2(
		Input.get_axis("cam_left", "cam_right"),
		Input.get_axis("cam_forward", "cam_back"))
	if edge_pan_enabled:
		move += _edge_pan_direction()
	if move != Vector2.ZERO:
		move = move.limit_length(1.0)
		var speed: float = key_pan_speed * (distance / 40.0)
		var right: Vector3 = global_transform.basis.x
		var back: Vector3 = global_transform.basis.z
		position += (right * move.x + back * move.y) * speed * delta
		_clamp_focus()
	var turn: float = Input.get_axis("cam_rotate_left", "cam_rotate_right")
	if turn != 0.0:
		rotate_by(-turn * rotate_speed * delta)
	var zoom: float = Input.get_axis("cam_zoom_in", "cam_zoom_out")
	if zoom != 0.0:
		zoom_by(pow(2.0, zoom * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(1.0 / 0.9)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_space_dragging = mb.pressed and space_pan_held()
	elif event is InputEventMouseMotion:
		edge_pan_enabled = true
		if _middle_dragging or _space_dragging:
			pan_screen((event as InputEventMouseMotion).relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var slot: int = _bookmark_slot(key.physical_keycode)
		if slot != 0:
			if key.ctrl_pressed or key.meta_pressed:
				save_bookmark(slot)
			else:
				jump_to_bookmark(slot)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		zoom_by(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
	elif event is InputEventPanGesture:
		pan_screen(-(event as InputEventPanGesture).delta * 8.0)


static func _bookmark_slot(keycode: Key) -> int:
	match keycode:
		KEY_F5: return 5
		KEY_F6: return 6
		KEY_F7: return 7
		KEY_F8: return 8
	return 0


func _edge_pan_direction() -> Vector2:
	if not GameSettings.current().edge_pan:
		return Vector2.ZERO
	var vp: Viewport = get_viewport()
	if not get_window().has_focus():
		return Vector2.ZERO
	var rect: Rect2 = vp.get_visible_rect()
	var mouse: Vector2 = vp.get_mouse_position()
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x <= rect.position.x + edge_pan_margin:
		dir.x = -1.0
	elif mouse.x >= rect.end.x - edge_pan_margin:
		dir.x = 1.0
	if mouse.y <= rect.position.y + edge_pan_margin:
		dir.y = -1.0
	elif mouse.y >= rect.end.y - edge_pan_margin:
		dir.y = 1.0
	return dir


func _apply_zoom() -> void:
	if camera == null:
		return
	var pitch: float = deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _meters_per_pixel() -> float:
	var height_px: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	return 2.0 * distance * tan(deg_to_rad(fov_degrees) * 0.5) / height_px


func _clamp_focus() -> void:
	position.x = clampf(position.x, _bounds.position.x, _bounds.end.x)
	position.z = clampf(position.z, _bounds.position.y, _bounds.end.y)
	position.y = 0.0
