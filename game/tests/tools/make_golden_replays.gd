extends SceneTree
## Regenerates the golden replays in res://tests/replays/ (P1-20).
## Run: tools/regen_golden_replays.sh
##
## Golden replays pin down exact simulation behavior: test_replays.gd plays
## them back and compares state hashes. When you change sim rules or game
## data ON PURPOSE, regenerate them and say why in the commit message.

const OUT_DIR: String = "res://tests/replays/"
const SEED: int = 4242
const CHECKPOINT_EVERY: int = 150


func _initialize() -> void:
	var content := ContentDb.new()
	if not content.load_all():
		printerr("content errors: ", content.errors)
		quit(1)
		return
	_record(content, "clash", 1350, _clash)
	_record(content, "economy", 1800, _economy)
	_record(content, "maneuvers", 900, _maneuvers)
	quit(0)


func _record(content: ContentDb, name: String, ticks: int, script: Callable) -> void:
	var world: SimWorld = MatchSetup.build(content, "sandbox", SEED)
	var replay := Replay.new()
	replay.scenario_id = "sandbox"
	replay.seed_value = SEED
	replay.content_hash = content.content_hash
	var plan: Array[SimCommand] = script.call(world)
	var seq: Dictionary[int, int] = {}
	for c: SimCommand in plan:
		seq[c.player_id] = seq.get(c.player_id, 0) + 1
		c.seq = seq[c.player_id]
		replay.commands.append(c.to_dict())
		world.queue_command(c)
	while world.tick < ticks:
		world.step()
		if world.tick % CHECKPOINT_EVERY == 0:
			replay.checkpoints[world.tick] = world.state_hash()
	replay.end_tick = ticks
	replay.save(ProjectSettings.globalize_path(OUT_DIR + name + ".json"))
	print("wrote %s: %d commands, %d checkpoints, final hash %08x" % [name, plan.size(), replay.checkpoints.size(), world.state_hash()])


func _ids(world: SimWorld, player: int, filter: Callable) -> Array[int]:
	var out: Array[int] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == player and filter.call(e):
			out.append(id)
	return out


func _at(c: SimCommand, tick: int, player: int) -> SimCommand:
	c.tick = tick
	c.player_id = player
	return c


## Both armies attack-move at each other's base.
func _clash(world: SimWorld) -> Array[SimCommand]:
	var armed := func(e: SimEntity) -> bool: return e.mover != null and not e.weapons.is_empty()
	return [
		_at(SimCommand.make_attack_move(_ids(world, 1, armed), Fx.from_int(100), Fx.from_int(60)), 15, 1),
		_at(SimCommand.make_attack_move(_ids(world, 2, armed), Fx.from_int(28), Fx.from_int(60)), 15, 2),
	]


## Both sides build up an economy and produce units.
func _economy(world: SimWorld) -> Array[SimCommand]:
	var eng1: Array[int] = _ids(world, 1, func(e: SimEntity) -> bool: return e.builder != null)
	var eng2: Array[int] = _ids(world, 2, func(e: SimEntity) -> bool: return e.builder != null)
	return [
		_at(SimCommand.make_build(eng1, "us_logistics_hub", Fx.from_int(46), Fx.from_int(58)), 5, 1),
		_at(SimCommand.make_build(eng2, "kp_power_plant", Fx.from_int(90), Fx.from_int(24)), 5, 2),
		_at(SimCommand.make_build(eng1, "us_microreactor", Fx.from_int(30), Fx.from_int(90)), 400, 1),
		_at(SimCommand.make_build(eng2, "kp_barracks", Fx.from_int(96), Fx.from_int(90)), 400, 2),
		_at(SimCommand.make_build(eng1, "us_barracks", Fx.from_int(44), Fx.from_int(90)), 700, 1),
		_at(SimCommand.make_build(eng2, "kp_logistics_hub", Fx.from_int(84), Fx.from_int(60)), 800, 2),
	]


## Group moves through the ridge gap and back, with stops.
func _maneuvers(world: SimWorld) -> Array[SimCommand]:
	var movers := func(e: SimEntity) -> bool: return e.mover != null and e.builder == null and e.gatherer == null
	var blue: Array[int] = _ids(world, 1, movers)
	return [
		_at(SimCommand.make_move(blue, Fx.from_int(60), Fx.from_int(64)), 10, 1),
		_at(SimCommand.make_move(blue, Fx.from_int(40), Fx.from_int(110)), 300, 1),
		_at(SimCommand.make_stop([blue[0]]), 360, 1),
		_at(SimCommand.make_move(blue, Fx.from_int(20), Fx.from_int(84)), 600, 1),
	]
