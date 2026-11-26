class_name ProtectionSystem
extends RefCounted
## Active protection and cage armor (P2-06).
##
## - Active protection (aps_charges): when a guided anti-tank missile or
##   loitering munition gets within INTERCEPT_RANGE of a protected vehicle, one
##   charge fires and destroys it with INTERCEPT_PERCENT chance (SimRng).
##   Each projectile is checked once. Used charges come back one at a time,
##   every RELOAD_TICKS.
## - Cage armor (cage_hits): the first hits from drones (drone_attack weapons
##   such as loitering munitions, or weapons fired by drone units) do only
##   CAGE_PERCENT damage, one cage hit used per hit.

const INTERCEPT_RANGE: int = 12 * Fx.ONE
const INTERCEPT_PERCENT: int = 90
const RELOAD_TICKS: int = 20 * SimWorld.TICK_RATE
const CAGE_PERCENT: int = 25


## Recharges active protection. Called once per tick (after combat).
static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.aps_max == 0 or e.aps_charges >= e.aps_max:
			continue
		e.aps_reload += 1
		if e.aps_reload >= RELOAD_TICKS:
			e.aps_reload = 0
			e.aps_charges += 1


## Checks a guided projectile against its target's active protection.
## Returns true if it was shot down (the caller drops the projectile).
static func try_intercept(world: SimWorld, p: SimProjectile) -> bool:
	if p.aps_checked or not p.guided or p.damage_type != "anti_tank":
		return false
	var t: SimEntity = world.get_entity(p.target_id)
	if t == null or t.dead or t.aps_charges <= 0:
		return false
	var reach: int = INTERCEPT_RANGE + t.radius
	var dx: int = t.x - p.x
	var dy: int = t.y - p.y
	if dx * dx + dy * dy > reach * reach:
		return false
	p.aps_checked = true
	t.aps_charges -= 1
	var hit: bool = world.rng.chance(INTERCEPT_PERCENT, 100)
	world.events.append({"type": "intercepted" if hit else "intercept_failed", "id": t.id, "x": p.x, "y": p.y})
	return hit


## Damage after cage armor for a drone hit on `t`.
static func cage(t: SimEntity, damage: int, drone_hit: bool) -> int:
	if not drone_hit or t.cage_hits <= 0:
		return damage
	t.cage_hits -= 1
	return maxi(1, (damage * CAGE_PERCENT) / 100)
