class_name LaserShield
extends RefCounted
## The UAE's laser shield (P3-02f, commander power kind "laser_shield"):
## for duration_ticks, a player's built air-defense sites (buildings with a
## weapon that targets aircraft or drones) inside the power's area also
## burn down enemy shells, rockets and missiles that come within
## LASER_RANGE of them (CombatSystem asks intercepts()), and hurt enemy
## drones that close in, DRONE_PERCENT of their max hp a second (step(),
## before combat). One shield per player; using it again moves it.

const LASER_RANGE: int = 35 * Fx.ONE
const DRONE_PERCENT: int = 25


static func activate(world: SimWorld, player_id: int, x: int, y: int, radius: int, duration: int) -> void:
	var p: SimPlayer = world.get_player(player_id)
	p.shield_x = x
	p.shield_y = y
	p.shield_radius = radius
	p.shield_until = world.tick + duration


## The shielded air-defense sites this tick: [player_id, x, y] each, in
## entity order. Empty (and cheap) when no shield is up.
static func sites(world: SimWorld) -> Array[Array]:
	var out: Array[Array] = []
	var any: bool = false
	for pid: int in world.players:
		if world.players[pid].shield_until > world.tick:
			any = true
	if not any:
		return out
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.building == null or not e.building.built or e.player_id == 0:
			continue
		var p: SimPlayer = world.get_player(e.player_id)
		if p.shield_until <= world.tick or Fx.length(e.x - p.shield_x, e.y - p.shield_y) > p.shield_radius:
			continue
		for w: SimWeapon in e.weapons:
			if DamageMatrix.can_target(w.targets, "aircraft") or DamageMatrix.can_target(w.targets, "drone"):
				out.append([e.player_id, e.x, e.y])
				break
	return out


## True if an enemy's shielded site burns this projectile down now.
static func intercepts(world: SimWorld, shield_sites: Array[Array], proj: SimProjectile) -> bool:
	for s: Array in shield_sites:
		if world.are_enemies(s[0], proj.player_id) and Fx.length(proj.x - s[1], proj.y - s[2]) <= LASER_RANGE:
			world.events.append({"type": "intercepted", "id": 0, "x": proj.x, "y": proj.y})
			return true
	return false


## Once a second: enemy drones near a shielded site take damage.
static func step(world: SimWorld) -> void:
	if world.tick % SimWorld.TICK_RATE != 0:
		return
	var shield_sites: Array[Array] = sites(world)
	if shield_sites.is_empty():
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.drone == null:
			continue
		for s: Array in shield_sites:
			if world.are_enemies(s[0], e.player_id) and Fx.length(e.x - s[1], e.y - s[2]) <= LASER_RANGE:
				world.apply_damage(e, maxi(1, (e.max_hp * DRONE_PERCENT) / 100), "counter_drone", 0, false)
				world.events.append({"type": "intercepted", "id": e.id, "x": e.x, "y": e.y})
				break
