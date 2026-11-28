class_name MapFeaturesView
extends Node3D
## Map scenery that isn't ground (P2-12): the water surface and obstacles
## from MapDef, styled by the map's biome (Biomes, P3-23). Town houses
## (P3-05, HouseModel) and bridges (P3-11, BridgeModel) are buildings.
## Placeholder shapes in the classic military RTS look; they use fog
## materials so unexplored areas stay dark. View only.

var _fog: FogOfWar
var _ground: Callable
var _pal: Dictionary = Biomes.TEMPERATE


## `ground` is the terrain height function (TerrainView.height_at).
func build(def: MapDef, fog: FogOfWar, ground: Callable) -> void:
	name = "MapFeatures"
	_fog = fog
	_ground = ground
	_pal = Biomes.palette(def.biome)
	if def.has_water():
		_add_water(def)
	_add_obstacles(def)


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
	var water := _mesh(plane, _pal["water"], "Water")
	water.position = Vector3((x0 + x1) / 2.0, def.water_level_cm / 100.0, (z0 + z1) / 2.0)


## Draws what blocks movement, in the biome's style (P3-23), so what you see is
## what blocks: rocks and hedges, sandstone mesas, or stands of pine trees.
## Sizes and tree spots are view-only decoration, from a fixed-seed generator.
func _add_obstacles(def: MapDef) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var style: String = _pal["obstacle"]
	var trees: Array[Transform3D] = []
	for o: PackedInt32Array in def.obstacles_m:
		if style == "trees":
			_place_trees(o, rng, trees)
			continue
		var cx: float = o[0] + o[2] * 0.5
		var cz: float = o[1] + o[3] * 0.5
		var box := BoxMesh.new()
		var h: float = rng.randf_range(1.5, 4.0) if style == "rock" else rng.randf_range(5.0, 9.0)
		box.size = Vector3(o[2], h, o[3])
		var block := _mesh(box, _pal["obstacle_color"], "Rock" if style == "rock" else "Mesa")
		block.position = Vector3(cx, _ground.call(cx, cz) + h * 0.5 - 0.3, cz)
	if not trees.is_empty():
		_add_forest(trees)


## Pine spots filling an obstacle rectangle (about one per 9 m²): each is a
## transform at the tree's foot, scaled by its height.
func _place_trees(o: PackedInt32Array, rng: RandomNumberGenerator, out: Array[Transform3D]) -> void:
	var count: int = maxi(1, (o[2] * o[3]) / 9)
	for i: int in count:
		var x: float = o[0] + rng.randf_range(0.8, maxf(0.9, o[2] - 0.8))
		var z: float = o[1] + rng.randf_range(0.8, maxf(0.9, o[3] - 0.8))
		var h: float = rng.randf_range(5.0, 8.5)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * h)
		out.append(Transform3D(basis, Vector3(x, _ground.call(x, z), z)))


## All the trees as two MultiMeshes (crowns and trunks), so a forest costs
## two draw calls on phones. Meshes are for a 1 m tree, scaled per instance.
func _add_forest(spots: Array[Transform3D]) -> void:
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 0.28
	crown.height = 0.8
	crown.radial_segments = 6
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.025
	trunk.bottom_radius = 0.035
	trunk.height = 0.25
	trunk.radial_segments = 5
	for part: Array in [[crown, _pal["obstacle_color"], "Trees", 0.6], [trunk, Color(0.30, 0.22, 0.15), "Trunks", 0.12]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = spots.size()
		for i: int in spots.size():
			var t: Transform3D = spots[i]
			mm.set_instance_transform(i, t.translated_local(Vector3(0.0, part[3], 0.0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = part[2]
		mmi.multimesh = mm
		mmi.material_override = _fog.make_material(part[1])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)


func _mesh(m: Mesh, color: Color, base_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = base_name
	mi.mesh = m
	mi.material_override = _fog.make_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi
