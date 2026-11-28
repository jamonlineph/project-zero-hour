class_name ModAssets
extends RefCounted
## Models and icons that mods ship as plain files (P3-17): a .glb or .png
## under user:// isn't imported by Godot, so it is loaded at run time.
## Game assets (res://) go through the normal resource loader. View only.

static var _icons: Dictionary[String, Texture2D] = {}


## A new instance of the model, or null if there is none.
static func load_model(path: String) -> Node3D:
	if path == "":
		return null
	if not path.begins_with("user://"):
		if not ResourceLoader.exists(path):
			return null
		var scene: PackedScene = load(path)
		return scene.instantiate() if scene != null else null
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## The icon texture, or null if there is none.
static func load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not path.begins_with("user://"):
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if _icons.has(path):
		return _icons[path]
	var img := Image.load_from_file(path)
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	_icons[path] = tex
	return tex
