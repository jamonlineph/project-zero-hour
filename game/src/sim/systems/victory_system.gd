class_name VictorySystem
extends RefCounted
## Defeat and victory (P1-19), checked once per second.
##
## - "buildings" rule: a player with no buildings and no builders left is
##   defeated, and their remaining units are removed.
## - "units" rule: a player with nothing left at all is defeated.
## - "none": no one ever loses (sandbox).
## When at most one team has undefeated players, the game is over; that team
## wins (winner_team 0 means everyone was eliminated at once: a draw).


static func step(world: SimWorld) -> void:
	if world.game_over or world.victory_rule == "none" or world.tick % SimWorld.TICK_RATE != 0:
		return
	var ids: Array[int] = []
	for pid: int in world.players:
		ids.append(pid)
	ids.sort()
	if ids.is_empty():
		return
	var assets: Dictionary[int, int] = {}
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.player_id == 0 or e.strike != null or e.sensor or e.ttl > 0:   # strikes in flight don't keep a player alive
			continue
		var counts: bool = world.victory_rule == "units" or e.building != null or e.builder != null
		if counts:
			assets[e.player_id] = assets.get(e.player_id, 0) + 1
	for pid: int in ids:
		var p: SimPlayer = world.players[pid]
		if p.defeated or assets.get(pid, 0) > 0:
			continue
		p.defeated = true
		world.events.append({"type": "defeated", "player": pid})
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			if e.player_id == pid:
				e.dead = true
	var teams: Dictionary[int, bool] = {}
	for pid: int in ids:
		if not world.players[pid].defeated:
			teams[world.team_of(pid)] = true
	if teams.size() <= 1:
		world.game_over = true
		world.winner_team = teams.keys()[0] if teams.size() == 1 else 0
		world.events.append({"type": "game_over", "winner_team": world.winner_team})
