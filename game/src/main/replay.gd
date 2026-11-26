class_name Replay
extends RefCounted
## A recorded match: scenario, seed, content hash and every command, plus
## state-hash checkpoints for verification (P1-20). Playing it back rebuilds
## the same world with MatchSetup and feeds the same commands at the same ticks.

const FORMAT: int = 1
const GAME_VERSION: String = "0.0.1"

var scenario_id: String = ""
## Embedded scenario for matches made in the menu; empty = look up scenario_id.
var scenario_data: Dictionary = {}
var seed_value: int = 0
var content_hash: int = 0
var commands: Array[Dictionary] = []      ## SimCommand.to_dict() entries
var checkpoints: Dictionary[int, int] = {}  ## tick -> state hash
var end_tick: int = 0


func to_dict() -> Dictionary:
	var cp: Dictionary = {}
	for t: int in checkpoints:
		cp[str(t)] = checkpoints[t]
	return {
		"format": FORMAT, "game_version": GAME_VERSION, "scenario": scenario_id,
		"seed": seed_value, "content_hash": content_hash, "end_tick": end_tick,
		"commands": commands, "checkpoints": cp, "scenario_data": scenario_data,
	}


static func from_dict(d: Dictionary) -> Replay:
	var r := Replay.new()
	r.scenario_id = str(d.get("scenario", ""))
	r.seed_value = int(d.get("seed", 0))
	r.content_hash = int(d.get("content_hash", 0))
	r.end_tick = int(d.get("end_tick", 0))
	r.scenario_data = d.get("scenario_data", {})
	for c: Variant in d.get("commands", []):
		r.commands.append(c as Dictionary)
	var cp: Dictionary = d.get("checkpoints", {})
	for k: Variant in cp:
		r.checkpoints[int(str(k))] = int(cp[k])
	return r


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "  "))
	return OK


static func load_file(path: String) -> Replay:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	return from_dict(parsed)


## Rebuilds the match and plays every command. Returns the world at end_tick
## (or null if the scenario can't be built).
func play(content: ContentDb) -> SimWorld:
	var world: SimWorld = _build(content)
	if world == null:
		return null
	for d: Dictionary in commands:
		world.queue_command(SimCommand.from_dict(d))
	while world.tick < end_tick:
		world.step()
	return world


## Plays the replay and lists every problem: different content (when
## `strict_content`), or state hashes that differ from the recorded
## checkpoints. Empty means it matches. Golden-replay tests pass
## strict_content = false: unrelated data files (a new scenario, say) change
## the content hash without changing what happens in the recorded match.
func verify(content: ContentDb, strict_content: bool = true) -> PackedStringArray:
	var problems: PackedStringArray = []
	if strict_content and content.content_hash != content_hash:
		problems.append("content differs from the recording (game data changed); regenerate golden replays if this was intended")
		return problems
	var world: SimWorld = _build(content)
	if world == null:
		problems.append("scenario '%s' could not be built" % scenario_id)
		return problems
	for d: Dictionary in commands:
		world.queue_command(SimCommand.from_dict(d))
	while world.tick < end_tick:
		world.step()
		if checkpoints.has(world.tick) and checkpoints[world.tick] != world.state_hash():
			problems.append("desync at tick %d: expected %08x, got %08x" % [world.tick, checkpoints[world.tick], world.state_hash()])
			return problems
	return problems


func _build(content: ContentDb) -> SimWorld:
	if not scenario_data.is_empty():
		return MatchSetup.build_from(content, scenario_data, seed_value)
	return MatchSetup.build(content, scenario_id, seed_value)
