class_name NetSession
extends Node
## LAN multiplayer over ENet (P3-14a). Lockstep: nothing but commands crosses
## the network. Each machine runs the same deterministic sim; every tick
## needs every player's command batch (SimRunner), so each side sends the
## batches it seals and feeds the other side's into its runner.
##
## - The host listens; a client joins by address. The host is player 1, the
##   client player 2. The host sends the match (scenario and seed) with
##   start_match(); both then build the same world.
## - Both send their state hash every second (SimRunner.hash_logged); a
##   mismatch is a desync (`desynced`), which means a determinism bug. The
##   first one saves this machine's replay (P3-14b) to `replay_dir`, so it
##   can be compared with the other machine's.
## - The session gets its own MultiplayerAPI rooted at itself, so two
##   sessions can live in one process (the loopback test) and it survives
##   scene changes when kept under the tree root.

signal peer_joined()
signal match_received(config: Dictionary)
signal desynced(tick: int, mine: int, theirs: int)
signal peer_left()

const PORT: int = 7340
const INPUT_DELAY: int = 3   ## ticks (200 ms): room for the batch to cross a LAN

var is_host: bool = false
var local_player_id: int = 1
var runner: SimRunner
var _api: SceneMultiplayer
var _their_hashes: Dictionary[int, int] = {}
var _early: Array[Array] = []   ## batches that arrived before attach(): [player, tick, cmds]
var replay_dir: String = "user://replays"
var last_desync_replay: String = ""   ## where the replay of the first desync went, or ""



func _enter_tree() -> void:
	_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(_api, get_path())
	_api.peer_connected.connect(func(_id: int) -> void: peer_joined.emit())
	_api.peer_disconnected.connect(func(_id: int) -> void: peer_left.emit())


func _process(_delta: float) -> void:
	poll()


## Lets ENet send and receive. _process does it every frame; tests call it.
func poll() -> void:
	if _api != null and _api.multiplayer_peer != null:
		_api.poll()


func host(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, 1)
	if err == OK:
		_api.multiplayer_peer = peer
		is_host = true
		local_player_id = 1
	return err


func join(address: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err == OK:
		_api.multiplayer_peer = peer
		is_host = false
		local_player_id = 2
	return err


func connected() -> bool:
	return _api != null and _api.multiplayer_peer != null and not _api.get_peers().is_empty()


func close() -> void:
	if _api != null and _api.multiplayer_peer != null:
		_api.multiplayer_peer.close()
		_api.multiplayer_peer = null


## Host only: sends the match to the client. The host starts it too.
func start_match(config: Dictionary) -> void:
	if is_host:
		_recv_match.rpc(config)


## Hooks a runner up: its sealed batches and hashes go out; the other
## player's batches come in.
func attach(r: SimRunner) -> void:
	runner = r
	runner.input_delay = INPUT_DELAY
	runner.batch_sealed.connect(_on_batch_sealed)
	runner.hash_logged.connect(_on_hash_logged)
	for b: Array in _early:
		runner.receive_batch(b[0], b[1], b[2])
	_early.clear()


func _on_batch_sealed(player_id: int, tick: int, cmds: Array[SimCommand]) -> void:
	if player_id != local_player_id:
		return
	var dicts: Array = []
	for c: SimCommand in cmds:
		dicts.append(c.to_dict())
	_recv_batch.rpc(player_id, tick, dicts)


func _on_hash_logged(tick: int, hash_value: int) -> void:
	_recv_hash.rpc(tick, hash_value)
	_check_hash(tick)


@rpc("authority", "call_remote", "reliable")
func _recv_match(config: Dictionary) -> void:
	match_received.emit(config)


@rpc("any_peer", "call_remote", "reliable")
func _recv_batch(player_id: int, tick: int, dicts: Array) -> void:
	var cmds: Array[SimCommand] = []
	for d: Variant in dicts:
		cmds.append(SimCommand.from_dict(d as Dictionary))
	if runner == null:
		_early.append([player_id, tick, cmds])   # the match is still being built here
		return
	runner.receive_batch(player_id, tick, cmds)


@rpc("any_peer", "call_remote", "reliable")
func _recv_hash(tick: int, hash_value: int) -> void:
	_their_hashes[tick] = hash_value
	_check_hash(tick)


func _check_hash(tick: int) -> void:
	if runner == null or not runner.hash_log.has(tick) or not _their_hashes.has(tick):
		return
	var mine: int = runner.hash_log[tick]
	var theirs: int = _their_hashes[tick]
	_their_hashes.erase(tick)
	if mine != theirs:
		if last_desync_replay == "" and runner != null:
			DirAccess.make_dir_recursive_absolute(replay_dir)
			var path: String = replay_dir.path_join("desync_tick%d_p%d.json" % [tick, local_player_id])
			last_desync_replay = path if runner.make_replay().save(path) == OK else ""
		desynced.emit(tick, mine, theirs)
