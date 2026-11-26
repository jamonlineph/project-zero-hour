extends TestCase
# Vision and fog of war (P1-11).


func _def(vision_m: int) -> UnitDef:
	var d := UnitDef.new()
	d.id = "eye"
	d.max_hp = 100
	d.speed = Fx.from_int(1)
	d.radius = Fx.from_int(1)
	d.vision = Fx.from_int(vision_m)
	return d


func test_units_see_within_their_vision_radius() -> void:
	var world := SimWorld.new(1, 200, 200)
	world.spawn_unit(_def(40), 1, Fx.from_int(50), Fx.from_int(50))
	world.step()
	assert_true(world.can_see(1, Fx.from_int(60), Fx.from_int(60)))
	assert_true(world.can_see(1, Fx.from_int(85), Fx.from_int(50)))
	assert_false(world.can_see(1, Fx.from_int(150), Fx.from_int(150)))
	assert_false(world.can_see(2, Fx.from_int(50), Fx.from_int(50)), "other players see nothing")


func test_explored_ground_is_remembered() -> void:
	var world := SimWorld.new(1, 200, 200)
	var id: int = world.spawn_unit(_def(30), 1, Fx.from_int(30), Fx.from_int(30))
	world.step()
	var c := SimCommand.make_move([id], Fx.from_int(170), Fx.from_int(170))
	c.player_id = 1
	c.tick = world.tick
	world.queue_command(c)
	for i: int in 300:
		world.step()
	assert_false(world.can_see(1, Fx.from_int(30), Fx.from_int(30)), "start area should be fogged again")
	assert_true(world.vision.is_explored(1, Fx.from_int(30), Fx.from_int(30)), "start area should stay explored")


func test_allies_share_vision() -> void:
	var world := SimWorld.new(1, 200, 200)
	world.player_team = {1: 1, 3: 1, 2: 2}
	world.spawn_unit(_def(30), 3, Fx.from_int(150), Fx.from_int(150))
	world.step()
	assert_true(world.can_see(1, Fx.from_int(150), Fx.from_int(150)), "player 1 should see through ally 3")
	assert_false(world.are_enemies(1, 3))
	assert_true(world.are_enemies(1, 2))


func test_cannot_target_unseen_enemies() -> void:
	var db := ContentDb.new()
	db.load_all()
	var world := SimWorld.new(1, 200, 200)
	world.damage_matrix = db.damage_matrix
	var tank: int = world.spawn_unit(db.get_unit("us_mbt"), 1, Fx.from_int(50), Fx.from_int(50))
	world.get_entity(tank).vision = Fx.from_int(10)   # nearly blind
	var enemy: int = world.spawn_unit(db.get_unit("ru_motor_rifle_squad"), 2, Fx.from_int(90), Fx.from_int(50))
	world.get_entity(enemy).weapons.clear()
	for i: int in 60:
		world.step()
	assert_eq(world.get_entity(enemy).hp, world.get_entity(enemy).max_hp, "fired at an enemy it could not see")
	# A friendly spotter next to the enemy lets the tank shoot.
	world.spawn_unit(db.get_unit("us_rifle_squad"), 1, Fx.from_int(95), Fx.from_int(60))
	for i: int in 60:
		world.step()
	assert_true(world.get_entity(enemy) == null or world.get_entity(enemy).hp < world.get_entity(enemy).max_hp)
