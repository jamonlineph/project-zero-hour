class_name TeamColors
extends RefCounted
## Player colors for the view layer. Models mark recolorable parts with a
## material named "team_color" (docs/04-art-pipeline.md).

const TEAM_MATERIAL_NAME: String = "team_color"

const DEFAULTS: Dictionary = {
	0: Color(0.75, 0.75, 0.75),   # neutral
	1: Color(0.16, 0.47, 0.95),   # player 1: blue
	2: Color(0.90, 0.24, 0.20),   # player 2: red
	3: Color(0.95, 0.80, 0.20),   # player 3: yellow
	4: Color(0.30, 0.80, 0.40),   # player 4: green
}


static func for_player(player_id: int) -> Color:
	return DEFAULTS.get(player_id, Color.WHITE)


## Recolors every surface whose material is named "team_color" under `root`.
static func apply(root: Node, color: Color) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and mat.resource_name == TEAM_MATERIAL_NAME:
				var tinted := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				tinted.albedo_color = color
				mi.set_surface_override_material(i, tinted)
