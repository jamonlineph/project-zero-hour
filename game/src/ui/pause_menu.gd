class_name PauseMenu
extends Control
## Pause menu and end-of-match screen (P1-32). Escape (or the HUD's Menu
## button) opens it; it pauses the simulation in single player.

const MENU_SCENE: String = "res://scenes/menu.tscn"

var runner: SimRunner
var _title: Label
var _resume: Button


func setup(sim_runner: SimRunner) -> void:
	runner = sim_runner


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_resume = _button(box, "Resume", close)
	_button(box, "Save replay", save_replay)
	_button(box, "Settings", open_settings)
	_button(box, "Quit to menu", quit_to_menu)


func open_paused() -> void:
	_title.text = "Paused"
	_resume.visible = true
	visible = true
	if runner != null:
		runner.paused = true


func open_game_over(text: String) -> void:
	_title.text = text
	_resume.visible = false
	visible = true


func close() -> void:
	visible = false
	if runner != null and not runner.world.game_over:
		runner.paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open_paused()


func save_replay() -> void:
	var path: String = "user://replays/replay_%d.json" % Time.get_unix_time_from_system()
	var err: Error = runner.make_replay().save(path)
	_title.text = "Replay saved" if err == OK else "Could not save (%s)" % error_string(err)


func open_settings() -> SettingsMenu:
	var menu := SettingsMenu.new()
	menu.name = "SettingsMenu"
	add_child(menu)
	return menu


func quit_to_menu() -> void:
	MatchConfig.pending = {}
	get_tree().change_scene_to_file(MENU_SCENE)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
