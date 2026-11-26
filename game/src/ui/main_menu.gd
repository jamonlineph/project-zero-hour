extends Control
## Main menu and skirmish setup (P1-32). Built in code; big touch-friendly
## buttons. Starting a match stores a scenario in MatchConfig.pending and
## switches to the game scene.

const GAME_SCENE: String = "res://scenes/main.tscn"
const MAP_ID: String = "sandbox"

var content: ContentDb
var faction: String = "us"
var credits_index: int = 1
var _faction_button: Button
var _credits_button: Button


func _ready() -> void:
	GameSettings.current().apply(get_tree())
	content = ContentDb.new()
	if not content.load_all():
		for e: String in content.errors:
			push_error(e)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "SIGNAL FRONT"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "codename  -  early development build"
	sub.modulate = Color(1, 1, 1, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_faction_button = _button(box, "", _cycle_faction)
	_credits_button = _button(box, "", _cycle_credits)
	_button(box, "Start skirmish vs computer", start_skirmish).name = "StartSkirmish"
	_button(box, "Watch computer vs computer", start_watch).name = "Watch"
	_button(box, "Sandbox (developer test map)", start_sandbox).name = "Sandbox"
	_button(box, "Settings", open_settings).name = "Settings"
	_button(box, "Quit", func() -> void: get_tree().quit())
	_refresh_labels()


func start_skirmish() -> void:
	_start(MatchConfig.skirmish(content, MAP_ID, faction, content.skirmish_credits[credits_index]))


func start_watch() -> void:
	_start(MatchConfig.skirmish(content, MAP_ID, faction, content.skirmish_credits[credits_index], true))


func start_sandbox() -> void:
	_start(content.scenarios.get("sandbox", {}))


func open_settings() -> SettingsMenu:
	var menu := SettingsMenu.new()
	menu.name = "SettingsMenu"
	add_child(menu)
	return menu


func _start(scenario: Dictionary) -> void:
	MatchConfig.pending = scenario
	get_tree().change_scene_to_file(GAME_SCENE)


func _cycle_faction() -> void:
	var ids: Array = MatchConfig.FACTIONS.keys()
	faction = ids[(ids.find(faction) + 1) % ids.size()]
	_refresh_labels()


func _cycle_credits() -> void:
	credits_index = (credits_index + 1) % content.skirmish_credits.size()
	_refresh_labels()


func _refresh_labels() -> void:
	_faction_button.text = "Your side: %s   (tap to change)" % MatchConfig.FACTIONS[faction]
	_credits_button.text = "Starting credits: %d   (tap to change)" % content.skirmish_credits[credits_index]


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
