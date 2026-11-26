extends SceneTree
## Performance harness (P1-33). Runs fixed scenarios headless and records the
## sim's milliseconds per tick (and the view's sync time), then compares them
## with res://tests/perf/perf_baseline.json.
##
## Machines differ, so every run also times a fixed calibration workload and
## the regression check uses normalized numbers: ms per tick / calibration ms.
## A scenario fails when its normalized median is more than TOLERANCE above
## the baseline.
##
## Usage (from the repo root): tools/run_perf.sh [--update-baseline]

const BASELINE_PATH: String = "res://tests/perf/perf_baseline.json"
const TOLERANCE: float = 0.20
## The view scenario times about 2 ms of work per frame and varies more from
## run to run, so it gets a looser limit.
const TOLERANCE_OVERRIDES: Dictionary = {"view_300": 0.5, "effects_50": 0.5}
const SEED: int = 4242

var _content: ContentDb
var _seq: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var update: bool = OS.get_cmdline_user_args().has("--update-baseline")
	_content = ContentDb.new()
	if not _content.load_all():
		printerr("run_perf: content failed to load: ", ", ".join(_content.errors))
		quit(2)
		return
	if OS.get_cmdline_user_args().has("--profile"):
		_profile("battle_300", _battle_world(150), 300)
		_profile("march_300", _march_world(300), 300)
		quit(0)
		return
	var calib_ms: float = _calibrate()
	print("calibration: %.2f ms" % calib_ms)
	var results: Dictionary = {"calibration_ms": calib_ms, "scenarios": {}}
	var scenarios: Dictionary = results["scenarios"]
	# The sim is deterministic, so each repeat does identical work; the fastest
	# repeat is the best estimate (noise from other processes only adds time).
	scenarios["battle_300"] = _best([_sim_scenario(_battle_world(150), 450, calib_ms),
			_sim_scenario(_battle_world(150), 450, calib_ms), _sim_scenario(_battle_world(150), 450, calib_ms)])
	scenarios["march_300"] = _best([_sim_scenario(_march_world(300), 450, calib_ms),
			_sim_scenario(_march_world(300), 450, calib_ms), _sim_scenario(_march_world(300), 450, calib_ms)])
	var views: Array[Dictionary] = []
	for r: int in 3:
		views.append(await _view_scenario(_battle_world(150), 120, calib_ms))
	scenarios["view_300"] = _best(views)
	var fx_runs: Array[Dictionary] = []
	for r: int in 3:
		fx_runs.append(await _effects_scenario(180, calib_ms))
	scenarios["effects_50"] = _best(fx_runs)
	for name: String in scenarios:
		var r: Dictionary = scenarios[name]
		print("%-11s median %6.2f ms  p95 %6.2f ms  max %6.2f ms  (normalized %.3f, %d entities)" % [
			name, r["median_ms"], r["p95_ms"], r["max_ms"], r["median_norm"], r["entities"]])
	_write_json(_output_path(), results)
	if update:
		_write_json(ProjectSettings.globalize_path(BASELINE_PATH), results)
		print("run_perf: baseline updated")
		quit(0)
		return
	quit(_compare(results))


## Compares normalized medians with the baseline. 0 = ok, 1 = regression.
func _compare(results: Dictionary) -> int:
	if not FileAccess.file_exists(BASELINE_PATH):
		print("run_perf: no baseline yet; run with --update-baseline")
		return 0
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	var failed: bool = false
	for name: String in results["scenarios"]:
		var base: Dictionary = baseline.get("scenarios", {}).get(name, {})
		if base.is_empty():
			print("run_perf: %s has no baseline entry" % name)
			continue
		var now: float = results["scenarios"][name]["median_norm"]
		var was: float = base["median_norm"]
		var change: float = (now - was) / maxf(was, 0.000001)
		var verdict: String = "ok"
		var limit: float = TOLERANCE_OVERRIDES.get(name, TOLERANCE)
		if change > limit:
			verdict = "REGRESSION"
			failed = true
		print("%-11s normalized %.3f vs baseline %.3f (%+.0f%%) %s" % [name, now, was, change * 100.0, verdict])
	if failed:
		printerr("run_perf: FAIL, a scenario is slower than its baseline allows (%d%%, view %d%%)" % [
				roundi(TOLERANCE * 100.0), roundi(float(TOLERANCE_OVERRIDES["view_300"]) * 100.0)])
		return 1
	print("run_perf: ok")
	return 0


## Two armies attack-move into each other on an open 256 m map.
func _battle_world(per_side: int) -> SimWorld:
	var world := _empty_world(256)
	var mix: Array[Array] = [["us_rifle_squad", "kp_infantry_squad", 40], ["us_at_team", "kp_at_team", 20],
			["us_mbt", "kp_mbt", 25], ["us_ifv", "kp_ifv", 15]]
	for side: int in [1, 2]:
		var ids: Array[int] = []
		var x0: int = 30 if side == 1 else 226
		var i: int = 0
		for m: Array in mix:
			var count: int = per_side * int(m[2]) / 100
			for k: int in count:
				var def: UnitDef = _content.get_unit(str(m[0] if side == 1 else m[1]))
				var x: int = x0 + (i % 6) * 5 * (1 if side == 1 else -1)
				var y: int = 30 + (i / 6) * 7 % 196
				ids.append(world.spawn_unit(def, side, Fx.from_int(x), Fx.from_int(y), 0 if side == 1 else Fx.ANGLE_FULL / 2))
				i += 1
		_queue(world, side, SimCommand.make_attack_move(ids, Fx.from_int(256 - x0), Fx.from_int(128)))
	return world


## One player's units cross the sandbox map in groups of 12 (pathfinding,
## group movement and separation).
func _march_world(count: int) -> SimWorld:
	var sc: Dictionary = (_content.scenarios["sandbox"] as Dictionary).duplicate(true)
	sc["spawns"] = []
	sc["victory"] = "none"
	var world: SimWorld = MatchSetup.build_from(_content, sc, SEED)
	var def: UnitDef = _content.get_unit("us_ifv")
	var group: Array[int] = []
	for i: int in count:
		var x: int = 6 + (i % 10) * 3
		var y: int = 8 + (i / 10) * 4 % 112
		group.append(world.spawn_unit(def, 1, Fx.from_int(x), Fx.from_int(y), 0))
		if group.size() == 12 or i == count - 1:
			_queue(world, 1, SimCommand.make_move(group, Fx.from_int(118), Fx.from_int(20 + (i / 12) * 4 % 90)))
			group = []
	return world


func _empty_world(size_m: int) -> SimWorld:
	var world := SimWorld.new(SEED, size_m, size_m)
	world.content = _content
	world.damage_matrix = _content.damage_matrix
	world.rules = _content.rules
	world.victory_rule = "none"
	for pid: int in [1, 2]:
		world.player_team[pid] = pid
		world.get_player(pid).team = pid
	return world


func _queue(world: SimWorld, player: int, c: SimCommand) -> void:
	c.player_id = player
	c.tick = world.tick
	_seq += 1
	c.seq = _seq
	world.queue_command(c)


func _sim_scenario(world: SimWorld, ticks: int, calib_ms: float) -> Dictionary:
	var samples: PackedFloat64Array = []
	for t: int in ticks:
		var start: int = Time.get_ticks_usec()
		world.step()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	return _summary(samples, calib_ms, world.entity_ids.size())


## Times GameView.sync (the per-frame view scripts) with every entity shown.
func _view_scenario(world: SimWorld, frames: int, calib_ms: float) -> Dictionary:
	var view := GameView.new()
	view.setup(world, _content)
	view.local_player_id = 1
	root.add_child(view)
	view.sync(0.0)
	var samples: PackedFloat64Array = []
	for f: int in frames:
		if f % 4 == 0:
			world.step()
		var start: int = Time.get_ticks_usec()
		view.sync(float(f % 4) / 4.0)
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
	view.queue_free()
	return _summary(samples, calib_ms, world.entity_ids.size())


func _best(runs: Array) -> Dictionary:
	var best: Dictionary = runs[0]
	for r: Dictionary in runs:
		if r["median_ms"] < best["median_ms"]:
			best = r
	return best


## 50 explosions per second (plus muzzle flashes and tracers) on top of the
## view: times the per-frame cost of starting pooled effects.
func _effects_scenario(frames: int, calib_ms: float) -> Dictionary:
	var world: SimWorld = _battle_world(150)
	var view := GameView.new()
	view.setup(world, _content)
	root.add_child(view)
	view.sync(0.0)
	var samples: PackedFloat64Array = []
	var carry: float = 0.0
	for f: int in frames:
		carry += 50.0 / 60.0          # 50 per second at 60 fps
		var start: int = Time.get_ticks_usec()
		while carry >= 1.0:
			carry -= 1.0
			var at := Vector3(float(f % 200) + 20.0, 0.5, float((f * 7) % 200) + 20.0)
			view.effects.play(CombatEffects.Kind.EXPLOSION, at, 1.5)
			view.effects.play(CombatEffects.Kind.MUZZLE, at + Vector3(0, 1, 0))
			view.effects.tracer(at + Vector3(0, 1, 0), at + Vector3(20, 1, 0))
		view.sync(0.0)
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
	view.queue_free()
	return _summary(samples, calib_ms, world.entity_ids.size())


func _summary(samples: PackedFloat64Array, calib_ms: float, entities: int) -> Dictionary:
	var sorted: PackedFloat64Array = samples.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	return {
		"median_ms": snappedf(median, 0.001),
		"p95_ms": snappedf(sorted[int(sorted.size() * 0.95)], 0.001),
		"max_ms": snappedf(sorted[sorted.size() - 1], 0.001),
		"median_norm": snappedf(median / calib_ms, 0.0001),
		"samples": samples.size(),
		"entities": entities,
	}


## A fixed GDScript workload (int math, array and dictionary access, like the
## sim). Best of 7 runs, in ms.
func _calibrate() -> float:
	var best: float = INF
	for run: int in 7:
		var start: int = Time.get_ticks_usec()
		var arr := PackedInt32Array()
		arr.resize(4096)
		var dict: Dictionary[int, int] = {}
		var acc: int = 1
		for i: int in 200000:
			acc = (acc * 1103515245 + 12345) & 0x7fffffff
			arr[i & 4095] = acc >> 8
			if i & 63 == 0:
				dict[i & 1023] = arr[(acc >> 4) & 4095]
		best = minf(best, (Time.get_ticks_usec() - start) / 1000.0)
	return best


func _output_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../build/perf/latest.json").simplify_path()


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	print("run_perf: wrote ", path)


## --profile: time each system separately. This mirrors SimWorld.step() for
## diagnosis only; keep it in the same order when step() changes.
func _profile(name: String, world: SimWorld, ticks: int) -> void:
	var parts: Dictionary[String, int] = {}
	var steps: Array = [
		["commands", func() -> void: world._apply_commands()],
		["order", func() -> void: OrderSystem.step(world)],
		["power", func() -> void: PowerSystem.step(world)],
		["construction", func() -> void: ConstructionSystem.step(world)],
		["production", func() -> void: ProductionSystem.step(world)],
		["gather", func() -> void: GatherSystem.step(world)],
		["pathing", func() -> void: PathingSystem.step(world)],
		["movement", func() -> void: MovementSystem.step(world)],
		["separation", func() -> void: SeparationSystem.step(world)],
		["vision", func() -> void:
			if world.tick % SimVision.UPDATE_INTERVAL == 0:
				world.vision.update(world)],
		["index", func() -> void: world._rebuild_index()],
		["combat", func() -> void: CombatSystem.step(world)],
		["veterancy", func() -> void: VeterancySystem.step(world)],
		["victory", func() -> void: VictorySystem.step(world)],
		["remove_dead", func() -> void: world._remove_dead()],
	]
	for t: int in ticks:
		world.events.clear()
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			e.prev_x = e.x
			e.prev_y = e.y
			e.prev_facing = e.facing
		for st: Array in steps:
			var start: int = Time.get_ticks_usec()
			(st[1] as Callable).call()
			parts[st[0]] = parts.get(st[0], 0) + Time.get_ticks_usec() - start
		world.tick += 1
	print("== %s: average ms per tick by system" % name)
	for k: String in parts:
		if parts[k] > ticks * 10:
			print("  %-13s %7.2f" % [k, parts[k] / 1000.0 / ticks])
