extends TestCase
# Gauntlet mode (P4-03): seven commanders in order; beating the next one
# unlocks the one after; a gauntlet match is a tagged skirmish.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func test_seven_valid_commanders() -> void:
	var all: Array = Gauntlet.commanders()
	assert_eq(all.size(), 7)
	var signs: Dictionary = {}
	for c: Dictionary in all:
		assert_true(MatchConfig.FACTIONS.has(str(c["faction"])), "%s: unknown faction" % c["call_sign"])
		assert_true(AiPersonality.NAMES.has(str(c["personality"])), "%s: unknown personality" % c["call_sign"])
		assert_true(str(c["difficulty"]) in ["easy", "normal", "hard"], "%s: unknown difficulty" % c["call_sign"])
		var map: MapDef = _content().get_map(str(c["map"]))
		assert_true(map != null and map.skirmish and map.start_positions.size() == 2, "%s: not a 1v1 skirmish map" % c["call_sign"])
		signs[c["call_sign"]] = true
	assert_eq(signs.size(), 7, "two commanders share a call sign")


func test_progress_moves_on_only_with_the_next_win() -> void:
	Gauntlet.save_path = "user://test_gauntlet.json"
	Gauntlet.reset()
	assert_eq(Gauntlet.beaten(), 0)
	Gauntlet.record_win(2)
	assert_eq(Gauntlet.beaten(), 0, "a locked commander counted")
	Gauntlet.record_win(0)
	assert_eq(Gauntlet.beaten(), 1)
	Gauntlet.record_win(0)
	assert_eq(Gauntlet.beaten(), 1, "beating a commander twice counted twice")
	Gauntlet.reset()
	assert_eq(Gauntlet.beaten(), 0)
	DirAccess.remove_absolute(Gauntlet.save_path)
	Gauntlet.save_path = Gauntlet.SAVE_PATH


func test_a_gauntlet_match_is_a_tagged_skirmish() -> void:
	var sc: Dictionary = Gauntlet.scenario(_content(), 5, "eu", 10000)
	var c: Dictionary = Gauntlet.commanders()[5]
	assert_eq(sc["gauntlet_step"], 5)
	assert_eq(sc["map"], c["map"])
	var enemy: Dictionary = sc["players"][1]
	assert_eq(enemy["faction"], c["faction"])
	assert_eq(enemy["personality"], c["personality"])
	assert_eq(enemy["difficulty"], c["difficulty"])
	assert_eq(sc["players"][0]["faction"], "eu")
