class_name PowerDef
extends RefCounted
## A commander power or unlock (P2-09), built by ContentDb from
## res://data/powers/<id>.json. See docs/design/commander.md.

const KINDS: PackedStringArray = ["reveal", "strike", "drone_sweep", "reinforce", "jam_area",
		"wingmen", "cyber", "decoys", "unlock"]

var id: String = ""
var faction: String = ""
var name: String = ""
var description: String = ""
var tier: int = 1               ## commander rank needed to choose it: 1, 3 or 5
var kind: String = ""
var targeted: bool = true       ## needs a map point when used
var cooldown_ticks: int = 0
var radius: int = 0             ## fixed-point meters (reveal, jamming, sweep vision)
var duration_ticks: int = 0
var count: int = 1
var strike_id: String = ""
var unit_id: String = ""        ## reinforce, wingmen, decoys, unlock
var needs_spotted: bool = false ## strike: the point must be seen by a friendly spotter
