extends Node3D

const SceneVisuals := preload("res://src/core/scene_visuals.gd")

@onready var cam: Camera3D = $Camera3D
var _out := ""
var _shot := ""
var _frames := 0
var _done := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.substr("--shot=".length())
		elif arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

	# Configure camera & actors for each close-up
	if _shot == "house":
		$KosRoom.visible = false
		$Actors.visible = false
		cam.position = Vector3(-1.85, 2.75, 5.85)
		cam.look_at(Vector3(-1.25, 1.45, -1.10), Vector3.UP)
	elif _shot == "gang":
		$KosRoom.visible = false
		$KampungStreet.visible = false
		var gang_scene: PackedScene = load("res://assets/models/kampung_gang.glb")
		if gang_scene != null:
			var gang_inst: Node3D = gang_scene.instantiate()
			add_child(gang_inst)
		$Actors/IbuSari.position = Vector3(-1.4, 0.02, 0.25)
		$Actors/PlayerArt.position = Vector3(0.1, 0.02, 0.10)
		$Actors/PakBudi.position = Vector3(1.5, 0.02, 0.25)
		cam.position = Vector3(2.8, 3.8, 5.8)
		cam.look_at(Vector3(0.0, 1.1, -0.8), Vector3.UP)
	elif _shot == "props":
		$KosRoom.visible = false
		$Actors.visible = false
		cam.position = Vector3(-0.6, 2.35, 6.8)
		cam.look_at(Vector3(-0.6, 0.65, 1.6), Vector3.UP)
	elif _shot == "chars":
		$KosRoom.visible = false
		$KampungStreet.visible = true
		cam.position = Vector3(-0.6, 1.45, 4.4)
		cam.look_at(Vector3(-0.6, 0.85, 1.4), Vector3.UP)
		$Actors/IbuSari.position = Vector3(-1.55, 0.02, 1.4)
		$Actors/PlayerArt.position = Vector3(-0.60, 0.02, 1.4)
		$Actors/PakBudi.position = Vector3(0.35, 0.02, 1.4)
		$Actors/IbuSari.rotation_degrees.y = 14
		$Actors/PlayerArt.rotation_degrees.y = 0
		$Actors/PakBudi.rotation_degrees.y = -14
	elif _shot == "room":
		$KampungStreet.visible = false
		$Actors.visible = false
		$KosRoom.visible = true
		cam.position = Vector3(3.6, 3.35, 3.6)
		cam.look_at(Vector3(-0.15, 0.80, -0.55), Vector3.UP)
	elif _shot in ["majikan_living", "kamar_small", "kamar_large"]:
		$KampungStreet.visible = false
		$KosRoom.visible = false
		$Actors/IbuSari.visible = false
		$Actors/PakBudi.visible = false
		var model_path := "res://assets/models/room_majikan_living.glb"
		if _shot == "kamar_small":
			model_path = "res://assets/models/kamar_art_small.glb"
		elif _shot == "kamar_large":
			model_path = "res://assets/models/kamar_art_large.glb"
		var room_scene: PackedScene = load(model_path)
		if room_scene != null:
			var r_inst: Node3D = room_scene.instantiate()
			add_child(r_inst)
		$Actors/PlayerArt.position = Vector3(-0.25, 0.02, 1.15)
		$Actors/PlayerArt.rotation_degrees.y = -20
		if _shot == "kamar_small":
			cam.position = Vector3(3.2, 3.0, 3.2)
			cam.look_at(Vector3(-0.1, 0.75, -0.2), Vector3.UP)
		elif _shot == "majikan_living":
			cam.position = Vector3(4.9, 4.3, 4.9)
			cam.look_at(Vector3(-0.1, 0.90, -0.2), Vector3.UP)
		else:
			cam.position = Vector3(4.2, 3.8, 4.2)
			cam.look_at(Vector3(-0.1, 0.85, -0.2), Vector3.UP)

	var idx := 0
	for a in $Actors.get_children():
		_play_idle(a, idx)
		idx += 1
	SceneVisuals.apply_baked_ao(self)

func _play_idle(node: Node, actor_idx: int = 0) -> void:
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		var list: PackedStringArray = ap.get_animation_list()
		for a_name in list:
			if "idle" in a_name.to_lower():
				ap.play(a_name)
				ap.seek(actor_idx * 0.55, true)
				return
		if not list.is_empty():
			ap.play(list[0])
		return
	for c in node.get_children():
		_play_idle(c, actor_idx)

func _process(_delta: float) -> void:
	if _out != "" and not _done:
		_frames += 1
		if _frames >= 4:
			_done = true
			call_deferred("_capture")

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("STUDIO CAPTURED:", _shot, _out)
	get_tree().quit(0)
