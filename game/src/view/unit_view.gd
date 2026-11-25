class_name UnitView
extends Node3D
## The visual for one SimEntity: a model (the Blender .glb if it exists, or a
## placeholder shape), team color, and a selection ring. It reads sim state and
## never writes it.

const RING_COLOR := Color(0.35, 1.0, 0.45)
const FACING_SMOOTHING: float = 0.35

var entity_id: int = 0
var _ring: MeshInstance3D
var _model: Node3D


func setup(entity: SimEntity, def: UnitDef, team_color: Color) -> void:
	entity_id = entity.id
	name = "Unit_%d" % entity.id
	var radius_m: float = Fx.to_float(entity.radius)
	_model = _make_model(def, radius_m, team_color)
	add_child(_model)
	_ring = _make_ring(radius_m)
	_ring.visible = false
	add_child(_ring)
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))


func set_selected(selected: bool) -> void:
	_ring.visible = selected


## Moves the node between the previous and current tick positions.
## alpha is 0..1: how far we are into the current tick.
func update_from_sim(e: SimEntity, alpha: float) -> void:
	var px: float = lerpf(Fx.to_float(e.prev_x), Fx.to_float(e.x), alpha)
	var pz: float = lerpf(Fx.to_float(e.prev_y), Fx.to_float(e.y), alpha)
	var new_pos := Vector3(px, 0.0, pz)
	var delta: Vector3 = new_pos - position
	if delta.length_squared() > 0.000001:
		# Models face +Z (Vector3.MODEL_FRONT), so this angle points them along delta.
		var target_yaw: float = atan2(delta.x, delta.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, FACING_SMOOTHING)
	position = new_pos


func _make_model(def: UnitDef, radius_m: float, team_color: Color) -> Node3D:
	if def != null and def.model_path != "" and ResourceLoader.exists(def.model_path):
		var scene: PackedScene = load(def.model_path)
		if scene != null:
			var instance: Node3D = scene.instantiate()
			TeamColors.apply(instance, team_color)
			return instance
	return _make_placeholder(def, radius_m, team_color)


## Used until a Blender model exists for this unit.
func _make_placeholder(def: UnitDef, radius_m: float, team_color: Color) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = team_color
	if def != null and def.is_infantry():
		var capsule := CapsuleMesh.new()
		capsule.radius = radius_m * 0.35
		capsule.height = radius_m * 1.4
		mesh_instance.mesh = capsule
		mesh_instance.position.y = capsule.height * 0.5
	else:
		var box := BoxMesh.new()
		box.size = Vector3(radius_m * 1.2, radius_m * 0.6, radius_m * 1.8)
		mesh_instance.mesh = box
		mesh_instance.position.y = box.size.y * 0.5
	mesh_instance.material_override = mat
	var holder := Node3D.new()
	holder.name = "Placeholder"
	holder.add_child(mesh_instance)
	return holder


func _make_ring(radius_m: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius_m * 1.05
	torus.outer_radius = radius_m * 1.2
	torus.rings = 32
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = RING_COLOR
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.position.y = 0.05
	return ring
