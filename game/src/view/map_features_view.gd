class_name MapFeaturesView
extends Node3D
## Map scenery that isn't ground (P2-12): the water surface and bridge decks
## from MapDef. Town houses are buildings now (P3-05, HouseModel). Placeholder shapes in the classic military RTS
## look; they use fog materials so unexplored areas stay dark. View only.

const WATER := Color(0.20, 0.32, 0.36)
const DECK := Color(0.52, 0.50, 0.46)
const RAIL := Color(0.30, 0.30, 0.30)
const DECK_THICKNESS: float = 0.5
const RAIL_HEIGHT: float = 0.9

var _fog: FogOfWar
var _ground: Callable


## `ground` is the terrain height function (TerrainView.height_at).
func build(def: MapDef, fog: FogOfWar, ground: Callable) -> void:
	name = "MapFeatures"
	_fog = fog
	_ground = ground
	if def.has_water():
		_add_water(def)
	for b: PackedInt32Array in def.bridges_m:
		_add_bridge(b)


## One flat plane over the cells below the water level.
func _add_water(def: MapDef) -> void:
	var w: int = def.cells_x()
	var lo := Vector2i(w, def.cells_y())
	var hi := Vector2i(-1, -1)
	for i: int in def.heights_cm.size():
		if def.heights_cm[i] < def.water_level_cm:
			lo = Vector2i(mini(lo.x, i % w), mini(lo.y, i / w))
			hi = Vector2i(maxi(hi.x, i % w), maxi(hi.y, i / w))
	if hi.x < 0:
		return
	var x0: float = maxf(0.0, lo.x * 2.0 - 4.0)
	var z0: float = maxf(0.0, lo.y * 2.0 - 4.0)
	var x1: float = minf(def.width_m, hi.x * 2.0 + 6.0)
	var z1: float = minf(def.height_m, hi.y * 2.0 + 6.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(x1 - x0, z1 - z0)
	var water := _mesh(plane, WATER, "Water")
	water.position = Vector3((x0 + x1) / 2.0, def.water_level_cm / 100.0, (z0 + z1) / 2.0)


## A deck across the crossing, with a railing on each long side.
func _add_bridge(r: PackedInt32Array) -> void:
	var along_x: bool = r[2] >= r[3]
	var center := Vector3(r[0] + r[2] / 2.0, 0.0, r[1] + r[3] / 2.0)
	var top: float = _ground.call(center.x, center.z) + 0.05
	var box := BoxMesh.new()
	box.size = Vector3(r[2], DECK_THICKNESS, r[3])
	var deck := _mesh(box, DECK, "Bridge")
	deck.position = center + Vector3(0.0, top - DECK_THICKNESS / 2.0, 0.0)
	for side: int in [-1, 1]:
		var rail := BoxMesh.new()
		rail.size = Vector3(r[2], RAIL_HEIGHT, 0.3) if along_x else Vector3(0.3, RAIL_HEIGHT, r[3])
		var m := _mesh(rail, RAIL, "Rail")
		var off: Vector3 = Vector3(0.0, 0.0, side * (r[3] / 2.0 - 0.15)) if along_x \
			else Vector3(side * (r[2] / 2.0 - 0.15), 0.0, 0.0)
		m.position = center + off + Vector3(0.0, top + RAIL_HEIGHT / 2.0, 0.0)


func _mesh(m: Mesh, color: Color, base_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = base_name
	mi.mesh = m
	mi.material_override = _fog.make_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
