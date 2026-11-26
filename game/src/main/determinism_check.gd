class_name DeterminismCheck
extends RefCounted
## Cross-device determinism check (P1-37). Plays the AI-vs-AI scenario named in
## data/determinism_check.json for a fixed number of ticks, then compares the
## final state hash with the hash a desktop computed. Run it on a phone (ARM)
## from Settings > Developer: a mismatch means the sim is not deterministic
## across CPUs, which would break multiplayer and replays.

var content: ContentDb
var ticks: int = 0
var expected: int = 0
var result: int = 0
var _runner: SimRunner


func _init(content_db: ContentDb) -> void:
	content = content_db
	var spec: Dictionary = content.determinism_check
	ticks = int(spec.get("ticks", 1800))
	expected = int(spec.get("expected_hash", 0))
	_runner = SimRunner.new()
	var scenario: String = str(spec.get("scenario", "ai_duel"))
	_runner.world = MatchSetup.build(content, scenario, int(spec.get("seed", 7)))
	_runner.players = [1, 2]
	_runner.local_players = []
	_runner.local_player_id = 0
	_runner.add_ai_from_scenario(content, content.scenarios.get(scenario, {}))
	_runner.start()


## Advances up to `budget` ticks. Returns true once the check is finished.
func advance(budget: int) -> bool:
	if _runner == null:
		return true
	var n: int = 0
	while _runner.world.tick < ticks and n < budget:
		_runner.try_step()
		n += 1
	if _runner.world.tick >= ticks:
		result = _runner.world.state_hash()
		_runner.free()
		_runner = null
		return true
	return false


func progress() -> float:
	return 1.0 if _runner == null else float(_runner.world.tick) / float(maxi(ticks, 1))


func matches() -> bool:
	return _runner == null and result == expected


## Runs the whole check at once (tests, tools).
func run() -> int:
	while not advance(1000):
		pass
	return result
