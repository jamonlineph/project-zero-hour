class_name GameView
extends Node3D
## Keeps one UnitView per sim entity and moves them smoothly every frame.
## The view only reads the sim. Player intent goes through SimCommands.

var world: SimWorld
var content: ContentDb
## Units of other teams are only drawn where this player can see (fog of war).
var local_player_id: int = 1
var _views: Dictionary[int, UnitView] = {}


func setup(sim_world: SimWorld, content_db: ContentDb) -> void:
	world = sim_world
	content = content_db


## Call once per frame after the sim has stepped. alpha = progress into the tick.
func sync(alpha: float) -> void:
	for id: int in world.entity_ids:
		if not _views.has(id):
			_create_view(world.entities[id])
	for id: int in _views.keys():
		if not world.entities.has(id):
			_views[id].queue_free()
			_views.erase(id)
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var v: UnitView = _views[id]
		v.update_from_sim(e, alpha)
		v.visible = not world.are_enemies(local_player_id, e.player_id) or world.can_see(local_player_id, e.x, e.y)


## Simple placeholder effects for sim events until P1-28 adds real ones: a
## brief flash where a weapon fires and a puff where something dies.
func play_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		match ev["type"]:
			"fired":
				_flash(Vector3(Fx.to_float(ev["x"]), 1.5, Fx.to_float(ev["y"])), Color(1.0, 0.85, 0.4), 0.6, 0.12)
			"died":
				_flash(Vector3(Fx.to_float(ev["x"]), 1.0, Fx.to_float(ev["y"])), Color(0.3, 0.3, 0.3), 3.0, 0.8)


func _flash(at: Vector3, color: Color, size: float, seconds: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var sphere := SphereMesh.new()
	sphere.radius = size * 0.5
	sphere.height = size
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	add_child(mi)
	var tween := mi.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(mi.queue_free)


func get_view(entity_id: int) -> UnitView:
	return _views.get(entity_id, null)


## Small fading ring where a move order was given.
func show_move_marker(point: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 1.0, 0.5, 0.9)
	var marker := MeshInstance3D.new()
	marker.mesh = torus
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(point.x, 0.08, point.z)
	marker.scale = Vector3(1.0, 0.1, 1.0)
	add_child(marker)
	var tween := marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(0.2, 0.1, 0.2), 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(marker.queue_free)


func _create_view(e: SimEntity) -> void:
	var v := UnitView.new()
	v.setup_entity(e, content, TeamColors.for_player(e.player_id))
	add_child(v)
	_views[e.id] = v
