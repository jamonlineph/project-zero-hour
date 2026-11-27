class_name Hud
extends CanvasLayer
## In-game HUD v1 (P1-25, docs/design/controls-and-ui.md):
## - top bar: credits, power, commander rank, game clock (+ debug line)
## - bottom left: minimap (click/tap to move the camera)
## - bottom center: what is selected
## - bottom right: the 3x4 command grid (unit orders, build menu, production)
## - Place / Cancel buttons while placing a building (for touch)
## Layout uses anchors so it reflows when a Googlebook window is resized.

const HELP_TEXT := "Mouse: click/drag select, right-click move/attack/gather/repair (or set rally with only buildings selected), A+click attack-move, G+click guard, S stop, H hold, grid keys Q-W-E-R / A-S-D-F / Z-X-C-V, Ctrl+1-9 set group, 1-9 select (twice: jump), Ctrl+F5-F8 save view, F5-F8 go to view, wheel zoom, middle-drag, Space+drag or arrows pan, , . rotate, F9 save replay, F1 hide help\nTouch: tap select, tap enemy attack, tap ground move, drag pan, hold then drag box-select, double-tap select type, pinch zoom/rotate, use the grid buttons"
const REFRESH_SEC: float = 0.25
const FUND_SECONDS: float = 5.0   ## how long "+N fund" stays in the top bar (P3-02b)

## The Menu button (top right) was pressed: open the pause menu.
signal menu_requested

var selection_box: SelectionBox
var command_grid: CommandGrid
var minimap: Minimap
var touch_bar: TouchBar
var power_bar: PowerBar
var _runner: SimRunner
var _selection: SelectionController
var _menus: CommandMenus
var _camera: RtsCamera
var _placement: PlacementController
var _top: Label
var _debug: Label
var _help: Label
var _banner: Label
var _selection_panel: Label
var _minimap_frame: Panel     ## framed backgrounds (P2-17)
var _notice: Label
var _selection_frame: Panel
var _place_buttons: HBoxContainer
var _selected_count: int = 0
var _last_hash: int = 0
var _refresh: float = 0.0
var _fund_gain: int = 0
var _fund_shown: float = 0.0


func _ready() -> void:
	UiTheme.apply_to_layer(self)
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

	_minimap_frame = Panel.new()
	_minimap_frame.name = "MinimapFrame"
	_minimap_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap_frame)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.custom_minimum_size = Vector2(180, 180)
	minimap.size = Vector2(180, 180)
	add_child(minimap)

	_selection_frame = Panel.new()
	_selection_frame.name = "SelectionFrame"
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_frame)
	_selection_panel = Label.new()
	_selection_panel.name = "SelectionPanel"
	_selection_panel.add_theme_font_size_override("font_size", 16)
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
	_banner.add_theme_font_override("font", UiTheme.bold_font())
	_banner.add_theme_color_override("font_color", UiTheme.ACCENT)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.visible = false
	add_child(_banner)


## A short message at the top of the screen that fades after a few seconds.
func show_notice(text: String, seconds: float = 6.0) -> void:
	if _notice == null:
		_notice = Label.new()
		_notice.name = "Notice"
		_notice.add_theme_color_override("font_color", UiTheme.ACCENT)
		_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_notice.position.y = 96
		add_child(_notice)
	_notice.text = text
	_notice.modulate.a = 1.0
	_notice.visible = true
	var t := _notice.create_tween()
	t.tween_interval(seconds)
	t.tween_property(_notice, "modulate:a", 0.0, 1.0)


func setup(runner: SimRunner) -> void:
	_runner = runner
	_runner.ticked.connect(_on_ticked)


## Call once the selection controller, camera and placement exist.
func bind_controls(selection: SelectionController, cam: RtsCamera, placement: PlacementController) -> void:
	_selection = selection
	_camera = cam
	_placement = placement
	_menus = CommandMenus.new(_runner, selection, placement)
	minimap.setup(_runner.world, selection.local_player_id, cam)
	minimap.jump_requested.connect(func(p: Vector3) -> void: cam.focus_on(p))
	placement.placement_changed.connect(func(active: bool) -> void: _place_buttons.visible = active)
	touch_bar = TouchBar.new()
	add_child(touch_bar)
	touch_bar.setup(selection)
	power_bar = PowerBar.new()
	add_child(power_bar)
	power_bar.setup(_runner, selection, selection.local_player_id)
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
	if _menus == null or command_grid == null:
		return
	command_grid.set_entries(_menus.entries())


func _on_ticked(tick: int) -> void:
	for ev: Dictionary in _runner.world.events:
		if ev.get("type") == "interest" and int(ev.get("player", 0)) == _runner.local_player_id:
			_fund_gain = int(ev["amount"])
			_fund_shown = FUND_SECONDS
	# Hashing every tick is wasteful; once per second is enough for a debug line.
	if tick % SimWorld.TICK_RATE == 0:
		_last_hash = _runner.world.state_hash()
		# Research progress, cooldowns and credits change over time.
		if _selection != null and not _selection.selected.is_empty():
			refresh_commands()


func _process(delta: float) -> void:
	if _runner == null or _runner.world == null:
		return
	var world: SimWorld = _runner.world
	var p: SimPlayer = world.get_player(_runner.local_player_id)
	var secs: int = world.tick / SimWorld.TICK_RATE
	_fund_shown = maxf(0.0, _fund_shown - delta)
	_top.text = "  Credits %d%s     Power %d / %d%s     Rank %s     %d:%02d" % [
		p.credits, "  (+%d fund)" % _fund_gain if _fund_shown > 0.0 else "",
		p.power_used, p.power_produced, "  LOW POWER" if p.low_power() else "",
		"*".repeat(p.rank) + ".".repeat(5 - p.rank), secs / 60, secs % 60]
	_debug.text = "tick %d | %d fps | state %08x  " % [world.tick, Engine.get_frames_per_second(), _last_hash]
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SEC
		refresh_commands()
		_selection_panel.text = SelectionText.describe(world, _selection.selected) if _selection != null else ""
	_layout()
	if world.game_over and not _banner.visible:
		var my_team: int = world.team_of(_runner.local_player_id)
		_banner.text = "DRAW" if world.winner_team == 0 else ("VICTORY" if world.winner_team == my_team else "DEFEAT")
		_banner.visible = true


func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_help.custom_minimum_size.x = minf(470.0, view.x * 0.37)   # clear of the power bar
	_help.size.x = _help.custom_minimum_size.x
	var margin: float = 10.0
	minimap.position = Vector2(margin, view.y - minimap.size.y - margin)
	if touch_bar != null:
		touch_bar.position = Vector2(margin, minimap.position.y - TouchBar.BUTTON_SIZE.y - 8.0)
	if power_bar != null:
		power_bar.position = Vector2((view.x - power_bar.get_combined_minimum_size().x) * 0.5, 40.0)
	var grid_size: Vector2 = command_grid.get_combined_minimum_size()
	command_grid.position = Vector2(view.x - grid_size.x - margin, view.y - grid_size.y - margin)
	_place_buttons.position = Vector2(view.x - grid_size.x - margin, command_grid.position.y - 60.0)
	_selection_panel.position = Vector2(minimap.position.x + minimap.size.x + 16.0, view.y - 110.0)
	_selection_panel.size.x = maxf(160.0, command_grid.position.x - _selection_panel.position.x - 16.0)
	_minimap_frame.position = minimap.position - Vector2(4, 4)
	_minimap_frame.size = minimap.size + Vector2(8, 8)
	_selection_frame.visible = _selection_panel.text != ""
	_selection_frame.position = _selection_panel.position - Vector2(10, 8)
	_selection_frame.size = Vector2(_selection_panel.size.x + 20, _selection_panel.get_combined_minimum_size().y + 16)
	_debug.position.x = view.x - _debug.size.x - margin
	if _banner.visible:
		_banner.position = (view - _banner.size) * 0.5
