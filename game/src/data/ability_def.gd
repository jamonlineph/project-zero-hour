class_name AbilityDef
extends RefCounted
## A unit's special ability (P3-02f; data: a unit's "abilities" list). Used
## with a USE_ABILITY command; see AbilitySystem.

const KINDS: PackedStringArray = ["strike", "disable"]

var id: String = ""
var kind: String = ""           ## "strike": call strikes on a point; "disable": shut down an enemy building
var name: String = ""
var description: String = ""
var range: int = 0              ## fixed-point meters from the unit
var cooldown_ticks: int = 0
var strike_id: String = ""      ## strike: the StrikeDef
var count: int = 1              ## strike: how many
var duration_ticks: int = 0     ## disable: how long
