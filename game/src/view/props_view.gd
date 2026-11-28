class_name PropsView
extends Node3D
## Scattered scenery (P3-23d): small props that make the ground look lived
## in, by biome. Temperate: bushes and stones. Desert: stones, dry shrubs and
## palms near water. Winter: snowdrifts and young firs. Decoration only: the
## sim never sees them, units drive through them, and they keep clear of
## bases, buildings, roads, supply sites and water. One MultiMesh per kind,
## placed by a generator seeded with the map id, so a map always looks the
## same. Fog materials darken them like the ground.

const SPACING: float = 7.0         ## meters between candidate spots
const BASE_CLEAR_M: float = 42.0   ## nothing this close to a start position
const SITE_CLEAR_M: float = 10.0   ## nor to a supply site or neutral building

## kind -> [mesh maker, color, chance per spot, scale range]
const KINDS: Dictionary = {
	"temperate": [["bush", Color(0.24, 0.33, 0.18), 0.22, Vector2(0.7, 1.4)],
		["stone", Color(0.46, 0.45, 0.42), 0.10, Vector2(0.4, 0.9)]],
	"desert": [["stone", Color(0.62, 0.50, 0.38), 0.14, Vector2(0.5, 1.2)],
		["shrub", Color(0.52, 0.48, 0.30), 0.12, Vector2(0.6, 1.1)],
		["palm", Color(0.30, 0.42, 0.20), 0.0, Vector2(0.9, 1.3)]],
	"winter": [["drift", Color(0.93, 0.95, 0.97), 0.20, Vector2(0.8, 1.8)],
		["fir", Color(0.15, 0.26, 0.19), 0.08, Vector2(0.6, 1.1)]],
}

var counts: Dictionary[String, int] = {}   ## kind -> instances placed (tests)


func build(def: MapDef, fog: FogOfWar) -> void:
	name = "Props"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id + "_props")
	var spots: Dictionary[String, Array] = {}
	var kinds: Array = KINDS.get(def.biome, KINDS["temperate"])
	for k: Array in kinds:
		spots[k[0]] = []
	var z: float = SPACING * 0.5
	while z < def.height_m:
		var x: float = SPACING * 0.5
		while x < def.width_m:
			var px: float = x + rng.randf_range(-2.5, 2.5)
			var pz: float = z + rng.randf_range(-2.5, 2.5)
			var roll: float = rng.randf()
			var near_water: bool = def.has_water() and _near_water(def, px, pz)
			if _clear(def, px, pz):
				var acc: float = 0.0
				for k: Array in kinds:
					var chance: float = k[2]
					if k[0] == "palm":
						chance = 0.6 if near_water else 0.0
					acc += chance
					if roll < acc:
						spots[k[0]].append(Vector3(px, def.height_at_m(px, pz), pz))
						break
			x += SPACING
		z += SPACING
	for k: Array in kinds:
		var list: Array = spots[k[0]]
		counts[k[0]] = list.size()
		if list.is_empty():
			continue
		if k[0] == "palm":
			# A palm is a brown trunk with a green crown on top, sharing transforms.
			var seed_now: int = rng.seed
			_add_multimesh(["palm_trunk", Color(0.45, 0.33, 0.20), 0.0, k[3]], list, fog, rng)
			rng.seed = seed_now
			_add_multimesh(["palm_crown", k[1], 0.0, k[3]], list, fog, rng)
		else:
			_add_multimesh(k, list, fog, rng)


## True where a prop may stand: dry, not steep, away from bases, buildings,
## obstacles, roads (bridges) and supply sites.
func _clear(def: MapDef, x: float, z: float) -> bool:
	if x < 2.0 or z < 2.0 or x > def.width_m - 2.0 or z > def.height_m - 2.0:
		return false
	var y: float = def.height_at_m(x, z)
	if def.has_water() and y < def.water_level_cm / 100.0 + 0.25:
		return false
	if absf(def.height_at_m(x + 1.0, z) - def.height_at_m(x - 1.0, z)) > 0.8:
		return false
	for s: Vector2i in def.start_positions:
		if Vector2(x, z).distance_to(Vector2(s)) < BASE_CLEAR_M:
			return false
	for s: PackedInt32Array in def.supply_sites:
		if Vector2(x, z).distance_to(Vector2(s[0], s[1])) < SITE_CLEAR_M:
			return false
	for nb: Dictionary in def.neutral_buildings:
		if Vector2(x, z).distance_to(Vector2(int(nb["x"]), int(nb["y"]))) < SITE_CLEAR_M:
			return false
	for rects: Array in [def.obstacles_m, def.civilian_buildings_m, def.bridges_m]:
		for r: PackedInt32Array in rects:
			if x > r[0] - 2.0 and x < r[0] + r[2] + 2.0 and z > r[1] - 2.0 and z < r[1] + r[3] + 2.0:
				return false
	return true


func _near_water(def: MapDef, x: float, z: float) -> bool:
	var level: float = def.water_level_cm / 100.0
	for d: Vector2 in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
		if def.height_at_m(x + d.x, z + d.y) < level:
			return true
	return false


func _add_multimesh(kind: Array, list: Array, fog: FogOfWar, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh(str(kind[0]))
	mm.instance_count = list.size()
	var scale_range: Vector2 = kind[3]
	for i: int in list.size():
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		var lift: float = {"fir": 1.5, "palm_trunk": 2.2, "palm_crown": 4.4}.get(kind[0], 0.0) * s   # trees stand on the ground
		mm.set_instance_transform(i, Transform3D(basis, list[i] + Vector3(0.0, lift, 0.0)))
	var mi := MultiMeshInstance3D.new()
	mi.name = str(kind[0]).capitalize()
	mi.multimesh = mm
	mi.material_override = fog.make_material(kind[1]) if fog != null else null
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind[0] in ["palm_crown", "fir"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _mesh(kind: String) -> Mesh:
	match kind:
		"bush", "shrub":
			var m := SphereMesh.new()
			m.radius = 0.7
			m.height = 0.9
			m.radial_segments = 8
			m.rings = 4
			return m
		"stone":
			var m := SphereMesh.new()
			m.radius = 0.6
			m.height = 0.6
			m.radial_segments = 6
			m.rings = 3
			return m
		"drift":
			var m := SphereMesh.new()
			m.radius = 1.4
			m.height = 0.7
			m.radial_segments = 8
			m.rings = 3
			return m
		"fir":
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = 1.1
			m.height = 3.2
			m.radial_segments = 7
			return m
		"palm_trunk":
			var m := CylinderMesh.new()
			m.top_radius = 0.12
			m.bottom_radius = 0.22
			m.height = 4.4
			m.radial_segments = 6
			return m
		"palm_crown":
			var m := SphereMesh.new()
			m.radius = 1.7
			m.height = 0.7
			m.radial_segments = 7
			m.rings = 3
			return m
	return BoxMesh.new()
