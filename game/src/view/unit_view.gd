class_name UnitView
extends Node3D
## The visual for one SimEntity: a model (the Blender .glb if it exists, or a
## placeholder shape), team color, and a selection ring. It reads sim state and
## never writes it.

const RING_COLOR := Color(0.35, 1.0, 0.45)
const DRONE_HOVER_M: float = 6.0  ## drones fly; the sim keeps them on the ground plane


var entity_id: int = 0
var _ring: MeshInstance3D
var _model: Node3D
var _static: bool = false       ## buildings and supply sites never turn


## Picks the right visual for any entity: unit, building or supply site.
func setup_entity(entity: SimEntity, content: ContentDb, team_color: Color) -> void:
	if entity.building == null and entity.supply == null:
		setup(entity, content.get_unit(entity.def_id) if content != null else null, team_color)
		return
	entity_id = entity.id
	name = "Entity_%d" % entity.id
	_static = true
	var radius_m: float = Fx.to_float(entity.radius)
	if entity.supply != null:
		_model = _make_supply_crates()
	else:
		var def: BuildingDef = content.get_building(entity.def_id) if content != null else null
		_model = _make_building_model(def, entity, team_color)
	add_child(_model)
	_ring = _make_ring(radius_m * 1.3)
	_ring.visible = false
	add_child(_ring)
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))


func setup(entity: SimEntity, def: UnitDef, team_color: Color) -> void:
	entity_id = entity.id
	name = "Unit_%d" % entity.id
	var radius_m: float = Fx.to_float(entity.radius)
	_model = _make_model(def, radius_m, team_color)
	if def != null and def.armor_class == "drone":
		_model.position.y = DRONE_HOVER_M
	add_child(_model)
	_ring = _make_ring(radius_m)
	_ring.visible = false
	add_child(_ring)
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))
	rotation.y = yaw_from_sim_angle(float(entity.facing))


func set_selected(selected: bool) -> void:
	_ring.visible = selected


## Moves the node between the previous and current tick positions.
## alpha is 0..1: how far we are into the current tick.
func update_from_sim(e: SimEntity, alpha: float) -> void:
	if _static:
		# Buildings rise out of the ground while under construction.
		if e.building != null:
			var done: float = 1.0 if e.building.built else float(e.building.progress) / float(maxi(1, e.building.total))
			_model.scale = Vector3(1.0, 0.15 + 0.85 * done, 1.0)
		return
	var px: float = lerpf(Fx.to_float(e.prev_x), Fx.to_float(e.x), alpha)
	var pz: float = lerpf(Fx.to_float(e.prev_y), Fx.to_float(e.y), alpha)
	position = Vector3(px, 0.0, pz)
	var facing: float = float(e.prev_facing) + float(Fx.angle_diff(e.prev_facing, e.facing)) * alpha
	rotation.y = yaw_from_sim_angle(facing)


## Sim angle a points along (cos a, sin a) in sim X/Y, which is Godot X/Z.
## Models face +Z (Vector3.MODEL_FRONT); rotating by yaw t points +Z along
## (sin t, cos t), so t = PI/2 - a.
static func yaw_from_sim_angle(sim_angle: float) -> float:
	return wrapf(PI * 0.5 - sim_angle * TAU / float(Fx.ANGLE_FULL), -PI, PI)


func _make_model(def: UnitDef, radius_m: float, team_color: Color) -> Node3D:
	if def != null and def.model_path != "" and ResourceLoader.exists(def.model_path):
		var scene: PackedScene = load(def.model_path)
		if scene != null:
			var instance: Node3D = scene.instantiate()
			TeamColors.apply(instance, team_color)
			return instance
	return _make_placeholder(def, radius_m, team_color)


func _make_building_model(def: BuildingDef, e: SimEntity, team_color: Color) -> Node3D:
	if def != null and def.model_path != "" and ResourceLoader.exists(def.model_path):
		var scene: PackedScene = load(def.model_path)
		if scene != null:
			var instance: Node3D = scene.instantiate()
			TeamColors.apply(instance, team_color)
			return instance
	# Placeholder: a block the size of the footprint with a team-colored band.
	var size := Vector3(e.building.w * 2.0 * 0.9, 4.0, e.building.h * 2.0 * 0.9)
	var holder := Node3D.new()
	holder.name = "Placeholder"
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.47)
	body.material_override = mat
	body.position.y = size.y * 0.5
	holder.add_child(body)
	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(size.x * 1.02, 0.6, size.z * 1.02)
	band.mesh = band_box
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = team_color
	band.material_override = band_mat
	band.position.y = size.y * 0.7
	holder.add_child(band)
	return holder


func _make_supply_crates() -> Node3D:
	var holder := Node3D.new()
	holder.name = "SupplyCrates"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.62, 0.25)
	for i: int in 4:
		var crate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 1.0, 1.4)
		crate.mesh = box
		crate.material_override = mat
		crate.position = Vector3((i % 2) * 1.6 - 0.8, 0.5 + (1.0 if i == 3 else 0.0), (i / 2) * 1.6 - 0.8 if i < 3 else 0.0)
		holder.add_child(crate)
	return holder


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
