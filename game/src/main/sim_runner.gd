class_name SimRunner
extends Node
## Steps the SimWorld at a fixed rate as a lockstep scheduler (P1-21).
##
## Every player in `players` must deliver a command batch (possibly empty)
## for a tick before that tick may run. Local players (the human here, and AI
## players later) seal their batch for tick T + input_delay as soon as tick T
## starts, so in single player the game never waits. Remote players' batches
## arrive through receive_batch() (P3-14/15); until then the runner waits.
## A state hash is logged every HASH_INTERVAL ticks for desync checks, and
## every command is recorded so the match can be saved as a replay.

signal ticked(tick: int)

const MAX_STEPS_PER_FRAME: int = 4
const HASH_INTERVAL: int = SimWorld.TICK_RATE

var world: SimWorld
var local_player_id: int = 1
## Every player whose batches the runner waits for. Defaults to the local one.
var players: Array[int] = []
## Players whose batches this machine fills itself (the human, AI players).
var local_players: Array[int] = []
## AI controllers by player id; each must also be in local_players.
var ai_players: Dictionary[int, AiPlayer] = {}
var input_delay: int = 1
var paused: bool = false
## For saving a replay: what this match was built from.
var scenario_id: String = ""
var seed_value: int = 0
## Every command that went into the world, in order.
var command_log: Array[Dictionary] = []
## tick -> state hash, every HASH_INTERVAL ticks.
var hash_log: Dictionary[int, int] = {}
## Progress into the current tick (0..1), for view interpolation.
var alpha: float = 0.0
## Sim events ("fired", "hit", "died", ...) from every tick stepped since the
## view last drained them. The view and audio consume these.
var pending_events: Array[Dictionary] = []
var _accumulator: float = 0.0
var _seq: int = 0
var _outbox: Array[SimCommand] = []       ## local commands not yet in a batch
var _batches: Dictionary[int, Dictionary] = {}   ## tick -> {player id: Array of SimCommand}
var _started: bool = false


## Call after setting world (and optionally players/local_players).
func start() -> void:
	if players.is_empty():
		players = [local_player_id]
	if local_players.is_empty():
		local_players = [local_player_id]
	# Nobody could have sent commands for the first input_delay ticks.
	for t: int in range(world.tick, world.tick + input_delay):
		for p: int in players:
			_store(p, t, [])
	_started = true


## Adds AI players for every scenario player that has an "ai" preset.
func add_ai_from_scenario(content: ContentDb, scenario: Dictionary) -> void:
	for p: Variant in scenario.get("players", []):
		var pd: Dictionary = p
		var preset: String = str(pd.get("ai", ""))
		if preset == "":
			continue
		var pid: int = int(pd.get("id", 0))
		var ai: AiPlayer = AiPlayer.from_preset(content, preset, pid)
		if ai == null:
			continue
		ai_players[pid] = ai
		if not players.has(pid):
			players.append(pid)
		if not local_players.has(pid):
			local_players.append(pid)


## Queues a command from the local player. It joins the next batch, which
## runs input_delay ticks from now.
func submit(cmd: SimCommand) -> void:
	if not _started:
		start()
	_seq += 1
	cmd.player_id = local_player_id
	cmd.seq = _seq
	_outbox.append(cmd)


## Delivers another player's batch for a tick (network, later).
func receive_batch(player_id: int, tick: int, cmds: Array[SimCommand]) -> void:
	_store(player_id, tick, cmds)


## True if every player's batch for the current tick has arrived.
func can_step() -> bool:
	var batch: Dictionary = _batches.get(world.tick, {})
	for p: int in players:
		if not batch.has(p):
			return false
	return true


## Runs one tick if allowed. Returns false if still waiting for a batch.
func try_step() -> bool:
	if not _started:
		start()
	_seal_local_batches()
	if not can_step():
		return false
	var batch: Dictionary = _batches[world.tick]
	_batches.erase(world.tick)
	for p: int in players:
		for c: SimCommand in batch[p]:
			command_log.append(c.to_dict())
			world.queue_command(c)
	world.step()
	pending_events.append_array(world.events)
	if world.tick % HASH_INTERVAL == 0:
		hash_log[world.tick] = world.state_hash()
	ticked.emit(world.tick)
	return true


## Everything needed to replay this match so far.
func make_replay() -> Replay:
	var r := Replay.new()
	r.scenario_id = scenario_id
	r.seed_value = seed_value
	r.content_hash = world.content.content_hash if world.content != null else 0
	r.commands = command_log.duplicate()
	r.checkpoints = hash_log.duplicate()
	r.end_tick = world.tick
	return r


func _process(delta: float) -> void:
	if paused or world == null:
		return
	var tick_sec: float = 1.0 / float(SimWorld.TICK_RATE)
	_accumulator += delta
	var steps: int = 0
	while _accumulator >= tick_sec and steps < MAX_STEPS_PER_FRAME:
		if not try_step():
			_accumulator = minf(_accumulator, tick_sec)   # waiting for others
			break
		_accumulator -= tick_sec
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		# Too slow to keep up: drop the backlog instead of spiraling.
		_accumulator = minf(_accumulator, tick_sec)
	alpha = clampf(_accumulator / tick_sec, 0.0, 1.0)


## Local players' batch for (current tick + delay) closes now: the outbox goes
## in it (for the human player), empty for others.
func _seal_local_batches() -> void:
	var t: int = world.tick + input_delay
	for p: int in local_players:
		if _batches.has(t) and (_batches[t] as Dictionary).has(p):
			continue
		var cmds: Array[SimCommand] = []
		if ai_players.has(p):
			var seq: int = 0
			for c: SimCommand in ai_players[p].think(world):
				seq += 1
				c.seq = seq
				cmds.append(c)
		elif p == local_player_id:
			for c: SimCommand in _outbox:
				c.tick = t
				cmds.append(c)
			_outbox.clear()
		_store(p, t, cmds)


func _store(player_id: int, tick: int, cmds: Array[SimCommand]) -> void:
	if not _batches.has(tick):
		_batches[tick] = {}
	for c: SimCommand in cmds:
		c.player_id = player_id
		c.tick = tick
	(_batches[tick] as Dictionary)[player_id] = cmds
