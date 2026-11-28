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
## Unarmed spotters (recon drones) kept at once. Without a cap the AI kept
## replacing lost drones and spent a third of its credits on them (P2-12).
var max_spotters: int = 2
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
## Own random numbers, seeded from the sim's state at the first think, so each
## match seed plays out differently without touching the sim's rng (P2-11c).
var _rng: SimRng = null
var _wave_size: int = 0          ## this match's wave size (attack_wave_size +-1)
var _first_attack: int = 0       ## this match's first attack tick (+-15 s)
## An army that hasn't grown for this long attacks anyway, so a broke AI
## doesn't wait forever for a full wave (P2-12: a Twin Ridge duel stalled).
const STALL_TICKS: int = 90 * SimWorld.TICK_RATE
var _army_size: int = 0
var _grew_at: int = 0
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
	ai.max_spotters = int(p.get("max_spotters", 2))
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
	if world.tick % think_interval != 0:   # every AI on the same tick: no one reacts first (P2-11c)
		return cmds
	if _rng == null:
		_seed(world)
	var mine := _Mine.new(world, player_id)
	_keep_builders(world, mine, cmds)
	var reserve: int = _build(world, mine, cmds)
	_gatherers(world, mine, cmds, reserve)
	AiProduction.produce(world, self, mine.army, mine.buildings, cmds, reserve)
	_military(world, mine, cmds)
	AiStrategy.research(world, self, mine.buildings, reserve, cmds)
	if difficulty != "easy" or (world.tick / think_interval) % 2 == 0:
		AiStrategy.powers(world, self, mine.hq, mine.army, cmds)
	return cmds


## Picks this match's variations. Without them every seed plays the same
## game, so AI-vs-AI results said nothing about balance (P2-11c).
func _seed(world: SimWorld) -> void:
	_rng = SimRng.new(world.rng.state ^ (player_id * 0x9E3779B1))
	_wave_size = maxi(2, attack_wave_size - 1 + _rng.range_int(3))
	_first_attack = maxi(0, first_attack_tick - 15 * SimWorld.TICK_RATE + _rng.range_int(30 * SimWorld.TICK_RATE + 1))


## Everything the AI owns, sorted by kind. Built once per think.
class _Mine:
	var buildings: Array[SimEntity] = []
	var builders: Array[SimEntity] = []
	var gatherers: Array[SimEntity] = []
	var army: Array[SimEntity] = []
	var hq: SimEntity = null
	var garrisoned: int = 0   ## our units inside buildings (P3-05)

	func _init(world: SimWorld, pid: int) -> void:
		for id: int in world.entity_ids:
			var e: SimEntity = world.entities[id]
			if e.player_id != pid or e.dead:
				continue
			if e.inside_id != 0:
				garrisoned += 1
				continue
			if e.building != null and e.garrison != null and e.garrison.neutral:
				continue   # a town house we hold isn't part of our base
			if e.building != null:
				buildings.append(e)
				if hq == null and e.def_id.ends_with("_command_hq"):
					hq = e
			elif e.builder != null:
				builders.append(e)
			elif e.gatherer != null:
				gatherers.append(e)
			elif e.mover != null and e.ttl == 0 and (not e.weapons.is_empty() or e.spotter):
				# Spotters (recon drones) move with the army, so kill-chain
				# weapons have someone marking their targets (P2-11c).
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
			var origin: Vector2i = world.footprint_origin(def, cx, cy)
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


## Rolls this match's noise in [0, bound) (AiProduction uses it).
func noise(bound: int) -> int:
	return _rng.range_int(maxi(1, bound))


func _military(world: SimWorld, mine: _Mine, cmds: Array[SimCommand]) -> void:
	if mine.hq == null:
		return
	_set_rally_points(world, mine, cmds)
	# Armed units fight; unarmed spotters (recon drones) hover over the army
	# instead of leading the charge, where rifles shot them down (P2-11e).
	var army_ids: Array[int] = []
	var fighters: Array[SimEntity] = []
	var spotters: Array[SimEntity] = []
	var support: Array[SimEntity] = []   ## unarmed helpers such as medics (P3-12a)
	for e: SimEntity in mine.army:
		if e.weapons.is_empty() and e.spotter:
			spotters.append(e)
		elif e.weapons.is_empty():
			support.append(e)
		else:
			fighters.append(e)
			army_ids.append(e.id)
	var lead_target: SimEntity = world.get_entity(_target_id) if _attacking else null
	AiTactics.escort(lead_target, spotters, fighters, cmds)
	AiTactics.escort(null, support, fighters, cmds)   # medics stay in the middle of the army
	AiTactics.use_abilities(world, fighters, cmds)
	if army_ids.is_empty():
		_attacking = false
		_army_size = 0
		_grew_at = world.tick
		return
	var threat: SimEntity = _nearest_threat(world, mine)
	if threat != null and not _attacking:
		cmds.append(SimCommand.make_attack_move(army_ids, threat.x, threat.y))
		return
	if army_ids.size() > _army_size:
		_grew_at = world.tick
	_army_size = army_ids.size()
	var stalled: bool = world.tick - _grew_at >= STALL_TICKS
	if not _attacking and (army_ids.size() >= _wave_size or stalled) and world.tick >= _first_attack:
		_attacking = true
		_target_id = 0
	if not _attacking:
		AiTactics.occupy_town(world, mine.hq, mine.army, mine.garrisoned, cmds)
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
	for e: SimEntity in fighters:
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
			# Up to 20 m of noise, so waves don't always take the same route.
			var d: int = Fx.length(e.x - hq.x, e.y - hq.y) + _rng.range_int(20) * Fx.ONE
			if best == null or d < best_d:
				best = e
				best_d = d
		if best != null:
			return best
	return null
