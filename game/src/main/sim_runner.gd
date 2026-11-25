class_name SimRunner
extends Node
## Steps the SimWorld at a fixed rate and schedules the local player's commands.
## In multiplayer this becomes the lockstep scheduler (docs/02-architecture.md):
## a tick may only run once every player's commands for it have arrived.

signal ticked(tick: int)

const INPUT_DELAY_TICKS: int = 1
const MAX_STEPS_PER_FRAME: int = 4

var world: SimWorld
var local_player_id: int = 1
var paused: bool = false
## Every submitted command, in order; with the seed this is a replay.
var command_log: Array[Dictionary] = []
## Progress into the current tick (0..1), for view interpolation.
var alpha: float = 0.0
var _accumulator: float = 0.0
var _seq: int = 0


func submit(cmd: SimCommand) -> void:
	_seq += 1
	cmd.player_id = local_player_id
	cmd.seq = _seq
	cmd.tick = world.tick + INPUT_DELAY_TICKS
	command_log.append(cmd.to_dict())
	world.queue_command(cmd)


func _process(delta: float) -> void:
	if paused or world == null:
		return
	var tick_sec: float = 1.0 / float(SimWorld.TICK_RATE)
	_accumulator += delta
	var steps: int = 0
	while _accumulator >= tick_sec and steps < MAX_STEPS_PER_FRAME:
		world.step()
		_accumulator -= tick_sec
		steps += 1
		ticked.emit(world.tick)
	if steps == MAX_STEPS_PER_FRAME:
		# Too slow to keep up: drop the backlog instead of spiraling.
		_accumulator = minf(_accumulator, tick_sec)
	alpha = clampf(_accumulator / tick_sec, 0.0, 1.0)
