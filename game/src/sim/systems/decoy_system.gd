class_name DecoySystem
extends RefCounted
## Decoys (P2-08), after KillChainSystem.
##
## A decoy (unit data "decoy_of": the unit it imitates) looks like the real
## unit to every enemy team until that team sees through it: one of its
## units comes within REVEAL_RANGE, or one of its spotter drones flies within
## FLYOVER_RANGE. Revealing is permanent and per team. Enemies target an
## unrevealed decoy like the real thing; once revealed they ignore it.
## Decoys have 1 hp, so any hit destroys them.

const REVEAL_RANGE: int = 15 * Fx.ONE
const FLYOVER_RANGE: int = 12 * Fx.ONE


static func step(world: SimWorld) -> void:
	for id: int in world.entity_ids:
		var d: SimEntity = world.entities[id]
		if d.dead or d.decoy_of == "":
			continue
		for t: SimEntity in world.query_enemies(d.player_id, d.x, d.y, REVEAL_RANGE):
			if t.dead or t.strike != null:
				continue
			var team: int = world.team_of(t.player_id)
			if revealed_to(d, team):
				continue
			var reach: int = FLYOVER_RANGE if t.drone != null else REVEAL_RANGE
			if t.drone != null and not t.spotter:
				continue   # only recon drones scout decoys from the air
			if Fx.length_sq(t.x - d.x, t.y - d.y) <= reach * reach:
				d.revealed_mask |= 1 << team
				world.events.append({"type": "decoy_revealed", "id": d.id, "team": team})


static func revealed_to(d: SimEntity, team: int) -> bool:
	return (d.revealed_mask >> team) & 1 == 1


## True if `viewer_player` should treat `t` as a decoy it has seen through.
static func is_known_decoy(world: SimWorld, viewer_player: int, t: SimEntity) -> bool:
	return t.decoy_of != "" and revealed_to(t, world.team_of(viewer_player))
