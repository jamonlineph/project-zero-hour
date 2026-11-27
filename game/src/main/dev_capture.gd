class_name DevCapture
extends Node
## Developer screenshots: run the game with
##   godot --path game -- --screenshot=/tmp/shot.png [--screenshot-frames=90]
##     [--camera=<x_m>,<z_m>,<distance_m>] [--reveal]
## --camera aims the camera at a map point, --reveal lifts the fog (view only).
## and it saves the rendered frame after that many frames, then quits. Works
## on machines without a screen through a virtual display and software OpenGL
## (see docs/08-testing-and-qa.md). Does nothing without the argument.

var path: String = ""
var frames_left: int = 90


## Adds a DevCapture to `host` when --screenshot= was given.
static func attach_if_requested(host: Node) -> void:
	var shot: String = ""
	var frames: int = 90
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--screenshot-frames="):
			frames = maxi(1, arg.trim_prefix("--screenshot-frames=").to_int())
	if shot == "" or DisplayServer.get_name() == "headless":
		return
	var cap := DevCapture.new()
	cap.name = "DevCapture"
	cap.path = shot
	cap.frames_left = frames
	host.add_child(cap)


## The --camera=x,z,distance point as (x, z, distance), or null.
static func camera_override() -> Variant:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			var parts: PackedStringArray = arg.trim_prefix("--camera=").split(",")
			if parts.size() == 3:
				return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	return null


static func reveal_requested() -> bool:
	return OS.get_cmdline_user_args().has("--reveal")


func _process(_delta: float) -> void:
	frames_left -= 1
	if frames_left > 0:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	print("DevCapture: saved %s (%s)" % [path, error_string(err)])
	get_tree().quit()
