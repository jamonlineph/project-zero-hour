class_name UnitView
extends Node3D
## The visual for one SimEntity: a model (the Blender .glb if it exists, or a
## placeholder shape), team color, a selection ring, a health bar with
## veterancy pips, turret aiming, and a wreck when it dies. It reads sim state
## and never writes it.

const RING_COLOR := Color(0.35, 1.0, 0.45)
const HOVER_OWN_COLOR := Color(0.85, 1.0, 0.85, 0.6)
const HOVER_ENEMY_COLOR := Color(1.0, 0.3, 0.25)
const DRONE_HOVER_M: float = 6.0  ## drones fly; the sim keeps them on the ground plane
const STRIKE_ALTITUDE_M: float = 18.0   ## missiles and jets (P2-07)
const TURRET_TURN_RAD_PER_S: float = 2.5
const BARREL_PITCH_RAD_PER_S: float = 1.0
const WRECK_SECONDS: float = 20.0

enum Kind { INFANTRY, VEHICLE, DRONE, BUILDING, SUPPLY, STRIKE }


var entity_id: int = 0
var _ring: MeshInstance3D
var _model: Node3D
var _static: bool = false       ## buildings and supply sites never turn
var kind: Kind = Kind.VEHICLE
var status: UnitStatus
var _selected: bool = false
var _turret: Node3D
var _barrel: Node3D
var _turret_rest: float = 0.0
var _barrel_rest: float = 0.0
var _muzzle: Node3D
var _height: float = 2.0
var is_wreck: bool = false
var _upgrade_parts: Dictionary[String, Node3D] = {}   ## upg_* node name -> node (P2-05)
var _upgrade_sig: int = -1
var _decoy_look: bool = false
var animator: InfantryAnimator   ## infantry with the shared rig (P2-16)
static var _decoy_material: StandardMaterial3D


## Power sensors (P2-09): no model, just a faint ring for the revealed or
## jammed area.
func _setup_sensor(entity: SimEntity) -> void:
	entity_id = entity.id
	name = "Sensor_%d" % entity.id
	kind = Kind.STRIKE   # moves like a flyer; never selected
	_model = Node3D.new()
	_model.name = "Placeholder"
	add_child(_model)
	if entity.jammer != null:
		add_child(_make_field_ring(Fx.to_float(entity.jammer.radius)))
	elif entity.vision > 0 and entity.mover == null:
		var ring := _make_field_ring(Fx.to_float(entity.vision))
		(ring.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.75, 1.0, 0.35)
		add_child(ring)
	_ring = _make_ring(1.0)
	_ring.visible = false
	add_child(_ring)
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))


## Missiles and strike jets (P2-07): simple shapes in code, flying high and
## diving onto the aim point at the end.
func _setup_strike(entity: SimEntity, team_color: Color) -> void:
	entity_id = entity.id
	name = "Strike_%d" % entity.id
	kind = Kind.STRIKE
	var holder := Node3D.new()
	holder.name = "Placeholder"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.56, 0.55)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 3.2) if not entity.strike.aircraft else Vector3(1.4, 0.8, 7.0)
	body.mesh = box
	body.material_override = mat
	holder.add_child(body)
	if entity.strike.aircraft:
		var wing := MeshInstance3D.new()
		var wbox := BoxMesh.new()
		wbox.size = Vector3(8.0, 0.2, 2.2)
		wing.mesh = wbox
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = team_color
		wing.material_override = wmat
		holder.add_child(wing)
	_model = holder
	_model.position.y = STRIKE_ALTITUDE_M
	add_child(_model)
	_ring = _make_ring(1.0)
	_ring.visible = false
	add_child(_ring)
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))
	rotation.y = yaw_from_sim_angle(float(entity.facing))


## Picks the right visual for any entity: unit, building or supply site.
func setup_entity(entity: SimEntity, content: ContentDb, team_color: Color) -> void:
	if entity.strike != null:
		_setup_strike(entity, team_color)
		return
	if entity.sensor:
		_setup_sensor(entity)
		return
	if entity.building == null and entity.supply == null:
		setup(entity, content.get_unit(entity.def_id) if content != null else null, team_color)
		return
	entity_id = entity.id
	name = "Entity_%d" % entity.id
	_static = true
	var radius_m: float = Fx.to_float(entity.radius)
	if entity.supply != null:
		kind = Kind.SUPPLY
		_model = _make_supply_crates()
	else:
		kind = Kind.BUILDING
		var def: BuildingDef = content.get_building(entity.def_id) if content != null else null
		_model = _make_building_model(def, entity, team_color)
	add_child(_model)
	_ring = _make_ring(radius_m * 1.3)
	_ring.visible = false
	add_child(_ring)
	_find_parts()
	if kind == Kind.BUILDING:
		_add_status(clampf(radius_m * 1.2, 3.0, 8.0))
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))


func setup(entity: SimEntity, def: UnitDef, team_color: Color) -> void:
	entity_id = entity.id
	name = "Unit_%d" % entity.id
	var radius_m: float = Fx.to_float(entity.radius)
	_model = _make_model(def, radius_m, team_color)
	if def != null and def.armor_class == "drone":
		kind = Kind.DRONE
		_model.position.y = DRONE_HOVER_M
	elif def != null and def.is_infantry():
		kind = Kind.INFANTRY
	add_child(_model)
	if kind == Kind.INFANTRY:
		animator = InfantryAnimator.attach_to(_model)
	_ring = _make_ring(radius_m)
	_ring.visible = false
	add_child(_ring)
	_find_parts()
	_add_status(clampf(radius_m * 2.0, 1.6, 5.0))
	if entity.jammer != null:
		add_child(_make_field_ring(Fx.to_float(entity.jammer.radius)))
	position = Vector3(Fx.to_float(entity.x), 0.0, Fx.to_float(entity.y))
	rotation.y = yaw_from_sim_angle(float(entity.facing))


func set_selected(selected: bool) -> void:
	_selected = selected
	_set_ring_color(RING_COLOR)
	_ring.visible = selected and not is_wreck


## Hover highlight (mouse only): a pale ring on own units, red on enemies.
## Selection wins over hover.
func set_hovered(hovered: bool, enemy: bool) -> void:
	if _selected or is_wreck:
		return
	_set_ring_color(HOVER_ENEMY_COLOR if enemy else HOVER_OWN_COLOR)
	_ring.visible = hovered


func is_ring_visible() -> bool:
	return _ring.visible


func _set_ring_color(color: Color) -> void:
	(_ring.material_override as StandardMaterial3D).albedo_color = color


## Shows the model's upg_* parts for the upgrades this unit has (P2-05).
## `signature` changes whenever the owned upgrades might have.
func update_upgrades(attachments: PackedStringArray, signature: int) -> void:
	if signature == _upgrade_sig or _upgrade_parts.is_empty():
		return
	_upgrade_sig = signature
	for name: String in _upgrade_parts:
		_upgrade_parts[name].visible = attachments.has(name)


func has_upgrade_part(name: String) -> bool:
	return _upgrade_parts.has(name)


func is_upgrade_part_visible(name: String) -> bool:
	return _upgrade_parts.has(name) and _upgrade_parts[name].visible


## Decoys (P2-08): translucent for their owner and for enemies who have seen
## through them; otherwise they look exactly like the real unit.
func set_decoy_look(on: bool) -> void:
	if on == _decoy_look or is_wreck:
		return
	_decoy_look = on
	if _decoy_material == null:
		_decoy_material = StandardMaterial3D.new()
		_decoy_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_decoy_material.albedo_color = Color(0.75, 0.75, 0.7, 0.45)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _decoy_material if on else null


func has_decoy_look() -> bool:
	return _decoy_look


## Health bar and veterancy pips; call every frame.
func update_status(e: SimEntity) -> void:
	if status != null and not is_wreck:
		status.refresh(e.hp, e.max_hp, e.vet_rank, _selected)


## Turns the turret toward a world point and raises the barrel by
## `elevation` radians. has_target = false returns both to rest.
func aim(target: Vector3, has_target: bool, elevation: float, delta: float) -> void:
	if is_wreck:
		return
	if _turret != null:
		var want: float = _turret_rest
		if has_target:
			var to: Vector3 = target - global_position if is_inside_tree() else target - position
			if Vector2(to.x, to.z).length() > 0.5:
				want = wrapf(atan2(to.x, to.z) - rotation.y, -PI, PI)
		_turret.rotation.y = rotate_toward(_turret.rotation.y, want, TURRET_TURN_RAD_PER_S * delta)
	if _barrel != null:
		var pitch: float = _barrel_rest - (elevation if has_target else 0.0)
		_barrel.rotation.x = move_toward(_barrel.rotation.x, pitch, BARREL_PITCH_RAD_PER_S * delta)


## World yaw the turret currently points at (the unit's yaw if it has none).
func turret_world_yaw() -> float:
	return wrapf(rotation.y + (_turret.rotation.y if _turret != null else 0.0), -PI, PI)


func has_turret() -> bool:
	return _turret != null


## Where shots come from: the model's muzzle_0 point, or above the center.
func muzzle_position() -> Vector3:
	if _muzzle != null and _muzzle.is_inside_tree():
		return _muzzle.global_position
	return global_position + Vector3(0.0, _height * 0.6, 0.0)


## Turns a destroyed vehicle or building into a dark wreck that sinks away;
## infantry, drones and supply crates simply vanish. The view frees itself.
func become_wreck(darken: Material) -> void:
	is_wreck = true
	_ring.visible = false
	if status != null:
		status.visible = false
	if kind == Kind.INFANTRY and animator != null:
		# Play the fall, lie still a moment, then sink away.
		animator.play("death_1" if entity_id % 2 == 0 else "death_2")
		var fall := create_tween()
		fall.tween_interval(3.0)
		fall.tween_property(self, "position:y", -1.0, 1.5)
		fall.tween_callback(queue_free)
		return
	if kind == Kind.INFANTRY or kind == Kind.DRONE or kind == Kind.SUPPLY:
		var t := create_tween()
		t.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.4)
		t.tween_callback(queue_free)
		return
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = darken
	# A fixed, id-based tilt so every wreck looks a little different.
	var tilt: float = float(entity_id % 7 - 3) * 0.04
	if kind == Kind.VEHICLE:
		rotation.z = tilt
		if _turret != null:
			_turret.rotation.y += tilt * 4.0
	var tween := create_tween()
	tween.tween_interval(WRECK_SECONDS)
	tween.tween_property(self, "position:y", -_height - 0.5, 3.0)
	tween.tween_callback(queue_free)


func _find_parts() -> void:
	# Upgrade attachments (P2-05): nodes named upg_* stay hidden until owned.
	for node: Node in _model.find_children("upg_*", "Node3D", true, false):
		_upgrade_parts[str(node.name)] = node as Node3D
		(node as Node3D).visible = false
	_turret = _model.find_child("turret", true, false) as Node3D
	_barrel = _model.find_child("barrel", true, false) as Node3D
	_muzzle = _model.find_child("muzzle_0", true, false) as Node3D
	if _turret != null:
		_turret_rest = _turret.rotation.y
	if _barrel != null:
		_barrel_rest = _barrel.rotation.x
	_height = _model_height()


func _add_status(width_m: float) -> void:
	status = UnitStatus.new()
	status.setup(width_m, _height + 0.8)
	add_child(status)


## Top of the model's bounding box, in this view's space.
func _model_height() -> float:
	var top: float = 0.0
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != self:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var box: AABB = t * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > 0.0 else 2.0


## Moves the node between the previous and current tick positions.
## alpha is 0..1: how far we are into the current tick.
func update_from_sim(e: SimEntity, alpha: float) -> void:
	if _static and e.garrison != null:
		# Who holds it shows as a flag (houses) and as pips (P3-05).
		HouseModel.set_holder(_model, TeamColors.for_player(e.player_id) if e.player_id != 0 else null)
	if _static:
		# Buildings rise out of the ground while under construction.
		if e.building != null:
			var done: float = 1.0 if e.building.built else float(e.building.progress) / float(maxi(1, e.building.total))
			_model.scale = Vector3(1.0, 0.15 + 0.85 * done, 1.0)
		return
	if kind == Kind.STRIKE and e.strike != null and not e.strike.aircraft:
		# Missiles dive over their last 40 m.
		var left: float = Fx.to_float(Fx.length(e.strike.dest_x - e.x, e.strike.dest_y - e.y))
		_model.position.y = STRIKE_ALTITUDE_M * clampf(left / 40.0, 0.05, 1.0)
	if kind == Kind.DRONE and e.drone != null:
		# Docked drones settle onto their launcher; airborne ones hover.
		var want: float = 1.0 if e.drone.docked else DRONE_HOVER_M
		_model.position.y = move_toward(_model.position.y, want, 4.0 * get_process_delta_time())
	var px: float = lerpf(Fx.to_float(e.prev_x), Fx.to_float(e.x), alpha)
	var pz: float = lerpf(Fx.to_float(e.prev_y), Fx.to_float(e.y), alpha)
	position = Vector3(px, 0.0, pz)
	var facing: float = float(e.prev_facing) + float(Fx.angle_diff(e.prev_facing, e.facing)) * alpha
	rotation.y = yaw_from_sim_angle(facing)
	if animator != null:
		animator.update(e, get_process_delta_time())


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
	if def != null and def.id == "civilian_house":
		return HouseModel.make(e.building.w * 2.0, e.building.h * 2.0, e.building.cell_x + e.building.cell_y)
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


## A faint ring showing a jamming field's reach (P2-03).
func _make_field_ring(radius_m: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius_m - 0.4
	torus.outer_radius = radius_m
	torus.rings = 64
	torus.ring_segments = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.4, 1.0, 0.45)
	var ring := MeshInstance3D.new()
	ring.name = "JammingField"
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position.y = 0.3
	return ring


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
