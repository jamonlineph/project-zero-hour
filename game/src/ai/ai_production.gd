class_name AiProduction
extends RefCounted
## What the skirmish AI's factories build (split out of AiPlayer in P2-11e).
## Each idle factory picks the unit type the army lacks most against the
## preset's unit mix (plus counters, AiStrategy), at most `max_spotters`
## unarmed recon drones; then it buys in order of need and saves for the
## neediest unit when it can't afford it yet.


static func produce(world: SimWorld, ai: AiPlayer, army: Array[SimEntity], buildings: Array[SimEntity],
		cmds: Array[SimCommand], reserve: int) -> void:
	var credits: int = world.get_player(ai.player_id).credits - reserve
	var counts: Dictionary[String, int] = {}
	for e: SimEntity in army:
		counts[e.def_id] = counts.get(e.def_id, 0) + 1
	# Units still being built count too, so a factory doesn't queue the same
	# missing type over and over before the first one is out (P2-11c).
	for b: SimEntity in buildings:
		for queued: String in b.building.queue:
			counts[queued] = counts.get(queued, 0) + 1
	var mix: Dictionary[String, int] = ai.unit_mix.duplicate()
	var bonus: Dictionary[String, int] = AiStrategy.counter_bonus(world, ai)
	for u: String in bonus:
		mix[u] = mix.get(u, 0) + bonus[u]
	var total_weight: int = 0
	for u: String in mix:
		total_weight += mix[u]
	var spotters: int = 0
	for u: String in counts:
		if unarmed_spotter(world, u):
			spotters += counts[u]
	# Each idle factory's most-needed unit first; then buy in order of need,
	# and when the neediest can't be afforded yet, stop and save for it.
	# Without saving, the barracks spent every credit and America's depot
	# never built its 1300-credit rocket artillery or much else (P2-11e).
	var choices: Array[Dictionary] = []
	for b: SimEntity in buildings:
		if not b.building.built or b.building.queue.size() >= 2:
			continue
		var best: String = ""
		var best_score: int = 0
		for u: String in b.building.produces:
			if not mix.has(u) or (spotters >= ai.max_spotters and unarmed_spotter(world, u)):
				continue
			var def: UnitDef = world.content.get_unit(u)
			if def == null or not world.has_requirements(ai.player_id, def.requires):
				continue
			# How far below its share of the army this unit type is, plus up
			# to one unit's worth of noise so mixes vary between matches.
			var score: int = (army.size() + 1) * mix[u] - counts.get(u, 0) * total_weight \
				+ ai.noise(total_weight)
			if best == "" or score > best_score or (score == best_score and u < best):
				best = u
				best_score = score
		if best != "":
			choices.append({"score": best_score, "building": b.id, "unit": best})
	choices.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		return a["score"] > c["score"] or (a["score"] == c["score"] and a["building"] < c["building"]))
	for choice: Dictionary in choices:
		var def: UnitDef = world.content.get_unit(choice["unit"])
		if credits < def.cost:
			break
		cmds.append(SimCommand.make_produce(choice["building"], choice["unit"]))
		credits -= def.cost


static func unarmed_spotter(world: SimWorld, unit_id: String) -> bool:
	var def: UnitDef = world.content.get_unit(unit_id)
	return def != null and def.spotter and def.weapons.is_empty()
