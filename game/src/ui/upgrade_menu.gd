class_name UpgradeMenu
extends RefCounted
## Command-grid entries for upgrades (P2-05): research buttons for a selected
## building, and per-unit kit buttons for selected units.


## Research entries for the upgrades researched at `building`.
static func research_entries(runner: SimRunner, player_id: int, building: SimEntity) -> Array[Dictionary]:
	var world: SimWorld = runner.world
	var player: SimPlayer = world.get_player(player_id)
	var out: Array[Dictionary] = []
	for def: UpgradeDef in world.content.upgrades_at(building.def_id):
		if def.faction != player.faction and player.faction != "":
			continue
		var done: bool = player.upgrades.has(def.id)
		var busy: bool = building.building.research_id != ""
		var mine: bool = building.building.research_id == def.id
		var ok: bool = not done and not busy and player.credits >= def.cost and player.rank >= def.requires_rank \
			and world.has_requirements(player_id, def.requires) and not Upgrades.researching(world, player_id, def.id)
		var label: String = "%s\n%d" % [Loc.t(def.name), def.cost]
		if done:
			label = Loc.t("%s\nDone") % Loc.t(def.name)
		elif mine:
			label = "%s\n%d%%" % [Loc.t(def.name), (100 * building.building.research_progress) / maxi(1, def.research_ticks)]
		var bid: int = building.id
		var up: String = def.id
		out.append({
			"label": label,
			"enabled": ok,
			"tooltip": Loc.t("Research %s (%d credits)%s") % [Loc.t(def.name), def.cost, _why_not(def, player, done, busy)],
			"action": func() -> void: runner.submit(SimCommand.make_research(bid, up)),
		})
	return out


## Per-unit kit entries for the selected units (at most `max_entries`).
static func kit_entries(runner: SimRunner, player_id: int, selected: Array[int], max_entries: int) -> Array[Dictionary]:
	var world: SimWorld = runner.world
	var player: SimPlayer = world.get_player(player_id)
	var out: Array[Dictionary] = []
	var ids: Array = world.content.upgrades.keys()
	ids.sort()
	for up_id: String in ids:
		var def: UpgradeDef = world.content.upgrades[up_id]
		if def.scope != "unit" or out.size() >= max_entries:
			continue
		var targets: Array[int] = []
		for id: int in selected:
			var e: SimEntity = world.get_entity(id)
			if e != null and def.applies(e.def_id) and not e.upgrades.has(def.id):
				targets.append(id)
		if targets.is_empty():
			continue
		var ok: bool = player.credits >= def.cost and player.rank >= def.requires_rank \
			and world.has_requirements(player_id, def.requires)
		out.append({
			"label": Loc.t("%s\n%d each") % [Loc.t(def.name), def.cost],
			"enabled": ok,
			"tooltip": Loc.t("Buy %s for %d selected unit(s)") % [Loc.t(def.name), targets.size()],
			"action": func() -> void: runner.submit(SimCommand.make_upgrade_unit(targets, up_id)),
		})
	return out


static func _why_not(def: UpgradeDef, player: SimPlayer, done: bool, busy: bool) -> String:
	if done:
		return ". Already researched."
	if busy:
		return ". This building is busy researching."
	if player.rank < def.requires_rank:
		return Loc.t(". Needs commander rank %d.") % def.requires_rank
	if player.credits < def.cost:
		return ". Not enough credits."
	return ""
