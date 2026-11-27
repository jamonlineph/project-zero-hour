class_name SaveLoader
extends RefCounted
## Fast-forwards a freshly built match to a save's moment (P3-22). The human
## players' recorded commands are fed back at their ticks; AI players think
## again (they're deterministic, so they give the same orders and end up with
## the same plans). Call advance() a chunk at a time so a loading screen can
## show progress.

var runner: SimRunner
var target_tick: int = 0
var expected_hash: int = 0


## Prepares `runner` (built from the save's scenario and seed, started, AI
## added) to replay the save `data` (SaveGame.read).
func begin(sim_runner: SimRunner, data: Dictionary) -> void:
	runner = sim_runner
	var replay: Replay = Replay.from_dict(data)
	target_tick = replay.end_tick
	expected_hash = int(data.get("state_hash", 0))
	var by_player: Dictionary[int, Array] = {}
	for c: Dictionary in replay.commands:
		var pid: int = int(c.get("player_id", 0))
		if runner.ai_players.has(pid):
			continue   # the AI will give these orders again
		if not by_player.has(pid):
			by_player[pid] = []
		by_player[pid].append(c)
	for pid: int in runner.players:
		if not runner.ai_players.has(pid):
			runner.preload_commands(pid, by_player.get(pid, []), target_tick)


## Runs up to `max_ticks` ticks. Returns true once the save's tick is reached.
func advance(max_ticks: int) -> bool:
	var n: int = 0
	while runner.world.tick < target_tick and n < max_ticks:
		if not runner.try_step():
			break
		n += 1
	return done()


func done() -> bool:
	return runner.world.tick >= target_tick


## 0..1 for a progress bar.
func progress() -> float:
	return 1.0 if target_tick <= 0 else clampf(float(runner.world.tick) / float(target_tick), 0.0, 1.0)


## True if the rebuilt match matches the save exactly (same state hash).
func matches() -> bool:
	return done() and runner.world.state_hash() == expected_hash
