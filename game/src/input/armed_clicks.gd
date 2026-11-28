class_name ArmedClicks
extends RefCounted
## The click or tap that completes a pending order (split out of
## SelectionController in P3-25): attack-move, patrol, commander power, unit
## or building ability (P3-02f, P3-03), spoof and guard. UI only: every
## result is a SimCommand sent through the runner.


## Runs the pending order at `screen_pos`. Returns true if one was pending.
static func handle(sel: SelectionController, screen_pos: Vector2) -> bool:
	if sel.attack_move_armed:
		sel.order_attack_move(screen_pos)
		return true
	if sel.patrol_armed:
		sel.order_patrol(screen_pos)
		return true
	if sel.power_armed != "":
		var power: String = sel.power_armed
		sel.power_armed = ""
		var at: Variant = sel.rts_camera.screen_to_ground(screen_pos)
		if at != null:
			sel.runner.submit(SimCommand.make_use_power(power, Fx.from_float((at as Vector3).x), Fx.from_float((at as Vector3).z)))
		return true
	if sel.ability_armed != "":
		_ability(sel, screen_pos)
		return true
	if sel.spoof_armed:
		sel.spoof_armed = false
		var ground: Variant = sel.rts_camera.screen_to_ground(screen_pos)
		if ground != null and not sel.selected.is_empty():
			var p: Vector3 = ground
			sel.runner.submit(SimCommand.make_spoof(sel.selected, Fx.from_float(p.x), Fx.from_float(p.z)))
		return true
	if sel.guard_armed:
		sel.guard_armed = false
		var ward: int = sel.pick_own_entity(screen_pos)
		if ward != 0:
			sel.order_guard(ward)
		return true
	return false


## An armed ability: the ground point and, if there is one under the
## pointer, the enemy building there (for "disable").
static func _ability(sel: SelectionController, screen_pos: Vector2) -> void:
	var ability: String = sel.ability_armed
	sel.ability_armed = ""
	var ground: Variant = sel.rts_camera.screen_to_ground(screen_pos)
	if ground == null or sel.selected.is_empty():
		return
	var target: int = sel.pick_entity(screen_pos, func(e: SimEntity) -> bool:
		return e.building != null and e.player_id != sel.local_player_id and e.player_id != 0)
	var p: Vector3 = ground
	sel.runner.submit(SimCommand.make_use_ability(sel.selected, ability, Fx.from_float(p.x), Fx.from_float(p.z), target))
