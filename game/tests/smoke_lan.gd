extends SceneTree
## LAN multiplayer smoke test (P3-14a): two NetSessions in one process,
## connected over ENet on localhost. The host sends the match; each side's
## player is an AI; after 40 s of play both machines must agree tick for
## tick, with no desync reported. Run by tools/run_tests.sh.

const TEST_PORT: int = 7351

var _db := ContentDb.new()
var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _side(session: NetSession, sc: Dictionary, me: int) -> SimRunner:
	var r := SimRunner.new()
	r.world = MatchSetup.build_from(_db, sc, 4242)
	r.players = [1, 2]
	r.local_players = [me]
	r.local_player_id = me
	var faction: String = str((sc["players"] as Array)[me - 1]["faction"])
	r.ai_players[me] = AiPlayer.from_preset(_db, faction + "_default", me)
	session.attach(r)
	r.start()
	return r


## Polls both sessions until `until` is true or `max_ms` passes.
func _pump(a: NetSession, b: NetSession, until: Callable, max_ms: int) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < max_ms:
		a.poll()
		b.poll()
		if until.call():
			return true
		await process_frame
	return false


func _run() -> void:
	_check(_db.load_all(), "content failed to load")
	var host := NetSession.new()
	host.name = "HostSession"
	var client := NetSession.new()
	client.name = "ClientSession"
	root.add_child(host)
	root.add_child(client)
	await process_frame
	_check(host.host(TEST_PORT) == OK, "could not host")
	_check(client.join("127.0.0.1", TEST_PORT) == OK, "could not join")
	_check(await _pump(host, client, func() -> bool: return host.connected() and client.connected(), 5000), "no connection")
	var received: Array[Dictionary] = []
	client.match_received.connect(func(cfg: Dictionary) -> void: received.append(cfg))
	var sc: Dictionary = MatchConfig.skirmish(_db, "twin_ridge", "us", 10000, false, "normal", "kp")
	(sc["players"] as Array)[1].erase("ai")
	host.start_match({"scenario": sc, "seed": 4242})
	_check(await _pump(host, client, func() -> bool: return not received.is_empty(), 5000), "the client never got the match")
	if not _failures.is_empty():
		_finish()
		return
	var desyncs: Array[int] = []
	host.desynced.connect(func(t: int, _m: int, _o: int) -> void: desyncs.append(t))
	client.desynced.connect(func(t: int, _m: int, _o: int) -> void: desyncs.append(t))
	var ra: SimRunner = _side(host, sc, 1)
	var rb: SimRunner = _side(client, received[0]["scenario"], 2)
	var target: int = 40 * SimWorld.TICK_RATE
	var done: bool = await _pump(host, client, func() -> bool:
		while ra.world.tick < target and ra.try_step():
			pass
		while rb.world.tick < target and rb.try_step():
			pass
		return ra.world.tick >= target and rb.world.tick >= target, 120000)
	_check(done, "stuck at ticks %d and %d" % [ra.world.tick, rb.world.tick])
	_check(ra.world.state_hash() == rb.world.state_hash(), "the two machines disagree")
	_check(desyncs.is_empty(), "desync reported at %s" % str(desyncs))
	_check(ra.command_log.size() > 5, "the AIs gave almost no orders")
	# P3-14b: a desync (forced here) is reported and saves a replay.
	host.replay_dir = "user://test_desync_replays"
	ra.world.get_player(1).credits += 1
	var forced: bool = await _pump(host, client, func() -> bool:
		while ra.world.tick < target + 3 * SimWorld.TICK_RATE and ra.try_step():
			pass
		while rb.world.tick < target + 3 * SimWorld.TICK_RATE and rb.try_step():
			pass
		return not desyncs.is_empty(), 60000)
	_check(forced, "a forced desync wasn't reported")
	_check(host.last_desync_replay != "" and FileAccess.file_exists(host.last_desync_replay), "no replay was saved on the desync")
	if host.last_desync_replay != "":
		DirAccess.remove_absolute(host.last_desync_replay)
	host.close()
	client.close()
	ra.free()
	rb.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("smoke_lan: ok")
		quit(0)
	else:
		for f: String in _failures:
			printerr("smoke_lan FAIL: ", f)
		quit(1)
