class_name GameView
extends Node3D
## Keeps one UnitView per sim entity and moves them smoothly every frame.
## The view only reads the sim. Player intent goes through SimCommands.

var world: SimWorld
var content: ContentDb
## Units of other teams are only drawn where this player can see (fog of war).
var local_player_id: int = 1
var _views: Dictionary[int, UnitView] = {}
var _wreck_material: StandardMaterial3D
var effects: CombatEffects
## Terrain height at (x, z) in meters (TerrainView.height_at); flat if unset.
var ground_height: Callable
## Developer videos (`--reveal`): draw every unit, ignoring the fog.
var reveal_all: bool = false
var sounds: GameSounds
var wrecks_made: int = 0


func setup(sim_world: SimWorld, content_db: ContentDb) -> void:
	world = sim_world
	content = content_db
	effects = CombatEffects.new()
	add_child(effects)
	sounds = GameSounds.new()
	add_child(sounds)


## Call once per frame after the sim has stepped. alpha = progress into the tick.
func sync(alpha: float) -> void:
	for id: int in world.entity_ids:
		if not _views.has(id):
			_create_view(world.entities[id])
	for id: int in _views.keys():
		if not world.entities.has(id):
			_remove_view(id)
	var delta: float = get_process_delta_time() if is_inside_tree() else 0.0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var v: UnitView = _views[id]
		v.update_from_sim(e, alpha)
		if ground_height.is_valid():
			v.position.y = ground_height.call(v.position.x, v.position.z)
		v.visible = is_shown(e)
		if v.visible:
			v.update_status(e)
			_aim(e, v, delta)
			_show_upgrades(e, v)
			if e.decoy_of != "":
				v.set_decoy_look(not world.are_enemies(local_player_id, e.player_id)
						or DecoySystem.is_known_decoy(world, local_player_id, e))


## Fog of war: enemies show only where this player sees; neutral things such
## as supply sites show once their ground has been explored.
func is_shown(e: SimEntity) -> bool:
	if reveal_all:
		return true
	if e.player_id == 0:
		return world.vision.is_explored(world.team_of(local_player_id), e.x, e.y)
	return not world.are_enemies(local_player_id, e.player_id) or world.can_see(local_player_id, e.x, e.y)


## Upgrade parts on the model (P2-05): per-unit kits plus researched upgrades.
func _show_upgrades(e: SimEntity, v: UnitView) -> void:
	if e.player_id == 0 or content == null:
		return
	var player_ups: PackedStringArray = world.get_player(e.player_id).upgrades
	var sig: int = e.upgrades.size() * 1000 + player_ups.size()
	var parts := PackedStringArray()
	if sig > 0:
		for list: PackedStringArray in [e.upgrades, player_ups]:
			for up_id: String in list:
				var def: UpgradeDef = content.get_upgrade(up_id)
				if def != null and def.attachment != "" and def.applies(e.def_id):
					parts.append(def.attachment)
	v.update_upgrades(parts, sig)


## Points turrets at the first weapon's target. Ballistic weapons raise the
## barrel more the farther the target is.
func _aim(e: SimEntity, v: UnitView, delta: float) -> void:
	if not v.has_turret() or e.weapons.is_empty():
		return
	var w: SimWeapon = e.weapons[0]
	var t: SimEntity = world.get_entity(w.target_id) if w.target_id != 0 else null
	if t == null:
		v.aim(Vector3.ZERO, false, 0.0, delta)
		return
	var target := Vector3(Fx.to_float(t.x), 0.0, Fx.to_float(t.y))
	var elevation: float = 0.03
	if w.projectile == "ballistic" and w.max_range > 0:
		var dist: float = Vector2(Fx.to_float(t.x - e.x), Fx.to_float(t.y - e.y)).length()
		elevation = clampf(dist / Fx.to_float(w.max_range), 0.15, 1.0) * 0.7
	v.aim(target, true, elevation, delta)


func _remove_view(id: int) -> void:
	var v: UnitView = _views[id]
	_views.erase(id)
	if v.visible:
		if _wreck_material == null:
			_wreck_material = StandardMaterial3D.new()
			_wreck_material.albedo_color = Color(0.12, 0.11, 0.1)
			_wreck_material.roughness = 1.0
		v.become_wreck(_wreck_material)
		wrecks_made += 1
	else:
		v.queue_free()


## Effects for sim events (P1-28). Nothing plays where this player can't see.
func play_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		match ev["type"]:
			"fired":
				var shooter: UnitView = _views.get(ev["attacker"], null)
				if shooter == null or not shooter.visible:
					continue
				var from: Vector3 = shooter.muzzle_position()
				effects.play(CombatEffects.Kind.MUZZLE, from)
				var weapon: WeaponDef = content.weapons.get(str(ev["weapon"]), null) if content != null else null
				if weapon == null or weapon.projectile == "instant":
					var tx: float = Fx.to_float(ev["tx"])
					var tz: float = Fx.to_float(ev["ty"])
					var beam: bool = weapon != null and weapon.damage_type == "counter_drone"
					var aim_y: float = UnitView.DRONE_HOVER_M if beam else 1.0
					effects.tracer(from, Vector3(tx, _ground(tx, tz) + aim_y, tz),
							CombatEffects.LASER_COLOR if beam else CombatEffects.TRACER_COLOR)
				sounds.play_at(GameSounds.weapon_sound(weapon), from)
			"hit":
				if not world.can_see(local_player_id, ev["x"], ev["y"]):
					continue
				var radius_m: float = Fx.to_float(ev["radius"])
				var at := Vector3(Fx.to_float(ev["x"]), 0.0, Fx.to_float(ev["y"]))
				at.y = _ground(at.x, at.z) + 0.6
				effects.play(CombatEffects.Kind.EXPLOSION, at, clampf(0.4 + radius_m * 0.25, 0.4, 3.0))
				if radius_m > 0.0:
					sounds.play_at("explosion_small", at)
			"died":
				if not world.can_see(local_player_id, ev["x"], ev["y"]):
					continue
				var at := Vector3(Fx.to_float(ev["x"]), 0.0, Fx.to_float(ev["y"]))
				at.y = _ground(at.x, at.z) + 0.8
				var unit: UnitDef = content.get_unit(str(ev["def_id"])) if content != null else null
				if unit != null and unit.is_infantry():
					effects.play(CombatEffects.Kind.EXPLOSION, at, 0.6)
				else:
					var big: float = 2.0 if unit == null else 1.0   # buildings blow up bigger
					effects.play(CombatEffects.Kind.DEATH, at, big)
					effects.play(CombatEffects.Kind.SMOKE, at, big)
					sounds.play_at("explosion_large", at)
			"intercepted", "intercept_failed":
				# Active protection firing (P2-06).
				if not world.can_see(local_player_id, ev["x"], ev["y"]):
					continue
				var at := Vector3(Fx.to_float(ev["x"]), 0.0, Fx.to_float(ev["y"]))
				at.y = _ground(at.x, at.z) + 2.0
				effects.play(CombatEffects.Kind.MUZZLE, at, 1.5)
				if ev["type"] == "intercepted":
					effects.play(CombatEffects.Kind.EXPLOSION, at, 0.5)
				sounds.play_at("autocannon", at)
			"built":
				if int(ev["player"]) == local_player_id:
					sounds.play_ui("build_complete")


func _ground(x: float, z: float) -> float:
	return ground_height.call(x, z) if ground_height.is_valid() else 0.0


func get_view(entity_id: int) -> UnitView:
	return _views.get(entity_id, null)


## Small fading ring where a move order was given.
func show_move_marker(point: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 1.0, 0.5, 0.9)
	var marker := MeshInstance3D.new()
	marker.mesh = torus
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(point.x, _ground(point.x, point.z) + 0.08, point.z)
	marker.scale = Vector3(1.0, 0.1, 1.0)
	add_child(marker)
	var tween := marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(0.2, 0.1, 0.2), 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(marker.queue_free)


func _create_view(e: SimEntity) -> void:
	var v := UnitView.new()
	v.setup_entity(e, content, TeamColors.for_player(e.player_id))
	add_child(v)
	_views[e.id] = v
