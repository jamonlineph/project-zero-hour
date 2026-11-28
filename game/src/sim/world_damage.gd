class_name WorldDamage
extends RefCounted
## Damage, deaths and experience (split out of SimWorld in P2-11d). Callers
## use SimWorld.apply_damage.


## Deals damage after armor (damage matrix, then the target's veterancy) and
## grants XP to the attacker and its player. Returns the damage dealt. An
## entity reaching 0 hp is marked dead and removed at the end of the tick.
static func apply(world: SimWorld, target: SimEntity, amount: int, damage_type: String, attacker_id: int, drone_hit: bool) -> int:
	if target.dead or (target.building != null and target.building.collapsed):
		return 0
	amount = ProtectionSystem.cage(target, amount, drone_hit)   # P2-06
	var raw: int = world.damage_matrix.apply(amount, damage_type, target.armor_class)
	if raw > 0:
		raw = maxi(1, (raw * (100 - world.rules.veterancy_armor_bonus[target.vet_rank])) / 100)
	var dealt: int = mini(raw, target.hp)
	target.hp -= dealt
	# A thermobaric hit on a garrisoned building also burns the units inside (P3-05).
	if damage_type == "thermobaric" and target.garrison != null:
		for oid: int in target.garrison.occupants:
			var o: SimEntity = world.get_entity(oid)
			if o != null and not o.dead:
				apply(world, o, (amount * GarrisonSystem.CLEAR_PERCENT) / 100, damage_type, attacker_id, false)
	var attacker: SimEntity = world.get_entity(attacker_id)
	if attacker != null and dealt > 0 and world.are_enemies(attacker.player_id, target.player_id):
		_grant_xp(world, attacker, (dealt * target.cost) / maxi(1, target.max_hp))
	if target.hp <= 0 and target.building != null and target.building.bridge:
		BridgeSystem.collapse(world, target)   # bridges fall, they don't die (P3-11)
		return dealt
	if target.hp <= 0:
		target.dead = true
		world.events.append({"type": "died", "id": target.id, "def_id": target.def_id,
				"player": target.player_id, "x": target.x, "y": target.y, "killer": attacker_id})
		if attacker != null and target.building != null and world.are_enemies(attacker.player_id, target.player_id):
			_grant_player_xp(world, attacker.player_id, (target.cost * world.rules.building_kill_xp_percent) / 100)
	return dealt


static func _grant_xp(world: SimWorld, attacker: SimEntity, amount: int) -> void:
	if amount <= 0:
		return
	attacker.xp += amount
	var base: int = maxi(100, attacker.cost)
	while attacker.vet_rank < 3 and attacker.xp >= base * world.rules.veterancy_xp_multipliers[attacker.vet_rank]:
		attacker.vet_rank += 1
		world.events.append({"type": "promoted", "id": attacker.id, "rank": attacker.vet_rank})
	_grant_player_xp(world, attacker.player_id, amount)


static func _grant_player_xp(world: SimWorld, player_id: int, amount: int) -> void:
	if amount <= 0 or player_id == 0:
		return
	var p: SimPlayer = world.get_player(player_id)
	p.xp += amount
	var new_rank: int = 1
	for i: int in world.rules.commander_rank_xp.size():
		if p.xp >= world.rules.commander_rank_xp[i]:
			new_rank = i + 1
	if new_rank > p.rank:
		p.rank = new_rank
		world.events.append({"type": "rank_up", "player": player_id, "rank": new_rank})
