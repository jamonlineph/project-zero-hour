class_name HouseModel
extends RefCounted
## Town houses (P3-05 entities; the look from P2-12): walls, a gable roof along
## the long side, and a flag pole whose flag shows who holds it. View only.

## The current map's biome (set by the match scene): picks wall and roof colors.
static var biome: String = "temperate"


## A house `w_m` by `d_m` meters (x by z), centered on its origin. `variant`
## picks colors and height, so neighbours differ.
static func make(w_m: float, d_m: float, variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "House"
	var height: float = 5.0 + float(variant % 3)
	var wall_h: float = height * 0.6
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var box := BoxMesh.new()
	box.size = Vector3(w_m - 0.4, wall_h, d_m - 0.4)
	walls.mesh = box
	var pal: Dictionary = Biomes.palette(biome)
	var walls_list: Array = pal["walls"]
	var roofs_list: Array = pal["roofs"]
	walls.material_override = _mat(walls_list[variant % walls_list.size()])
	walls.position.y = wall_h * 0.5
	root.add_child(walls)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var prism := PrismMesh.new()
	var along_x: bool = w_m >= d_m
	prism.size = Vector3(d_m if along_x else w_m, height * 0.4, w_m if along_x else d_m)
	roof.mesh = prism
	roof.material_override = _mat(roofs_list[variant % roofs_list.size()])
	roof.position.y = wall_h + height * 0.2
	if along_x:
		roof.rotation.y = PI / 2.0
	root.add_child(roof)
	var pole := MeshInstance3D.new()
	pole.name = "FlagPole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = 2.4
	pole.mesh = pole_mesh
	pole.material_override = _mat(Color(0.2, 0.2, 0.2))
	pole.position = Vector3(w_m * 0.35, height + 1.0, d_m * 0.25)
	pole.visible = false
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.2, 0.7, 0.05)
	flag.mesh = flag_mesh
	flag.material_override = _mat(Color.WHITE)
	flag.position = Vector3(0.6, 0.8, 0.0)
	pole.add_child(flag)
	return root


## Shows the flag in the holder's color, or hides it when nobody holds the house.
static func set_holder(house: Node3D, holder_color: Variant) -> void:
	var pole: Node3D = house.get_node_or_null("FlagPole")
	if pole == null:
		return
	pole.visible = holder_color != null
	if holder_color != null:
		((pole.get_node("Flag") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = holder_color


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
