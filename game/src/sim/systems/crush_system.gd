class_name CrushSystem
extends RefCounted
## Crushing (P3-07): a moving crusher (a unit with "crusher": true in its
## data, the main battle tanks) runs down enemies it drives into.
##
## - A victim is crushed while it touches the crusher (their circles overlap)
##   and lies ahead of the crusher's movement this tick. Separation keeps
##   pushing it in front of the hull, so a tank that keeps driving into a
##   squad grinds it down; a squad brushed from the side or behind is safe,
##   and a parked tank crushes no one.
## - Damage per tick: rules.crush_percent_per_s of the victim's max hp, a
##   fifteenth of that per tick, as damage type "crush". The damage matrix
##   decides who can be crushed (infantry only, today).
## - Never friends, neutrals, flying units or units inside a building.
## Runs after the spatial index is rebuilt and before combat.


static func step(world: SimWorld) -> void:
	if world.rules.crush_percent_per_s <= 0:
		return
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if not e.crusher or e.dead or e.inside_id != 0:
			continue
		var vx: int = e.x - e.prev_x
		var vy: int = e.y - e.prev_y
		if vx == 0 and vy == 0:
			continue
		for v: SimEntity in world.query_enemies(e.player_id, e.x, e.y, e.radius + SimWorld.MAX_UNIT_RADIUS):
			if v.dead or v.inside_id != 0 or v.mover == null or v.mover.flying:
				continue
			var dx: int = v.x - e.x
			var dy: int = v.y - e.y
			if Fx.length(dx, dy) >= e.radius + v.radius:
				continue   # not touching
			# Ahead of the tank: the direction to the victim agrees with the
			# tank's movement. Both are small (meters), so the products fit.
			if Fx.mul(dx, vx) + Fx.mul(dy, vy) <= 0:
				continue
			if world.damage_matrix.percent("crush", v.armor_class) <= 0:
				continue
			var amount: int = maxi(1, (v.max_hp * world.rules.crush_percent_per_s) / (100 * SimWorld.TICK_RATE))
			world.apply_damage(v, amount, "crush", e.id)
