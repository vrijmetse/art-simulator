extends Node3D

@onready var player_node: Node3D = $PlayerArt

var _capture_path := ""
var _frame_count := 0
var _captured := false

func _ready() -> void:
	_play_idle(player_node)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-room="):
			_capture_path = arg.substr("--capture-room=".length())

func _play_idle(node: Node) -> void:
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		var list: PackedStringArray = ap.get_animation_list()
		for a_name in list:
			if "idle" in a_name.to_lower():
				ap.play(a_name)
				return
		if not list.is_empty():
			ap.play(list[0])
		return
	for c in node.get_children():
		_play_idle(c)

func _on_exit_house_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/street_poc.tscn")

func _process(_delta: float) -> void:
	if _capture_path != "" and not _captured:
		_frame_count += 1
		if _frame_count >= 4:
			_captured = true
			call_deferred("_do_capture")

func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture_path)
	print("CAPTURED ROOM PNG:", _capture_path, "size=", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
