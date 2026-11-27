extends SceneTree
## Plays AI-vs-AI skirmishes headless and logs the results (P2-11).
## Usage: godot --headless --path game --script res://tests/tools/ai_matches.gd -- [runs] [p1_level] [p2_level] [swap] [map=<id>] [seed=<first>] [stats]
## "swap" trades the two factions between the start positions (tells a
## faction imbalance apart from a map-side bias).
## Writes build/ai/results.json and prints a summary. Used for balance and
## map fairness checks (P2-12 needs neither side above 55% over 40 runs).

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 10
	var levels: Array = [args[1] if args.size() > 1 else "normal", args[2] if args.size() > 2 else "normal"]
	var swap: bool = args.has("swap")
	var map_id: String = ""
	var first_seed: int = 1000
	for a: String in args:
		if a.begins_with("map="):
			map_id = a.trim_prefix("map=")
		elif a.begins_with("seed="):
			first_seed = int(a.trim_prefix("seed="))
	var db := ContentDb.new()
	if not db.load_all():
		printerr("ai_matches: content failed to load")
		quit(1)
		return
	var results: Array = []
	var wins: Dictionary = {0: 0, 1: 0, 2: 0}
	var produced: Dictionary = {}   ## player -> def_id -> count, over all runs
	var lost: Dictionary = {}
	for r: int in runs:
		var sc: Dictionary = (db.scenarios["ai_duel"] as Dictionary).duplicate(true)
		for i: int in 2:
			(sc["players"] as Array)[i]["difficulty"] = levels[i]
		if swap:
			_swap_factions(sc)
		if map_id != "":
			sc["map"] = map_id
		var runner := SimRunner.new()
		runner.world = MatchSetup.build_from(db, sc, first_seed + r)
		runner.players = [1, 2]
		runner.local_players = []
		runner.local_player_id = 0
		runner.add_ai_from_scenario(db, sc)
		runner.start()
		var limit: int = SimWorld.TICK_RATE * 60 * 30
		var powers: int = 0
		while not runner.world.game_over and runner.world.tick < limit:
			runner.try_step()
			for ev: Dictionary in runner.world.events:
				match ev["type"]:
					"power_used":
						powers += 1
					"produced":
						_count(produced, int(ev["player"]), str(ev["def_id"]))
					"died":
						_count(lost, int(ev["player"]), str(ev["def_id"]))
		var winner: int = runner.world.winner_team if runner.world.game_over else 0
		wins[winner] = int(wins[winner]) + 1
		var minutes: float = runner.world.tick / float(SimWorld.TICK_RATE * 60)
		results.append({"seed": first_seed + r, "winner_team": winner, "minutes": snappedf(minutes, 0.1), "powers_used": powers})
		print("run %d: winner team %d after %.1f min, %d powers used" % [r + 1, winner, minutes, powers])
		runner.free()
	var out: String = ProjectSettings.globalize_path("res://").path_join("../build/ai/results.json").simplify_path()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": levels, "runs": results, "wins": wins,
			"produced": produced, "lost": lost}, "  ") + "\n")
	f.close()
	if args.has("stats"):
		for pid: int in [1, 2]:
			print("player %d produced %s" % [pid, produced.get(pid, {})])
			print("player %d lost     %s" % [pid, lost.get(pid, {})])
	var p: Array = (db.scenarios["ai_duel"] as Dictionary)["players"]
	var f1: String = str(p[1 if swap else 0]["faction"])
	var f2: String = str(p[0 if swap else 1]["faction"])
	print("ai_matches: team 1 (%s, %s, west) %d, team 2 (%s, %s, east) %d, no result %d; wrote %s" % [
		f1, levels[0], wins[1], f2, levels[1], wins[2], wins[0], out])
	quit(0)


func _count(table: Dictionary, pid: int, def_id: String) -> void:
	if not table.has(pid):
		table[pid] = {}
	table[pid][def_id] = int(table[pid].get(def_id, 0)) + 1


## Trades factions, AI presets and starting units between the two players.
func _swap_factions(sc: Dictionary) -> void:
	var players: Array = sc["players"]
	var f0: String = str(players[0]["faction"])
	var f1: String = str(players[1]["faction"])
	for i: int in 2:
		var f: String = f1 if i == 0 else f0
		players[i]["faction"] = f
		if players[i].has("ai"):
			players[i]["ai"] = f + "_default"
	for s: Variant in sc.get("spawns", []):
		var spawn: Dictionary = s
		var def: String = str(spawn.get("def", ""))
		if def.begins_with(f0 + "_"):
			spawn["def"] = f1 + def.substr(f0.length())
		elif def.begins_with(f1 + "_"):
			spawn["def"] = f0 + def.substr(f1.length())
