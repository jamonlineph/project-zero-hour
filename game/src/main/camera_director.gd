class_name CameraDirector
extends Node
## Developer tool for gameplay videos (`--director`): moves the camera to
## where the action is, the way a spectator would. Reads sim events and state
## only (view side). Also saves a screenshot every `shot_every_s` game seconds
## when `--shot-dir=` is given, and quits a few seconds after the match ends.
## Record with Godot's movie writer, for example:
##   godot -- --watch=riverside --director --reveal --seed=5003 --speed=3 \
##     --write-movie match.avi --fixed-fps 30   (engine flags go before --)

const DECIDE_EVERY_S: float = 2.0      ## game seconds between focus choices
const HEAT_LIFETIME_S: float = 6.0     ## how long a shot or death keeps a spot hot
const CLUSTER_M: float = 25.0
const BASE_TOUR_S: float = 10.0        ## quiet times alternate between the bases
const QUIT_AFTER_END_S: float = 6.0

var world: SimWorld
var content: ContentDb
var rts_camera: RtsCamera
var shot_dir: String = ""
var shot_every_s: float = 10.0

var _heat: Array[Dictionary] = []      ## {"p": Vector3, "t": float (game s), "w": float}
var _target := Vector3.ZERO
var _target_distance: float = 60.0
var _next_decide: float = 0.0
var _next_shot: float = 0.0
var _tour_side: int = 0
var _next_tour: float = 0.0
var _end_timer: float = -1.0


func setup(sim_world: SimWorld, content_db: ContentDb, camera: RtsCamera) -> void:
	name = "CameraDirector"
	world = sim_world
	content = content_db
	rts_camera = camera
	_target = rts_camera.position
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)


func _game_s() -> float:
	return world.tick / float(SimWorld.TICK_RATE)


## Feeds the sim events of the frame (call before they are cleared).
func observe(events: Array[Dictionary]) -> void:
	var now: float = _game_s()
	for ev: Dictionary in events:
		match ev["type"]:
			"hit":
				_add_heat(ev, now, 1.0)
			"died":
				var big: bool = content.get_building(str(ev.get("def_id", ""))) != null
				_add_heat(ev, now, 8.0 if big else 3.0)


func _add_heat(ev: Dictionary, now: float, w: float) -> void:
	if not ev.has("x"):
		return
	_heat.append({"p": Vector3(Fx.to_float(ev["x"]), 0.0, Fx.to_float(ev["y"])), "t": now, "w": w})


func _process(delta: float) -> void:
	if world == null:
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var now: float = _game_s()
	if world.game_over:
		if _end_timer < 0.0:
			_end_timer = 0.0
			Engine.time_scale = 1.0
		_end_timer += real_delta
		if _end_timer >= QUIT_AFTER_END_S:
			_save_shot("end")
			get_tree().quit()
		return
	if now >= _next_decide:
		_next_decide = now + DECIDE_EVERY_S
		_decide(now)
	var k: float = 1.0 - exp(-real_delta * 1.2)
	rts_camera.focus_on(rts_camera.position.lerp(_target, k))
	rts_camera.distance = lerpf(rts_camera.distance, _target_distance, k)
	rts_camera.zoom_by(1.0)
	if shot_dir != "" and now >= _next_shot:
		_next_shot = now + shot_every_s
		_save_shot("t%04d" % int(now))


## Picks the hottest fight; with no fighting, tours the two bases.
func _decide(now: float) -> void:
	var fresh: Array[Dictionary] = []
	for h: Dictionary in _heat:
		if now - float(h["t"]) < HEAT_LIFETIME_S:
			fresh.append(h)
	_heat = fresh
	var best := Vector3.ZERO
	var best_score: float = 0.0
	for h: Dictionary in _heat:
		var score: float = 0.0
		var sum := Vector3.ZERO
		for o: Dictionary in _heat:
			if (o["p"] as Vector3).distance_to(h["p"]) < CLUSTER_M:
				var w: float = float(o["w"]) * (1.0 - (now - float(o["t"])) / HEAT_LIFETIME_S)
				score += w
				sum += (o["p"] as Vector3) * w
		if score > best_score:
			best_score = score
			best = sum / score
	if best_score >= 4.0:
		_target = best
		_target_distance = 48.0
		return
	if now >= _next_tour:
		_next_tour = now + BASE_TOUR_S
		_tour_side = 1 - _tour_side
		var base: Variant = _base_of(_tour_side + 1)
		if base != null:
			_target = base
			_target_distance = 62.0


## Center of a player's buildings, or null.
func _base_of(player: int) -> Variant:
	var sum := Vector3.ZERO
	var n: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == player and not e.dead and e.building != null:
			sum += Vector3(Fx.to_float(e.x), 0.0, Fx.to_float(e.y))
			n += 1
	return sum / n if n > 0 else null


func _save_shot(tag: String) -> void:
	if shot_dir == "":
		return
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join("%s.png" % tag))
