class_name PowerSystem
extends RefCounted
## Recomputes every player's power from their finished buildings (P1-16).
## Low power (use > production) halves production speed and switches off
## weapons on powered structures (see CombatSystem).


static func step(world: SimWorld) -> void:
	for pid: int in world.players:
		world.players[pid].power_produced = 0
		world.players[pid].power_used = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.building == null or not e.building.built or e.dead or e.player_id == 0:
			continue
		var p: SimPlayer = world.get_player(e.player_id)
		if e.building.power >= 0:
			p.power_produced += e.building.power
		else:
			p.power_used -= e.building.power
