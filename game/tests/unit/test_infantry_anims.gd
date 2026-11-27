extends TestCase
# Infantry rig and animations (P2-16): every infantry model carries the shared
# animation set, and the animator follows the sim state.

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		assert_true(_db.load_all(), ", ".join(_db.errors))
	return _db


func _model(def_id: String) -> Node3D:
	var scene: PackedScene = load(_content().get_unit(def_id).model_path)
	return scene.instantiate() as Node3D


func test_every_infantry_model_has_the_animation_set() -> void:
	var checked: int = 0
	for id: String in _content().units:
		var def: UnitDef = _content().get_unit(id)
		if not def.is_infantry() or def.model_path == "":
			continue
		var model := _model(id)
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(player != null, "%s has no AnimationPlayer" % id)
		if player != null:
			for s: String in InfantryAnimator.STATES:
				assert_true(player.has_animation(s), "%s is missing the '%s' animation" % [id, s])
		assert_true(model.find_child("Skeleton3D", true, false) != null, "%s has no skeleton" % id)
		model.free()
		checked += 1
	assert_true(checked >= 5, "only %d infantry models checked" % checked)


func _soldier() -> SimEntity:
	var e := SimEntity.new()
	e.id = 4
	e.mover = SimMover.new()
	var w := SimWeapon.new()
	e.weapons.append(w)
	return e


func test_state_follows_the_sim() -> void:
	var e := _soldier()
	assert_eq(InfantryAnimator.state_for(e, false), "idle")
	e.weapons[0].target_id = 9
	assert_eq(InfantryAnimator.state_for(e, false), "aim")
	assert_eq(InfantryAnimator.state_for(e, true), "fire")
	e.mover.has_target = true
	e.order = SimEntity.Order.MOVE
	assert_eq(InfantryAnimator.state_for(e, true), "run", "moving beats firing")
	e.order = SimEntity.Order.ATTACK_MOVE
	assert_eq(InfantryAnimator.state_for(e, false), "walk")
	e.mover.has_target = false
	e.order = SimEntity.Order.HOLD
	assert_eq(InfantryAnimator.state_for(e, false), "prone")
	e.dead = true
	assert_eq(InfantryAnimator.state_for(e, false), "death_1")
	e.id = 5
	assert_eq(InfantryAnimator.state_for(e, false), "death_2")


func test_animator_drives_its_tree() -> void:
	var model := _model("us_rifle_squad")
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(model)
	var a: InfantryAnimator = InfantryAnimator.attach_to(model)
	assert_true(a != null, "no animator for the rifle squad")
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_eq(player.get_animation("walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation("death_1").loop_mode, Animation.LOOP_NONE)
	assert_eq(a.state, "idle")
	var e := _soldier()
	e.weapons[0].target_id = 3
	a.fired()
	a.update(e, 0.1)
	assert_eq(a.state, "fire")
	a.update(e, InfantryAnimator.FIRE_HOLD_S)
	assert_eq(a.state, "aim", "fire did not settle back to aim")
	model.free()


func test_models_without_a_rig_get_no_animator() -> void:
	var tank := _model("us_mbt")
	assert_true(InfantryAnimator.attach_to(tank) == null)
	tank.free()
