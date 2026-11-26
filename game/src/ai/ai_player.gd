class_name AiPlayer
extends RefCounted
## Skirmish AI (v0 P1-31, v1 P2-11). See docs/design/ai-opponent.md.
##
## Acts only through SimCommands, like a human, and decides only from the sim
## state, its preset and its own SimRng, so every machine running it makes
## the same decisions (it obeys the sim's determinism rules: ints only).
## Every think_interval ticks it:
## 1. keeps a builder alive and follows its build order (one building at a
##    time, placed with a clearance ring so lanes stay open);
## 2. keeps up to max_gatherers trucks working;
## 3. keeps every factory busy with the unit mix it lacks most;
## 4. defends buildings against visible enemies, and attacks in waves;
## 5. (v1, normal) shifts production toward counters of what it sees,
##    spends commander points and uses powers, and researches upgrades
##    (AiStrategy). Easy thinks half as often and attacks later and bigger.
## Known v0 shortcuts: it knows where enemy buildings are (start positions are
## public in skirmish), and it never retreats.

var player_id: int = 0
var preset_id: String = ""
var build_order: PackedStringArray = []
var unit_mix: Dictionary[String, int] = {}
var max_gatherers: int = 4
var gatherer_unit: String = ""
var attack_wave_size: int = 6
var first_attack_tick: int = 2700
var think_interval: int = 15
var defend_radius: int = 45 * Fx.ONE
var difficulty: String = "normal"   ## "easy" or "normal"
var counters: Dictionary[String, PackedStringArray] = {}
var power_priority: PackedStringArray = []
var research: PackedStringArray = []

var _attacking: bool = false
var _target_id: int = 0
var _rally_set: Dictionary[int, bool] = {}


static func from_preset(content: ContentDb, id: String, player: int, level: String = "normal") -> AiPlayer:
	var p: Dictionary = content.ai_presets.get(id, {})
	if p.is_empty():
		push_error("AiPlayer: unknown preset '%s'" % id)
		return null
	var ai := AiPlayer.new()
	ai.player_id = player
	ai.preset_id = id
	for b: Variant in p.get("build_order", []):
		ai.build_order.append(str(b))
	var mix: Dictionary = p.get("unit_mix", {})
	for u: Variant in mix:
		ai.unit_mix[str(u)] = int(mix[u])
	ai.max_gatherers = int(p.get("max_gatherers", 4))
	ai.gatherer_unit = str(p.get("gatherer_unit", ""))
	ai.attack_wave_size = int(p.get("attack_wave_size", 6))
	ai.first_attack_tick = int(p.get("first_attack_after_s", 180)) * SimWorld.TICK_RATE
	ai.think_interval = maxi(1, int(p.get("think_interval_ticks", 15)))
	ai.defend_radius = Fx.from_int(int(p.get("defend_radius_m", 45)))
	var ctr: Dictionary = p.get("counters", {})
	for cls: Variant in ctr:
		ai.counters[str(cls)] = PackedStringArray(ctr[cls])
	for pw: Variant in p.get("power_priority", []):
		ai.power_priority.append(str(pw))
	for r: Variant in p.get("research", []):
		ai.research.append(str(r))
	ai.difficulty = level
	if level == "easy":
		ai.think_interval *= 2
		ai.attack_wave_size += 3
		ai.first_attack_tick += 60 * SimWorld.TICK_RATE
		ai.max_gatherers = maxi(2, ai.max_gatherers - 1)
		ai.counters.clear()
		ai.research.clear()
	return ai


## Commands for this tick (usually none: the AI thinks every think_interval).
func think(world: SimWorld) -> Array[SimCommand]:
	var cmds: Array[SimCommand] = []
	if world.game_over or world.content == null or world.get_player(player_id).defeated:
		return cmds
	if (world.tick + player_id) % think_interval != 0:
		return cmds
	var mine := _Mine.new(world, player_id)
	_keep_builders(world, mine, cmds)
	var reserve: int = _build(world, mine, cmds)
	_gatherers(world, mine, cmds, reserve)
	_produce(world, mine, cmds, reserve)
	_military(world, mine, cmds)
	AiStrategy.research(world, self, mine.buildings, reserve, cmds)
	if difficulty != "easy" or (world.tick / think_interval) % 2 == 0:
		AiStrategy.powers(world, self, mine.hq, mine.army, cmds)
	return cmds


## Everything the AI owns, sorted by kind. Built once per think.
class _Mine:
	var buildings: Array[SimEntity] = []
	var builders: Array[SimEntity] = []
	var gatherers: Array[SimEntity] = []
	var army: Array[SimEntity] = []
	var hq: SimEntity = null

	func _init(world: SimWorld, pid: int) -> void:
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			if e.player_id != pid or e.dead:
				continue
			if e.building != null:
				buildings.append(e)
				if hq == null and e.def_id.ends_with("_command_hq"):
					hq = e
			elif e.builder != null:
				builders.append(e)
			elif e.gatherer != null:
				gatherers.append(e)
			elif e.mover != null and not e.weapons.is_empty():
				army.append(e)
		if hq == null and not buildings.is_empty():
			hq = buildings[0]


func _keep_builders(world: SimWorld, mine: _Mine, cmds: Array[SimCommand]) -> void:
	if not mine.builders.is_empty():
		return
	for b: SimEntity in mine.buildings:
		if b.building.built and b.building.queue.is_empty():
			for unit_id: String in b.building.produces:
				var def: UnitDef = world.content.get_unit(unit_id)
				if def != null and def.builder and world.get_player(player_id).credits >= def.cost:
					cmds.append(SimCommand.make_produce(b.id, unit_id))
					return


## Places the next building of the build order. Returns credits to keep in
## reserve for it (0 if nothing is waiting).
func _build(world: SimWorld, mine: _Mine, cmds: Array[SimCommand]) -> int:
	var idle: SimEntity = null
	for e: SimEntity in mine.builders:
		if e.builder.target_id == 0 and not e.mover.has_target:
			idle = e
			break
	# Resume any unfinished building nobody is working on.
	for b: SimEntity in mine.buildings:
		if not b.building.built and idle != null and not _someone_builds(mine, b.id):
			cmds.append(SimCommand.make_repair([idle.id], b.id))
			return 0
		if not b.building.built:
			return 0   # one construction at a time
	var next: String = _next_in_build_order(mine)
	if next == "" or idle == null or mine.hq == null:
		return 0
	var def: BuildingDef = world.content.get_building(next)
	if def == null or not world.has_requirements(player_id, def.requires):
		return 0
	if world.get_player(player_id).credits < def.cost:
		return def.cost
	var spot: Vector2i = _find_spot(world, def, mine.hq)
	if spot.x >= 0:
		cmds.append(SimCommand.make_build([idle.id], def.id, spot.x, spot.y))
	return 0


func _someone_builds(mine: _Mine, building_id: int) -> bool:
	for e: SimEntity in mine.builders:
		if e.builder.target_id == building_id:
			return true
	return false


func _next_in_build_order(mine: _Mine) -> String:
	var needed: Dictionary[String, int] = {}
	for id: String in build_order:
		needed[id] = needed.get(id, 0) + 1
		var have: int = 0
		for b: SimEntity in mine.buildings:
			if b.def_id == id:
				have += 1
		if have < needed[id]:
			return id
	return ""


## A center point near the HQ where the building fits with one free cell all
## around it. Searches rings of 10 m in a fixed order.
func _find_spot(world: SimWorld, def: BuildingDef, hq: SimEntity) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1),
		Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(-1, 0)]
	# Mirror the search for a base on the east half, so both sides lay out
	# their bases the same way relative to the front (P2-11b fairness).
	var sx: int = 1 if hq.x < world.map_width / 2 else -1
	for ring: int in range(1, 9):
		for d: Vector2i in dirs:
			var cx: int = hq.x + d.x * sx * ring * 10 * Fx.ONE
			var cy: int = hq.y + d.y * ring * 10 * Fx.ONE
			var origin: Vector2i = SimWorld.footprint_origin(def, cx, cy)
			if _clear(world, def, origin) and world.can_place(def, origin):
				return Vector2i(cx, cy)
	return Vector2i(-1, -1)


func _clear(world: SimWorld, def: BuildingDef, origin: Vector2i) -> bool:
	for y: int in range(origin.y - 1, origin.y + def.footprint_h + 1):
		for x: int in range(origin.x - 1, origin.x + def.footprint_w + 1):
			if not world.map.is_passable(x, y):
				return false
	return true


func _gatherers(world: SimWorld, mine: _Mine, cmds: Array[SimCommand], reserve: int) -> void:
	if mine.gatherers.size() >= max_gatherers or gatherer_unit == "":
		return
	var def: UnitDef = world.content.get_unit(gatherer_unit)
	if def == null or world.get_player(player_id).credits - reserve < def.cost:
		return
	for b: SimEntity in mine.buildings:
		if b.building.built and b.building.produces.has(gatherer_unit) and not b.building.queue.has(gatherer_unit):
			cmds.append(SimCommand.make_produce(b.id, gatherer_unit))
			return


func _produce(world: SimWorld, mine: _Mine, cmds: Array[SimCommand], reserve: int) -> void:
	var credits: int = world.get_player(player_id).credits - reserve
	var counts: Dictionary[String, int] = {}
	for e: SimEntity in mine.army:
		counts[e.def_id] = counts.get(e.def_id, 0) + 1
	var mix: Dictionary[String, int] = unit_mix.duplicate()
	var bonus: Dictionary[String, int] = AiStrategy.counter_bonus(world, self)
	for u: String in bonus:
		mix[u] = mix.get(u, 0) + bonus[u]
	var total_weight: int = 0
	for u: String in mix:
		total_weight += mix[u]
	for b: SimEntity in mine.buildings:
		if not b.building.built or b.building.queue.size() >= 2:
			continue
		var best: String = ""
		var best_score: int = 0
		for u: String in b.building.produces:
			if not mix.has(u):
				continue
			# How far below its share of the army this unit type is.
			var score: int = (mine.army.size() + 1) * mix[u] - counts.get(u, 0) * total_weight
			if best == "" or score > best_score or (score == best_score and u < best):
				best = u
				best_score = score
		if best == "":
			continue
		var def: UnitDef = world.content.get_unit(best)
		if def == null or credits < def.cost or not world.has_requirements(player_id, def.requires):
			continue
		cmds.append(SimCommand.make_produce(b.id, best))
		credits -= def.cost
		counts[best] = counts.get(best, 0) + 1


func _military(world: SimWorld, mine: _Mine, cmds: Array[SimCommand]) -> void:
	if mine.hq == null:
		return
	_set_rally_points(world, mine, cmds)
	var army_ids: Array[int] = []
	for e: SimEntity in mine.army:
		army_ids.append(e.id)
	if army_ids.is_empty():
		_attacking = false
		return
	var threat: SimEntity = _nearest_threat(world, mine)
	if threat != null and not _attacking:
		cmds.append(SimCommand.make_attack_move(army_ids, threat.x, threat.y))
		return
	if not _attacking and army_ids.size() >= attack_wave_size and world.tick >= first_attack_tick:
		_attacking = true
		_target_id = 0
	if not _attacking:
		return
	var target: SimEntity = world.get_entity(_target_id)
	var retarget: bool = target == null or target.dead
	if retarget:
		target = _pick_target(world, mine.hq)
		_target_id = target.id if target != null else 0
		if target == null:
			return
		cmds.append(SimCommand.make_attack_move(army_ids, target.x, target.y))
		return
	# Units that finished their attack-move (or just arrived from a factory)
	# join the push.
	var idle: Array[int] = []
	for e: SimEntity in mine.army:
		if e.order == SimEntity.Order.IDLE:
			idle.append(e.id)
	if not idle.is_empty():
		cmds.append(SimCommand.make_attack_move(idle, target.x, target.y))


func _set_rally_points(world: SimWorld, mine: _Mine, cmds: Array[SimCommand]) -> void:
	var cx: int = world.map_width / 2
	var cy: int = world.map_height / 2
	var dx: int = cx - mine.hq.x
	var dy: int = cy - mine.hq.y
	var dist: int = maxi(1, Fx.length(dx, dy))
	var rx: int = mine.hq.x + (dx * 22 * Fx.ONE) / dist
	var ry: int = mine.hq.y + (dy * 22 * Fx.ONE) / dist
	for b: SimEntity in mine.buildings:
		if b.building.built and not b.building.produces.is_empty() and not _rally_set.has(b.id):
			_rally_set[b.id] = true
			cmds.append(SimCommand.make_rally(b.id, rx, ry))


## The visible enemy unit closest to one of our buildings, within defend range.
func _nearest_threat(world: SimWorld, mine: _Mine) -> SimEntity:
	var best: SimEntity = null
	var best_d: int = 0
	for b: SimEntity in mine.buildings:
		for e: SimEntity in world.query_radius(b.x, b.y, defend_radius):
			if e.dead or e.mover == null or not world.are_enemies(player_id, e.player_id):
				continue
			if not world.can_see(player_id, e.x, e.y):
				continue
			var d: int = Fx.length(e.x - b.x, e.y - b.y)
			if best == null or d < best_d or (d == best_d and e.id < best.id):
				best = e
				best_d = d
	return best


## Nearest enemy building to our HQ, then nearest enemy builder (so the
## "buildings" victory rule can finish).
func _pick_target(world: SimWorld, hq: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var best_d: int = 0
	for pass_buildings: bool in [true, false]:
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			if e.dead or not world.are_enemies(player_id, e.player_id):
				continue
			if pass_buildings and e.building == null:
				continue
			if not pass_buildings and e.builder == null:
				continue
			var d: int = Fx.length(e.x - hq.x, e.y - hq.y)
			if best == null or d < best_d:
				best = e
				best_d = d
		if best != null:
			return best
	return null
