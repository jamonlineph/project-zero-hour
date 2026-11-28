class_name PowerBar
extends HBoxContainer
## Commander power bar (P2-09b): a "Commander" button that opens the power
## tree, then one button per chosen power with its cooldown. Targeted powers
## arm the next click or tap on the map (SelectionController.power_armed).

const BUTTON_SIZE := Vector2(118, 48)

var runner: SimRunner
var selection: SelectionController
var player_id: int = 1
var commander_button: Button
var _power_buttons: Dictionary[String, Button] = {}
var _shown_powers: PackedStringArray = []
var _panel: CommanderPanel


func setup(sim_runner: SimRunner, selection_controller: SelectionController, local_player: int) -> void:
	name = "PowerBar"
	runner = sim_runner
	selection = selection_controller
	player_id = local_player
	add_theme_constant_override("separation", 6)
	commander_button = _button("Commander")
	commander_button.name = "Commander"
	commander_button.pressed.connect(open_commander)
	refresh()


func _process(_delta: float) -> void:
	if runner != null and Engine.get_process_frames() % 10 == 0:
		refresh()


## Rebuilds the buttons when the chosen powers change; updates cooldowns.
func refresh() -> void:
	var world: SimWorld = runner.world
	var player: SimPlayer = world.get_player(player_id)
	var points: int = CommanderPowers.points(player)
	commander_button.text = Loc.t("Commander\n%d point%s") % [points, "" if points == 1 else "s"] if points > 0 else "Commander"
	var usable := PackedStringArray()
	for id: String in player.powers:
		var def: PowerDef = world.content.get_power(id)
		if def != null and def.kind != "unlock":
			usable.append(id)
	if usable != _shown_powers:
		_shown_powers = usable
		for b: Button in _power_buttons.values():
			b.queue_free()
		_power_buttons.clear()
		for id: String in usable:
			var b := _button("")
			b.name = "Power_" + id
			b.pressed.connect(press_power.bind(id))
			_power_buttons[id] = b
	for id: String in _power_buttons:
		var def: PowerDef = world.content.get_power(id)
		var left: int = int(player.power_ready.get(id, 0)) - world.tick
		var b: Button = _power_buttons[id]
		b.disabled = left > 0
		b.text = Loc.t(def.name) if left <= 0 else "%s\n%d s" % [Loc.t(def.name), ceili(left / float(SimWorld.TICK_RATE))]
		b.tooltip_text = Loc.t(def.description)


## Uses a power now, or arms it for the next click when it needs a point.
func press_power(power_id: String) -> void:
	var def: PowerDef = runner.world.content.get_power(power_id)
	if def == null:
		return
	if def.targeted:
		selection.disarm()
		selection.power_armed = power_id
	else:
		runner.submit(SimCommand.make_use_power(power_id, 0, 0))


func open_commander() -> CommanderPanel:
	if _panel != null and is_instance_valid(_panel):
		return _panel
	_panel = CommanderPanel.new()
	get_parent().add_child(_panel)
	_panel.setup(runner, player_id)
	return _panel


func power_button(power_id: String) -> Button:
	return _power_buttons.get(power_id, null)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	add_child(b)
	return b
