class_name GameSettings
extends RefCounted
## Player settings (P1-35), saved in user://settings.cfg and applied live.
## GameSettings.current() loads them once; every screen reads and changes that
## one instance, then calls apply() and save().
##
## These are view and device settings only. Nothing here may reach the sim.

const PATH: String = "user://settings.cfg"
const FPS_CHOICES: Array[int] = [30, 60, 0]          ## 0 = unlimited
const RENDER_SCALES: Array[float] = [0.5, 0.67, 0.75, 0.85, 1.0]
const UI_SCALES: Array[float] = [0.75, 0.9, 1.0, 1.15, 1.3, 1.5]
const BUSES: Array[String] = ["Master", "Music", "SFX", "UI", "Voice"]
## Quality presets (P1-36): render scale, shadows, frame-rate limit.
const PRESETS: Dictionary = {
	"low": {"render_scale": 0.67, "shadows": false, "fps_cap": 30},
	"medium": {"render_scale": 0.85, "shadows": true, "fps_cap": 60},
	"high": {"render_scale": 1.0, "shadows": true, "fps_cap": 60},
}
## Devices with less memory than this start on the low preset.
const LOW_END_MEMORY_BYTES: int = 4500 * 1024 * 1024
## Battery saver forces these, whatever the other settings say.
const SAVER_FPS: int = 30
const SAVER_RENDER_SCALE: float = 0.67

static var _current: GameSettings
## Tests point this at a scratch file so they never touch real settings.
static var file_path: String = PATH

var render_scale: float = 1.0
var fps_cap: int = 60
var shadows: bool = true
var ui_scale: float = 1.0
var edge_pan: bool = true
var battery_saver: bool = false
## Accessibility (P3-20): team colors that stay apart with color blindness.
var colorblind_colors: bool = false
## Interface language (P3-18, Loc.LANGUAGES); "" follows the device.
var language: String = ""
## Bus name -> linear volume 0..1.
var volumes: Dictionary[String, float] = {"Master": 1.0, "Music": 0.7, "SFX": 1.0, "UI": 0.8, "Voice": 1.0}
## Action -> physical keycode, only for actions the player rebound.
var bindings: Dictionary[String, int] = {}


static func current() -> GameSettings:
	if _current == null:
		_current = GameSettings.new()
		if FileAccess.file_exists(file_path):
			_current.load_from(file_path)
		else:
			# First run: pick a preset that suits the device (P1-36).
			var mem: Dictionary = OS.get_memory_info()
			var low: bool = is_low_end(RenderingServer.get_current_rendering_method(), int(mem.get("physical", -1)))
			_current.apply_preset("low" if low else "high")
	return _current


## True for devices that should start on the low preset: no Vulkan (the game
## fell back to the Compatibility renderer) or little memory (-1 = unknown).
static func is_low_end(rendering_method: String, physical_bytes: int) -> bool:
	if rendering_method == "gl_compatibility":
		return true
	return physical_bytes > 0 and physical_bytes < LOW_END_MEMORY_BYTES


func apply_preset(preset: String) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["high"])
	render_scale = p["render_scale"]
	shadows = p["shadows"]
	fps_cap = p["fps_cap"]


## The preset the current values match, or "custom".
func preset_name() -> String:
	for name: String in PRESETS:
		var p: Dictionary = PRESETS[name]
		if is_equal_approx(render_scale, p["render_scale"]) and shadows == p["shadows"] and fps_cap == p["fps_cap"]:
			return name
	return "custom"


## The values actually used once battery saver is taken into account.
func effective_fps() -> int:
	return SAVER_FPS if battery_saver else fps_cap


func effective_render_scale() -> float:
	return minf(render_scale, SAVER_RENDER_SCALE) if battery_saver else render_scale


func effective_shadows() -> bool:
	return shadows and not battery_saver


## Applies everything to the running game. Safe to call at any time.
func apply(tree: SceneTree) -> void:
	Engine.max_fps = effective_fps()
	var root: Window = tree.root
	root.scaling_3d_scale = effective_render_scale()
	root.content_scale_factor = ui_scale
	for node: Node in tree.get_nodes_in_group("shadow_lights"):
		(node as Light3D).shadow_enabled = effective_shadows()
	GameSounds.ensure_buses()
	for bus: String in volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
			AudioServer.set_bus_mute(index, volumes[bus] <= 0.0)
	apply_bindings()
	TeamColors.colorblind = colorblind_colors
	Loc.use(language)


## Replaces the key of every rebound action (InputActions has the defaults).
func apply_bindings() -> void:
	InputActions.register()
	for action: String in InputActions.BINDINGS:
		var key: int = bindings.get(action, (InputActions.BINDINGS[action] as Array)[0])
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)


func key_for(action: String) -> int:
	return bindings.get(action, (InputActions.BINDINGS[action] as Array)[0])


## Rebinds an action. A key already used by another action is swapped onto
## that action, so no two actions share a key.
func rebind(action: String, keycode: int) -> void:
	var old: int = key_for(action)
	for other: String in InputActions.BINDINGS:
		if other != action and key_for(other) == keycode:
			bindings[other] = old
	bindings[action] = keycode


func reset_bindings() -> void:
	bindings.clear()


func save_to(path: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("video", "battery_saver", battery_saver)
	cfg.set_value("accessibility", "colorblind_colors", colorblind_colors)
	cfg.set_value("ui", "ui_scale", ui_scale)
	cfg.set_value("ui", "language", language)
	cfg.set_value("controls", "edge_pan", edge_pan)
	for bus: String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	for action: String in bindings:
		cfg.set_value("keys", action, bindings[action])
	return cfg.save(path)


func save() -> Error:
	return save_to(file_path)


## Forgets the loaded settings (tests use this after changing file_path).
static func reset_current() -> void:
	_current = null


## Loads settings; missing or invalid values keep their defaults.
func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.25, 1.0)
	var fps: int = int(cfg.get_value("video", "fps_cap", fps_cap))
	fps_cap = fps if FPS_CHOICES.has(fps) else 60
	shadows = bool(cfg.get_value("video", "shadows", shadows))
	battery_saver = bool(cfg.get_value("video", "battery_saver", battery_saver))
	colorblind_colors = bool(cfg.get_value("accessibility", "colorblind_colors", colorblind_colors))
	ui_scale = clampf(float(cfg.get_value("ui", "ui_scale", ui_scale)), 0.5, 2.0)
	language = str(cfg.get_value("ui", "language", language))
	if not Loc.LANGUAGES.has(language):
		language = ""
	edge_pan = bool(cfg.get_value("controls", "edge_pan", edge_pan))
	for bus: String in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes.get(bus, 1.0))), 0.0, 1.0)
	bindings.clear()
	if cfg.has_section("keys"):
		for action: String in cfg.get_section_keys("keys"):
			if InputActions.BINDINGS.has(action):
				bindings[action] = int(cfg.get_value("keys", action))
