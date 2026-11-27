class_name Biomes
extends RefCounted
## Map looks by biome (P3-23): ground, water and building colors, and how
## obstacles are drawn. A map picks one with "biome" in map.json; the view
## reads it, the sim never does. All original placeholder palettes.

const TEMPERATE := {
	"grass": Color(0.36, 0.42, 0.28), "rock": Color(0.45, 0.43, 0.40), "earth": Color(0.33, 0.30, 0.22),
	"mud": Color(0.30, 0.27, 0.20), "water": Color(0.20, 0.32, 0.36),
	"obstacle": "rock", "obstacle_color": Color(0.45, 0.43, 0.40),
	"walls": [Color(0.78, 0.72, 0.60), Color(0.62, 0.40, 0.30), Color(0.84, 0.82, 0.76)],
	"roofs": [Color(0.45, 0.20, 0.16), Color(0.30, 0.30, 0.32)],
}
const DESERT := {
	"grass": Color(0.74, 0.64, 0.45), "rock": Color(0.62, 0.45, 0.32), "earth": Color(0.66, 0.55, 0.38),
	"mud": Color(0.55, 0.47, 0.33), "water": Color(0.18, 0.42, 0.44),
	"obstacle": "mesa", "obstacle_color": Color(0.64, 0.46, 0.33),
	"walls": [Color(0.93, 0.91, 0.86), Color(0.80, 0.56, 0.40), Color(0.88, 0.80, 0.66)],
	"roofs": [Color(0.72, 0.48, 0.34), Color(0.58, 0.54, 0.48)],
}
const WINTER := {
	"grass": Color(0.86, 0.88, 0.90), "rock": Color(0.50, 0.52, 0.55), "earth": Color(0.70, 0.72, 0.74),
	"mud": Color(0.55, 0.57, 0.60), "water": Color(0.62, 0.72, 0.80),
	"obstacle": "trees", "obstacle_color": Color(0.16, 0.28, 0.20),
	"walls": [Color(0.55, 0.38, 0.26), Color(0.70, 0.62, 0.52), Color(0.45, 0.30, 0.22)],
	"roofs": [Color(0.88, 0.90, 0.92), Color(0.80, 0.82, 0.86)],
}
const ALL := {"temperate": TEMPERATE, "desert": DESERT, "winter": WINTER}


static func palette(biome: String) -> Dictionary:
	return ALL.get(biome, TEMPERATE)
