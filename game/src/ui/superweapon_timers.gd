class_name SuperweaponTimers
extends Label
## Every superweapon on the map and its countdown, shown to all players
## (P3-03: "countdown visible to everyone"), under the top bar on the right.
## View only: reads AbilitySystem cooldowns from the sim.


func _init() -> void:
	name = "SuperweaponTimers"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", UiTheme.ACCENT)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position.y = 74
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lines like "North Korea superweapon  2:31" or "... READY", or nothing.
func refresh(world: SimWorld) -> void:
	var lines: PackedStringArray = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.dead or e.building == null or not e.building.built:
			continue
		for a: AbilityDef in AbilitySystem.abilities_of(world, e):
			if a.kind != "superweapon":
				continue
			var faction: String = world.get_player(e.player_id).faction
			var who: String = str(MatchConfig.FACTIONS.get(faction, "Player %d" % e.player_id))
			var left: int = maxi(0, int(e.ability_ready.get(a.id, 0)) - world.tick) / SimWorld.TICK_RATE
			lines.append("%s %s  %s  " % [who, a.name, "READY" if left == 0 else "%d:%02d" % [left / 60, left % 60]])
	text = "\n".join(lines)
