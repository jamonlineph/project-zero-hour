class_name FogOfWar
extends Node
## Draws the local player's fog of war on the terrain (P1-27). Copies the
## sim's vision grid into a small texture after each vision update and hands
## it to every terrain material made with make_material(). Reads only.

const SHADER: Shader = preload("res://src/view/fog_terrain.gdshader")
const UNEXPLORED: int = 0
const EXPLORED: int = 128
const VISIBLE: int = 255

var world: SimWorld
var local_player_id: int = 1
var texture: ImageTexture
var _image: Image
var _materials: Array[ShaderMaterial] = []
var _last_tick: int = -1


func setup(sim_world: SimWorld, player_id: int) -> void:
	name = "FogOfWar"
	world = sim_world
	local_player_id = player_id
	var v: SimVision = world.vision
	_image = Image.create(v.cols, v.rows, false, Image.FORMAT_L8)
	texture = ImageTexture.create_from_image(_image)
	refresh()


## A terrain material of this color that darkens under the fog.
func make_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("fog_texture", texture)
	var v: SimVision = world.vision
	m.set_shader_parameter("fog_size", Vector2(v.cols, v.rows) * Fx.to_float(SimVision.CELL))
	_materials.append(m)
	return m


func _process(_delta: float) -> void:
	if world != null and world.tick != _last_tick:
		refresh()


## Rebuilds the texture from the sim's visible and explored layers.
func refresh() -> void:
	_last_tick = world.tick
	var v: SimVision = world.vision
	var team: int = world.team_of(local_player_id)
	var half: int = SimVision.CELL / 2
	for cy: int in v.rows:
		for cx: int in v.cols:
			var x: int = cx * SimVision.CELL + half
			var y: int = cy * SimVision.CELL + half
			var value: int = UNEXPLORED
			if v.is_visible(team, x, y):
				value = VISIBLE
			elif v.is_explored(team, x, y):
				value = EXPLORED
			_image.set_pixel(cx, cy, Color8(value, value, value))
	texture.update(_image)


## Fog value (0, 128 or 255) at a world point, for tests and the view.
func value_at(x_m: float, z_m: float) -> int:
	var cell: float = Fx.to_float(SimVision.CELL)
	var cx: int = clampi(int(x_m / cell), 0, _image.get_width() - 1)
	var cy: int = clampi(int(z_m / cell), 0, _image.get_height() - 1)
	return roundi(_image.get_pixel(cx, cy).r * 255.0)
