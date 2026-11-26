class_name Hud
extends CanvasLayer
## Minimal developer HUD: a status line, control hints and the selection box.
## The real HUD comes in Phase 1 (P1-25, docs/design/controls-and-ui.md).

const HELP_TEXT := "Debug build (select an engineer, point, press): N power, B barracks, L logistics hub, V vehicle factory. P: queue a unit in selected buildings.\nMouse: left-click/drag select, right-click move/attack, A+click attack-move, H hold, S stop, wheel zoom, middle-drag pan, arrows pan, , . rotate\nTouch: tap unit select, tap enemy attack, tap ground move, drag pan, hold then drag box-select, double-tap select same type, pinch zoom/rotate"

var selection_box: SelectionBox
var _runner: SimRunner
var _status: Label
var _help: Label
var _banner: Label
var _selected_count: int = 0
var _last_hash: int = 0


func _ready() -> void:
	selection_box = SelectionBox.new()
	selection_box.name = "SelectionBox"
	add_child(selection_box)
	_status = Label.new()
	_status.name = "Status"
	_status.position = Vector2(12, 8)
	add_child(_status)
	_help = Label.new()
	_help.name = "Help"
	_help.text = HELP_TEXT
	_help.modulate = Color(1, 1, 1, 0.8)
	add_child(_help)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.visible = false
	add_child(_banner)


func setup(runner: SimRunner) -> void:
	_runner = runner
	_runner.ticked.connect(_on_ticked)


func on_selection_changed(ids: Array[int]) -> void:
	_selected_count = ids.size()


func _on_ticked(tick: int) -> void:
	# Hashing every tick is wasteful; once per second is enough for a debug line.
	if tick % SimWorld.TICK_RATE == 0:
		_last_hash = _runner.world.state_hash()


func _process(_delta: float) -> void:
	if _runner == null or _runner.world == null:
		return
	var p: SimPlayer = _runner.world.get_player(_runner.local_player_id)
	_status.text = "Credits %d | Power %d/%d%s | Rank %s (%d XP) | tick %d | %d fps | selected %d | state %08x" % [
		p.credits, p.power_used, p.power_produced, " LOW" if p.low_power() else "",
		"*".repeat(p.rank), p.xp, _runner.world.tick, Engine.get_frames_per_second(), _selected_count, _last_hash]
	if _runner.world.game_over and not _banner.visible:
		var my_team: int = _runner.world.team_of(_runner.local_player_id)
		_banner.text = "DRAW" if _runner.world.winner_team == 0 else ("VICTORY" if _runner.world.winner_team == my_team else "DEFEAT")
		_banner.visible = true
	if _banner.visible:
		_banner.position = (get_viewport().get_visible_rect().size - _banner.size) * 0.5
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_help.position = Vector2(12.0, view_size.y - _help.size.y - 12.0)
