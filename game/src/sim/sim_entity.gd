class_name SimEntity
extends RefCounted
## One simulated object: units now, buildings later.
##
## Holds only deterministic data (ints, fixed-point where noted, bools and
## Strings) plus optional component objects. Systems in res://src/sim/systems/
## read and change entities; nothing outside the sim writes to them.

## What the unit was told to do (P1-10; GUARD and PATROL from P1-24b).
enum Order { IDLE = 0, MOVE = 1, ATTACK = 2, ATTACK_MOVE = 3, HOLD = 4, GUARD = 5, PATROL = 6, GARRISON = 7, CAPTURE = 8 }

var id: int = 0
var player_id: int = 0          ## 0 = neutral
var def_id: String = ""         ## content id, for example "us_mbt" (res://data/)
var armor_class: String = ""    ## see docs/design/combat.md
var x: int = 0                  ## fixed-point meters (sim X maps to Godot X)
var y: int = 0                  ## fixed-point meters (sim Y maps to Godot Z)
var prev_x: int = 0             ## position at the start of the tick, for view interpolation
var prev_y: int = 0
var facing: int = 0             ## binary angle (Fx.ANGLE_FULL per turn); 0 = +X, 1024 = +Y
var prev_facing: int = 0        ## facing at the start of the tick, for view interpolation
var radius: int = 0             ## fixed-point meters
var vision: int = 0             ## sight radius, fixed-point meters
var hp: int = 0
var max_hp: int = 0
var dead: bool = false          ## set when hp reaches 0; removed at the end of the tick
var cost: int = 0               ## credits; weights veterancy XP (P1-17)
var xp: int = 0                 ## veterancy XP (cost-weighted damage dealt)
var vet_rank: int = 0           ## 0..3
var mover: SimMover = null      ## only on entities that can move
var weapons: Array[SimWeapon] = []
var building: SimBuilding = null
var builder: SimBuilder = null
var gatherer: SimGatherer = null
var supply: SimSupply = null    ## supply sites only
var drone: SimDrone = null      ## drones only: endurance and launcher (P2-01)
var jammer: SimJammer = null    ## jamming field and spoofing (P2-03)
var spotter: bool = false       ## marks targets for kill-chain weapons (P2-04)
var crusher: bool = false       ## hurts enemies it drives over (P3-07); from the def, so not hashed
var launcher: SimLauncher = null   ## swarm-drone launcher (P3-02c)
var ability_ready: Dictionary[String, int] = {}   ## ability id -> first tick it can be used again (P3-02f)
var strike: SimStrike = null    ## a missile or strike aircraft in flight (P2-07)
var decoy_of: String = ""       ## a decoy imitating this unit id (P2-08)
var revealed_mask: int = 0      ## decoys: bit per team that has seen through it
var sensor: bool = false        ## temporary vision/jamming marker from a power (P2-09): untargetable
var ttl: int = 0                ## ticks left for temporary entities; 0 = permanent
var upgrades: PackedStringArray = []   ## per-unit upgrades bought for this unit (P2-05)
var aps_charges: int = 0        ## active protection: interceptions left (P2-06)
var aps_max: int = 0
var aps_reload: int = 0         ## ticks toward the next charge
var cage_hits: int = 0          ## cage armor: drone hits it still softens (P2-06)
var garrison: SimGarrison = null   ## structures infantry can enter (P3-05)
var inside_id: int = 0          ## the structure this unit is garrisoned in (P3-05); 0 = outside

var order: Order = Order.IDLE
var order_target_id: int = 0    ## ATTACK: the entity to destroy; GUARD: the entity to protect
var order_x: int = 0            ## ATTACK_MOVE / PATROL: where to go (fixed-point meters)
var order_y: int = 0
var order_repath_tick: int = 0  ## ATTACK / GUARD: when the chase path was last planned
var order_from_x: int = 0       ## PATROL: the other end of the route
var order_from_y: int = 0


func is_armed() -> bool:
	return not weapons.is_empty()


func write_hash(h: SimHash) -> void:
	h.add_int(id)
	h.add_int(player_id)
	h.add_string(def_id)
	h.add_string(armor_class)
	h.add_int(x)
	h.add_int(y)
	h.add_int(facing)
	h.add_int(radius)
	h.add_int(vision)
	h.add_int(hp)
	h.add_int(max_hp)
	h.add_bool(dead)
	h.add_int(order)
	h.add_int(order_target_id)
	h.add_int(order_x)
	h.add_int(order_y)
	h.add_int(order_repath_tick)
	# Only while patrolling, so states without patrols hash as they always did
	# (golden replays recorded before P1-24b stay valid).
	if order == Order.PATROL:
		h.add_int(order_from_x)
		h.add_int(order_from_y)
	if drone != null:   # only drones, so older replays hash as before
		drone.write_hash(h)
	if jammer != null:
		jammer.write_hash(h)
	if spotter:
		h.add_bool(true)
	if strike != null:
		strike.write_hash(h)
	if launcher != null:   # only launchers, so older replays hash as before
		launcher.write_hash(h)
	if not ability_ready.is_empty():   # only after an ability was used (P3-02f)
		var keys: Array = ability_ready.keys()
		keys.sort()
		for k: String in keys:
			h.add_string(k)
			h.add_int(ability_ready[k])
	if sensor or ttl != 0:
		h.add_bool(sensor)
		h.add_int(ttl)
	if decoy_of != "":
		h.add_string(decoy_of)
		h.add_int(revealed_mask)
	if not upgrades.is_empty() or aps_max != 0 or cage_hits != 0:
		for u: String in upgrades:
			h.add_string(u)
		h.add_int(aps_charges)
		h.add_int(aps_max)
		h.add_int(aps_reload)
		h.add_int(cage_hits)
	# Garrisons (P3-05): only when present, so older replays hash as before.
	if garrison != null:
		garrison.write_hash(h)
	if inside_id != 0:
		h.add_int(inside_id)
	if mover != null:
		mover.write_hash(h)
	else:
		h.add_int(-1)
	h.add_int(weapons.size())
	for w: SimWeapon in weapons:
		w.write_hash(h)
	h.add_int(cost)
	h.add_int(xp)
	h.add_int(vet_rank)
	for c: Variant in [building, builder, gatherer, supply]:
		if c == null:
			h.add_int(-1)
		else:
			c.write_hash(h)
