class_name MapDef
extends RefCounted
## A map's content definition, built by ContentDb from the map folder
## res://data/maps/<id>/ (map.json plus an optional height.r16).
## See docs/design/maps-and-modes.md.

var id: String = ""
var name: String = ""
var width_m: int = 0
var height_m: int = 0
## Each obstacle is [x_m, y_m, w_m, h_m]: a blocked rectangle from its corner.
var obstacles_m: Array[PackedInt32Array] = []
## Each supply site is [x_m, y_m, amount]: a finite stock of credits.
var supply_sites: Array[PackedInt32Array] = []
## Skirmish start positions [x_m, y_m], one per player slot.
var start_positions: Array[Vector2i] = []
## One height per 2 m cell in centimeters, row by row; empty = flat.
var heights_cm: PackedInt32Array = PackedInt32Array()
## A cell more than this above a neighbor is an impassable cliff edge.
var max_step_cm: int = 100
## Cells lower than this are deep water (impassable). Unset = no water.
var water_level_cm: int = -1000000
## Town houses [x_m, y_m, w_m, h_m, roof_height_m]: MatchSetup spawns them as
## neutral buildings infantry can garrison (P3-05); the view draws them.
var civilian_buildings_m: Array[PackedInt32Array] = []
## Bridge decks [x_m, y_m, w_m, h_m] drawn over river crossings (view only).
var bridges_m: Array[PackedInt32Array] = []
## Offered in the skirmish menu (P2-12).
var skirmish: bool = false
## The look (P3-23): "temperate", "desert" or "winter" (view only, Biomes).
var biome: String = "temperate"
## The looks a map can pick (the view styles each one: Biomes, P3-23).
const BIOMES: PackedStringArray = ["temperate", "desert", "winter"]


func has_water() -> bool:
	return water_level_cm > -1000000


## Builds the sim grid for this map.
func make_sim_map() -> SimMap:
	var map := SimMap.new(width_m, height_m)
	for o: PackedInt32Array in obstacles_m:
		map.add_obstacle_m(o[0], o[1], o[2], o[3])
	if not heights_cm.is_empty():
		var fx := PackedInt32Array()
		fx.resize(heights_cm.size())
		for i: int in heights_cm.size():
			fx[i] = (heights_cm[i] * Fx.ONE) / 100
		map.set_heights(fx)
		map.block_cliffs((max_step_cm * Fx.ONE) / 100)
		map.block_below((water_level_cm * Fx.ONE) / 100)
	return map


## Height in meters at a point, interpolated between cell centers (view only:
## floats are fine here, the sim uses SimMap.height_at).
func height_at_m(x_m: float, z_m: float) -> float:
	if heights_cm.is_empty():
		return 0.0
	var w: int = cells_x()
	var h: int = cells_y()
	var fx: float = clampf(x_m / 2.0 - 0.5, 0.0, w - 1.0)
	var fz: float = clampf(z_m / 2.0 - 0.5, 0.0, h - 1.0)
	var x0: int = int(fx)
	var z0: int = int(fz)
	var x1: int = mini(x0 + 1, w - 1)
	var z1: int = mini(z0 + 1, h - 1)
	var tx: float = fx - x0
	var tz: float = fz - z0
	var a: float = lerpf(heights_cm[z0 * w + x0], heights_cm[z0 * w + x1], tx)
	var b: float = lerpf(heights_cm[z1 * w + x0], heights_cm[z1 * w + x1], tx)
	return lerpf(a, b, tz) / 100.0


func cells_x() -> int:
	return maxi(1, (width_m * 100 + SimMap.CELL_CM - 1) / SimMap.CELL_CM)


func cells_y() -> int:
	return maxi(1, (height_m * 100 + SimMap.CELL_CM - 1) / SimMap.CELL_CM)
