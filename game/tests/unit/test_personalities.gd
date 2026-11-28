extends TestCase
# AI personalities (P3-13b): rusher, turtle and tech overlay a faction preset;
# "random" picks one from the AI's own seed, the same on every machine.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _ai(style: String, faction: String = "us") -> AiPlayer:
	return AiPlayer.from_preset(_content(), faction + "_default", 2, "normal", style)


func test_personalities_are_data() -> void:
	for name: String in AiPersonality.NAMES:
		var p: Dictionary = _content().ai_personalities.get(name, {})
		assert_true(p.has("name") and p.has("description"), "%s has no name or description" % name)


func test_balanced_is_the_plain_preset() -> void:
	var plain := AiPlayer.from_preset(_content(), "us_default", 2)
	var balanced := _ai("balanced")
	assert_eq(balanced.first_attack_tick, plain.first_attack_tick)
	assert_eq(balanced.build_order, plain.build_order)
	assert_eq(balanced.unit_mix, plain.unit_mix)


func test_a_rusher_attacks_sooner_with_light_units_and_no_research() -> void:
	var plain := _ai("balanced")
	var rusher := _ai("rusher")
	assert_true(rusher.first_attack_tick < plain.first_attack_tick)
	assert_true(rusher.attack_wave_size < plain.attack_wave_size)
	assert_true(rusher.research.is_empty())
	assert_eq(rusher.superweapon, "")
	assert_eq(rusher.unit_mix["us_rifle_squad"], plain.unit_mix["us_rifle_squad"] * 2)
	assert_eq(rusher.unit_mix["us_mbt"], plain.unit_mix["us_mbt"], "tanks shouldn't be boosted")


func test_a_turtle_builds_extra_defenses_and_attacks_late() -> void:
	var plain := _ai("balanced", "kp")
	var turtle := _ai("turtle", "kp")
	assert_true(turtle.first_attack_tick > plain.first_attack_tick)
	assert_true(turtle.attack_wave_size > plain.attack_wave_size)
	var extra: Array[String] = AiPersonality.defensive_buildings(_content(), "kp")
	assert_eq(extra, ["kp_sam_site", "kp_trench_line"] as Array[String])
	assert_eq(turtle.build_order.size(), plain.build_order.size() + 2 * extra.size())


func test_tech_researches_every_upgrade_of_its_faction() -> void:
	var tech := _ai("tech", "eu")
	for id: String in _content().upgrades:
		var up: UpgradeDef = _content().upgrades[id]
		if up.faction == "eu" and up.scope == "global" and not up.granted:
			assert_true(tech.research.has(id), "tech skipped %s" % id)
	assert_false(tech.research.has("eu_heavy_armor_doctrine"), "a doctrine bonus can't be researched")
	assert_eq(tech.unit_mix["eu_attack_heli"], _ai("balanced", "eu").unit_mix["eu_attack_heli"] * 3)


func test_random_resolves_the_same_way_for_the_same_match() -> void:
	var picks: Dictionary[String, bool] = {}
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var a := _resolved(seed_value)
		assert_eq(a, _resolved(seed_value), "random picked differently for seed %d" % seed_value)
		assert_true(AiPersonality.NAMES.has(a))
		picks[a] = true
	assert_true(picks.size() >= 2, "random always picked the same style")


func _resolved(seed_value: int) -> String:
	var sc: Dictionary = MatchConfig.skirmish(_content(), "twin_ridge", "us", 10000, false, "normal", "kp", "random")
	var runner := SimRunner.new()
	runner.world = MatchSetup.build_from(_content(), sc, seed_value)
	runner.add_ai_from_scenario(_content(), sc)
	var ai: AiPlayer = runner.ai_players[2]
	assert_eq(ai.personality, "random")
	ai.think(runner.world)
	var style: String = ai.personality
	runner.free()
	return style
