class_name AbilityInput
extends RefCounted
## The click that aims an armed unit ability (P3-02f): sends USE_ABILITY with
## the ground point and, if there is one under the pointer, the enemy
## building there (for "disable"). Split out of SelectionController.


static func click(sel: SelectionController, screen_pos: Vector2) -> void:
	var ability: String = sel.ability_armed
	sel.ability_armed = ""
	var ground: Variant = sel.rts_camera.screen_to_ground(screen_pos)
	if ground == null or sel.selected.is_empty():
		return
	var target: int = sel.pick_entity(screen_pos, func(e: SimEntity) -> bool:
		return e.building != null and e.player_id != sel.local_player_id and e.player_id != 0)
	var p: Vector3 = ground
	sel.runner.submit(SimCommand.make_use_ability(sel.selected, ability, Fx.from_float(p.x), Fx.from_float(p.z), target))
