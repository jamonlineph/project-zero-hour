class_name TerrainView
extends MeshInstance3D
## The ground mesh (P1-30), built from the same heights the sim uses
## (MapDef.heights_cm): one vertex per 2 m cell center, plus a border ring so
## the mesh reaches the map edges. Vertex colors: grass on flat ground, rock
## on steep slopes, darker earth in hollows. The material darkens under the
## fog of war (FogOfWar.make_material). View only.

const GRASS := Color(0.36, 0.42, 0.28)
const ROCK := Color(0.45, 0.43, 0.40)
const EARTH := Color(0.33, 0.30, 0.22)

var map_def: MapDef


func build(def: MapDef, fog: FogOfWar) -> void:
	name = "Terrain"
	map_def = def
	var w: int = def.cells_x()
	var h: int = def.cells_y()
	# Grid lines at the map edge (0), every cell center, and the far edge.
	var xs := PackedFloat32Array([0.0])
	for i: int in w:
		xs.append(i * 2.0 + 1.0)
	xs.append(def.width_m)
	var zs := PackedFloat32Array([0.0])
	for j: int in h:
		zs.append(j * 2.0 + 1.0)
	zs.append(def.height_m)
	var low: float = INF
	var high: float = -INF
	for v: int in def.heights_cm:
		low = minf(low, v / 100.0)
		high = maxf(high, v / 100.0)
	if def.heights_cm.is_empty():
		low = 0.0
		high = 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = xs.size()
	for j: int in zs.size():
		for i: int in cols:
			var x: float = xs[i]
			var z: float = zs[j]
			var y: float = def.height_at_m(x, z)
			st.set_color(_color(def, x, z, y, low, high))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, y, z))
	for j: int in zs.size() - 1:
		for i: int in cols - 1:
			var a: int = j * cols + i
			var b: int = a + 1
			var c: int = a + cols
			var d: int = c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	mesh = st.commit()
	var mat: ShaderMaterial = fog.make_material(Color.WHITE)
	mat.set_shader_parameter("use_vertex_color", true)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Height of the view's ground at (x, z) in meters.
func height_at(x: float, z: float) -> float:
	return map_def.height_at_m(x, z) if map_def != null else 0.0


static func _color(def: MapDef, x: float, z: float, y: float, low: float, high: float) -> Color:
	var dx: float = def.height_at_m(x + 1.0, z) - def.height_at_m(x - 1.0, z)
	var dz: float = def.height_at_m(x, z + 1.0) - def.height_at_m(x, z - 1.0)
	var slope: float = clampf(Vector2(dx, dz).length() / 2.0, 0.0, 1.0)   # rise per meter
	var c: Color = GRASS.lerp(ROCK, smoothstep(0.25, 0.6, slope))
	if high - low > 0.1:
		var t: float = (y - low) / (high - low)
		c = EARTH.lerp(c, smoothstep(0.0, 0.35, t))
	return c
