class_name LanMenu
extends Control
## LAN game setup (P3-14a): host a game or join one by address. The host
## uses the main menu's map, credits and sides ("You" plays the host,
## "Enemy" the other player) and starts the match for both machines.

const GAME_SCENE: String = "res://scenes/main.tscn"

var menu: Control   ## the main menu (map, factions, credits)
var session: NetSession
var _status: Label
var _address: LineEdit
var _start: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.07, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "LAN game"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_button(box, "Host a game on this device", host).name = "Host"
	var join_row := HBoxContainer.new()
	box.add_child(join_row)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.placeholder_text = "Host address, e.g. 192.168.1.20"
	_address.custom_minimum_size = Vector2(380, 50)
	join_row.add_child(_address)
	var join_button := _button(join_row, "Join", func() -> void: join(_address.text.strip_edges()))
	join_button.name = "Join"
	join_button.custom_minimum_size = Vector2(170, 50)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560, 60)
	_status.text = "Both devices must be on the same network."
	box.add_child(_status)
	_start = _button(box, "Start the match", start_match)
	_start.name = "Start"
	_start.disabled = true
	_button(box, "Back", close).name = "Back"


func _process(_delta: float) -> void:
	if session != null and session.is_host:
		_start.disabled = not session.connected()


func _session() -> NetSession:
	if session == null:
		session = NetSession.new()
		session.name = "NetSession"
		# Under the tree root, so it survives the change to the match scene.
		get_tree().root.add_child(session)
		session.peer_joined.connect(func() -> void:
			_status.text = "The other player is here." + (" Press Start." if session.is_host else " Waiting for the host to start."))
		session.peer_left.connect(func() -> void: _status.text = "The other player left.")
		session.match_received.connect(_begin)
	return session


func host() -> void:
	var err: Error = _session().host()
	if err != OK:
		_status.text = "Could not host (port %d busy?)." % NetSession.PORT
		return
	var addresses: PackedStringArray = []
	for a: String in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127."):
			addresses.append(a)
	_status.text = "Hosting. The other player joins with: %s" % (", ".join(addresses) if not addresses.is_empty() else "this device's address")


func join(address: String) -> void:
	if address == "":
		_status.text = "Type the host's address first."
		return
	if _session().join(address) != OK:
		_status.text = "Could not connect to %s." % address
		return
	_status.text = "Connecting to %s..." % address


## Host: sends the match to the other player and starts it here too.
func start_match() -> void:
	if session == null or not session.is_host or not session.connected():
		return
	var content: ContentDb = menu.get("content")
	var sc: Dictionary = MatchConfig.lan(content, str(menu.get("map_id")), str(menu.get("faction")),
		str(menu.get("enemy")), content.skirmish_credits[int(menu.get("credits_index"))])
	var config: Dictionary = {"scenario": sc, "seed": int(Time.get_unix_time_from_system()) % 1000000,
		"content_hash": content.content_hash}
	session.start_match(config)
	_begin(config)


func _begin(config: Dictionary) -> void:
	# Both machines need the same game data and mods (P3-17), or lockstep
	# would desync at once.
	var content: ContentDb = menu.get("content") if menu != null else null
	if content != null and config.has("content_hash") and int(config["content_hash"]) != content.content_hash:
		_status.text = "The host has different game data or mods. Use the same version and mods on both devices."
		return
	MatchConfig.net = session
	MatchConfig.net_seed = int(config.get("seed", 0))
	MatchConfig.pending = config.get("scenario", {})
	get_tree().change_scene_to_file(GAME_SCENE)


func close() -> void:
	if session != null:
		session.close()
		session.queue_free()
		session = null
	queue_free()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
