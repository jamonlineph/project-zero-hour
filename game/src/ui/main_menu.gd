extends Control
## Main menu and skirmish setup (P1-32). Built in code; big touch-friendly
## buttons. Starting a match stores a scenario in MatchConfig.pending and
## switches to the game scene.

const GAME_SCENE: String = "res://scenes/main.tscn"
## The first skirmish map in id order is the default (P2-12: Riverside).
const DEFAULT_MAP: String = "riverside"

var content: ContentDb
var faction: String = "us"
var enemy: String = "kp"   ## the computer's faction (P3-02a)
var credits_index: int = 1
var difficulty: String = "normal"   ## the computer opponent (P2-11)
var personality: String = "random"   ## its style (P3-13b, AiPersonality)
var team_mode: bool = false   ## 2v2 with a computer ally (P3-23b)
var map_id: String = DEFAULT_MAP
var _map_button: Button
var _difficulty_button: Button
var _style_button: Button
var _faction_button: Button
var _enemy_button: Button
var _credits_button: Button
var _mode_button: Button


func _ready() -> void:
	# Back from a LAN match: that session is over (P3-14a).
	if MatchConfig.net != null:
		MatchConfig.net.close()
		MatchConfig.net.queue_free()
		MatchConfig.net = null
	GameSettings.current().apply(get_tree())
	UiTheme.apply(get_tree())
	add_child(MusicPlayer.new())
	content = ContentDb.new()
	if not content.load_all(ContentDb.INDEX_PATH, ModLoader.mod_dirs()):   # mods (P3-17)
		for e: String in content.errors:
			push_error(e)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)   # fits 720p with the map and LAN rows
	center.add_child(box)

	var title := Label.new()
	title.text = "PROJECT ZERO HOUR"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "early development build" + ("   ·   mods: %s" % ", ".join(content.mods) if not content.mods.is_empty() else "")
	sub.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_map_button = _button(box, "", _cycle_map)
	_map_button.name = "Map"
	# Both sides on one row, so the menu still fits 720p.
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 8)
	box.add_child(sides)
	_faction_button = _button(sides, "", _cycle_faction)
	_faction_button.name = "Faction"
	_enemy_button = _button(sides, "", _cycle_enemy)
	_enemy_button.name = "Enemy"
	for b: Button in [_faction_button, _enemy_button]:
		b.custom_minimum_size = Vector2(206, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Credits and 1v1/2v2 share a row.
	var setup := HBoxContainer.new()
	setup.add_theme_constant_override("separation", 8)
	box.add_child(setup)
	_credits_button = _button(setup, "", _cycle_credits)
	_mode_button = _button(setup, "", _cycle_mode)
	_mode_button.name = "Mode"
	for b: Button in [_credits_button, _mode_button]:
		b.custom_minimum_size = Vector2(206, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Difficulty and style share a row, like the two sides.
	var computer := HBoxContainer.new()
	computer.add_theme_constant_override("separation", 8)
	box.add_child(computer)
	_difficulty_button = _button(computer, "", _cycle_difficulty)
	_difficulty_button.name = "Difficulty"
	_style_button = _button(computer, "", _cycle_style)
	_style_button.name = "Style"
	for b: Button in [_difficulty_button, _style_button]:
		b.custom_minimum_size = Vector2(206, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Start skirmish vs computer", start_skirmish).name = "StartSkirmish"
	_button(box, "Watch computer vs computer", start_watch).name = "Watch"
	_button(box, "LAN game (two devices)", open_lan).name = "Lan"
	_button(box, "Gauntlet: seven commanders", open_gauntlet).name = "Gauntlet"
	# Load and the sandbox share a row (P4-03 made room for the Gauntlet).
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 8)
	box.add_child(extra)
	_button(extra, "Load game", open_load).name = "LoadGame"
	_button(extra, "Sandbox", start_sandbox).name = "Sandbox"
	for b: Node in extra.get_children():
		(b as Button).custom_minimum_size = Vector2(206, 46)
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Settings and credits share a row (P4-06).
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", 8)
	box.add_child(more)
	_button(more, "Settings", open_settings).name = "Settings"
	_button(more, "Credits", open_credits).name = "Credits"
	for b: Node in more.get_children():
		(b as Button).custom_minimum_size = Vector2(206, 46)
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Quit", func() -> void: get_tree().quit())
	_refresh_labels()
	DevCapture.attach_if_requested(self)
	# `godot --path game -- --scenario=<id>` skips the menu and starts that match.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			var id: String = arg.trim_prefix("--scenario=")
			if content.scenarios.has(id):
				_start.call_deferred(content.scenarios[id])
			else:
				push_error("Unknown scenario '%s'" % id)
		elif arg == "--open=load":
			open_load.call_deferred()
		elif arg == "--open=lan":
			open_lan.call_deferred()
		elif arg == "--open=credits":
			open_credits.call_deferred()
		elif arg == "--open=gauntlet":
			open_gauntlet.call_deferred()
		# `-- --watch=<map> [--side=<faction>]` starts computer vs computer on
		# that map; --side picks player 1's faction (the HUD's point of view).
		elif arg.begins_with("--watch="):
			var watch_map: String = arg.trim_prefix("--watch=")
			faction = DevCapture.arg("side", faction)
			enemy = DevCapture.arg("enemy", MatchConfig.default_enemy(faction))
			if content.maps.has(watch_map) and MatchConfig.FACTIONS.has(faction) and MatchConfig.FACTIONS.has(enemy):
				map_id = watch_map
				team_mode = content.maps[watch_map].start_positions.size() >= 4
				start_watch.call_deferred()
			else:
				push_error("Unknown map '%s'" % watch_map)


func start_skirmish() -> void:
	_start(_scenario(false))


func start_watch() -> void:
	_start(_scenario(true))


## The 1v1 or 2v2 skirmish the menu describes (watching: computer vs computer).
func _scenario(watch: bool) -> Dictionary:
	var credits: int = content.skirmish_credits[credits_index]
	if team_mode:
		return MatchConfig.skirmish_2v2(content, map_id, faction, credits, watch,
			"normal" if watch else difficulty, enemy, "balanced" if watch else personality)
	if watch:
		return MatchConfig.skirmish(content, map_id, faction, credits, true, "normal", enemy)
	return MatchConfig.skirmish(content, map_id, faction, credits, false, difficulty, enemy, personality)


func start_sandbox() -> void:
	_start(content.scenarios.get("sandbox", {}))


func open_lan() -> LanMenu:
	var lan := LanMenu.new()
	lan.name = "LanMenu"
	lan.menu = self
	add_child(lan)
	return lan


func open_load() -> LoadMenu:
	var menu := LoadMenu.new()
	menu.name = "LoadMenu"
	menu.chosen.connect(load_game)
	add_child(menu)
	return menu


## Starts a saved game (SaveGame.read data).
func load_game(data: Dictionary) -> void:
	MatchConfig.load_save = data
	_start(data.get("scenario_data", {}))


func open_gauntlet() -> GauntletMenu:
	var g := GauntletMenu.new()
	g.name = "GauntletMenu"
	g.menu = self
	add_child(g)
	return g


func open_credits() -> CreditsMenu:
	var menu := CreditsMenu.new()
	menu.name = "CreditsMenu"
	add_child(menu)
	return menu


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


func _cycle_enemy() -> void:
	var ids: Array = MatchConfig.FACTIONS.keys()
	enemy = ids[(ids.find(enemy) + 1) % ids.size()]
	_refresh_labels()


## Maps offered for skirmish (MapDef.skirmish) in the current mode, in id
## order: 1v1 maps have two start positions, 2v2 maps four (P3-23b).
func skirmish_maps() -> Array[String]:
	var ids: Array[String] = []
	for id: String in content.maps:
		var m: MapDef = content.maps[id]
		if m.skirmish and m.start_positions.size() == (4 if team_mode else 2):
			ids.append(id)
	ids.sort()
	return ids


func _cycle_mode() -> void:
	team_mode = not team_mode
	var ids: Array[String] = skirmish_maps()
	if ids.is_empty():
		team_mode = not team_mode
		return
	map_id = DEFAULT_MAP if not team_mode and ids.has(DEFAULT_MAP) else ids[0]
	_refresh_labels()


func _cycle_map() -> void:
	var ids: Array[String] = skirmish_maps()
	if not ids.is_empty():
		map_id = ids[(ids.find(map_id) + 1) % ids.size()]
	_refresh_labels()


func _cycle_difficulty() -> void:
	var levels: Array[String] = ["easy", "normal", "hard"]
	difficulty = levels[(levels.find(difficulty) + 1) % levels.size()]
	_refresh_labels()


func _cycle_style() -> void:
	var styles: Array[String] = ["random"]
	styles.append_array(AiPersonality.NAMES)
	personality = styles[(styles.find(personality) + 1) % styles.size()]
	_refresh_labels()


func _cycle_credits() -> void:
	credits_index = (credits_index + 1) % content.skirmish_credits.size()
	_refresh_labels()


func _refresh_labels() -> void:
	var map: MapDef = content.get_map(map_id)
	_map_button.text = "Map: %s   (tap to change)" % (map.name if map != null else map_id)
	_faction_button.text = "You: %s" % MatchConfig.FACTIONS[faction]
	_enemy_button.text = "Enemy: %s" % MatchConfig.FACTIONS[enemy]
	_credits_button.text = "Credits: %d" % content.skirmish_credits[credits_index]
	_mode_button.text = "Mode: %s" % ("2v2 with ally" if team_mode else "1v1")
	_difficulty_button.text = "Computer: %s" % difficulty.capitalize()
	_style_button.text = "Style: %s" % personality.capitalize()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 46)   # 46: eleven rows fit 720p (P3-14a)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
