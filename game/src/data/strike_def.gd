class_name StrikeDef
extends RefCounted
## A missile or strike aircraft that powers and superweapons launch (P2-07),
## built by ContentDb from res://data/strikes/<id>.json. In flight it is a
## real sim entity (armor class "aircraft") that air defense can shoot down.

var id: String = ""
var name: String = ""
var kind: String = "missile"      ## "missile" (dies on impact) or "aircraft" (drops its load, flies away)
var max_hp: int = 1
var speed: int = 0                ## fixed-point meters per tick
var radius: int = Fx.ONE
var vision: int = 0
## Payload: `count` impacts scattered up to `spread` around the aim point.
var damage: int = 0
var damage_type: String = "high_explosive"
var splash_radius: int = 0
var splash_edge_percent: int = 50
var count: int = 1
var spread: int = 0
