class_name MapDef
extends RefCounted
## A map's content definition, built by ContentDb from res://data/maps/<id>.json.
## Temporary format until P1-30 adds heightmaps and the full map folder.

var id: String = ""
var name: String = ""
var width_m: int = 0
var height_m: int = 0
## Each obstacle is [x_m, y_m, w_m, h_m]: a blocked rectangle from its corner.
var obstacles_m: Array[PackedInt32Array] = []


## Builds the sim grid for this map.
func make_sim_map() -> SimMap:
	var map := SimMap.new(width_m, height_m)
	for o: PackedInt32Array in obstacles_m:
		map.add_obstacle_m(o[0], o[1], o[2], o[3])
	return map
