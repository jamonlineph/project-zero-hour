class_name VeterancySystem
extends RefCounted
## Top-rank veterans slowly repair themselves (P1-17). XP and promotions are
## granted in SimWorld.apply_damage.

const INTERVAL: int = 2 * SimWorld.TICK_RATE


static func step(world: SimWorld) -> void:
	if world.tick % INTERVAL != 0:
		return
	var percent: int = world.rules.self_repair_percent_per_2s
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.vet_rank < world.rules.self_repair_rank or e.hp >= e.max_hp:
			continue
		e.hp = mini(e.max_hp, e.hp + maxi(1, (e.max_hp * percent) / 100))
