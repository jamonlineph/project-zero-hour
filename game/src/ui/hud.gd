class_name Hud
extends CanvasLayer
## In-game HUD v1 (P1-25, docs/design/controls-and-ui.md):
## - top bar: credits, power, commander rank, game clock (+ debug line)
## - bottom left: minimap (click/tap to move the camera)
## - bottom center: what is selected
## - bottom right: the 3x4 command grid (unit orders, build menu, production)
## - Place / Cancel buttons while placing a building (for touch)
## Layout uses anchors so it reflows when a Googlebook window is resized.

const HELP_TEXT := "Mouse: click/drag select, right-click move/attack/gather/repair (or set rally with only buildings selected), A+click attack-move, S stop, H hold, grid keys Q-W-E-R / A-S-D-F / Z-X-C-V, Ctrl+1-9 set group, 1-9 select (twice: jump), Ctrl+F5-F8 save view, F5-F8 go to view, wheel zoom, middle-drag, Space+drag or arrows pan, , . rotate, F9 save replay, F1 hide help\nTouch: tap select, tap enemy attack, tap ground move, drag pan, hold then drag box-select, double-tap select type, pinch zoom/rotate, use the grid buttons"
const REFRESH_SEC: float = 0.25

## The Menu button (top right) was pressed: open the pause menu.
signal menu_requested

var selection_box: SelectionBox
var command_grid: CommandGrid
var minimap: Minimap
var touch_bar: TouchBar
var _runner: SimRunner
var _selection: SelectionController
var _camera: RtsCamera
var _placement: PlacementController
var _top: Label
var _debug: Label
var _help: Label
var _banner: Label
var _selection_panel: Label
var _place_buttons: HBoxContainer
var _selected_count: int = 0
var _last_hash: int = 0
var _refresh: float = 0.0


func _ready() -> void:
	selection_box = SelectionBox.new()
	selection_box.name = "SelectionBox"
	add_child(selection_box)

	var top_panel := PanelContainer.new()
	top_panel.name = "TopBar"
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_panel)
	_top = Label.new()
	_top.add_theme_font_size_override("font_size", 18)
	top_panel.add_child(_top)

	_debug = Label.new()
	_debug.name = "Debug"
	_debug.add_theme_font_size_override("font_size", 11)
	_debug.modulate = Color(1, 1, 1, 0.6)
	_debug.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug.position.y = 52
	add_child(_debug)

	_help = Label.new()
	_help.name = "Help"
	_help.text = HELP_TEXT
	_help.add_theme_font_size_override("font_size", 11)
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.position = Vector2(12, 40)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size.x = 560.0
	add_child(_help)

	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.custom_minimum_size = Vector2(180, 180)
	minimap.size = Vector2(180, 180)
	add_child(minimap)

	_selection_panel = Label.new()
	_selection_panel.name = "SelectionPanel"
	_selection_panel.add_theme_font_size_override("font_size", 14)
	_selection_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_panel.custom_minimum_size = Vector2(360, 100)
	add_child(_selection_panel)

	command_grid = CommandGrid.new()
	command_grid.name = "CommandGrid"
	add_child(command_grid)

	_place_buttons = HBoxContainer.new()
	_place_buttons.name = "PlaceButtons"
	var place := Button.new()
	place.text = "Place"
	place.custom_minimum_size = Vector2(110, 52)
	place.pressed.connect(func() -> void: if _placement != null: _placement.confirm())
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(110, 52)
	cancel.pressed.connect(func() -> void: if _placement != null: _placement.cancel())
	_place_buttons.add_child(place)
	_place_buttons.add_child(cancel)
	_place_buttons.visible = false
	add_child(_place_buttons)

	var menu := Button.new()
	menu.name = "MenuButton"
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(90, 44)
	menu.focus_mode = Control.FOCUS_NONE
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.position = Vector2(-100, 4)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	add_child(menu)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.visible = false
	add_child(_banner)


func setup(runner: SimRunner) -> void:
	_runner = runner
	_runner.ticked.connect(_on_ticked)


## Call once the selection controller, camera and placement exist.
func bind_controls(selection: SelectionController, cam: RtsCamera, placement: PlacementController) -> void:
	_selection = selection
	_camera = cam
	_placement = placement
	minimap.setup(_runner.world, selection.local_player_id, cam)
	minimap.jump_requested.connect(func(p: Vector3) -> void: cam.focus_on(p))
	placement.placement_changed.connect(func(active: bool) -> void: _place_buttons.visible = active)
	touch_bar = TouchBar.new()
	add_child(touch_bar)
	touch_bar.setup(selection)
	selection.long_pressed.connect(open_radial)
	refresh_commands()


## Opens the long-press order menu at a screen position (P1-24).
func open_radial(pos: Vector2) -> RadialMenu:
	var old: Node = get_node_or_null("RadialMenu")
	if old != null:
		old.free()
	var menu := RadialMenu.new()
	add_child(menu)
	if not menu.open(_selection, pos):
		return null
	return menu


func on_selection_changed(ids: Array[int]) -> void:
	_selected_count = ids.size()
	refresh_commands()


func toggle_help() -> void:
	_help.visible = not _help.visible


## Rebuilds the command grid for the current selection.
func refresh_commands() -> void:
	if _selection == null or command_grid == null:
		return
	var world: SimWorld = _runner.world
	var entries: Array[Dictionary] = []
	var builders: bool = false
	var units: bool = false
	var producer: SimEntity = null
	for id: int in _selection.selected:
		var e: SimEntity = world.get_entity(id)
		if e == null:
			continue
		builders = builders or e.builder != null
		units = units or e.mover != null
		if producer == null and e.building != null and e.building.built and not e.building.produces.is_empty():
			producer = e
	if builders:
		entries = _build_menu(world)
	elif units:
		entries = _unit_orders()
	elif producer != null:
		entries = _production_menu(world, producer)
	command_grid.set_entries(entries)


func _unit_orders() -> Array[Dictionary]:
	var none: Dictionary = {"label": "", "enabled": false}
	return [
		none, none, none, none,
		{"label": "Attack-move", "tooltip": "Then tap or click the target point", "action": func() -> void: _selection.attack_move_armed = true},
		{"label": "Stop", "action": _selection.order_stop},
		{"label": "Hold", "action": _selection.order_hold},
	]


func _build_menu(world: SimWorld) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var player: SimPlayer = world.get_player(_selection.local_player_id)
	for def: BuildingDef in world.content.buildings.values():
		if def.faction != player.faction or entries.size() >= 12:
			continue
		var ok: bool = player.credits >= def.cost and world.has_requirements(_selection.local_player_id, def.requires)
		entries.append({
			"label": "%s\n%d" % [def.name, def.cost],
			"icon": _icon(def.icon_path),
			"enabled": ok,
			"tooltip": "%s (%d credits)%s" % [def.name, def.cost, "" if ok else _missing(world, def.requires, def.cost)],
			"action": func() -> void: _placement.begin(def.id),
		})
	return entries


func _production_menu(world: SimWorld, building: SimEntity) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var player: SimPlayer = world.get_player(_selection.local_player_id)
	for unit_id: String in building.building.produces:
		var def: UnitDef = world.content.get_unit(unit_id)
		if def == null:
			continue
		var queued: int = building.building.queue.count(unit_id)
		var ok: bool = player.credits >= def.cost and world.has_requirements(_selection.local_player_id, def.requires) \
			and building.building.queue.size() < SimBuilding.MAX_QUEUE
		var bid: int = building.id
		entries.append({
			"label": "%s\n%d%s" % [def.name, def.cost, " (x%d)" % queued if queued > 0 else ""],
			"icon": _icon(def.icon_path),
			"enabled": ok,
			"tooltip": "%s (%d credits). Right-click or Shift+key cancels one.%s" % [def.name, def.cost, "" if ok else _missing(world, def.requires, def.cost)],
			"action": func() -> void: _runner.submit(SimCommand.make_produce(bid, unit_id)),
			"alt_action": func() -> void: _cancel_last(bid, unit_id),
		})
	return entries


func _cancel_last(building_id: int, unit_id: String) -> void:
	var b: SimEntity = _runner.world.get_entity(building_id)
	if b == null or b.building == null:
		return
	var slot: int = b.building.queue.rfind(unit_id)
	if slot >= 0:
		_runner.submit(SimCommand.make_cancel(building_id, slot))


func _missing(world: SimWorld, requires: PackedStringArray, cost: int) -> String:
	var parts: PackedStringArray = []
	if world.get_player(_selection.local_player_id).credits < cost:
		parts.append("not enough credits")
	for r: String in requires:
		if not world.has_requirements(_selection.local_player_id, [r]):
			var def: BuildingDef = world.content.get_building(r)
			parts.append("needs " + (def.name if def != null else r))
	return " - " + ", ".join(parts) if not parts.is_empty() else ""


func _icon(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func _on_ticked(tick: int) -> void:
	# Hashing every tick is wasteful; once per second is enough for a debug line.
	if tick % SimWorld.TICK_RATE == 0:
		_last_hash = _runner.world.state_hash()


func _process(delta: float) -> void:
	if _runner == null or _runner.world == null:
		return
	var world: SimWorld = _runner.world
	var p: SimPlayer = world.get_player(_runner.local_player_id)
	var secs: int = world.tick / SimWorld.TICK_RATE
	_top.text = "  Credits %d     Power %d / %d%s     Rank %s     %d:%02d" % [
		p.credits, p.power_used, p.power_produced, "  LOW POWER" if p.low_power() else "",
		"*".repeat(p.rank) + ".".repeat(5 - p.rank), secs / 60, secs % 60]
	_debug.text = "tick %d | %d fps | state %08x  " % [world.tick, Engine.get_frames_per_second(), _last_hash]
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SEC
		refresh_commands()
		_selection_panel.text = _describe_selection(world)
	_layout()
	if world.game_over and not _banner.visible:
		var my_team: int = world.team_of(_runner.local_player_id)
		_banner.text = "DRAW" if world.winner_team == 0 else ("VICTORY" if world.winner_team == my_team else "DEFEAT")
		_banner.visible = true


func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_help.custom_minimum_size.x = minf(560.0, view.x * 0.6)
	_help.size.x = _help.custom_minimum_size.x
	var margin: float = 10.0
	minimap.position = Vector2(margin, view.y - minimap.size.y - margin)
	if touch_bar != null:
		touch_bar.position = Vector2(margin, minimap.position.y - TouchBar.BUTTON_SIZE.y - 8.0)
	var grid_size: Vector2 = command_grid.get_combined_minimum_size()
	command_grid.position = Vector2(view.x - grid_size.x - margin, view.y - grid_size.y - margin)
	_place_buttons.position = Vector2(view.x - grid_size.x - margin, command_grid.position.y - 60.0)
	_selection_panel.position = Vector2(minimap.position.x + minimap.size.x + 16.0, view.y - 110.0)
	_selection_panel.size.x = maxf(160.0, command_grid.position.x - _selection_panel.position.x - 16.0)
	_debug.position.x = view.x - _debug.size.x - margin
	if _banner.visible:
		_banner.position = (view - _banner.size) * 0.5


func _describe_selection(world: SimWorld) -> String:
	if _selection == null or _selection.selected.is_empty():
		return ""
	if _selection.selected.size() == 1:
		var e: SimEntity = world.get_entity(_selection.selected[0])
		if e == null:
			return ""
		var text: String = "%s   %d / %d hp" % [_name_of(world, e.def_id), e.hp, e.max_hp]
		if e.vet_rank > 0:
			text += "   veteran " + "*".repeat(e.vet_rank)
		if e.building != null:
			if not e.building.built:
				text += "   building %d%%" % ((100 * e.building.progress) / maxi(1, e.building.total))
			elif not e.building.queue.is_empty():
				var def: UnitDef = world.content.get_unit(e.building.queue[0])
				var pct: int = (100 * e.building.queue_progress) / maxi(1, def.build_ticks if def != null else 1)
				text += "\nQueue: %s (%d%%)%s" % [_name_of(world, e.building.queue[0]), pct,
					" + %d more" % (e.building.queue.size() - 1) if e.building.queue.size() > 1 else ""]
		if e.gatherer != null and e.gatherer.carried > 0:
			text += "   carrying %d" % e.gatherer.carried
		if e.supply != null:
			text = "Supply site   %d credits left" % e.supply.remaining
		return text
	var counts: Dictionary[String, int] = {}
	for id: int in _selection.selected:
		var e: SimEntity = world.get_entity(id)
		if e != null:
			counts[e.def_id] = counts.get(e.def_id, 0) + 1
	var parts: PackedStringArray = []
	for def_id: String in counts:
		parts.append("%dx %s" % [counts[def_id], _name_of(world, def_id)])
	return "%d selected: %s" % [_selection.selected.size(), ", ".join(parts)]


func _name_of(world: SimWorld, def_id: String) -> String:
	if world.content == null:
		return def_id
	var u: UnitDef = world.content.get_unit(def_id)
	if u != null:
		return u.name
	var b: BuildingDef = world.content.get_building(def_id)
	return b.name if b != null else def_id
