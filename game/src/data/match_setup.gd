class_name MatchSetup
extends RefCounted
## Builds a SimWorld from a scenario: map, players, starting credits and
## starting units/buildings. Deterministic, so a replay only needs the
## scenario id, the seed and the command log (P1-20).
##
## Scenario JSON (game/data/scenarios/<id>.json):
##   "map": map id, "victory": "buildings" | "units" | "none",
##   "players": [{"id": 1, "team": 1, "faction": "us", "credits": 10000}],
##   "spawns":  [{"def": "us_mbt", "player": 1, "x_m": 30, "y_m": 56,
##                "count": 3, "step_x_m": 0, "step_y_m": 8, "facing_deg": 0,
##                "built": true}]


static func build(content: ContentDb, scenario_id: String, seed_value: int) -> SimWorld:
	var sc: Dictionary = content.scenarios.get(scenario_id, {})
	if sc.is_empty():
		push_error("MatchSetup: unknown scenario '%s'" % scenario_id)
		return null
	return build_from(content, sc, seed_value)


static func build_from(content: ContentDb, sc: Dictionary, seed_value: int) -> SimWorld:
	var map_def: MapDef = content.get_map(str(sc.get("map", "")))
	if map_def == null:
		push_error("MatchSetup: scenario '%s' has an unknown map" % str(sc.get("id", "?")))
		return null
	var world := SimWorld.from_map(seed_value, map_def)
	world.content = content
	world.damage_matrix = content.damage_matrix
	world.rules = content.rules
	world.victory_rule = str(sc.get("victory", "buildings"))
	for p: Variant in sc.get("players", []):
		var pd: Dictionary = p
		var pid: int = int(pd.get("id", 0))
		world.player_team[pid] = int(pd.get("team", pid))
		var player: SimPlayer = world.get_player(pid)
		player.team = world.team_of(pid)
		player.faction = str(pd.get("faction", ""))
		player.credits = int(pd.get("credits", 0))
	for site: PackedInt32Array in map_def.supply_sites:
		world.spawn_supply_site(Fx.from_int(site[0]), Fx.from_int(site[1]), site[2])
	for s: Variant in sc.get("spawns", []):
		_spawn(world, content, s as Dictionary)
	return world


static func _spawn(world: SimWorld, content: ContentDb, s: Dictionary) -> void:
	var def_id: String = str(s.get("def", ""))
	var player: int = int(s.get("player", 0))
	var count: int = int(s.get("count", 1))
	var x_m: int = int(s.get("x_m", 0))
	var y_m: int = int(s.get("y_m", 0))
	var step_x: int = int(s.get("step_x_m", 0))
	var step_y: int = int(s.get("step_y_m", 0))
	var facing: int = Fx.angle_from_degrees(int(s.get("facing_deg", 0)))
	for i: int in count:
		var x: int = Fx.from_int(x_m + i * step_x)
		var y: int = Fx.from_int(y_m + i * step_y)
		var unit: UnitDef = content.get_unit(def_id)
		if unit != null:
			world.spawn_unit(unit, player, x, y, facing)
			continue
		var building: BuildingDef = content.get_building(def_id)
		if building != null:
			var origin: Vector2i = SimWorld.footprint_origin(building, x, y)
			if world.spawn_building(building, player, origin.x, origin.y, bool(s.get("built", true))) == 0:
				push_error("MatchSetup: no room for %s at (%d, %d) m" % [def_id, x_m, y_m])
