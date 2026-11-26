class_name CombatSystem
extends RefCounted
## Weapons: targeting, reloading, firing, projectiles and impacts (P1-08).
##
## - Targets: visible enemies (another team, not neutral) whose armor class the
##   weapon can hit, within range (center distance minus the target's radius)
##   and outside min range. Best target = units before structures, then nearest,
##   then lowest id. Units without a target look for one every
##   ACQUIRE_INTERVAL ticks (staggered by id), or right after losing one.
## - Weapons fire regardless of facing (turrets); units that stand still turn
##   toward their target.
## - Instant weapons hit immediately; ballistic shells fly to where the target
##   was; guided missiles follow it. Splash damages enemies in the radius,
##   falling off linearly to splash_edge_percent at the edge. Splash only hurts
##   what the weapon can target (artillery doesn't hit drones overhead; P2-02).
## - Cone weapons (cone_half > 0, microwave emitters) hit every visible enemy
##   they can target inside the cone toward the target and within range.

const ACQUIRE_INTERVAL: int = 3


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.weapons.is_empty():
			continue
		# Unfinished buildings can't fire; built ones need power.
		if e.building != null and (not e.building.built or world.get_player(e.player_id).low_power()):
			continue
		# Jammed drones can't fire; spoofed ones fire only at their spoofed target.
		if e.drone != null and e.drone.jammed:
			continue
		if e.drone != null and e.drone.spoofed_ticks > 0:
			_fire_spoofed(world, e)
			continue
		for w: SimWeapon in e.weapons:
			if w.cooldown > 0:
				w.cooldown -= 1
			var t: SimEntity = world.get_entity(w.target_id) if w.target_id != 0 else null
			var lost: bool = false
			if t != null and not _valid_target(world, e, w, t):
				# An ATTACK order keeps its target while chasing it out of range.
				var chasing: bool = e.order == SimEntity.Order.ATTACK and e.order_target_id == t.id and not t.dead
				if not chasing:
					t = null
					w.target_id = 0
					lost = true
			if t == null and (lost or (world.tick + e.id) % ACQUIRE_INTERVAL == 0):
				t = _acquire(world, e, w)
				w.target_id = t.id if t != null else 0
			if t == null or not in_range(e, w, t):
				continue
			_face(e, t)
			if w.cooldown == 0:
				_fire(world, e, w, t)
	_step_projectiles(world)


## True if `t` is close enough for `w` (center distance minus target radius).
static func in_range(e: SimEntity, w: SimWeapon, t: SimEntity) -> bool:
	var dx: int = t.x - e.x
	var dy: int = t.y - e.y
	var reach: int = w.max_range + t.radius
	if absi(dx) > reach or absi(dy) > reach:
		return false
	# Same as Fx.length(dx, dy) <= reach and >= min_range (length is floor(sqrt)).
	var sq: int = dx * dx + dy * dy
	return sq < (reach + 1) * (reach + 1) and sq >= w.min_range * w.min_range


static func _valid_target(world: SimWorld, e: SimEntity, w: SimWeapon, t: SimEntity) -> bool:
	return not t.dead and world.are_enemies(e.player_id, t.player_id) \
			and DamageMatrix.can_target(w.targets, t.armor_class) and in_range(e, w, t) \
			and world.can_see(e.player_id, t.x, t.y) and KillChainSystem.may_engage(world, e, w, t)


static func _acquire(world: SimWorld, e: SimEntity, w: SimWeapon) -> SimEntity:
	var best: SimEntity = null
	var best_structure: bool = true
	var best_dist: int = 0
	for t: SimEntity in world.query_enemies(e.player_id, e.x, e.y, w.max_range + SimWorld.MAX_UNIT_RADIUS):
		if t.dead:
			continue
		if not DamageMatrix.can_target(w.targets, t.armor_class) or not in_range(e, w, t):
			continue
		if not world.can_see(e.player_id, t.x, t.y) or not KillChainSystem.may_engage(world, e, w, t):
			continue
		var structure: bool = t.armor_class == "structure"
		var dist: int = Fx.length(t.x - e.x, t.y - e.y)
		var better: bool = best == null
		if not better:
			if structure != best_structure:
				better = not structure
			elif dist != best_dist:
				better = dist < best_dist
			else:
				better = t.id < best.id
		if better:
			best = t
			best_structure = structure
			best_dist = dist
	return best


static func _face(e: SimEntity, t: SimEntity) -> void:
	if e.mover == null or (e.mover.has_target and not e.mover.paused):
		return
	var heading: int = Fx.atan2_a(t.y - e.y, t.x - e.x)
	var turn: int = clampi(Fx.angle_diff(e.facing, heading), -e.mover.turn_rate, e.mover.turn_rate)
	e.facing = Fx.wrap_angle(e.facing + turn)


static func _fire(world: SimWorld, e: SimEntity, w: SimWeapon, t: SimEntity) -> void:
	w.cooldown = w.reload_ticks
	var damage: int = (w.damage * (100 + world.damage_bonus(e))) / 100
	world.events.append({"type": "fired", "attacker": e.id, "weapon": w.def_id,
			"x": e.x, "y": e.y, "tx": t.x, "ty": t.y})
	if w.projectile == "instant":
		if w.cone_half > 0:
			_cone(world, e, w, t, damage)
			return
		_impact(world, e.player_id, e.id, t.id, t.x, t.y, damage, w.damage_type,
				w.splash_radius, w.splash_edge_percent, w.targets, w.drone_attack or e.drone != null)
		return
	var p := SimProjectile.new()
	p.id = world.next_projectile_id()
	p.guided = w.projectile == "guided"
	p.player_id = e.player_id
	p.attacker_id = e.id
	p.target_id = t.id
	p.x = e.x
	p.y = e.y
	p.prev_x = e.x
	p.prev_y = e.y
	p.dest_x = t.x
	p.dest_y = t.y
	p.speed = w.projectile_speed
	p.damage = damage
	p.damage_type = w.damage_type
	p.splash_radius = w.splash_radius
	p.splash_edge_percent = w.splash_edge_percent
	p.weapon_id = w.def_id
	p.targets = w.targets
	p.needs_spotter = w.needs_spotter
	p.drone_hit = w.drone_attack or e.drone != null
	# Jamming (P2-03): a guided shot at a target inside a hostile field loses
	# its lock half the time and flies to a scattered point instead.
	if p.guided and world.jam_level(e.player_id, t.x, t.y) > 0 and world.rng.chance(1, 2):
		var angle: int = world.rng.range_int(Fx.ANGLE_FULL)
		var miss: int = 4 * Fx.ONE + world.rng.range_int(6 * Fx.ONE)
		p.guided = false
		p.target_id = 0
		p.dest_x = clampi(t.x + Fx.mul(Fx.cos_a(angle), miss), 0, world.map_width)
		p.dest_y = clampi(t.y + Fx.mul(Fx.sin_a(angle), miss), 0, world.map_height)
		world.events.append({"type": "jammed_shot", "x": t.x, "y": t.y})
	world.projectiles.append(p)


static func _step_projectiles(world: SimWorld) -> void:
	var still_flying: Array[SimProjectile] = []
	for p: SimProjectile in world.projectiles:
		p.prev_x = p.x
		p.prev_y = p.y
		KillChainSystem.check_guidance(world, p)
		if ProtectionSystem.try_intercept(world, p):
			continue   # shot down by active protection
		if p.guided:
			var t: SimEntity = world.get_entity(p.target_id)
			if t != null and not t.dead:
				p.dest_x = t.x
				p.dest_y = t.y
		var dx: int = p.dest_x - p.x
		var dy: int = p.dest_y - p.y
		var dist: int = Fx.length(dx, dy)
		if dist > p.speed:
			p.x += (dx * p.speed) / dist
			p.y += (dy * p.speed) / dist
			still_flying.append(p)
			continue
		p.x = p.dest_x
		p.y = p.dest_y
		_impact(world, p.player_id, p.attacker_id, p.target_id, p.x, p.y, p.damage, p.damage_type,
				p.splash_radius, p.splash_edge_percent, p.targets, p.drone_hit)
	world.projectiles = still_flying


## Applies a hit at (x, y). Without splash, only the intended target is hurt,
## and only if it is still there; with splash, every enemy in the radius is.
static func _impact(world: SimWorld, player_id: int, attacker_id: int, target_id: int, x: int, y: int,
		damage: int, damage_type: String, splash_radius: int, edge_percent: int,
		targets: PackedStringArray, drone_hit: bool = false) -> void:
	world.events.append({"type": "hit", "x": x, "y": y, "damage_type": damage_type, "radius": splash_radius})
	if splash_radius <= 0:
		var t: SimEntity = world.get_entity(target_id)
		if t != null and not t.dead and Fx.length(t.x - x, t.y - y) <= t.radius + Fx.ONE / 2:
			world.apply_damage(t, damage, damage_type, attacker_id, drone_hit)
		return
	for t: SimEntity in world.query_radius(x, y, splash_radius + SimWorld.MAX_UNIT_RADIUS):
		if t.dead or not world.are_enemies(player_id, t.player_id):
			continue
		if not targets.is_empty() and not DamageMatrix.can_target(targets, t.armor_class):
			continue
		var dist: int = maxi(0, Fx.length(t.x - x, t.y - y) - t.radius)
		if dist > splash_radius:
			continue
		var percent: int = 100 - ((100 - edge_percent) * dist) / splash_radius
		world.apply_damage(t, (damage * percent) / 100, damage_type, attacker_id, drone_hit)


## Cone hit (P2-02): every visible enemy the weapon can target, in range and
## within cone_half of the direction to the aimed target, in id order.
static func _cone(world: SimWorld, e: SimEntity, w: SimWeapon, aimed: SimEntity, damage: int) -> void:
	var heading: int = Fx.atan2_a(aimed.y - e.y, aimed.x - e.x)
	world.events.append({"type": "hit", "x": aimed.x, "y": aimed.y, "damage_type": w.damage_type, "radius": 0})
	var hits: Array[SimEntity] = []
	for t: SimEntity in world.query_enemies(e.player_id, e.x, e.y, w.max_range + SimWorld.MAX_UNIT_RADIUS):
		if t.dead or not DamageMatrix.can_target(w.targets, t.armor_class) or not in_range(e, w, t):
			continue
		if not world.can_see(e.player_id, t.x, t.y):
			continue
		if t.id != aimed.id and absi(Fx.angle_diff(heading, Fx.atan2_a(t.y - e.y, t.x - e.x))) > w.cone_half:
			continue
		hits.append(t)
	hits.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return a.id < b.id)
	for t: SimEntity in hits:
		world.apply_damage(t, damage, w.damage_type, e.id, e.drone != null)


## A spoofed drone fires only at the target spoofing gave it, friend or foe.
static func _fire_spoofed(world: SimWorld, e: SimEntity) -> void:
	for w: SimWeapon in e.weapons:
		if w.cooldown > 0:
			w.cooldown -= 1
		var t: SimEntity = world.get_entity(w.target_id) if w.target_id != 0 else null
		if t == null or t.dead or not in_range(e, w, t):
			continue
		if w.cooldown == 0:
			_fire(world, e, w, t)
