extends TestCase
# The UAE's sovereign fund (P3-02b): interest on unspent credits once a
# minute, capped; the rank-5 unlock doubles the cap.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


## Players 1..3: the UAE, America, the UAE, with the given credits.
func _world(credits: Array[int]) -> SimWorld:
	var w := SimWorld.new(17, 128, 128)
	w.content = _content()
	w.damage_matrix = _content().damage_matrix
	w.rules = _content().rules
	var factions: Array[String] = ["ae", "us", "ae"]
	for i: int in credits.size():
		var pid: int = i + 1
		w.player_team[pid] = pid
		var p: SimPlayer = w.get_player(pid)
		p.team = pid
		p.faction = factions[i]
		p.credits = credits[i]
	return w


func _run(w: SimWorld, ticks: int) -> Array[Dictionary]:
	var paid: Array[Dictionary] = []
	for i: int in ticks:
		w.step()
		for ev: Dictionary in w.events:
			if ev.get("type") == "interest":
				paid.append(ev)
	return paid


func test_rules_load_from_data() -> void:
	var r: SimRules = _content().rules
	assert_eq(r.fund_faction, "ae")
	assert_eq(r.fund_interval_ticks, 60 * SimWorld.TICK_RATE)
	assert_eq(r.fund_percent, 3)
	assert_eq(r.fund_cap, 300)
	assert_true(_content().powers.has(r.fund_cap_doubler), "the cap-doubling unlock is missing")


func test_the_uae_earns_interest_once_a_minute() -> void:
	var w := _world([5000, 5000])
	# Steps run with ticks 0..899 first: a full minute, no payment yet.
	var paid: Array[Dictionary] = _run(w, 60 * SimWorld.TICK_RATE)
	assert_eq(paid.size(), 0, "interest came before a minute had passed")
	assert_eq(w.get_player(1).credits, 5000)
	paid = _run(w, 1)
	assert_eq(w.get_player(1).credits, 5150, "3% of 5000")
	assert_eq(w.get_player(2).credits, 5000, "America has no sovereign fund")
	assert_eq(paid.size(), 1)
	assert_eq(int(paid[0]["amount"]), 150)
	_run(w, 60 * SimWorld.TICK_RATE)
	assert_eq(w.get_player(1).credits, 5150 + 154, "the second minute pays on the new balance")


func test_the_cap_and_the_unlock_that_doubles_it() -> void:
	var w := _world([20000, 0, 20000])
	w.get_player(3).powers.append(w.rules.fund_cap_doubler)
	_run(w, 60 * SimWorld.TICK_RATE + 1)
	assert_eq(w.get_player(1).credits, 20300, "capped at 300")
	assert_eq(w.get_player(3).credits, 20600, "the unlock doubles the cap")


func test_no_interest_for_the_broke_or_the_defeated() -> void:
	var w := _world([20, 0, 9000])
	w.get_player(3).defeated = true
	_run(w, 60 * SimWorld.TICK_RATE + 1)
	assert_eq(w.get_player(1).credits, 20, "3% of 20 rounds down to nothing")
	assert_eq(w.get_player(3).credits, 9000, "a defeated player earned interest")


func test_the_fund_is_deterministic() -> void:
	var a := _world([7777, 100, 4321])
	var b := _world([7777, 100, 4321])
	_run(a, 60 * SimWorld.TICK_RATE * 2 + 1)
	_run(b, 60 * SimWorld.TICK_RATE * 2 + 1)
	assert_true(a.get_player(1).credits > 7777, "no interest was paid")
	assert_eq(a.state_hash(), b.state_hash())
