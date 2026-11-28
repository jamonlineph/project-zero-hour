class_name CommandMenus
extends RefCounted
## The command grid's entries for the current selection (split out of Hud on
## 2026-11-27): build menu for builders, orders for units, production and
## research for a building, "Exit all" for garrisoned buildings. UI only:
## actions submit SimCommands through the runner.

var _runner: SimRunner
var _selection: SelectionController
var _placement: PlacementController


func _init(runner: SimRunner, selection: SelectionController, placement: PlacementController) -> void:
	_runner = runner
	_selection = selection
	_placement = placement


## The entries for what is selected now.
func entries() -> Array[Dictionary]:
	var world: SimWorld = _runner.world
	var out: Array[Dictionary] = []
	var builders: bool = false
	var units: bool = false
	var producer: SimEntity = null
	var shelters: Array[int] = []   ## our buildings with units inside (P3-05)
	for id: int in _selection.selected:
		var e: SimEntity = world.get_entity(id)
		if e == null:
			continue
		if e.garrison != null and not e.garrison.occupants.is_empty():
			shelters.append(e.id)
		builders = builders or e.builder != null
		units = units or e.mover != null
		if producer == null and e.building != null and e.building.built \
				and (not e.building.produces.is_empty() or not world.content.upgrades_at(e.def_id).is_empty()):
			producer = e
	if builders:
		out = _build_menu(world)
	elif units:
		out = _unit_orders()
	elif producer != null:
		out = _production_menu(world, producer)
		out.append_array(UpgradeMenu.research_entries(_runner, _selection.local_player_id, producer))
	elif not units:
		out.append_array(_ability_entries(4))   # a superweapon building's launch (P3-03)
	if not shelters.is_empty() and not units:
		out.append({"label": "Exit all", "tooltip": "Everyone inside comes out",
			"action": func() -> void:
				for sid: int in shelters:
					_runner.submit(SimCommand.make_unload(sid))})
	return out


func _unit_orders() -> Array[Dictionary]:
	var none: Dictionary = {"label": "", "enabled": false}
	# Top row: per-unit upgrade kits for the selection (P2-05).
	var top: Array[Dictionary] = UpgradeMenu.kit_entries(_runner, _selection.local_player_id, _selection.selected, 4)
	while top.size() < 4:
		top.append(none)
	var out: Array[Dictionary] = [
		top[0], top[1], top[2], top[3],
		{"label": "Attack-move", "tooltip": "Then tap or click the target point", "action": func() -> void: _selection.attack_move_armed = true},
		{"label": "Stop", "action": _selection.order_stop},
		{"label": "Hold", "action": _selection.order_hold},
		{"label": "Patrol", "tooltip": "Then tap or click the far end of the route",
			"action": func() -> void:
				_selection.disarm()
				_selection.patrol_armed = true},
		{"label": "Guard", "tooltip": "Then tap or click the unit or building to guard (key G)",
			"action": func() -> void:
				_selection.disarm()
				_selection.guard_armed = true},
		_unload_entry() if _carrying() else _spoof_entry(),
	]
	out.append_array(_ability_entries(2))
	return out


## Buttons for the selected units' abilities (P3-02f), at most `slots`, each
## greyed out until one of the units has it ready.
func _ability_entries(slots: int) -> Array[Dictionary]:
	var world: SimWorld = _runner.world
	var out: Array[Dictionary] = []
	var seen: Dictionary[String, bool] = {}
	for id: int in _selection.selected:
		var e: SimEntity = world.get_entity(id)
		if e == null or e.player_id != _selection.local_player_id or (e.building != null and not e.building.built):
			continue
		for a: AbilityDef in AbilitySystem.abilities_of(world, e):
			if seen.has(a.id) or out.size() >= slots:
				continue
			seen[a.id] = true
			var ready: bool = false
			for sid: int in _selection.selected:
				var s: SimEntity = world.get_entity(sid)
				if s != null and s.def_id == e.def_id and world.tick >= int(s.ability_ready.get(a.id, 0)):
					ready = true
			var aid: String = a.id
			var label: String = a.name
			if a.kind == "superweapon" and not ready:
				var left: int = maxi(0, int(e.ability_ready.get(a.id, 0)) - world.tick) / SimWorld.TICK_RATE
				label = "%s\n%d:%02d" % [a.name, left / 60, left % 60]
			out.append({"label": label, "enabled": ready,
				"tooltip": "%s Then tap or click the %s." % [a.description, "building" if a.kind == "disable" else "target point"],
				"action": func() -> void:
					_selection.disarm()
					_selection.ability_armed = aid})
	return out


## True if a selected transport has passengers (P3-06).
func _carrying() -> bool:
	for id: int in _selection.selected:
		var e: SimEntity = _runner.world.get_entity(id)
		if e != null and e.mover != null and e.garrison != null and not e.garrison.occupants.is_empty():
			return true
	return false


## "Unload" for selected transports with passengers (P3-06).
func _unload_entry() -> Dictionary:
	return {"label": "Unload", "tooltip": "Everyone inside gets out",
		"action": func() -> void:
			for id: int in _selection.selected:
				var e: SimEntity = _runner.world.get_entity(id)
				if e != null and e.mover != null and e.garrison != null and not e.garrison.occupants.is_empty():
					_runner.submit(SimCommand.make_unload(e.id))}


## "Spoof" for selected jamming vehicles (P2-03), greyed out while cooling down.
func _spoof_entry() -> Dictionary:
	var world: SimWorld = _runner.world
	var any: bool = false
	var ready: bool = false
	for id: int in _selection.selected:
		var e: SimEntity = world.get_entity(id)
		if e != null and e.jammer != null and e.jammer.spoof_radius > 0:
			any = true
			ready = ready or world.tick >= e.jammer.spoof_ready_tick
	if not any:
		return {"label": "", "enabled": false}
	return {"label": "Spoof", "enabled": ready,
		"tooltip": "Then tap or click: enemy drones there fly off course and may attack their own side",
		"action": func() -> void:
			_selection.disarm()
			_selection.spoof_armed = true}


func _build_menu(world: SimWorld) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var player: SimPlayer = world.get_player(_selection.local_player_id)
	for def: BuildingDef in world.content.buildings.values():
		if def.faction != player.faction or entries.size() >= 12:
			continue
		var why: String = BaseCommands.blocker(world, _selection.local_player_id, def)
		var ok: bool = why == ""
		var reason: String = _missing(world, def.requires, def.cost)
		if not ok and reason == "":
			reason = " - " + why   # rank or limit (superweapons, P3-03)
		entries.append({
			"label": "%s\n%d" % [def.name, def.cost],
			"icon": _icon(def.icon_path),
			"enabled": ok,
			"tooltip": "%s (%d credits)%s" % [def.name, def.cost, "" if ok else reason],
			"action": func() -> void: _placement.begin(def.id),
		})
	return entries


func _production_menu(world: SimWorld, building: SimEntity) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var player: SimPlayer = world.get_player(_selection.local_player_id)
	for unit_id: String in building.building.produces:
		var def: UnitDef = world.content.get_unit(unit_id)
		if def == null:
			continue
		var queued: int = building.building.queue.count(unit_id)
		var ok: bool = player.credits >= def.cost and world.has_requirements(_selection.local_player_id, def.requires) \
			and building.building.queue.size() < SimBuilding.MAX_QUEUE
		var bid: int = building.id
		entries.append({
			"label": "%s\n%d%s" % [def.name, def.cost, " (x%d)" % queued if queued > 0 else ""],
			"icon": _icon(def.icon_path),
			"enabled": ok,
			"tooltip": "%s (%d credits). Right-click or Shift+key cancels one.%s" % [def.name, def.cost, "" if ok else _missing(world, def.requires, def.cost)],
			"action": func() -> void: _runner.submit(SimCommand.make_produce(bid, unit_id)),
			"alt_action": func() -> void: _cancel_last(bid, unit_id),
		})
	return entries


func _cancel_last(building_id: int, unit_id: String) -> void:
	var b: SimEntity = _runner.world.get_entity(building_id)
	if b == null or b.building == null:
		return
	var slot: int = b.building.queue.rfind(unit_id)
	if slot >= 0:
		_runner.submit(SimCommand.make_cancel(building_id, slot))


func _missing(world: SimWorld, requires: PackedStringArray, cost: int) -> String:
	var parts: PackedStringArray = []
	if world.get_player(_selection.local_player_id).credits < cost:
		parts.append("not enough credits")
	for r: String in requires:
		if not world.has_requirements(_selection.local_player_id, [r]):
			var def: BuildingDef = world.content.get_building(r)
			parts.append("needs " + (def.name if def != null else r))
	return " - " + ", ".join(parts) if not parts.is_empty() else ""


func _icon(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null
